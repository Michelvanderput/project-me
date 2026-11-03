import SwiftData
import SwiftUI

@main
struct ProjectMeApp: App {
    @State private var router = Router.shared

    init() {
        Prefs.registerDefaults()
        NotificationService.shared.configure()
        WaterStore.onAdd = { ml, date in HealthService.shared.saveWater(ml: ml, at: date) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { router.handle($0) }
                .tint(Theme.Palette.accent)
                .fontDesign(.rounded)
        }
        .modelContainer(SharedModelContainer.shared)
    }
}
