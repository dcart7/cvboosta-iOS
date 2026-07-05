import SwiftUI

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.metricPillMinHeight, alignment: .leading)
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, BoostaSpace.sm)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))
    }
}
