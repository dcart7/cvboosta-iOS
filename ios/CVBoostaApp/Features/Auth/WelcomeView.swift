import SwiftUI

struct WelcomeView: View {
    private let storySteps = [
        "Upload your CV and let CVBoosta decode what ATS systems actually see.",
        "Get role-specific optimization, missing keywords, and sharper positioning in minutes.",
        "Apply with more confidence using one account across iPhone, iPad, and web."
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BoostaSpace.xl) {
                        heroSection
                            .staggered(index: 0)

                        statGrid
                            .staggered(index: 1)

                        actionSection
                            .staggered(index: 2)

                        AuthStoryCard(
                            title: "The CVBoosta revolution",
                            steps: storySteps
                        )
                        .staggered(index: 3)

                        featureSection
                            .staggered(index: 4)
                    }
                    .padding(.horizontal, BoostaSpace.lg)
                    .padding(.top, BoostaSpace.xl)
                    .padding(.bottom, BoostaSpace.xxl)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.md) {
            BrandMarkView(size: 88)

            AuthHeadlineBlock(
                eyebrow: "Career acceleration",
                title: "Turn one CV into a faster, smarter job-search engine.",
                subtitle: "CVBoosta helps you beat generic applications with ATS analysis, tailored rewrites, and a workflow that feels built for the modern market."
            )

            Text("Native on Apple devices. Connected to your real CVBoosta account.")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.tertiaryText)
        }
    }

    private var statGrid: some View {
        VStack(spacing: BoostaSpace.sm) {
            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "ATS-first", detail: "Pinpoint missing skills before you send.")
                AuthStatPill(title: "One account", detail: "Web, iPhone, and iPad stay aligned.")
            }

            HStack(spacing: BoostaSpace.sm) {
                AuthStatPill(title: "Fast clarity", detail: "See what to change and why it matters.")
                AuthStatPill(title: "Premium flow", detail: "A polished workspace for focused applications.")
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

            Text("Private by default. Built to help your experience land better interviews, not just prettier PDFs.")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var featureSection: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text("Why candidates switch")
                    .font(BoostaType.section)
                    .foregroundStyle(BoostaColor.primaryText)

                AuthFeatureRow(
                    icon: "wand.and.stars",
                    title: "Tailored, not templated",
                    detail: "Each role gets a sharper positioning angle, stronger keyword match, and better narrative."
                )
                AuthFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Feedback that moves fast",
                    detail: "See impact signals, weak spots, and practical edits without guesswork."
                )
                AuthFeatureRow(
                    icon: "rectangle.split.3x1",
                    title: "Built like a workspace",
                    detail: "A polished native experience that feels closer to a productivity tool than a stretched form."
                )
            }
        }
    }
}

#Preview {
    WelcomeView()
}
