import Observation
import SwiftUI

/// Centrale navigatie: tabs, sheets en deep links (widgets, notificaties, Dynamic Island).
@MainActor
@Observable
final class Router {
    static let shared = Router()

    enum Tab: Hashable { case today, journal, body, insights }

    enum Sheet: Identifiable, Hashable {
        case morning, evening, water, motivation, settings
        case meditation(MeditationKind)
        case exercise(String)

        var id: String {
            switch self {
            case .morning: "morning"
            case .evening: "evening"
            case .water: "water"
            case .motivation: "motivation"
            case .settings: "settings"
            case .meditation(let kind): "meditation-\(kind.rawValue)"
            case .exercise(let id): "exercise-\(id)"
            }
        }
    }

    var tab: Tab = .today
    var sheet: Sheet?

    func open(_ link: DeepLink) {
        switch link {
        case .today: tab = .today; sheet = nil
        case .morning: tab = .today; sheet = .morning
        case .evening: tab = .today; sheet = .evening
        case .water: tab = .today; sheet = .water
        case .meditationMorning: sheet = .meditation(.morning)
        case .meditationEvening: sheet = .meditation(.evening)
        case .exercises: tab = .body; sheet = nil
        case .journal: tab = .journal; sheet = nil
        case .motivation: sheet = .motivation
        }
    }

    func handle(_ url: URL) {
        if let link = DeepLink(url: url) { open(link) }
    }
}
