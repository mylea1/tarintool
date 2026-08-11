import ActivityKit
import Foundation

struct KiloLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var phaseLabel: String
        var workoutStartedAt: Date
        var restEndsAt: Date?
        var pausedElapsedSeconds: Int
        var pausedRestSeconds: Int
        var isPaused: Bool
        var completedSets: Int
        var totalSets: Int
    }

    var workoutName: String
}
