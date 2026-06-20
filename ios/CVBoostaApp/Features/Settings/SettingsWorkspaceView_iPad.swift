import SwiftUI
import SwiftData
import UserNotifications

/// iPad-only Settings workspace.
/// The iPhone Settings experience remains in `SettingsView` untouched.
struct SettingsWorkspaceView_iPad: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Query private var trackedApplications: [ApplicationRecord]
    @AppStorage(AppPreferenceKeys.appearance) private var appearanceMode = AppAppearancePreference.system.rawValue
    @AppStorage(AppPreferenceKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppPreferenceKeys.biometricsEnabled) private var biometricsEnabled = true

    @State private var showPaywall = false
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

                GeometryReader { proxy in
                    let horizontalPadding = WorkspaceLayoutMetrics.horizontalPadding(for: proxy.size.width)

                    ScrollView {
                        settingsGrid(width: proxy.size.width, horizontalPadding: horizontalPadding)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, BoostaSpace.lg)
                            .padding(.bottom, BoostaSpace.xxl)
                            .frame(maxWidth: 1400)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await authViewModel.refreshSharedState() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .hoverEffect(.lift)

                    Button {
                        openURL(AppEnvironment.webBaseURL)
                    } label: {
                        Label("Website", systemImage: "safari")
                    }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .hoverEffect(.lift)
                }
            }
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
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
            }
        }
    }

    private func settingsGrid(width: CGFloat, horizontalPadding: CGFloat) -> some View {
        let columnCount = settingsColumnCount(for: width, horizontalPadding: horizontalPadding)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 300), spacing: BoostaSpace.lg, alignment: .top),
            count: columnCount
        )

        return LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
            headerCard
                .gridCellColumns(columnCount)

            accountCard
                .gridCellColumns(min(2, columnCount))

            subscriptionCard
            dataCard
            preferencesCard
            appCard
        }
        .animation(BoostaMotion.smooth, value: columnCount)
    }

    private func settingsColumnCount(for width: CGFloat, horizontalPadding: CGFloat) -> Int {
        WorkspaceLayoutMetrics.columnCount(
            for: width,
            minCardWidth: 300,
            maxColumns: 3,
            horizontalPadding: horizontalPadding
        )
    }

    private var headerCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: BoostaSpace.lg) {
                    settingsHeaderContent
                    Spacer(minLength: 0)
                    settingsHeaderActions
                }

                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    settingsHeaderContent
                    settingsHeaderActions
                }
            }
        }
    }

    private var settingsHeaderContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account & App")
                .font(BoostaType.title)
                .foregroundStyle(BoostaColor.primaryText)
            Text("Manage your plan, privacy, appearance, and workflow preferences.")
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsHeaderActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BoostaSpace.sm) {
                settingsHeaderButtons
            }

            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                settingsHeaderButtons
            }
        }
    }

    private var settingsHeaderButtons: some View {
        Group {
            WorkspaceActionButton(title: "Upgrade", systemImage: "crown", isDisabled: subscriptionService.isPremium) {
                showPaywall = true
            }

            WorkspaceActionButton(title: "Log out", systemImage: "rectangle.portrait.and.arrow.right") {
                Task { await authViewModel.logout() }
            }
        }
    }

    private var accountCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Account")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.lg) {
                        accountPrimaryDetails
                        Spacer(minLength: 0)
                        accountSecondaryDetails
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        accountPrimaryDetails
                        accountSecondaryDetails
                    }
                }
            }
        }
    }

    private var accountPrimaryDetails: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            infoRow("Name", value: userName)
            infoRow("Email", value: email)
            infoRow("Subscription", value: planTitle)
        }
    }

    private var accountSecondaryDetails: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            infoRow("Resume history", value: "\(authViewModel.me?.savedResumes.count ?? 0)")
            infoRow("Scan history", value: "\(authViewModel.me?.scanHistory.count ?? 0)")
            infoRow("Applications", value: "\(trackedApplications.count)")
        }
    }

    private var subscriptionCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Subscription")
                infoRow("Current plan", value: planTitle)
                if let lastSyncedAt = subscriptionService.lastSyncedAt {
                    infoRow("Last synced", value: lastSyncedAt.formatted(date: .omitted, time: .shortened))
                }
                infoRow("Cover letters", value: workspaceLimitLabel(for: .coverLetter))
                infoRow("Interview prep", value: workspaceLimitLabel(for: .interviewPrep))

                PrimaryButton(title: subscriptionService.isPremium ? "Premium Active" : "Upgrade to Premium", isDisabled: subscriptionService.isPremium) {
                    showPaywall = true
                }
                .hoverEffect(.lift)

                SecondaryButton(title: "Restore Purchases") {
                    Task {
                        await subscriptionService.restorePurchases()
                        await authViewModel.refreshSharedState()
                    }
                }
                .hoverEffect(.highlight)

                SecondaryButton(title: "Manage on Website") {
                    openURL(AppEnvironment.webBaseURL)
                }
                .hoverEffect(.highlight)
            }
        }
    }

    private var dataCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Data")
                Text("Your data syncs with CVBoosta Studio on web.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                infoRow("Scan history", value: "\(authViewModel.me?.scanHistory.count ?? 0)")
                infoRow("Applications", value: "\(trackedApplications.count)")

                SecondaryButton(title: "Delete Account") {
                    // Backend endpoint is not implemented yet.
                }
                .opacity(0.7)
                .hoverEffect(.highlight)
            }
        }
    }

    private var preferencesCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Preferences")

                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppAppearancePreference.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                settingsToggle("Notifications", subtitle: "Career reminders and follow-up nudges", isOn: $notificationsEnabled)
                if notificationsEnabled {
                    notificationStatusView
                }
                settingsToggle("Haptics", subtitle: "Subtle feedback during scans and actions", isOn: $hapticsEnabled)
                settingsToggle("Biometric Lock", subtitle: "Protect account and resume data", isOn: $biometricsEnabled)
            }
        }
    }

    private var appCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "App")
                infoRow("Support", value: AppEnvironment.supportEmail)
                infoRow("Version", value: appVersion)

                SecondaryButton(title: "Open Privacy Policy") {
                    openURL(AppEnvironment.privacyPolicyURL)
                }
                .hoverEffect(.highlight)

                SecondaryButton(title: "Open Terms of Service") {
                    openURL(AppEnvironment.termsOfServiceURL)
                }
                .hoverEffect(.highlight)

                SecondaryButton(title: "Open Website Dashboard") {
                    openURL(AppEnvironment.webBaseURL)
                }
                .hoverEffect(.highlight)
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

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            Text(title)
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(value)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
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
                Text("iPad Settings still block notifications for CVBoosta.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.warning)

                SecondaryButton(title: "Open Notification Settings") {
                    openSystemNotificationSettings()
                }
                .hoverEffect(.highlight)
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

extension SettingsWorkspaceView_iPad {
    @ViewBuilder
    private func settingsToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
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

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(isDisabled ? BoostaColor.surfaceDisabled : BoostaColor.surfaceInteractive)
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
        .hoverEffect(.lift)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview("Settings Workspace (iPad)") {
    SettingsWorkspaceView_iPad()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
