import AppIntents
import Foundation

enum ProjectMeDestination: String, AppEnum {
    case morning, evening, water, meditationMorning, meditationEvening, exercises, journal

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Onderdeel" }
    static var caseDisplayRepresentations: [ProjectMeDestination: DisplayRepresentation] {
        [
            .morning: "Ochtend check-in",
            .evening: "Avond check-in",
            .water: "Water",
            .meditationMorning: "Ochtendmeditatie",
            .meditationEvening: "Avondmeditatie",
            .exercises: "Oefeningen",
            .journal: "Mijn boekje",
        ]
    }

    var link: DeepLink {
        switch self {
        case .morning: .morning
        case .evening: .evening
        case .water: .water
        case .meditationMorning: .meditationMorning
        case .meditationEvening: .meditationEvening
        case .exercises: .exercises
        case .journal: .journal
        }
    }
}

/// Opent een onderdeel van Project Me (Siri, Spotlight, Actieknop, Shortcuts).
struct OpenProjectMeIntent: AppIntent {
    static var title: LocalizedStringResource { "Open in Project Me" }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Onderdeel", default: .morning)
    var destination: ProjectMeDestination

    init() {}
    init(destination: ProjectMeDestination) { self.destination = destination }

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.open(destination.link)
        return .result()
    }
}

struct ProjectMeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWaterIntent(),
            phrases: [
                "Voeg water toe in \(.applicationName)",
                "Ik heb water gedronken in \(.applicationName)",
            ],
            shortTitle: "Water toevoegen",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: OpenProjectMeIntent(destination: .morning),
            phrases: ["Start mijn ochtend in \(.applicationName)", "Ochtend check-in in \(.applicationName)"],
            shortTitle: "Ochtend check-in",
            systemImageName: "sunrise.fill"
        )
        AppShortcut(
            intent: OpenProjectMeIntent(destination: .evening),
            phrases: ["Avond check-in in \(.applicationName)", "Sluit mijn dag af in \(.applicationName)"],
            shortTitle: "Avond check-in",
            systemImageName: "moon.stars.fill"
        )
        AppShortcut(
            intent: OpenProjectMeIntent(destination: .exercises),
            phrases: ["Kaakoefeningen in \(.applicationName)", "Nekoefeningen in \(.applicationName)"],
            shortTitle: "Oefeningen",
            systemImageName: "figure.mind.and.body"
        )
    }
}
