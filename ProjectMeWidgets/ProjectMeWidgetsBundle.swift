import SwiftUI
import WidgetKit

@main
struct ProjectMeWidgetsBundle: WidgetBundle {
    init() { Prefs.registerDefaults() }

    var body: some Widget {
        WaterWidget()
        DayWidget()
        MotivationWidget()
        WaterControl()
        WaterLiveActivity()
        MeditationLiveActivity()
    }
}
