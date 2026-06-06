import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var restoreMessage: String?

    private let plans: [WebsitePlan] = [
        .init(title: "Single Scan", badge: "Pay as you go", price: 1.15, cadence: "one-time", features: ["1 ATS scan", "Quick recruiter visibility check"], accent: BoostaColor.warning),
        .init(title: "Go", badge: "Most flexible", price: 9.20, cadence: "/ month", features: ["Unlimited ATS scans", "ATS score + keyword gaps", "Resume optimization preview"], accent: BoostaColor.accent),
        .init(title: "Pro", badge: "Best value", price: 23.00, cadence: "/ month", features: ["Everything in Go", "Tailoring workspace", "Deeper analytics + AI insights", "Priority web studio access"], accent: BoostaColor.success),
        .init(title: "Lifetime", badge: "One payment", price: 137.99, cadence: "once", features: ["Permanent CVBoosta access", "All premium ATS + tailoring tools", "No renewals"], accent: BoostaColor.accentSecondary)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    SectionHeader(
                        title: "Same plans as CVBoosta web, adapted for iOS.",
                        subtitle: "App pricing is set 15% above the website while account access, ATS logic, and subscription status stay shared."
                    )

                    benefitsCard
                    plansCard

                    PrimaryButton(title: "Continue") {
                        // Payments and plan management live on the website.
                        openURL(AppEnvironment.webBaseURL)
                    }

                    SecondaryButton(title: "Restore Purchases") {
                        Task {
                            await subscriptionService.restorePurchases()
                            await authViewModel.refreshSharedState()
                            restoreMessage = subscriptionService.isPremium ? "Purchases restored." : "No purchases found."
                        }
                    }

                    SecondaryButton(title: "Maybe Later") {
                        dismiss()
                    }

                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Premium")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private var benefitsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                benefit("Shared CVBoosta account across web, iPhone, and iPad")
                benefit("Unlimited ATS scans on paid plans")
                benefit("AI rewrite engine + role-specific tailoring")
                benefit("Recruiter visibility prediction")
                benefit("Advanced keyword targeting + analytics")
                benefit("Priority access to CVBoosta Studio on web")
            }
        }
    }

    private var plansCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Plans")
                    .font(BoostaType.section)

                ForEach(plans) { plan in
                    planRow(plan)
                }

                Text("Website reference: Single Scan $1, Go $8/mo, Pro $20/mo, Lifetime $119.99. iOS prices shown here are +15%.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.primaryText)
    }

    private func planRow(_ plan: WebsitePlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: BoostaSpace.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(BoostaType.bodyStrong)
                        Text(plan.badge)
                            .font(BoostaType.caption)
                            .foregroundStyle(plan.accent)
                    }

                    Text(plan.features.joined(separator: " • "))
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text(plan.price, format: .currency(code: "USD"))
                        .font(BoostaType.bodyStrong)
                    Text(plan.cadence)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct WebsitePlan: Identifiable {
    let id = UUID()
    let title: String
    let badge: String
    let price: Double
    let cadence: String
    let features: [String]
    let accent: Color
}

#Preview {
    NavigationStack {
        PaywallView()
            .environmentObject(AuthViewModel())
    }
}
