import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var profileWorkspaceService = ProfileWorkspaceService.shared
    @Query private var trackedApplications: [ApplicationRecord]
    @AppStorage(AppPreferenceKeys.appearance) private var appearanceMode = AppAppearancePreference.system.rawValue
    @AppStorage(AppPreferenceKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppPreferenceKeys.biometricsEnabled) private var biometricsEnabled = true
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    private var userName: String {
        profileWorkspaceService.effectiveDisplayName(fallback: authViewModel.me?.user.displayName).isEmpty
            ? "-"
            : profileWorkspaceService.effectiveDisplayName(fallback: authViewModel.me?.user.displayName)
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
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

                NavigationLink {
                    ProfileDashboardView()
                } label: {
                    settingsNavigationRow(
                        title: "Profile",
                        subtitle: "Manage your photo, primary resume, progress, and account details"
                    )
                }
                .buttonStyle(.plain)

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
                row("Cover letters", value: workspaceLimitLabel(for: .coverLetter))
                row("Interview prep", value: workspaceLimitLabel(for: .interviewPrep))

                Text("Unlock unlimited scans, deeper ATS intelligence, AI rewrite power, more cover letters, more interview prep, and stronger recruiter visibility.")
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
                row("Resume history", value: "\(profileWorkspaceService.combinedResumeCount(remoteNames: authViewModel.me?.savedResumes.map(\.fileName) ?? []))")
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
                    .frame(maxWidth: .infinity)
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

    private func workspaceLimitLabel(for feature: WorkspaceDailyFeature) -> String {
        let status = subscriptionService.status(for: feature)
        if let dailyLimit = status.dailyLimit, let remaining = status.remainingToday {
            return "\(remaining) left of \(dailyLimit)/day"
        }
        if let remaining = status.remainingToday {
            return "\(remaining) left today"
        }
        return "Unlimited"
    }

    private func row(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: BoostaSpace.sm) {
                Text(title)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                Spacer(minLength: BoostaSpace.sm)
                Text(value)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                Text(value)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsNavigationRow(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(subtitle)
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BoostaColor.secondaryText)
                .padding(.top, 4)
        }
        .padding(.horizontal, BoostaSpace.sm)
        .padding(.vertical, 12)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
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
