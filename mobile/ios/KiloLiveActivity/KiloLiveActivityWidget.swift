import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, *)
struct KiloPauseResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "暂停或继续训练"

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<KiloLiveActivityAttributes>.activities.first else {
            return .result()
        }
        var state = activity.content.state
        if state.isPaused {
            state.workoutStartedAt = Date().addingTimeInterval(TimeInterval(-state.pausedElapsedSeconds))
            if state.pausedRestSeconds > 0 {
                state.restEndsAt = Date().addingTimeInterval(TimeInterval(state.pausedRestSeconds))
            }
            state.isPaused = false
            state.phaseLabel = state.restEndsAt == nil ? "训练中" : "组间休息"
        } else {
            state.pausedElapsedSeconds = max(0, Int(Date().timeIntervalSince(state.workoutStartedAt)))
            if let restEnd = state.restEndsAt {
                state.pausedRestSeconds = max(0, Int(restEnd.timeIntervalSinceNow.rounded(.up)))
            }
            state.restEndsAt = nil
            state.isPaused = true
            state.phaseLabel = "已暂停"
        }
        await activity.update(ActivityContent(state: state, staleDate: nil))
        return .result()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct KiloCompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "完成本组"

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<KiloLiveActivityAttributes>.activities.first else {
            return .result()
        }
        var state = activity.content.state
        state.completedSets = min(state.totalSets, state.completedSets + 1)
        state.phaseLabel = state.completedSets >= state.totalSets ? "全部组已完成" : "本组已完成"
        await activity.update(ActivityContent(state: state, staleDate: nil))
        return .result()
    }
}

@available(iOSApplicationExtension 16.1, *)
struct KiloLiveActivityWidget: Widget {
    private let ember = Color(red: 0.93, green: 0.34, blue: 0.08)
    private let espresso = Color(red: 0.16, green: 0.09, blue: 0.06)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KiloLiveActivityAttributes.self) { context in
            KiloLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 1.0, green: 0.97, blue: 0.94))
                .activitySystemActionForegroundColor(ember)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KiloWorkoutTimer(state: context.state, compact: true)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                      HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.restEndsAt == nil ? "保持节奏，完成下一组" : "组间休息")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.72))
                            if context.state.totalSets > 0 {
                                Text("\(context.state.completedSets)/\(context.state.totalSets) 组")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        Spacer()
                        KiloRestTimer(state: context.state)
                            .foregroundStyle(ember)
                      }
                      if #available(iOSApplicationExtension 17.0, *) {
                        HStack(spacing: 10) {
                            Button(intent: KiloCompleteSetIntent()) {
                                Label("完成本组", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ember)
                            Button(intent: KiloPauseResumeIntent()) {
                                Label(context.state.isPaused ? "继续" : "暂停", systemImage: context.state.isPaused ? "play.fill" : "pause.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                        .font(.caption.weight(.bold))
                      }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(ember)
            } compactTrailing: {
                if context.state.restEndsAt != nil || context.state.pausedRestSeconds > 0 {
                    KiloRestTimer(state: context.state, compact: true)
                        .foregroundStyle(ember)
                } else {
                    KiloWorkoutTimer(state: context.state, compact: true)
                        .foregroundStyle(.white)
                }
            } minimal: {
                if context.state.restEndsAt != nil || context.state.pausedRestSeconds > 0 {
                    KiloRestTimer(state: context.state, compact: true)
                        .foregroundStyle(ember)
                } else {
                    KiloWorkoutTimer(state: context.state, compact: true)
                        .foregroundStyle(.white)
                }
            }
            .widgetURL(URL(string: "ember://training"))
            .keylineTint(ember)
        }
    }

    private struct KiloLockScreenView: View {
        let context: ActivityViewContext<KiloLiveActivityAttributes>
        private let primaryText = Color(red: 0.16, green: 0.09, blue: 0.06)
        private let secondaryText = Color(red: 0.38, green: 0.29, blue: 0.25)

        var body: some View {
            VStack(spacing: 10) {
              HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(red: 0.93, green: 0.34, blue: 0.08).opacity(0.14))
                    Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                        .foregroundStyle(Color(red: 0.93, green: 0.34, blue: 0.08))
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text(context.state.exerciseName)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                    if context.state.totalSets > 0 {
                        Text("已完成 \(context.state.completedSets)/\(context.state.totalSets) 组")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("训练").font(.caption2).foregroundStyle(secondaryText)
                        KiloWorkoutTimer(state: context.state, compact: false)
                            .foregroundStyle(primaryText)
                    }
                    if context.state.restEndsAt != nil || context.state.pausedRestSeconds > 0 {
                        HStack(spacing: 4) {
                            Text("休息").font(.caption2).foregroundStyle(secondaryText)
                            KiloRestTimer(state: context.state)
                                .foregroundStyle(Color(red: 0.93, green: 0.34, blue: 0.08))
                        }
                    } else {
                        Text(context.state.isPaused ? "已暂停" : context.state.phaseLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(context.state.isPaused ? Color.orange : secondaryText)
                    }
                }
              }
              if #available(iOSApplicationExtension 17.0, *) {
                HStack(spacing: 10) {
                    Button(intent: KiloCompleteSetIntent()) {
                        Label("完成本组", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.93, green: 0.34, blue: 0.08))
                    Button(intent: KiloPauseResumeIntent()) {
                        Label(context.state.isPaused ? "继续" : "暂停", systemImage: context.state.isPaused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(primaryText)
                }
                .font(.caption.weight(.bold))
              }
            }
            .padding(14)
        }
    }

    private struct KiloWorkoutTimer: View {
        let state: KiloLiveActivityAttributes.ContentState
        let compact: Bool

        var body: some View {
            Group {
                if state.isPaused {
                    Text(KiloTimeText.format(state.pausedElapsedSeconds))
                } else {
                    Text(
                        timerInterval: state.workoutStartedAt...Date.distantFuture,
                        pauseTime: nil,
                        countsDown: false,
                        showsHours: true
                    )
                }
            }
            .font(.system(compact ? .caption : .body, design: .monospaced).weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: compact ? 44 : nil, alignment: .trailing)
        }
    }

    private struct KiloRestTimer: View {
        let state: KiloLiveActivityAttributes.ContentState
        var compact = false

        var body: some View {
            Group {
                if state.isPaused && state.pausedRestSeconds > 0 {
                    Text(KiloTimeText.format(state.pausedRestSeconds))
                } else if let end = state.restEndsAt {
                    Text(timerInterval: Date()...end, countsDown: true)
                } else {
                    Text("—")
                }
            }
            .font(.system(compact ? .caption2 : .body, design: .monospaced).weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: compact ? 40 : nil, alignment: .trailing)
        }
    }

    private enum KiloTimeText {
        static func format(_ seconds: Int) -> String {
            let value = max(0, seconds)
            if value >= 3600 {
                return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
            }
            return String(format: "%02d:%02d", value / 60, value % 60)
        }
    }
}
