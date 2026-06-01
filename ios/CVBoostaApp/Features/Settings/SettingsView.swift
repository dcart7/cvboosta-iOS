import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    private var userName: String {
        authViewModel.me?.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? authViewModel.me?.user.displayName ?? "-"
            : "-"
    }

    private var email: String {
        authViewModel.me?.user.email ?? "-"
    }

    private var planTitle: String {
        if subscriptionService.isPremium {
            return subscriptionService.entitlement ?? "Premium"
        }
        return "Free"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: BoostaSpace.md) {
                        accountSection
                        subscriptionSection
                        dataSection
                        appSection
                        developerSection
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await authViewModel.refreshSharedState()
                }
            }
        }
    }

    private var accountSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Account")
                row("Name", value: userName)
                row("Email", value: email)
                row("Subscription", value: planTitle)

                PrimaryButton(title: "Log out") {
                    Task {
                        await authViewModel.logout()
                    }
                }
            }
        }
    }

    private var subscriptionSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Subscription")
                row("Current plan", value: planTitle)

                NavigationLink {
                    PaywallView()
                } label: {
                    Text("Upgrade to Premium")
                        .font(BoostaType.bodyStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BoostaSpace.sm)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(BoostaColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))

                SecondaryButton(title: "Restore Purchases") {
                    Task {
                        await subscriptionService.restorePurchases()
                        await authViewModel.refreshSharedState()
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Data")
                row("Resume history", value: "\(authViewModel.me?.savedResumes.count ?? 0)")
                row("Scan history", value: "\(authViewModel.me?.scanHistory.count ?? 0)")

                SecondaryButton(title: "Delete Account") {
                    // Backend endpoint is not implemented yet.
                }
                .opacity(0.7)
            }
        }
    }

    private var appSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "App")
                row("Appearance", value: "System")
                row("Notifications", value: "Enabled")
                row("Privacy Policy", value: "Available")
                row("Terms of Service", value: "Available")
                row("Contact Support", value: "support@cvboosta.com")
            }
        }
    }

    private var developerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Developer")
                row("API environment", value: AppEnvironment.apiBaseURL.absoluteString)
                row("App version", value: "1.0")
            }
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
            Spacer()
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
