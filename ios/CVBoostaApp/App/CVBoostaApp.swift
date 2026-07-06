import SwiftUI
import SwiftData
import UIKit

@main
struct CVBoostaApp: App {
    @UIApplicationDelegateAdaptor(CVBoostaAppDelegate.self) private var appDelegate

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appRouter = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let cloudSchema = Schema([
            ApplicationFolder.self,
            ApplicationRecord.self,
            CloudResumeAsset.self,
            CloudStreakState.self
        ])

        let localSchema = Schema([
            ResumeProfile.self,
            ATSInsight.self,
            LatestScanReport.self,
            SavedTailoringSuggestion.self
        ])

        let fullSchema = Schema([
            ResumeProfile.self,
            ApplicationFolder.self,
            ApplicationRecord.self,
            CloudResumeAsset.self,
            CloudStreakState.self,
            ATSInsight.self,
            LatestScanReport.self,
            SavedTailoringSuggestion.self
        ])

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        do {
            if isPreview {
                let previewConfig = ModelConfiguration(
                    schema: fullSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: fullSchema, configurations: previewConfig)
            }

            let trackerConfiguration = ModelConfiguration(
                "TrackerCloud",
                schema: cloudSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            let localConfiguration = ModelConfiguration(
                "WorkspaceLocal",
                schema: localSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: fullSchema,
                configurations: trackerConfiguration,
                localConfiguration
            )
        } catch {
            let trackerFallbackConfiguration = ModelConfiguration(
                "TrackerFallback",
                schema: cloudSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let localConfiguration = ModelConfiguration(
                "WorkspaceLocalFallback",
                schema: localSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            if let fallback = try? ModelContainer(
                for: fullSchema,
                configurations: trackerFallbackConfiguration,
                localConfiguration
            ) {
                return fallback
            }
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authViewModel)
                .environmentObject(appRouter)
                .task {
                    await authViewModel.bootstrap()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppPreferenceKeys.appearance) private var appearanceMode = AppAppearancePreference.system.rawValue
    @AppStorage(SharedStreakState.updatedAtKey, store: SharedStreakState.sharedDefaults)
    private var streakStateUpdatedAt = 0.0
    @State private var accountSyncTicker = Timer.publish(every: 180, on: .main, in: .common).autoconnect()
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var profileWorkspaceService = ProfileWorkspaceService.shared
    @State private var authPaywallContext: PaywallPresentationContext?
    @State private var isAccountSyncInFlight = false
    @State private var hasPendingAccountSyncRequest = false
    @State private var workspaceCloudSyncReady = false
    @State private var lastCloudResumeRevision = Date.distantPast
    @State private var lastCloudStreakRevision = Date.distantPast

    private var accountTrackerSignature: String {
        let trackerSource = authViewModel.me?.hasTrackerSnapshot == true ? "remote" : "local"
        let folderSignature = authViewModel.me?.applicationFolders
            .sorted(by: { $0.createdAt < $1.createdAt })
            .map { "\($0.id.uuidString)-\($0.name)-\($0.emoji)-\($0.createdAt.timeIntervalSince1970)" }
            .joined(separator: "|") ?? ""

        let applicationSignature = authViewModel.me?.applications
            .sorted(by: { $0.appliedAt < $1.appliedAt })
            .map {
                "\($0.id.uuidString)-\($0.status)-\($0.appliedAt.timeIntervalSince1970)-\($0.folderID?.uuidString ?? "none")-\($0.interviewReflectionSubmittedAt?.timeIntervalSince1970 ?? 0)"
            }
            .joined(separator: "|") ?? ""

        return [trackerSource, folderSignature, applicationSignature].joined(separator: "||")
    }

    private var resumeCloudSyncSignature: TimeInterval {
        profileWorkspaceService.resumeSyncRevisionDate.timeIntervalSinceReferenceDate
    }

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ZStack {
                    AuthBackgroundView()

                    ProgressView("Loading account...")
                        .tint(BoostaColor.accentSecondary)
                }
            case .loggedOut:
                WelcomeView()
            case .loggedIn:
                RootTabView()
            }
        }
        .preferredColorScheme(AppAppearancePreference(rawValue: appearanceMode)?.colorScheme)
        .task {
            await reconcileWorkspaceCloudState()
        }
        .task(id: accountTrackerSignature) {
            syncAccountTrackerState()
        }
        .task(id: resumeCloudSyncSignature) {
            await pushLocalResumeChangesIfNeeded()
        }
        .task(id: streakStateUpdatedAt) {
            pushLocalStreakChangesIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await reconcileWorkspaceCloudState()
                await PushNotificationService.shared.refreshRegistrationState()
                if authViewModel.state == .loggedIn {
                    await PushNotificationService.shared.syncIfPossible()
                }
            }
            guard authViewModel.state == .loggedIn else { return }
            requestAccountSync()
        }
        .onChange(of: authViewModel.pendingFreshAuthEvent) { _, event in
            guard let event, authViewModel.state == .loggedIn, !subscriptionService.isPremium else { return }
            switch event {
            case .login:
                authPaywallContext = .postLogin
            case .register:
                authPaywallContext = .postRegister
            }
            authViewModel.consumePendingFreshAuthEvent()
        }
        .onReceive(accountSyncTicker) { _ in
            guard scenePhase == .active, authViewModel.state == .loggedIn else { return }
            requestAccountSync()
        }
        .sheet(item: $authPaywallContext) { context in
            NavigationStack {
                PaywallView(context: context)
                    .environmentObject(authViewModel)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @MainActor
    private func syncAccountTrackerState() {
        guard authViewModel.state == .loggedIn else { return }
        guard authViewModel.me?.hasTrackerSnapshot == true else {
            syncLocalTrackerWidgetSnapshot()
            return
        }

        let accountFolders = authViewModel.me?.applicationFolders ?? []
        let accountApplications = authViewModel.me?.applications ?? []

        let existingFolders = (try? modelContext.fetch(FetchDescriptor<ApplicationFolder>())) ?? []
        let existingFoldersByID = Dictionary(uniqueKeysWithValues: existingFolders.map { ($0.id, $0) })
        let folderSnapshotIDs = Set(accountFolders.map(\.id))

        for snapshot in accountFolders {
            if let existing = existingFoldersByID[snapshot.id] {
                existing.name = snapshot.name
                existing.emoji = snapshot.emoji
                existing.createdAt = snapshot.createdAt
                existing.isAccountBacked = true
            } else {
                modelContext.insert(
                    ApplicationFolder(
                        id: snapshot.id,
                        name: snapshot.name,
                        emoji: snapshot.emoji,
                        isAccountBacked: true,
                        createdAt: snapshot.createdAt
                    )
                )
            }
        }

        for folder in existingFolders where folder.isAccountBacked && !folderSnapshotIDs.contains(folder.id) {
            modelContext.delete(folder)
        }

        let existingRecords = (try? modelContext.fetch(FetchDescriptor<ApplicationRecord>())) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        let snapshotIDs = Set(accountApplications.map(\.id))

        for snapshot in accountApplications {
            let status = ApplicationStatus(rawValue: snapshot.status.lowercased()) ?? .applied

            if let existing = existingByID[snapshot.id] {
                existing.company = snapshot.company
                existing.role = snapshot.role
                existing.status = status
                existing.appliedAt = snapshot.appliedAt
                existing.source = snapshot.source ?? existing.source
                existing.interviewAt = snapshot.interviewAt
                existing.notes = snapshot.notes
                existing.resumeUsed = snapshot.resumeUsed
                existing.jobLink = snapshot.jobLink
                existing.folderID = snapshot.folderID
                existing.atsScore = snapshot.atsScore
                existing.interviewReflectionRating = snapshot.interviewReflectionRating
                existing.interviewReflectionOutcome = snapshot.interviewReflectionOutcome
                existing.interviewReflectionNotes = snapshot.interviewReflectionNotes
                existing.interviewReflectionSubmittedAt = snapshot.interviewReflectionSubmittedAt
                existing.isAccountBacked = true
            } else {
                modelContext.insert(
                    ApplicationRecord(
                        id: snapshot.id,
                        company: snapshot.company,
                        role: snapshot.role,
                        status: status,
                        appliedAt: snapshot.appliedAt,
                        source: snapshot.source ?? "Account",
                        interviewAt: snapshot.interviewAt,
                        notes: snapshot.notes,
                        resumeUsed: snapshot.resumeUsed,
                        jobLink: snapshot.jobLink,
                        folderID: snapshot.folderID,
                        atsScore: snapshot.atsScore,
                        interviewReflectionRating: snapshot.interviewReflectionRating,
                        interviewReflectionOutcome: snapshot.interviewReflectionOutcome,
                        interviewReflectionNotes: snapshot.interviewReflectionNotes,
                        interviewReflectionSubmittedAt: snapshot.interviewReflectionSubmittedAt,
                        isAccountBacked: true
                    )
                )
            }
        }

        for record in existingRecords where record.isAccountBacked && !snapshotIDs.contains(record.id) {
            modelContext.delete(record)
        }

        do {
            try modelContext.save()
        } catch {
            // Keep the UI alive even if SwiftData persistence temporarily fails.
        }

        syncLocalTrackerWidgetSnapshot()
    }

    @MainActor
    private func requestAccountSync() {
        if isAccountSyncInFlight {
            hasPendingAccountSyncRequest = true
            return
        }

        Task {
            await performAccountSync()
        }
    }

    @MainActor
    private func performAccountSync() async {
        guard !isAccountSyncInFlight else {
            hasPendingAccountSyncRequest = true
            return
        }

        isAccountSyncInFlight = true
        defer {
            isAccountSyncInFlight = false

            if hasPendingAccountSyncRequest {
                hasPendingAccountSyncRequest = false
                Task {
                    await performAccountSync()
                }
            }
        }

        await authViewModel.refreshSharedState()
        _ = await subscriptionService.syncFromBackend()
        syncAccountTrackerState()
    }

    @MainActor
    private func reconcileWorkspaceCloudState() async {
        await WorkspaceCloudSyncService.reconcileResumes(
            modelContext: modelContext,
            profileWorkspaceService: profileWorkspaceService
        )
        WorkspaceCloudSyncService.reconcileStreakState(modelContext: modelContext)
        lastCloudResumeRevision = profileWorkspaceService.resumeSyncRevisionDate
        lastCloudStreakRevision = SharedStreakState.currentSnapshot().updatedAt
        workspaceCloudSyncReady = true
    }

    @MainActor
    private func pushLocalResumeChangesIfNeeded() async {
        guard workspaceCloudSyncReady else { return }
        let localRevision = profileWorkspaceService.resumeSyncRevisionDate
        guard localRevision > lastCloudResumeRevision else { return }
        await WorkspaceCloudSyncService.pushLocalResumes(
            modelContext: modelContext,
            profileWorkspaceService: profileWorkspaceService
        )
        lastCloudResumeRevision = profileWorkspaceService.resumeSyncRevisionDate
    }

    @MainActor
    private func pushLocalStreakChangesIfNeeded() {
        guard workspaceCloudSyncReady else { return }
        let snapshot = SharedStreakState.currentSnapshot()
        guard !snapshot.isEmpty, snapshot.updatedAt > lastCloudStreakRevision else { return }
        WorkspaceCloudSyncService.pushLocalStreakState(modelContext: modelContext)
        lastCloudStreakRevision = snapshot.updatedAt
    }

    @MainActor
    private func syncLocalTrackerWidgetSnapshot() {
        let localApplications = (try? modelContext.fetch(FetchDescriptor<ApplicationRecord>())) ?? []
        WidgetSyncService.shared.mergeLocalApplications(localApplications)
        WidgetSyncService.shared.syncStreakState(
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: localApplications
        )
    }
}

struct RootTabView: View {
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
            iPadWorkspaceView()
        } else {
            phoneTabView
        }
    }

    private var phoneTabView: some View {
        TabView(selection: $appRouter.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            ATSScannerView()
                .tabItem {
                    Label("Scanner", systemImage: "doc.text.magnifyingglass")
                }
                .tag(AppTab.scanner)

            TailoringPreviewView()
                .tabItem {
                    Label("Tailoring", systemImage: "wand.and.stars")
                }
                .tag(AppTab.tailoring)

            ApplicationTrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "list.bullet.clipboard")
                }
                .tag(AppTab.tracker)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(BoostaColor.accent)
    }
}

#if DEBUG
struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppRouter())
            .modelContainer(PreviewModelContainer.shared)
            .previewDisplayName("Root Tab")
    }
}
#endif

enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            ResumeProfile.self,
            ApplicationFolder.self,
            ApplicationRecord.self,
            CloudResumeAsset.self,
            CloudStreakState.self,
            ATSInsight.self,
            LatestScanReport.self,
            SavedTailoringSuggestion.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        fatalError("Failed to create PreviewModelContainer")
    }()
}
