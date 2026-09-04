import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchWorkoutModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var phase = "idle"
    @Published private(set) var workoutName = "形域训练"
    @Published private(set) var exercise = "在 iPhone 开始训练"
    @Published private(set) var exerciseSymbol = "figure.strengthtraining.traditional"
    @Published private(set) var completedSets = 0
    @Published private(set) var totalSets = 0
    @Published private(set) var nextRestSeconds = 0
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var isSendingCompletion = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        apply(session.receivedApplicationContext)
        session.activate()
    }

    var canCompleteSet: Bool {
        phase == "workout" && !isSendingCompletion
    }

    func completeCurrentSet() {
        guard canCompleteSet, WCSession.isSupported() else { return }
        let target = completedSets + 1
        isSendingCompletion = true

        // Give immediate feedback while the phone applies the authoritative
        // completion and sends the exact rest deadline back to the watch.
        if nextRestSeconds > 0 {
            phase = "rest"
            restEndsAt = Date().addingTimeInterval(TimeInterval(nextRestSeconds))
        }

        let message: [String: Any] = [
            "action": "completeSet",
            "completedSets": target,
        ]
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message) { [weak self] reply in
                Task { @MainActor in
                    self?.isSendingCompletion = false
                    if reply["accepted"] as? Bool == true {
                        self?.completedSets = max(self?.completedSets ?? 0, target)
                    }
                }
            } errorHandler: { [weak self] _ in
                session.transferUserInfo(message)
                Task { @MainActor in self?.isSendingCompletion = false }
            }
        } else {
            session.transferUserInfo(message)
            isSendingCompletion = false
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        phase = context["phase"] as? String ?? phase
        workoutName = context["workoutName"] as? String ?? workoutName
        exercise = context["exercise"] as? String ?? exercise
        exerciseSymbol = context["exerciseSymbol"] as? String ?? exerciseSymbol
        completedSets = context["completedSets"] as? Int ?? completedSets
        totalSets = context["totalSets"] as? Int ?? totalSets
        nextRestSeconds = context["nextRestSeconds"] as? Int ?? nextRestSeconds
        if let epochMs = context["restEndsAtEpochMs"] as? Int64 {
            restEndsAt = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
        } else if let number = context["restEndsAtEpochMs"] as? NSNumber {
            restEndsAt = Date(timeIntervalSince1970: number.doubleValue / 1000)
        } else if phase != "rest" {
            restEndsAt = nil
        }
        isSendingCompletion = false
    }
}
