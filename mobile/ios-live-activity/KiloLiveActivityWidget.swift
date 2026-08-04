import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct KiloLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KiloLiveActivityAttributes.self) { context in
            KiloLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.95, green: 0.965, blue: 0.975))
                .activitySystemActionForegroundColor(Color(red: 0.04, green: 0.40, blue: 0.83))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KiloTimeLabel(seconds: context.state.remainingSeconds)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.nextSetLabel)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(max(0, context.state.remainingSeconds)), total: 300)
                        .tint(Color(red: 0.04, green: 0.40, blue: 0.83))
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
            } compactTrailing: {
                KiloTimeLabel(seconds: context.state.remainingSeconds)
            } minimal: {
                KiloTimeLabel(seconds: context.state.remainingSeconds)
            }
            .widgetURL(URL(string: "kilo://training"))
            .keylineTint(Color(red: 0.04, green: 0.40, blue: 0.83))
        }
    }
}

@available(iOS 16.1, *)
private struct KiloLockScreenView: View {
    let state: KiloLiveActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.isPaused ? "pause.circle.fill" : "timer")
                .font(.title2)
                .foregroundStyle(Color(red: 0.04, green: 0.40, blue: 0.83))
            VStack(alignment: .leading, spacing: 4) {
                Text(state.nextSetLabel).font(.headline)
                Text(state.isPaused ? "已暂停" : "休息中").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            KiloTimeLabel(seconds: state.remainingSeconds)
        }
        .padding(16)
    }
}

private struct KiloTimeLabel: View {
    let seconds: Int
    var body: some View {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return Text(String(format: "%02d:%02d", minutes, remainder))
            .font(.system(.title3, design: .monospaced).weight(.bold))
            .monospacedDigit()
    }
}
