import SwiftUI

struct StaggeredReveal: ViewModifier {
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                withAnimation(BoostaMotion.slowReveal.delay(Double(index) * 0.06)) {
                    visible = true
                }
            }
    }
}

extension View {
    func staggered(index: Int) -> some View {
        modifier(StaggeredReveal(index: index))
    }
}
