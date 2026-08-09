import ActivityKit
import Foundation

@available(iOS 16.1, *)
@MainActor
final class KiloLiveActivityManager {
    static let shared = KiloLiveActivityManager()

    private var currentActivity: Activity<KiloLiveActivityAttributes>?
    private var currentState: KiloLiveActivityAttributes.ContentState?

    private init() {}

    func startWorkout(name: String, elapsedSeconds: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        var state = currentState ?? KiloLiveActivityAttributes.ContentState(
            exerciseName: "准备下一组",
            phaseLabel: "训练中",
            workoutStartedAt: now.addingTimeInterval(TimeInterval(-max(0, elapsedSeconds))),
            restEndsAt: nil,
            pausedElapsedSeconds: max(0, elapsedSeconds),
            pausedRestSeconds: 0,
            isPaused: false
        )
        state.workoutStartedAt = now.addingTimeInterval(TimeInterval(-max(0, elapsedSeconds)))
        state.pausedElapsedSeconds = max(0, elapsedSeconds)
        state.pausedRestSeconds = 0
        state.isPaused = false
        currentState = state

        if let activity = activeActivity {
            await activity.update(using: state)
            return
        }
        do {
            currentActivity = try Activity.request(
                attributes: KiloLiveActivityAttributes(workoutName: name),
                contentState: state,
                pushType: nil
            )
        } catch {
            // Flutter remains authoritative when Live Activities are disabled
            // or the extension is not available on the current device.
        }
    }

    func updateRest(exercise: String, seconds: Int) async {
        guard let activity = activeActivity, var state = currentState else { return }
        let remaining = max(0, seconds)
        state.exerciseName = exercise
        state.phaseLabel = remaining > 0 ? "组间休息" : "训练中"
        state.restEndsAt = remaining > 0
            ? Date().addingTimeInterval(TimeInterval(remaining))
            : nil
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
    }

    func clearRest() async {
        guard let activity = activeActivity, var state = currentState else { return }
        state.exerciseName = "准备下一组"
        state.phaseLabel = "训练中"
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
    }

    func pause() async {
        guard let activity = activeActivity, var state = currentState else { return }
        state.pausedElapsedSeconds = max(
            state.pausedElapsedSeconds,
            Int(Date().timeIntervalSince(state.workoutStartedAt))
        )
        if let end = state.restEndsAt {
            state.pausedRestSeconds = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        }
        state.restEndsAt = nil
        state.isPaused = true
        state.phaseLabel = "已暂停"
        currentState = state
        await activity.update(using: state)
    }

    func finish() async {
        guard let activity = activeActivity, var state = currentState else { return }
        state.isPaused = true
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        state.phaseLabel = "训练已保存"
        await activity.end(using: state, dismissalPolicy: .immediate)
        currentState = nil
        currentActivity = nil
    }

    private var activeActivity: Activity<KiloLiveActivityAttributes>? {
        if let currentActivity { return currentActivity }
        currentActivity = Activity<KiloLiveActivityAttributes>.activities.first
        return currentActivity
    }
}
