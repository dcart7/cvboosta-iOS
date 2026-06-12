import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        heroSection
                            .staggered(index: 0)

                        AuthSocialProofRow()
                            .staggered(index: 1)

                        statGrid
                            .staggered(index: 2)

                        AuthProductPreviewCard()
                            .staggered(index: 3)

                        actionSection
                            .staggered(index: 4)

                        AuthTrustRow()
                            .staggered(index: 5)
                    }
                    .padding(.horizontal, BoostaSpace.lg)
                    .padding(.top, 44)
                    .padding(.bottom, BoostaSpace.xxl)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            BrandMarkView(size: 76)

            AuthHeadlineBlock(
                eyebrow: "Designed for modern hiring",
                title: "Better applications start here.",
                subtitle: "Check ATS score, detect keyword gaps, and improve every application with clearer, smarter resume edits."
            )
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "Real ATS matching", detail: "See what hiring systems miss.")
                AuthStatPill(title: "Tailored per job", detail: "Optimize for each application.")
            }
            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "AI-powered optimization", detail: "Sharper bullets and stronger keyword alignment.")
                AuthStatPill(title: "Interview insights", detail: "Surface the strengths recruiters notice first.")
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: BoostaSpace.sm) {
            AppleSignInActionButton(label: .continue)

            AuthPrimaryNavigationButton(title: "Check ATS Score") {
                RegisterView()
            }

            AuthSecondaryNavigationButton(
                title: "I already have an account",
                systemImage: "person.crop.circle.badge.checkmark"
            ) {
                LoginView()
            }

            if let errorMessage = authViewModel.errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
