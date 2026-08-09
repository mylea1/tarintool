import ActivityKit
import SwiftUI
import WidgetKit

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
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KiloWorkoutTimer(state: context.state, compact: true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseLabel)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(context.state.restEndsAt == nil ? "保持节奏，完成下一组" : "组间休息")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        KiloRestTimer(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(ember)
            } compactTrailing: {
                if context.state.restEndsAt != nil || context.state.pausedRestSeconds > 0 {
                    KiloRestTimer(state: context.state)
                } else {
                    KiloWorkoutTimer(state: context.state, compact: true)
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(ember)
            }
            .widgetURL(URL(string: "ember://training"))
            .keylineTint(ember)
        }
    }

    private struct KiloLockScreenView: View {
        let context: ActivityViewContext<KiloLiveActivityAttributes>

        var body: some View {
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
                        .lineLimit(1)
                    Text(context.state.exerciseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("训练").font(.caption2).foregroundStyle(.secondary)
                        KiloWorkoutTimer(state: context.state, compact: false)
                    }
                    if context.state.restEndsAt != nil || context.state.pausedRestSeconds > 0 {
                        HStack(spacing: 4) {
                            Text("休息").font(.caption2).foregroundStyle(.secondary)
                            KiloRestTimer(state: context.state)
                                .foregroundStyle(Color(red: 0.93, green: 0.34, blue: 0.08))
                        }
                    } else {
                        Text(context.state.isPaused ? "已暂停" : context.state.phaseLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(context.state.isPaused ? .orange : .secondary)
                    }
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
        }
    }

    private struct KiloRestTimer: View {
        let state: KiloLiveActivityAttributes.ContentState

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
            .font(.system(.body, design: .monospaced).weight(.bold))
            .monospacedDigit()
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
