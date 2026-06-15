import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Query private var trackedApplications: [ApplicationRecord]
    @AppStorage(AppPreferenceKeys.appearance) private var appearanceMode = AppAppearancePreference.system.rawValue
    @AppStorage(AppPreferenceKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppPreferenceKeys.biometricsEnabled) private var biometricsEnabled = true
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

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
                        preferencesSection
                        appSection
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await authViewModel.refreshSharedState()
                    await refreshNotificationAuthorizationStatus()
                }
            }
            .onChange(of: notificationsEnabled) { _, isEnabled in
                Task {
                    await PushNotificationService.shared.applyUserPreference(isEnabled: isEnabled)
                    await refreshNotificationAuthorizationStatus()
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
                if let lastSyncedAt = subscriptionService.lastSyncedAt {
                    row("Last synced", value: lastSyncedAt.formatted(date: .omitted, time: .shortened))
                }

                Text("Unlock unlimited scans, deeper ATS intelligence, AI rewrite power, interview prediction signals, and stronger recruiter visibility.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

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

                SecondaryButton(title: "Manage on Website") {
                    openURL(AppEnvironment.webBaseURL)
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
                row("Applications", value: "\(trackedApplications.count)")

                SecondaryButton(title: "Delete Account") {
                    // Backend endpoint is not implemented yet.
                }
                .opacity(0.7)
            }
        }
    }

    private var preferencesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Preferences")

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    Text("Appearance")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)

                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppAppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                ToggleRow(title: "Notifications", subtitle: "Career reminders and follow-up nudges", isOn: $notificationsEnabled)
                if notificationsEnabled {
                    notificationStatusView
                }
                ToggleRow(title: "Haptics", subtitle: "Keep subtle feedback during scans and actions", isOn: $hapticsEnabled)
                ToggleRow(title: "Biometric Lock", subtitle: "Protect sensitive resume and account data", isOn: $biometricsEnabled)
            }
        }
    }

    private var appSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "App")
                row("Version", value: appVersion)
                row("Contact Support", value: AppEnvironment.supportEmail)

                SecondaryButton(title: "Open Privacy Policy") {
                    openURL(AppEnvironment.privacyPolicyURL)
                }

                SecondaryButton(title: "Open Terms of Service") {
                    openURL(AppEnvironment.termsOfServiceURL)
                }

                SecondaryButton(title: "Open Website Dashboard") {
                    openURL(AppEnvironment.webBaseURL)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
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

    @ViewBuilder
    private var notificationStatusView: some View {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Text("Push access is enabled on this device.")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        case .denied:
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                Text("iPhone Settings still block notifications for CVBoosta.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.warning)

                SecondaryButton(title: "Open Notification Settings") {
                    openSystemNotificationSettings()
                }
            }
        case .notDetermined:
            Text("Turn this on to allow reminders, push updates, and message delivery prompts.")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        @unknown default:
            EmptyView()
        }
    }

    @MainActor
    private func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await PushNotificationService.shared.authorizationStatus()
    }

    private func openSystemNotificationSettings() {
        let rawValue = UIApplication.openNotificationSettingsURLString
        let fallback = UIApplication.openSettingsURLString
        guard let url = URL(string: rawValue.isEmpty ? fallback : rawValue) else { return }
        openURL(url)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(subtitle)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
        .tint(BoostaColor.accent)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
