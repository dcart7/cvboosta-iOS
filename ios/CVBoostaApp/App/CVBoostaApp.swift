import SwiftUI
import SwiftData
import UIKit

@main
struct CVBoostaApp: App {
    @UIApplicationDelegateAdaptor(CVBoostaAppDelegate.self) private var appDelegate

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appRouter = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ResumeProfile.self,
            ApplicationRecord.self,
            ATSInsight.self,
            LatestScanReport.self,
            SavedTailoringSuggestion.self
        ])

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        do {
            if isPreview {
                let previewConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: previewConfig)
            }

            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            if let fallback = try? ModelContainer(for: schema, configurations: fallbackConfig) {
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

    private var accountApplicationsSignature: String {
        authViewModel.me?.applications
            .sorted(by: { $0.appliedAt < $1.appliedAt })
            .map { "\($0.id.uuidString)-\($0.status)-\($0.appliedAt.timeIntervalSince1970)" }
            .joined(separator: "|") ?? ""
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
        .task(id: accountApplicationsSignature) {
            syncAccountApplications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, authViewModel.state == .loggedIn else { return }
            Task {
                await authViewModel.refreshSharedState()
            }
        }
    }

    private func syncAccountApplications() {
        guard let accountApplications = authViewModel.me?.applications, !accountApplications.isEmpty else { return }

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
                existing.source = snapshot.source ?? "Account"
            } else {
                modelContext.insert(
                    ApplicationRecord(
                        id: snapshot.id,
                        company: snapshot.company,
                        role: snapshot.role,
                        status: status,
                        appliedAt: snapshot.appliedAt,
                        source: snapshot.source ?? "Account"
                    )
                )
            }
        }

        for record in existingRecords where record.source == "Account" && !snapshotIDs.contains(record.id) {
            modelContext.delete(record)
        }

        try? modelContext.save()
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
            ApplicationRecord.self,
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
