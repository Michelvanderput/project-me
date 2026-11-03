import ActivityKit
import Foundation
import SwiftData
import WidgetKit

/// Eén plek voor het lezen en schrijven van water, gedeeld door app, widgets en intents.
@MainActor
enum WaterStore {
    /// Optionele hook (bijv. Gezondheid), gezet door de app bij het opstarten.
    static var onAdd: (@MainActor (Int, Date) -> Void)?

    static func logs(on day: Date = .now, in context: ModelContext) -> [WaterLog] {
        let start = day.startOfDay
        let end = day.endOfDay
        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func total(on day: Date = .now, in context: ModelContext) -> Int {
        logs(on: day, in: context).reduce(0) { $0 + $1.amountML }
    }

    @discardableResult
    static func add(_ amountML: Int, at date: Date = .now, in context: ModelContext) -> Int {
        context.insert(WaterLog(date: date, amountML: amountML))
        try? context.save()
        onAdd?(amountML, date)
        let newTotal = total(in: context)
        didChange(total: newTotal)
        return newTotal
    }

    static func remove(_ log: WaterLog, in context: ModelContext) {
        context.delete(log)
        try? context.save()
        didChange(total: total(in: context))
    }

    static func didChange(total: Int) {
        WidgetCenter.shared.reloadAllTimelines()
        let goal = Prefs.waterGoalML
        Task { await LiveActivityBridge.updateWater(total: total, goal: goal) }
    }
}

/// Werkt een lopende water-Live Activity bij (draait in het app-proces).
enum LiveActivityBridge {
    static func updateWater(total: Int, goal: Int) async {
        let state = WaterActivityAttributes.ContentState(totalML: total, goalML: goal, updatedAt: .now)
        for activity in Activity<WaterActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }
}
