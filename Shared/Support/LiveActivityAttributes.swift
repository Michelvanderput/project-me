import ActivityKit
import Foundation

/// Water-voortgang in de Dynamic Island en op het toegangsscherm.
struct WaterActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var totalML: Int
        var goalML: Int
        var updatedAt: Date

        var progress: Double { goalML > 0 ? min(1, Double(totalML) / Double(goalML)) : 0 }
        var remainingML: Int { max(0, goalML - totalML) }
    }
    var title: String
}

/// Een lopende meditatie in de Dynamic Island, met live afteltimer.
struct MeditationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var phase: String
        var sessionStart: Date
        var sessionEnd: Date
        var isFinished: Bool
    }
    var kind: MeditationKind
}
