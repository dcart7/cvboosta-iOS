import SwiftUI

enum PaywallPresentationContext: Identifiable, Equatable {
    case standard
    case postLogin
    case postRegister
    case optimizationLimit(resetDate: Date?)

    var id: String {
        switch self {
        case .standard:
            return "standard"
        case .postLogin:
            return "postLogin"
        case .postRegister:
            return "postRegister"
        case .optimizationLimit(let resetDate):
            return "optimizationLimit-\(resetDate?.timeIntervalSince1970 ?? 0)"
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var restoreMessage: String?

    let context: PaywallPresentationContext

    private let plans: [WebsitePlan] = [
        .init(title: "Single Scan", badge: "Pay as you go", price: 1.15, cadence: "one-time", features: ["1 ATS scan", "Quick recruiter visibility check"], accent: BoostaColor.warning),
        .init(title: "Go", badge: "Most flexible", price: 9.20, cadence: "/ month", features: ["Unlimited ATS scans", "ATS score + keyword gaps", "Resume optimization preview"], accent: BoostaColor.accent),
        .init(title: "Pro", badge: "Best value", price: 23.00, cadence: "/ month", features: ["Everything in Go", "Tailoring workspace", "Deeper analytics + AI insights", "Priority web studio access"], accent: BoostaColor.success),
        .init(title: "Lifetime", badge: "One payment", price: 137.99, cadence: "once", features: ["Permanent CVBoosta access", "All premium ATS + tailoring tools", "No renewals"], accent: BoostaColor.accentSecondary)
    ]

    init(context: PaywallPresentationContext = .standard) {
        self.context = context
    }

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
                    heroCard

                    benefitsCard
                    plansCard

                    PrimaryButton(title: primaryCTA) {
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

                    SecondaryButton(title: secondaryCTA) {
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

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    Image(systemName: heroIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(heroTint)
                        .frame(width: 42, height: 42)
                        .background(heroTint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(heroTitle)
                            .font(BoostaType.section)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(heroSubtitle)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                if let supportText {
                    Text(supportText)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Free", value: "1/day", color: BoostaColor.warning)
                    MetricPill(title: "Premium", value: "Unlimited", color: BoostaColor.success)
                    MetricPill(title: "Sync", value: "Shared account", color: BoostaColor.accent)
                }
            }
        }
    }

    private var benefitsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                ForEach(benefitItems, id: \.self) { item in
                    benefit(item)
                }
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

    private var heroTitle: String {
        switch context {
        case .standard:
            return "Same plans as CVBoosta web, adapted for iOS."
        case .postLogin:
            return "You’re in — unlock the full workflow when you need it."
        case .postRegister:
            return "Strong start. Keep free for now or unlock more depth."
        case .optimizationLimit:
            return "Today’s free optimization is used."
        }
    }

    private var heroSubtitle: String {
        switch context {
        case .standard:
            return "App pricing is set 15% above the website while account access, ATS logic, and subscription status stay shared."
        case .postLogin:
            return "Free already works well. Premium simply removes the daily cap and opens deeper ATS and tailoring output."
        case .postRegister:
            return "You can explore CVBoosta on free, then upgrade only when you want unlimited scanning and deeper insights."
        case .optimizationLimit(let resetDate):
            if let resetDate {
                return "You can wait until \(resetDate.formatted(date: .omitted, time: .shortened)) or keep optimizing now with Premium."
            }
            return "You can come back tomorrow for another free run, or unlock unlimited optimizations now."
        }
    }

    private var supportText: String? {
        switch context {
        case .standard:
            return nil
        case .postLogin:
            return "This is just a soft prompt — you can dismiss it and keep using the app on free."
        case .postRegister:
            return "No pressure: the free plan stays active immediately."
        case .optimizationLimit:
            return "Your account, history, and results stay the same either way."
        }
    }

    private var heroIcon: String {
        switch context {
        case .standard:
            return "crown"
        case .postLogin, .postRegister:
            return "sparkles"
        case .optimizationLimit:
            return "timer"
        }
    }

    private var heroTint: Color {
        switch context {
        case .standard:
            return BoostaColor.accent
        case .postLogin, .postRegister:
            return BoostaColor.success
        case .optimizationLimit:
            return BoostaColor.warning
        }
    }

    private var primaryCTA: String {
        switch context {
        case .optimizationLimit:
            return "Keep optimizing today"
        case .postLogin, .postRegister:
            return "See Premium plans"
        case .standard:
            return "Continue"
        }
    }

    private var secondaryCTA: String {
        switch context {
        case .postLogin, .postRegister:
            return "Stay on Free"
        case .optimizationLimit:
            return "Maybe Later"
        case .standard:
            return "Maybe Later"
        }
    }

    private var benefitItems: [String] {
        switch context {
        case .standard:
            return [
                "Shared CVBoosta account across web, iPhone, and iPad",
                "Unlimited ATS scans on paid plans",
                "AI rewrite engine + role-specific tailoring",
                "Recruiter visibility prediction",
                "Advanced keyword targeting + analytics",
                "Priority access to CVBoosta Studio on web"
            ]
        case .postLogin, .postRegister:
            return [
                "Keep the same shared account across web, iPhone, and iPad",
                "Unlock unlimited ATS scans when free feels too tight",
                "See more keyword gaps, recommendations, and rewrite depth",
                "Open richer tailoring and analytics output"
            ]
        case .optimizationLimit:
            return [
                "Unlimited ATS scans and optimizations today",
                "More keyword gaps and deeper AI recommendations",
                "Full tailoring depth without waiting for tomorrow",
                "Shared subscription status across web, iPhone, and iPad"
            ]
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
