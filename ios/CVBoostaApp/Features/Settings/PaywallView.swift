import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var restoreMessage: String?

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
                        title: "Unlock your full interview potential.",
                        subtitle: "Unlimited ATS scans, full tailoring, and advanced keyword intelligence."
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
                benefit("Unlimited ATS scans")
                benefit("Full resume tailoring")
                benefit("AI rewrite suggestions")
                benefit("Advanced keyword intelligence")
                benefit("Interview preparation")
                benefit("Application analytics")
            }
        }
    }

    private var plansCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                Text("Plans")
                    .font(BoostaType.section)

                planRow("Monthly", "$12.99")
                planRow("Yearly", "$79.99")
                planRow("Lifetime", "$199")
            }
        }
    }

    private func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.primaryText)
    }

    private func planRow(_ title: String, _ price: String) -> some View {
        HStack {
            Text(title)
                .font(BoostaType.body)
            Spacer()
            Text(price)
                .font(BoostaType.bodyStrong)
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView()
            .environmentObject(AuthViewModel())
    }
}
