import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BoostaSpace.lg) {
                        heroSection
                            .staggered(index: 0)

                        statGrid
                            .staggered(index: 1)

                        actionSection
                            .staggered(index: 2)
                    }
                    .padding(.horizontal, BoostaSpace.lg)
                    .padding(.top, 56)
                    .padding(.bottom, BoostaSpace.xxl)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            BrandMarkView(size: 70)

            AuthHeadlineBlock(
                eyebrow: "CVBoosta",
                title: "Better CVs. Smarter applications.",
                subtitle: "ATS analysis and tailoring in a clean native workspace."
            )
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "ATS-first", detail: "See gaps before you apply.")
                AuthStatPill(title: "One account", detail: "Web, iPhone, and iPad.")
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: BoostaSpace.sm) {
            AuthPrimaryNavigationButton(title: "Start the CV revolution") {
                RegisterView()
            }

            AuthSecondaryNavigationButton(
                title: "I already have an account",
                systemImage: "person.crop.circle.badge.checkmark"
            ) {
                LoginView()
            }
        }
    }
}

#Preview {
    WelcomeView()
}
