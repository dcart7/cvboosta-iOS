import SwiftUI

struct PaywallView: View {
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

            VStack(spacing: BoostaSpace.md) {
                Text("CVBoosta Pro")
                    .font(BoostaType.title)

                if subscriptionService.isPremium {
                    Text("Premium active")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.success)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        feature("Unlimited ATS scans")
                        feature("AI rewrites and tailoring")
                        feature("Interview prep simulator")
                        feature("Advanced conversion analytics")
                        feature("Role intelligence and keyword coverage")
                    }
                }

                Button("Start Free Trial") {
                    HapticsService.success()
                    // Placeholder until RevenueCat keys and products are wired.
                    subscriptionService.unlockPremiumForDebug()
                }
                .buttonStyle(.borderedProminent)
                .tint(BoostaColor.accent)

                Button("Restore Purchases") {
                    Task {
                        await subscriptionService.restorePurchases()
                        restoreMessage = subscriptionService.isPremium ? "Purchases restored." : "No purchases found."
                    }
                }
                .buttonStyle(.bordered)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Text("$12.99 / month, $79.99 / year, $199 lifetime")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
            .padding(BoostaSpace.md)
        }
    }

    private func feature(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.primaryText)
    }
}

#Preview {
    PaywallView()
}
