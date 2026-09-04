import Foundation
import WatchConnectivity

/// Keeps the paired Apple Watch in sync with the Flutter workout state and
/// forwards actions from the watch back to Flutter. The application context is
/// the durable source of truth; an immediate message is also sent when the watch
/// app is reachable so an on-screen workout updates without delay.
final class KiloWatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = KiloWatchConnectivityManager()

    var onCompleteSet: ((Int) -> Void)?
    private var pendingCompletedSets: Int?
    private var workoutContext: [String: Any] = [
        "phase": "idle",
        "exercise": "准备训练",
        "exerciseSymbol": "figure.strengthtraining.traditional",
        "completedSets": 0,
        "totalSets": 0,
        "nextRestSeconds": 0,
    ]

    private override init() {
        super.init()
    }

    var isSupported: Bool { WCSession.isSupported() }

    var isPairedAndInstalled: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.isPaired && session.isWatchAppInstalled
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func consumeCompletedSets() -> Int? {
        let value = pendingCompletedSets
        pendingCompletedSets = nil
        return value
    }

    func startWorkout(
        name: String,
        exercise: String,
        exerciseSymbol: String,
        completedSets: Int,
        totalSets: Int,
        nextRestSeconds: Int
    ) {
        workoutContext = [
            "phase": "workout",
            "workoutName": name,
            "exercise": exercise,
            "exerciseSymbol": exerciseSymbol,
            "completedSets": max(0, completedSets),
            "totalSets": max(0, totalSets),
            "nextRestSeconds": max(0, nextRestSeconds),
        ]
        publish()
    }

    func updateWorkout(
        exercise: String,
        exerciseSymbol: String,
        completedSets: Int,
        totalSets: Int,
        nextRestSeconds: Int
    ) {
        workoutContext["phase"] = "workout"
        workoutContext["exercise"] = exercise
        workoutContext["exerciseSymbol"] = exerciseSymbol
        workoutContext["completedSets"] = max(0, completedSets)
        workoutContext["totalSets"] = max(0, totalSets)
        workoutContext["nextRestSeconds"] = max(0, nextRestSeconds)
        workoutContext.removeValue(forKey: "restEndsAtEpochMs")
        publish()
    }

    func updateRest(exercise: String, seconds: Int, endsAtEpochMs: Int64?) {
        workoutContext["phase"] = "rest"
        workoutContext["exercise"] = exercise
        let fallbackEnd = Int64(Date().addingTimeInterval(TimeInterval(max(0, seconds))).timeIntervalSince1970 * 1000)
        workoutContext["restEndsAtEpochMs"] = endsAtEpochMs ?? fallbackEnd
        publish()
    }

    func clearRest() {
        workoutContext["phase"] = "workout"
        workoutContext.removeValue(forKey: "restEndsAtEpochMs")
        publish()
    }

    func pause() {
        workoutContext["phase"] = "paused"
        publish()
    }

    func finish() {
        workoutContext = ["phase": "finished"]
        publish()
    }

    private func publish() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            activate()
            return
        }
        do {
            try session.updateApplicationContext(workoutContext)
        } catch {
            // The next state transition retries. Flutter remains authoritative.
        }
        if session.isReachable {
            session.sendMessage(workoutContext, replyHandler: nil, errorHandler: nil)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        publish()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message, replyHandler: nil)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo, replyHandler: nil)
    }

    private func handle(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) {
        guard message["action"] as? String == "completeSet" else {
            replyHandler?(["accepted": false])
            return
        }
        let current = workoutContext["completedSets"] as? Int ?? 0
        let requested = message["completedSets"] as? Int ?? current + 1
        let target = max(current + 1, requested)
        pendingCompletedSets = target
        DispatchQueue.main.async { [weak self] in
            self?.onCompleteSet?(target)
        }
        replyHandler?(["accepted": true, "completedSets": target])
    }
}
