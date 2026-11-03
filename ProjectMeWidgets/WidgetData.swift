import Foundation
import SwiftData
import WidgetKit

/// Momentopname van vandaag voor alle widgets.
struct DaySnapshot: Sendable {
    var date: Date
    var waterML: Int
    var waterGoal: Int
    var morningDone: Bool
    var morningMeditated: Bool
    var eveningDone: Bool
    var eveningMeditated: Bool
    var name: String
    var motivation: String
    var lastHappyMoment: String?

    var waterProgress: Double { min(1, Double(waterML) / Double(max(waterGoal, 1))) }

    static let placeholder = DaySnapshot(
        date: .now, waterML: 1250, waterGoal: 2000, morningDone: true, morningMeditated: true,
        eveningDone: false, eveningMeditated: false, name: "",
        motivation: "Je hoeft vandaag niet perfect te zijn. Je bent al goed genoeg.",
        lastHappyMoment: "Koffie in de zon met een goed gesprek.")

    /// Wat is nu het fijnste volgende stapje?
    var nextStep: (title: String, symbol: String, link: DeepLink) {
        let part = Date.now.dayPart
        if !morningDone && part == .morning { return ("Ochtend check-in", "sunrise.fill", .morning) }
        if morningDone && !morningMeditated && part == .morning { return ("Ochtendmeditatie", "sun.max.fill", .meditationMorning) }
        if (part == .evening || part == .night) && !eveningDone { return ("Avond check-in", "moon.stars.fill", .evening) }
        if eveningDone && !eveningMeditated && (part == .evening || part == .night) {
            return ("Avondmeditatie", "moon.zzz.fill", .meditationEvening)
        }
        if waterML < waterGoal { return ("Drink een glas water", "drop.fill", .water) }
        return ("Lief zijn voor jezelf", "heart.fill", .motivation)
    }
}

/// Nonisolated: elke aanroep gebruikt een eigen ModelContext op de huidige thread.
enum WidgetData {
    static func snapshot() -> DaySnapshot {
        let context = ModelContext(SharedModelContainer.shared)
        let today = Date.now.startOfDay
        let tomorrow = today.endOfDay
        let morning = try? context.fetch(FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day == today })).first
        let evening = try? context.fetch(FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day == today })).first
        var lastHappy = FetchDescriptor<EveningCheckIn>(
            predicate: #Predicate { !$0.happyMoment.isEmpty },
            sortBy: [SortDescriptor(\.day, order: .reverse)])
        lastHappy.fetchLimit = 1
        let happy = (try? context.fetch(lastHappy))?.first?.happyMoment

        let generated: String? = {
            let d = AppGroup.defaults
            guard d.bool(forKey: PrefKey.appleIntelligence),
                  let day = d.object(forKey: PrefKey.generatedMotivationDay) as? Date,
                  Calendar.current.isDateInToday(day) else { return nil }
            return d.string(forKey: PrefKey.generatedMotivation)
        }()

        return DaySnapshot(
            date: .now,
            waterML: ((try? context.fetch(FetchDescriptor<WaterLog>(
                predicate: #Predicate { $0.date >= today && $0.date < tomorrow }))) ?? []).reduce(0) { $0 + $1.amountML },
            waterGoal: Prefs.waterGoalML,
            morningDone: morning != nil,
            morningMeditated: morning?.meditationCompleted ?? false,
            eveningDone: evening != nil,
            eveningMeditated: evening?.meditationCompleted ?? false,
            name: Prefs.userName,
            motivation: generated ?? MotivationLibrary.pick().text,
            lastHappyMoment: happy)
    }

    /// Ververs bij elk dagdeel, zodat 'volgende stap' en het bericht meegaan.
    static func nextRefresh() -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: .now)
        let boundaries = [5, 12, 18, 23, 29]
        let next = boundaries.first { $0 > hour } ?? 29
        return calendar.date(bySettingHour: next % 24, minute: 0, second: 0,
                             of: next >= 24 ? Date.now.adding(days: 1) : .now) ?? .now.addingTimeInterval(3600)
    }
}

struct DayEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetData.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let entry = DayEntry(date: .now, snapshot: WidgetData.snapshot())
        completion(Timeline(entries: [entry], policy: .after(WidgetData.nextRefresh())))
    }
}
