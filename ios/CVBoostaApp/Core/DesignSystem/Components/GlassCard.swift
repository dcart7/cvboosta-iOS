import SwiftUI

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder var content: Content

    init(padding: CGFloat = BoostaSpace.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(BoostaGlass.background)
            .overlay(
                RoundedRectangle(cornerRadius: BoostaRadius.lg)
                    .stroke(BoostaColor.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.lg, style: .continuous))
            .shadow(color: BoostaColor.glassShadow, radius: 14, x: 0, y: 8)
    }
}
