import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Het lieve berichtje van vandaag.
/// Met Apple Intelligence (on-device, privé) wordt het persoonlijk gemaakt op basis van
/// je stemming, pijn en water. Anders kiest de app uit de bibliotheek, gewogen naar je ❤️'s.
@MainActor
enum MotivationService {
    struct Today: Equatable {
        let text: String
        let messageID: String
        let category: MotivationCategory?
        let isPersonal: Bool
    }

    static func today(for date: Date = .now) -> Today {
        if let text = cachedGeneratedText(for: date) {
            return Today(text: text, messageID: "ai", category: nil, isPersonal: true)
        }
        let message = MotivationLibrary.pick(for: date)
        return Today(text: message.text, messageID: message.id, category: message.category, isPersonal: false)
    }

    static func cachedGeneratedText(for date: Date) -> String? {
        let d = AppGroup.defaults
        guard d.bool(forKey: PrefKey.appleIntelligence),
              let day = d.object(forKey: PrefKey.generatedMotivationDay) as? Date,
              Calendar.current.isDate(day, inSameDayAs: date),
              let text = d.string(forKey: PrefKey.generatedMotivation), !text.isEmpty else { return nil }
        return text
    }

    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportedLanguages.contains { $0.languageCode?.identifier == "nl" }
        #else
        return false
        #endif
    }

    /// Maakt (hooguit één keer per dag) een persoonlijk bericht. Faalt stil en valt terug op de bibliotheek.
    static func generateIfNeeded(context: ModelContext) async {
        let d = AppGroup.defaults
        guard d.bool(forKey: PrefKey.appleIntelligence), cachedGeneratedText(for: .now) == nil,
              isAppleIntelligenceAvailable else { return }
        #if canImport(FoundationModels)
        let prompt = buildPrompt(context: context)
        let session = LanguageModelSession(instructions: """
            Je bent een warme, lieve coach in de app Project Me. Je schrijft in het Nederlands, \
            in de je-vorm. Schrijf precies één kort bemoedigend berichtje (maximaal 25 woorden) voor de middag. \
            Geen medisch advies, geen druk, geen schuldgevoel. Hooguit één emoji. Geef alleen het bericht terug.
            """)
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            guard !text.isEmpty, text.count < 220 else { return }
            d.set(text, forKey: PrefKey.generatedMotivation)
            d.set(Date.now, forKey: PrefKey.generatedMotivationDay)
        } catch {
            // Bijv. guardrails of model niet klaar: de bibliotheek neemt het over.
        }
        #endif
    }

    private static func buildPrompt(context: ModelContext) -> String {
        let today = Date.now.startOfDay
        let yesterday = today.adding(days: -1)
        var facts: [String] = []
        let name = Prefs.userName
        if !name.isEmpty { facts.append("De naam is \(name).") }

        let mornings = (try? context.fetch(FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day == today }))) ?? []
        if let morning = mornings.first {
            facts.append("Stemming vanochtend: \(Mood(rawValue: morning.mood)?.title ?? "oké").")
            if !morning.intention.isEmpty { facts.append("Intentie voor vandaag: \(morning.intention).") }
            if let gratitude = morning.gratitudes.first(where: { !$0.isEmpty }) {
                facts.append("Dankbaar voor: \(gratitude).")
            }
        }
        let evenings = (try? context.fetch(FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day == yesterday }))) ?? []
        if let evening = evenings.first, evening.maxPain >= 5 {
            facts.append("Gisteren had de gebruiker veel kaak- of nekpijn (\(evening.maxPain)/10).")
        }
        let water = WaterStore.total(in: context)
        facts.append("Water tot nu toe: \(water) van \(Prefs.waterGoalML) ml.")
        if let favorite = LearningEngine.favoriteCategory(in: context) {
            facts.append("Deze persoon houdt van berichtjes over \(favorite.title.lowercased()).")
        }
        return "Context:\n" + facts.joined(separator: "\n") + "\nSchrijf het berichtje."
    }
}
