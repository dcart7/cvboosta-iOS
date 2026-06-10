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

            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(color)
        }
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, BoostaSpace.xs)
        .background(BoostaColor.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.sm, style: .continuous))
    }
}
