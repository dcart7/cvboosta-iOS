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
            .background(
                RoundedRectangle(cornerRadius: BoostaRadius.lg, style: .continuous)
                    .fill(BoostaColor.surface)
            )
            .shadow(color: BoostaColor.glassShadow, radius: 22, x: 0, y: 16)
    }
}
#if DEBUG
struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // A neutral background to showcase the glass effect
            LinearGradient(colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass Card")
                        .font(.headline)
                    Text("This is a preview of the reusable glass card component.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .previewDisplayName("GlassCard")
    }
}
#endif
