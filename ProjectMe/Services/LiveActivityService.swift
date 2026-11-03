import ActivityKit
import Foundation
import SwiftData

/// Start en beheert Live Activities voor de Dynamic Island en het toegangsscherm.
@MainActor
enum LiveActivityService {
    static var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    // MARK: Water

    static var isWaterActive: Bool { !Activity<WaterActivityAttributes>.activities.isEmpty }

    static func startWater(context: ModelContext) {
        guard isSupported, !isWaterActive else { return }
        let state = WaterActivityAttributes.ContentState(
            totalML: WaterStore.total(in: context), goalML: Prefs.waterGoalML, updatedAt: .now)
        let content = ActivityContent(state: state, staleDate: Date.now.endOfDay)
        _ = try? Activity.request(attributes: WaterActivityAttributes(title: "Water vandaag"), content: content)
    }

    nonisolated static func endWater() async {
        for activity in Activity<WaterActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Water-activiteiten van een vorige dag netjes opruimen.
    nonisolated static func cleanUpStale() async {
        for activity in Activity<WaterActivityAttributes>.activities
        where !Calendar.current.isDateInToday(activity.content.state.updatedAt) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Meditatie

    static func startMeditation(kind: MeditationKind, phase: String, start: Date, end: Date) {
        guard isSupported else { return }
        // Oude sessies (bijv. na een crash) sluiten, maar niet de nieuwe.
        let old = Set(Activity<MeditationActivityAttributes>.activities.map(\.id))
        Task { await endMeditations(ids: old, immediately: true) }
        let state = MeditationActivityAttributes.ContentState(phase: phase, sessionStart: start, sessionEnd: end, isFinished: false)
        _ = try? Activity.request(
            attributes: MeditationActivityAttributes(kind: kind),
            content: ActivityContent(state: state, staleDate: end.addingTimeInterval(120)))
    }

    static func updateMeditation(phase: String, start: Date, end: Date) {
        let state = MeditationActivityAttributes.ContentState(phase: phase, sessionStart: start, sessionEnd: end, isFinished: false)
        Task { await update(state) }
    }

    nonisolated private static func update(_ state: MeditationActivityAttributes.ContentState) async {
        for activity in Activity<MeditationActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: state.sessionEnd.addingTimeInterval(120)))
        }
    }

    nonisolated static func endMeditation(immediately: Bool = false) async {
        await endMeditations(ids: nil, immediately: immediately)
    }

    nonisolated private static func endMeditations(ids: Set<String>?, immediately: Bool) async {
        for activity in Activity<MeditationActivityAttributes>.activities where ids?.contains(activity.id) ?? true {
            var state = activity.content.state
            state.isFinished = true
            state.phase = "Mooi gedaan"
            await activity.end(ActivityContent(state: state, staleDate: nil),
                               dismissalPolicy: immediately ? .immediate : .after(.now.addingTimeInterval(60)))
        }
    }
}
