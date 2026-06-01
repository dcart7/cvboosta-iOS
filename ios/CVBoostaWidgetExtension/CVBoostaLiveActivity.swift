import ActivityKit
import WidgetKit
import SwiftUI

struct CVBoostaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CVBoostaActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color(red: 0.93, green: 0.96, blue: 1.0))
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("CV", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percentText(context.state.progress))
                        .font(.headline)
                        .foregroundStyle(.green)
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
                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(percentText(context.state.progress))
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
            }
            .widgetURL(URL(string: "cvboosta://live"))
            .keylineTint(.blue)
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<CVBoostaActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.state.title)
                    .font(.headline)
                Spacer()
                Text(percentText(context.state.progress))
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            ProgressView(value: context.state.progress)
                .tint(.blue)

            HStack {
                Text(context.state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(context.state.etaText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
}
