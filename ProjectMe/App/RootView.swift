import SwiftData
import SwiftUI
import WidgetKit

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PrefKey.onboardingDone, store: AppGroup.defaults) private var onboardingDone = false
    @AppStorage("lastMotivationPopup", store: AppGroup.defaults) private var lastMotivationPopup = 0.0
    @State private var today = Date.now.startOfDay

    var body: some View {
        @Bindable var router = router
        Group {
            if onboardingDone {
                TabView(selection: $router.tab) {
                    Tab("Vandaag", systemImage: "sun.horizon", value: Router.Tab.today) {
                        TodayView(day: today)
                    }
                    Tab("Boekje", systemImage: "book.closed", value: Router.Tab.journal) {
                        JournalView()
                    }
                    Tab("Lichaam", systemImage: "figure.mind.and.body", value: Router.Tab.body) {
                        ExerciseLibraryView()
                    }
                    Tab("Inzicht", systemImage: "chart.xyaxis.line", value: Router.Tab.insights) {
                        InsightsView()
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .sheet(item: $router.sheet) { sheet in
                    sheetContent(sheet)
                }
            } else {
                OnboardingView {
                    withAnimation(Theme.Motion.gentle) { onboardingDone = true }
                    Task { await refresh() }
                }
            }
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = Date.now.startOfDay
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Router.Sheet) -> some View {
        switch sheet {
        case .morning: MorningCheckInView()
        case .evening: EveningCheckInView()
        case .water: WaterView()
        case .motivation: MotivationSheet()
        case .settings: SettingsView()
        case .meditation(let kind): MeditationView(kind: kind)
        case .exercise(let id):
            if let exercise = ExerciseLibrary.exercise(id: id) { ExercisePlayerView(exercise: exercise) }
        }
    }

    /// Bij elke keer openen: leren, opnieuw plannen, widgets verversen, middagpopup.
    private func refresh() async {
        guard onboardingDone else { return }
        LearningEngine.recomputeMotivationWeights(in: context)
        await MotivationService.generateIfNeeded(context: context)
        await NotificationService.shared.rescheduleAll(context: context)
        await LiveActivityService.cleanUpStale()
        WidgetCenter.shared.reloadAllTimelines()
        showAfternoonPopupIfNeeded()
    }

    /// De middag-popup: één keer per dag, tussen 12:00 en 18:00, als er niets anders open staat.
    private func showAfternoonPopupIfNeeded() {
        guard Date.now.dayPart == .afternoon, router.sheet == nil,
              AppGroup.defaults.bool(forKey: PrefKey.motivationOn) else { return }
        let last = Date(timeIntervalSince1970: lastMotivationPopup)
        guard !Calendar.current.isDateInToday(last) else { return }
        lastMotivationPopup = Date.now.timeIntervalSince1970
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if router.sheet == nil { router.sheet = .motivation }
        }
    }
}
