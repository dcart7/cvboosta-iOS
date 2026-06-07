import SwiftUI
import SwiftData

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
                    ScrollView {
                        settingsGrid(width: proxy.size.width)
                            .padding(.horizontal, BoostaSpace.xl)
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
                Task { await authViewModel.refreshSharedState() }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
            }
        }
    }

    private func settingsGrid(width: CGFloat) -> some View {
        let columnCount = settingsColumnCount(for: width)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 320), spacing: BoostaSpace.lg, alignment: .top),
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

    private func settingsColumnCount(for width: CGFloat) -> Int {
        if width >= 1220 { return 3 }
        if width >= 860 { return 2 }
        return 1
    }

    private var headerCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account & App")
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text("Manage your plan, privacy, appearance, and workflow preferences.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceActionButton(title: "Upgrade", systemImage: "crown", isDisabled: subscriptionService.isPremium) {
                        showPaywall = true
                    }

                    WorkspaceActionButton(title: "Log out", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await authViewModel.logout() }
                    }
                }
            }
        }
    }

    private var accountCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Account")

                HStack(spacing: BoostaSpace.lg) {
                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        infoRow("Name", value: userName)
                        infoRow("Email", value: email)
                        infoRow("Subscription", value: planTitle)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        infoRow("Resume history", value: "\(authViewModel.me?.savedResumes.count ?? 0)")
                        infoRow("Scan history", value: "\(authViewModel.me?.scanHistory.count ?? 0)")
                        infoRow("Applications", value: "\(trackedApplications.count)")
                    }
                }
            }
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
                settingsToggle("Haptics", subtitle: "Subtle feedback during scans and actions", isOn: $hapticsEnabled)
                settingsToggle("Biometric Lock", subtitle: "Protect account and resume data", isOn: $biometricsEnabled)
            }
        }
    }

    private var appCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "App")
                infoRow("Support", value: "support@cvboosta.com")
                infoRow("Version", value: "1.0")

                SecondaryButton(title: "Open Privacy Policy") {
                    openURL(AppEnvironment.webBaseURL.appending(path: "privacy-policy"))
                }
                .hoverEffect(.highlight)

                SecondaryButton(title: "Open Terms of Service") {
                    openURL(AppEnvironment.webBaseURL.appending(path: "terms-of-service"))
                }
                .hoverEffect(.highlight)

                SecondaryButton(title: "Open Website Dashboard") {
                    openURL(AppEnvironment.webBaseURL)
                }
                .hoverEffect(.highlight)
            }
        }
    }

    private func infoRow(_ title: String, value: String) -> some View {
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
                .background(isDisabled ? Color.white.opacity(0.35) : Color.white.opacity(0.55))
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
