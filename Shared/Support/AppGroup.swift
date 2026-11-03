import Foundation
import SwiftData

/// Gedeelde identifiers tussen de app, widgets en Live Activities.
enum AppGroup {
    static let identifier = "group.nl.michelvanderput.projectme"
    static let urlScheme = "projectme"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Eén SwiftData-store in de App Group, zodat widgets en intents dezelfde data zien.
enum SharedModelContainer {
    static var schema: Schema { Schema([
        MorningCheckIn.self,
        EveningCheckIn.self,
        WaterLog.self,
        ExerciseSession.self,
        MotivationReaction.self,
        MeditationSession.self,
    ]) }

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(
            "ProjectMe",
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Valt terug op een store in het geheugen zodat de app nooit crasht bij opstarten.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    @MainActor
    static func preview() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}

/// Deep links die widgets, notificaties en de Dynamic Island gebruiken.
enum DeepLink: String, CaseIterable, Sendable {
    case today, morning, evening, water, meditationMorning = "meditation-morning",
         meditationEvening = "meditation-evening", exercises, journal, motivation

    var url: URL { URL(string: "\(AppGroup.urlScheme)://\(rawValue)")! }

    init?(url: URL) {
        guard url.scheme == AppGroup.urlScheme, let host = url.host() else { return nil }
        self.init(rawValue: host)
    }
}
