import ActivityKit
import AppIntents

@available(iOS 16.1, *)
struct KiloPauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "暂停形域计时"
    static var description = IntentDescription("暂停当前训练休息计时。")

    func perform() async throws -> some IntentResult {
        KiloSharedTimerStore.shared.setPaused(true)
        return .result()
    }
}

@available(iOS 16.1, *)
struct KiloSkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "跳过休息"
    static var description = IntentDescription("结束当前休息并进入下一组。")

    func perform() async throws -> some IntentResult {
        KiloSharedTimerStore.shared.setRemaining(0)
        return .result()
    }
}

@available(iOS 16.1, *)
struct KiloFinishWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束形域训练"
    static var description = IntentDescription("结束当前训练并保存记录。")

    func perform() async throws -> some IntentResult {
        KiloSharedTimerStore.shared.setWorkoutFinished(true)
        return .result()
    }
}

/// Minimal App Group state. Widget/intent targets must never access Flutter
/// objects directly; the main app writes this JSON before invoking ActivityKit.
final class KiloSharedTimerStore {
    static let shared = KiloSharedTimerStore()
    private let defaults = UserDefaults(suiteName: "group.com.kilostrength")!
    private let key = "kilo.timer.state"

    private init() {}

    func setPaused(_ value: Bool) {
        update { $0["isPaused"] = value }
    }

    func setRemaining(_ value: Int) {
        update { $0["remainingSeconds"] = value }
    }

    func setWorkoutFinished(_ value: Bool) {
        update { $0["workoutFinished"] = value }
    }

    private func update(_ mutate: (inout [String: Any]) -> Void) {
        var state = defaults.dictionary(forKey: key) ?? [:]
        mutate(&state)
        defaults.set(state, forKey: key)
    }
}
