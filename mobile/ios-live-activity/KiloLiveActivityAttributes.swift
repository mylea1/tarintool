import ActivityKit
import Foundation

/// Shared payload between the Flutter app and the WidgetKit extension.
/// Keep this intentionally small so the extension never reads Flutter memory.
struct KiloLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var nextSetLabel: String
        var remainingSeconds: Int
        var isPaused: Bool
    }

    var workoutName: String
    var appGroupIdentifier: String = "group.com.kilostrength"
}
