import AppIntents
import Foundation
import SwiftData

/// Interactieve knop in widgets, Control Center, Dynamic Island en Siri.
/// `LiveActivityIntent` zorgt dat hij in het app-proces draait, zodat de Live Activity mee kan updaten.
struct AddWaterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Water toevoegen" }
    static var description: IntentDescription { IntentDescription("Voeg een glas water toe aan vandaag.") }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Hoeveelheid (ml)", default: 250)
    var amount: Int

    init() {}
    init(amount: Int) { self.amount = amount }

    static var parameterSummary: some ParameterSummary {
        Summary("Voeg \(\.$amount) ml water toe")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Prefs.registerDefaults()
        let context = SharedModelContainer.shared.mainContext
        let total = WaterStore.add(amount, in: context)
        let goal = Prefs.waterGoalML
        let left = max(0, goal - total)
        let line: String = left == 0
            ? "Top! Je hebt je \(goal / 1000) liter vandaag gehaald. 💧"
            : "Lekker bezig. Nog \(left) ml te gaan."
        return .result(dialog: "\(line)")
    }
}
