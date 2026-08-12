import ActivityKit
import Foundation
import UserNotifications

@available(iOS 16.1, *)
@MainActor
final class KiloLiveActivityManager {
    static let shared = KiloLiveActivityManager()

    private var currentActivity: Activity<KiloLiveActivityAttributes>?
    private var currentState: KiloLiveActivityAttributes.ContentState?

    func consumeSystemActions() -> [String: Any] {
        guard let activity = activeActivity else { return [:] }
        let state = activity.content.state
        currentState = state
        return [
            "completedSets": state.completedSets,
            "paused": state.isPaused,
        ]
    }
    private var restExpirationTask: Task<Void, Never>?
    private let restNotificationIdentifier = "kilo.rest.finished"

    private init() {}

    func startWorkout(name: String, elapsedSeconds: Int, exercise: String, completedSets: Int, totalSets: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        var state = currentState ?? KiloLiveActivityAttributes.ContentState(
            exerciseName: "准备下一组",
            phaseLabel: "训练中",
            workoutStartedAt: now.addingTimeInterval(TimeInterval(-max(0, elapsedSeconds))),
            restEndsAt: nil,
            pausedElapsedSeconds: max(0, elapsedSeconds),
            pausedRestSeconds: 0,
            isPaused: false,
            completedSets: max(0, completedSets),
            totalSets: max(0, totalSets)
        )
        state.workoutStartedAt = now.addingTimeInterval(TimeInterval(-max(0, elapsedSeconds)))
        state.pausedElapsedSeconds = max(0, elapsedSeconds)
        state.pausedRestSeconds = 0
        state.isPaused = false
        state.exerciseName = exercise
        state.completedSets = max(0, completedSets)
        state.totalSets = max(0, totalSets)
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

    func updateWorkoutState(exercise: String, completedSets: Int, totalSets: Int) async {
        guard let activity = activeActivity, var state = currentState else { return }
        state.exerciseName = exercise
        state.completedSets = max(0, completedSets)
        state.totalSets = max(0, totalSets)
        currentState = state
        await activity.update(using: state)
    }

    func updateRest(exercise: String, seconds: Int) async {
        guard let activity = activeActivity, var state = currentState else { return }
        let remaining = max(0, seconds)
        restExpirationTask?.cancel()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [restNotificationIdentifier]
        )
        state.exerciseName = exercise
        state.phaseLabel = remaining > 0 ? "组间休息" : "训练中"
        let restEndsAt = remaining > 0
            ? Date().addingTimeInterval(TimeInterval(remaining))
            : nil
        state.restEndsAt = restEndsAt
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
        if let restEndsAt {
            scheduleRestExpiration(at: restEndsAt)
            await scheduleRestFinishedNotification(after: remaining)
        }
    }

    func clearRest() async {
        cancelRestCompletion()
        guard let activity = activeActivity, var state = currentState else { return }
        state.exerciseName = "准备下一组"
        state.phaseLabel = "训练中"
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
    }

    func pause() async {
        cancelRestCompletion()
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
        cancelRestCompletion()
        guard let activity = activeActivity, var state = currentState else { return }
        state.isPaused = true
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        state.phaseLabel = "训练已保存"
        await activity.end(using: state, dismissalPolicy: .immediate)
        currentState = nil
        currentActivity = nil
    }

    private func scheduleRestExpiration(at end: Date) {
        let delay = max(0, end.timeIntervalSinceNow)
        restExpirationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.expireRest(expectedEnd: end)
        }
    }

    private func expireRest(expectedEnd: Date) async {
        guard
            let activity = activeActivity,
            var state = currentState,
            state.restEndsAt == expectedEnd
        else { return }
        state.exerciseName = "准备下一组"
        state.phaseLabel = "休息结束"
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
    }

    func completeRest() async {
        restExpirationTask?.cancel()
        restExpirationTask = nil
        guard let activity = activeActivity, var state = currentState else { return }
        state.exerciseName = "准备下一组"
        state.phaseLabel = "休息结束"
        state.restEndsAt = nil
        state.pausedRestSeconds = 0
        currentState = state
        await activity.update(using: state)
    }

    private func scheduleRestFinishedNotification(after seconds: Int) async {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        if settings.authorizationStatus == .notDetermined {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "可以开始下一组了"
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(
            identifier: restNotificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(1, seconds)),
                repeats: false
            )
        )
        try? await center.add(request)
    }

    private func cancelRestCompletion() {
        restExpirationTask?.cancel()
        restExpirationTask = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restNotificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [restNotificationIdentifier])
    }

    private var activeActivity: Activity<KiloLiveActivityAttributes>? {
        if let currentActivity { return currentActivity }
        currentActivity = Activity<KiloLiveActivityAttributes>.activities.first
        return currentActivity
    }
}
