import SwiftUI

struct OnboardingView: View {
    @State private var page = 0

    private let slides: [OnboardingSlide] = [
        .init(
            title: "Your resume is screened before people read it.",
            body: "Most candidates are filtered by systems first. CVBoosta strengthens your signal before submission.",
            accent: .blue
        ),
        .init(
            title: "Strong experience can still look invisible.",
            body: "We surface weak recruiter signals, missing keywords, and low-impact bullets.",
            accent: .cyan
        ),
        .init(
            title: "Position yourself with intent.",
            body: "Tailor every resume for role language, ATS logic, and interview conversion.",
            accent: .green
        )
    ]

    var body: some View {
        ZStack {
            background

            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                        Spacer()
                        Text(slide.title)
                            .font(BoostaType.hero)
                            .foregroundStyle(BoostaColor.primaryText)
                            .staggered(index: 0)

                        Text(slide.body)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                            .staggered(index: 1)

                        Spacer()

                        Button(idx == slides.count - 1 ? "Enter CVBoosta" : "Continue") {
                            HapticsService.impact(.light)
                            if page < slides.count - 1 {
                                withAnimation(BoostaMotion.snap) {
                                    page += 1
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoostaColor.accent)
                        .font(BoostaType.bodyStrong)
                    }
                    .padding(BoostaSpace.xl)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct OnboardingSlide {
    let title: String
    let body: String
    let accent: Color
}

#Preview {
    OnboardingView()
}
