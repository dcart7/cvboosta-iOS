import ActivityKit
import WidgetKit
import SwiftUI

struct CVBoostaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CVBoostaActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.13, blue: 0.28))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("CVBoosta", systemImage: iconName(for: context.state.mode))
                        .font(.caption)
                        .foregroundStyle(tint(for: context.state.mode))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(trailingValue(for: context.state))
                        .font(.headline)
                        .foregroundStyle(tint(for: context.state.mode))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: progressValue(for: context.state))
                        .tint(tint(for: context.state.mode))
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.state.mode))
                    .foregroundStyle(tint(for: context.state.mode))
            } compactTrailing: {
                Text(trailingValue(for: context.state))
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: iconName(for: context.state.mode))
                    .foregroundStyle(tint(for: context.state.mode))
            }
            .widgetURL(URL(string: "cvboosta://live"))
            .keylineTint(.blue)
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<CVBoostaActivityAttributes>) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(context.state.title, systemImage: iconName(for: context.state.mode))
                        .font(.headline)
                        .foregroundStyle(tint(for: context.state.mode))
                    Spacer()
                    Text(trailingValue(for: context.state))
                        .font(.headline)
                        .foregroundStyle(tint(for: context.state.mode))
                }

                ProgressView(value: progressValue(for: context.state))
                    .tint(tint(for: context.state.mode))

                HStack {
                    Text(context.state.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(context.state.etaText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(.vertical, 8)
        }

    private func percentText(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func iconName(for mode: CVBoostaActivityAttributes.ActivityMode) -> String {
        switch mode {
        case .atsOptimization, .tailoring:
            return "sparkles"
        case .interviewCountdown:
            return "timer"
        case .applicationStatus:
            return "briefcase.fill"
        case .dailyStreak:
            return "flame.fill"
        case .postInterviewReflection:
            return "text.bubble.fill"
        }
    }

    private func tint(for mode: CVBoostaActivityAttributes.ActivityMode) -> Color {
        switch mode {
        case .atsOptimization, .tailoring:
            return .cyan
        case .interviewCountdown:
            return .orange
        case .applicationStatus:
            return .green
        case .dailyStreak:
            return .orange
        case .postInterviewReflection:
            return .mint
        }
    }

    private func trailingValue(for state: CVBoostaActivityAttributes.ContentState) -> String {
        switch state.mode {
        case .dailyStreak, .interviewCountdown, .postInterviewReflection:
            return state.etaText
        default:
            return percentText(state.progress)
        }
    }

    private func progressValue(for state: CVBoostaActivityAttributes.ContentState) -> Double {
        switch state.mode {
        case .postInterviewReflection:
            return 1
        default:
            return state.progress
        }
    }
}
