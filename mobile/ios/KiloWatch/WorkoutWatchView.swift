import SwiftUI

struct WorkoutWatchView: View {
    @ObservedObject var model: WatchWorkoutModel

    var body: some View {
        Group {
            if model.phase == "rest", let end = model.restEndsAt {
                restView(until: end)
            } else if model.phase == "finished" {
                finishedView
            } else {
                workoutView
            }
        }
        .padding(.horizontal, 8)
        .containerBackground(
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.08, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
    }

    private var workoutView: some View {
        VStack(spacing: 8) {
            Image(systemName: model.exerciseSymbol)
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(model.exercise)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text("\(model.completedSets) / \(model.totalSets) 组")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(action: model.completeCurrentSet) {
                Label(
                    model.isSendingCompletion ? "同步中" : "完成本组",
                    systemImage: "checkmark.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!model.canCompleteSet)
            .accessibilityHint("完成当前组并开始组间休息")
        }
    }

    private func restView(until end: Date) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.orange)
            Text("组间休息")
                .font(.headline)
            Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(model.exercise)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var finishedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("训练已完成")
                .font(.headline)
            Text("在 iPhone 查看训练记录")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
