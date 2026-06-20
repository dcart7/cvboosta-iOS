import SwiftUI

enum PaywallPresentationContext: Identifiable, Equatable {
    case standard
    case postLogin
    case postRegister
    case optimizationLimit(resetDate: Date?)
    case workspaceFeatureLimit(feature: WorkspaceDailyFeature, resetDate: Date?)

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
        case .workspaceFeatureLimit(let feature, let resetDate):
            return "workspaceFeatureLimit-\(feature.rawValue)-\(resetDate?.timeIntervalSince1970 ?? 0)"
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    let context: PaywallPresentationContext

    private let plans: [AppStorePlan] = [
        .init(title: "Single Scan", badge: "Pay as you go", productID: AppEnvironment.appStoreSingleScanProductID, fallbackPrice: 1.00, cadence: "one-time", ctaTitle: "Buy", features: ["1 ATS scan", "Free plan still keeps 4 cover letters/day", "Free plan still keeps 4 interview prep regenerations/day"], accent: BoostaColor.warning),
        .init(title: "Go", badge: "Most flexible", productID: AppEnvironment.appStoreGoMonthlyProductID, fallbackPrice: 10.00, cadence: "/ month", ctaTitle: "Subscribe", features: ["Unlimited ATS scans", "20 cover letters per day", "20 interview prep regenerations per day", "Resume optimization preview"], accent: BoostaColor.accent),
        .init(title: "Pro", badge: "Best value", productID: AppEnvironment.appStoreProMonthlyProductID, fallbackPrice: 25.00, cadence: "/ month", ctaTitle: "Subscribe", features: ["Everything in Go", "Unlimited cover letters", "Unlimited interview prep regenerations", "Deeper analytics + AI insights"], accent: BoostaColor.success),
        .init(title: "Lifetime", badge: "One payment", productID: AppEnvironment.appStoreLifetimeProductID, fallbackPrice: 150.00, cadence: "once", ctaTitle: "Unlock", features: ["Permanent CVBoosta access", "Unlimited cover letters", "Unlimited interview prep regenerations", "No renewals"], accent: BoostaColor.accentSecondary)
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
                        Task {
                            await handlePrimaryCTA()
                        }
                    }

                    SecondaryButton(title: subscriptionService.isRestoringStorePurchases ? "Restoring..." : "Restore Purchases", isDisabled: subscriptionService.isRestoringStorePurchases || subscriptionService.isLoadingStoreProducts) {
                        Task {
                            await subscriptionService.restorePurchases()
                            await authViewModel.refreshSharedState()
                        }
                    }

                    SecondaryButton(title: secondaryCTA) {
                        dismiss()
                    }

                    if let storeStatusMessage = subscriptionService.storeStatusMessage {
                        Text(storeStatusMessage)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    if let storeErrorMessage = subscriptionService.storeErrorMessage {
                        Text(storeErrorMessage)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.warning)
                    }
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Premium")
        .task {
            await subscriptionService.prepareStore()
        }
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        MetricPill(title: "Free", value: "4/day", color: BoostaColor.warning)
                        MetricPill(title: "Go", value: "20/day", color: BoostaColor.accent)
                        MetricPill(title: "Pro", value: "Unlimited", color: BoostaColor.success)
                        MetricPill(title: "Sync", value: "Shared account", color: BoostaColor.accent)
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        HStack(spacing: BoostaSpace.sm) {
                            MetricPill(title: "Free", value: "4/day", color: BoostaColor.warning)
                            MetricPill(title: "Go", value: "20/day", color: BoostaColor.accent)
                        }
                        HStack(spacing: BoostaSpace.sm) {
                            MetricPill(title: "Pro", value: "Unlimited", color: BoostaColor.success)
                            MetricPill(title: "Sync", value: "Shared account", color: BoostaColor.accent)
                        }
                    }
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

                Text("Free includes 1 ATS optimization/day, 4 cover letters/day, and 4 interview prep regenerations/day. Go includes 20/day for cover letters and interview prep. Pro and Lifetime unlock both without a daily cap.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                Text("App Store pricing: Single Scan $1, Go $10/mo, Pro $25/mo, Lifetime $150.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                if subscriptionService.isLoadingStoreProducts {
                    Text("Loading App Store products…")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.primaryText)
    }

    private func planRow(_ plan: AppStorePlan) -> some View {
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
                    Text(subscriptionService.displayPrice(for: plan.productID, fallback: plan.fallbackPrice))
                        .font(BoostaType.bodyStrong)
                    Text(plan.cadence)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
            .padding(.vertical, 6)

            Button {
                Task {
                    await subscriptionService.purchase(productID: plan.productID)
                    await authViewModel.refreshSharedState()
                }
            } label: {
                Text(subscriptionService.isProductAvailable(plan.productID) ? subscriptionService.purchaseButtonTitle(for: plan.productID) : "Unavailable")
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(subscriptionService.isProductAvailable(plan.productID) ? plan.accent : BoostaColor.surfaceDisabled)
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!subscriptionService.isProductAvailable(plan.productID) || subscriptionService.purchaseInFlightProductID != nil || subscriptionService.isRestoringStorePurchases)
        }
    }

    private func handlePrimaryCTA() async {
        if subscriptionService.isPremium {
            await subscriptionService.openManageSubscriptions()
            return
        }

        openURL(AppEnvironment.webBaseURL)
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
        case .workspaceFeatureLimit(let feature, _):
            return "Today’s free \(feature.shortTitle) limit is used."
        }
    }

    private var heroSubtitle: String {
        switch context {
        case .standard:
            return "Choose the App Store plan that fits you best while keeping the same CVBoosta account, ATS logic, and synced history."
        case .postLogin:
            return "Free already works well. Premium simply removes the daily cap and opens deeper ATS and tailoring output."
        case .postRegister:
            return "You can explore CVBoosta on free, then upgrade only when you want unlimited scanning and deeper insights."
        case .optimizationLimit(let resetDate):
            if let resetDate {
                return "You can wait until \(resetDate.formatted(date: .omitted, time: .shortened)) or keep optimizing now with Premium."
            }
            return "You can come back tomorrow for another free run, or unlock unlimited optimizations now."
        case .workspaceFeatureLimit(let feature, let resetDate):
            if let resetDate {
                return "Free includes 4 \(feature.shortTitle) per day. You can wait until \(resetDate.formatted(date: .omitted, time: .shortened)) or unlock more capacity now."
            }
            return "Free includes 4 \(feature.shortTitle) per day. Upgrade when you want more room without waiting for tomorrow."
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
        case .workspaceFeatureLimit:
            return "Your tracker workspace, history, and generated assets stay with the same shared account."
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
        case .workspaceFeatureLimit(let feature, _):
            switch feature {
            case .coverLetter:
                return "text.badge.sparkles"
            case .interviewPrep:
                return "person.crop.rectangle.stack"
            }
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
        case .workspaceFeatureLimit(let feature, _):
            switch feature {
            case .coverLetter:
                return BoostaColor.accentSecondary
            case .interviewPrep:
                return BoostaColor.warning
            }
        }
    }

    private var primaryCTA: String {
        switch context {
        case .optimizationLimit:
            return subscriptionService.isPremium ? "Manage App Store Plan" : "Open Website Dashboard"
        case .workspaceFeatureLimit:
            return subscriptionService.isPremium ? "Manage App Store Plan" : "Open Website Dashboard"
        case .postLogin, .postRegister:
            return subscriptionService.isPremium ? "Manage App Store Plan" : "Open Website Dashboard"
        case .standard:
            return subscriptionService.isPremium ? "Manage App Store Plan" : "Open Website Dashboard"
        }
    }

    private var secondaryCTA: String {
        switch context {
        case .postLogin, .postRegister:
            return "Stay on Free"
        case .optimizationLimit:
            return "Maybe Later"
        case .workspaceFeatureLimit:
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
        case .workspaceFeatureLimit(let feature, _):
            return [
                "Free includes 4 \(feature.shortTitle) per day",
                "Go raises \(feature.shortTitle) to 20 per day",
                "Pro and Lifetime remove the daily cap",
                "Your shared CVBoosta account stays in sync across web, iPhone, and iPad"
            ]
        }
    }
}

private struct AppStorePlan: Identifiable {
    let id = UUID()
    let title: String
    let badge: String
    let productID: String
    let fallbackPrice: Double
    let cadence: String
    let ctaTitle: String
    let features: [String]
    let accent: Color
}

#Preview {
    NavigationStack {
        PaywallView()
            .environmentObject(AuthViewModel())
    }
}
