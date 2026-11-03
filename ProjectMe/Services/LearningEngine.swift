import Foundation
import SwiftData

/// "De app leert van de gebruiker."
/// Alles gebeurt lokaal op het toestel, met eenvoudige, uitlegbare regels:
/// - herinneringen schuiven mee naar het moment waarop je echt incheckt;
/// - motivatieberichtjes volgen wat je ❤️ vindt;
/// - oefeningen worden gerangschikt op wat bij jóu helpt;
/// - patronen tussen pijn, water, meditatie en triggers worden zichtbaar.
@MainActor
enum LearningEngine {

    // MARK: Herinneringstijden

    enum CheckInKind { case morning, evening }

    /// Mediaan van het tijdstip waarop je de laatste 14 keer incheckte, iets eerder gezet
    /// zodat de herinnering je net vóór je natuurlijke moment bereikt.
    static func learnedReminderMinutes(_ kind: CheckInKind, in context: ModelContext) -> Int? {
        let since = Date.now.adding(days: -21)
        let minutes: [Int]
        switch kind {
        case .morning:
            let d = FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.createdAt >= since })
            minutes = ((try? context.fetch(d)) ?? []).map(\.createdAt.minutesSinceMidnight)
        case .evening:
            let d = FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.createdAt >= since })
            minutes = ((try? context.fetch(d)) ?? []).map(\.createdAt.minutesSinceMidnight)
        }
        guard minutes.count >= 3 else { return nil }
        let sorted = minutes.suffix(14).sorted()
        let median = sorted[sorted.count / 2]
        let wake = AppGroup.defaults.integer(forKey: PrefKey.wakeMinutes)
        let bed = AppGroup.defaults.integer(forKey: PrefKey.bedMinutes)
        let nudged = median - 10
        switch kind {
        case .morning: return min(max(nudged, wake), wake + 4 * 60)
        case .evening: return min(max(nudged, 18 * 60), max(18 * 60, bed - 15))
        }
    }

    static func effectiveReminderMinutes(_ kind: CheckInKind, in context: ModelContext) -> Int {
        let d = AppGroup.defaults
        let base = d.integer(forKey: kind == .morning ? PrefKey.morningReminderMinutes : PrefKey.eveningReminderMinutes)
        guard d.bool(forKey: PrefKey.adaptiveTiming), let learned = learnedReminderMinutes(kind, in: context) else {
            return base
        }
        return learned
    }

    // MARK: Motivatie

    static func recordReaction(messageID: String, liked: Bool, in context: ModelContext) {
        let category = MotivationLibrary.message(id: messageID)?.category.rawValue ?? "ai"
        context.insert(MotivationReaction(messageID: messageID, category: category, liked: liked))
        try? context.save()
        recomputeMotivationWeights(in: context)
    }

    static func recomputeMotivationWeights(in context: ModelContext) {
        let reactions = (try? context.fetch(FetchDescriptor<MotivationReaction>())) ?? []
        var weights: [String: Double] = [:]
        for category in MotivationCategory.allCases {
            let relevant = reactions.filter { $0.category == category.rawValue }
            let likes = Double(relevant.filter(\.liked).count)
            let dislikes = Double(relevant.filter { !$0.liked }.count)
            weights[category.rawValue] = min(3, max(0.3, 1 + 0.35 * likes - 0.35 * dislikes))
        }
        for reaction in reactions {
            weights[reaction.messageID] = reaction.liked ? 1.5 : 0.15
        }
        Prefs.setMotivationWeights(weights)
    }

    static func favoriteCategory(in context: ModelContext) -> MotivationCategory? {
        let weights = Prefs.motivationWeights
        return MotivationCategory.allCases
            .map { ($0, weights[$0.rawValue] ?? 1) }
            .filter { $0.1 > 1 }
            .max { $0.1 < $1.1 }?.0
    }

    // MARK: Oefeningen

    struct Suggestion: Identifiable {
        let exercise: Exercise
        let reason: String
        var id: String { exercise.id }
    }

    /// Rangschikt oefeningen voor vanavond, op basis van waar de pijn zit,
    /// wat eerder hielp (je eigen beoordeling) en of de pijn de dag erna lager was.
    static func suggestions(jaw: Int, neck: Int, limit: Int = 3, in context: ModelContext) -> [Suggestion] {
        let sessions = (try? context.fetch(FetchDescriptor<ExerciseSession>())) ?? []
        let evenings = (try? context.fetch(FetchDescriptor<EveningCheckIn>(sortBy: [SortDescriptor(\.day)]))) ?? []
        let painByDay = Dictionary(evenings.map { ($0.day, $0.maxPain) }, uniquingKeysWith: { a, _ in a })

        let focus: PainArea = jaw == neck ? .both : (jaw > neck ? .jaw : .neck)
        let threeDaysAgo = Date.now.adding(days: -3)

        let scored: [(Exercise, Double, String)] = ExerciseLibrary.all.map { exercise in
            var score = 0.0
            var reason = exercise.area == .both ? "Goed voor kaak én nek" : "Goed voor je \(exercise.area.title.lowercased())"

            if exercise.area == focus || exercise.area == .both || focus == .both { score += 2 }
            if max(jaw, neck) >= 6 && exercise.isGentle { score += 1; reason = "Zacht, voor een pijnlijke dag" }

            let mine = sessions.filter { $0.exerciseID == exercise.id }
            let rated = mine.filter { $0.helpfulness != 0 }
            if !rated.isEmpty {
                let avg = Double(rated.reduce(0) { $0 + $1.helpfulness }) / Double(rated.count)
                score += avg * 1.8
                if avg > 0.3 { reason = "Hielp jou eerder \(rated.filter { $0.helpfulness > 0 }.count)×" }
            }

            // Effect op de volgende dag: lager = beter.
            let deltas: [Double] = mine.compactMap { session in
                let day = session.date.startOfDay
                guard let today = painByDay[day], let next = painByDay[day.adding(days: 1)] else { return nil }
                return Double(today - next)
            }
            if deltas.count >= 2 {
                let effect = deltas.reduce(0, +) / Double(deltas.count)
                score += effect * 0.5
                if effect >= 1 { reason = "Je pijn was daarna vaak lager" }
            }

            if mine.isEmpty { score += 0.4; if rated.isEmpty && score < 2.5 { reason = "Nieuw om te proberen" } }
            if mine.contains(where: { $0.date >= threeDaysAgo }) { score -= 0.3 }
            return (exercise, score, reason)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { Suggestion(exercise: $0.0, reason: $0.2) }
    }

    // MARK: Water

    /// Meest gebruikte glasgrootte van de afgelopen 30 dagen.
    static func preferredGlassSize(in context: ModelContext) -> Int {
        let since = Date.now.adding(days: -30)
        let logs = (try? context.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= since }))) ?? []
        let counts = Dictionary(grouping: logs, by: \.amountML).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? 250
    }

    /// Hoeveel je volgens je eigen ritme rond dit moment ongeveer op hebt.
    static func expectedWater(at date: Date = .now) -> Int {
        let wake = AppGroup.defaults.integer(forKey: PrefKey.wakeMinutes)
        let bed = AppGroup.defaults.integer(forKey: PrefKey.bedMinutes)
        let now = date.minutesSinceMidnight
        let span = max(60, bed - 60 - wake)
        let fraction = min(1, max(0, Double(now - wake) / Double(span)))
        return Int(Double(Prefs.waterGoalML) * fraction)
    }

    // MARK: Inzichten

    struct Insight: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
        let tint: InsightTint
    }
    enum InsightTint { case water, sage, dusk, dawn, rose }

    static func insights(in context: ModelContext) -> [Insight] {
        let since = Date.now.adding(days: -60).startOfDay
        let evenings = (try? context.fetch(FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day >= since }))) ?? []
        let mornings = (try? context.fetch(FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day >= since }))) ?? []
        let water = (try? context.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= since }))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ExerciseSession>(predicate: #Predicate { $0.date >= since }))) ?? []

        var result: [Insight] = []
        let goal = Prefs.waterGoalML
        let waterByDay = Dictionary(grouping: water, by: { $0.date.startOfDay }).mapValues { $0.reduce(0) { $0 + $1.amountML } }

        // 1. Water ↔ pijn
        let hit = evenings.filter { (waterByDay[$0.day] ?? 0) >= goal }
        let miss = evenings.filter { (waterByDay[$0.day] ?? 0) < goal }
        if hit.count >= 3, miss.count >= 3 {
            let diff = average(miss.map(\.maxPain)) - average(hit.map(\.maxPain))
            if abs(diff) >= 0.5 {
                result.append(Insight(
                    symbol: "drop.fill",
                    title: diff > 0 ? "Water lijkt te helpen" : "Water en pijn",
                    detail: diff > 0
                        ? "Op dagen dat je je \(goal / 1000) liter haalde, was je pijn gemiddeld \(format(diff)) punt lager."
                        : "Op dagen met genoeg water was je pijn niet lager. Iets anders speelt misschien mee.",
                    tint: .water))
            }
        }

        // 2. Avondmeditatie ↔ pijn de volgende dag
        let eveningByDay = Dictionary(evenings.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        var afterMeditation: [Int] = [], afterNone: [Int] = []
        for evening in evenings {
            guard let next = eveningByDay[evening.day.adding(days: 1)] else { continue }
            if evening.meditationCompleted { afterMeditation.append(next.maxPain) } else { afterNone.append(next.maxPain) }
        }
        if afterMeditation.count >= 3, afterNone.count >= 3 {
            let diff = average(afterNone) - average(afterMeditation)
            if diff >= 0.5 {
                result.append(Insight(symbol: "moon.stars.fill", title: "Avondrust werkt door",
                                      detail: "Na een avondmeditatie was je pijn de volgende dag gemiddeld \(format(diff)) punt lager.",
                                      tint: .dusk))
            }
        }

        // 3. Triggers op pijnlijke dagen
        let painful = evenings.filter { $0.maxPain >= 6 }
        if painful.count >= 3 {
            let counts = Dictionary(grouping: painful.flatMap(\.triggers), by: { $0 }).mapValues(\.count)
            if let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 {
                result.append(Insight(symbol: "exclamationmark.bubble", title: "Let op: \(top.key.lowercased())",
                                      detail: "Op \(top.value) van je \(painful.count) pijnlijkste dagen noteerde je \(top.key.lowercased()).",
                                      tint: .rose))
            }
        }

        // 4. Oefening die het meest helpt
        let helpful = Dictionary(grouping: sessions.filter { $0.helpfulness > 0 }, by: \.exerciseID).mapValues(\.count)
        if let best = helpful.max(by: { $0.value < $1.value }), best.value >= 2,
           let exercise = ExerciseLibrary.exercise(id: best.key) {
            result.append(Insight(symbol: exercise.symbol, title: "Jouw favoriete oefening",
                                  detail: "\(exercise.title) hielp je al \(best.value) keer. Bewaar hem voor zware dagen.",
                                  tint: .sage))
        }

        // 5. Stemming ↔ dankbaarheid
        let fullGratitude = mornings.filter { $0.gratitudes.filter { !$0.isEmpty }.count >= 3 }
        if fullGratitude.count >= 3 {
            result.append(Insight(symbol: "sun.max.fill", title: "Dankbaarheid groeit",
                                  detail: "Je schreef al \(mornings.flatMap(\.gratitudes).filter { !$0.isEmpty }.count) dingen op waar je dankbaar voor bent.",
                                  tint: .dawn))
        }

        // 6. Trend: deze week vs vorige week
        let weekAgo = Date.now.adding(days: -7).startOfDay
        let twoWeeksAgo = Date.now.adding(days: -14).startOfDay
        let thisWeek = evenings.filter { $0.day >= weekAgo }.map(\.maxPain)
        let lastWeek = evenings.filter { $0.day >= twoWeeksAgo && $0.day < weekAgo }.map(\.maxPain)
        if thisWeek.count >= 3, lastWeek.count >= 3 {
            let diff = average(lastWeek) - average(thisWeek)
            if diff >= 0.5 {
                result.append(Insight(symbol: "chart.line.downtrend.xyaxis", title: "Rustiger dan vorige week",
                                      detail: "Je pijn ligt deze week gemiddeld \(format(diff)) punt lager. Mooi zo.",
                                      tint: .sage))
            } else if diff <= -0.5 {
                result.append(Insight(symbol: "heart.text.square", title: "Een zwaardere week",
                                      detail: "Je pijn was deze week wat hoger. Wees extra lief voor jezelf en kies een zachte oefening.",
                                      tint: .rose))
            }
        }

        // 7. Wanneer check je in?
        if let learned = learnedReminderMinutes(.morning, in: context) {
            result.append(Insight(symbol: "alarm", title: "Je ochtendritme",
                                  detail: "Je checkt meestal rond \(clock(learned + 10)) in. Herinneringen schuiven met je mee.",
                                  tint: .dawn))
        }
        return result
    }

    // MARK: Helpers

    static func average(_ values: [Int]) -> Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
