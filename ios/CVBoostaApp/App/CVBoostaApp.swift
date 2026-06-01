import SwiftUI
import SwiftData

@main
struct CVBoostaApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ResumeProfile.self,
            ApplicationRecord.self,
            ATSInsight.self
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
            // Fall back to local in-memory container to keep the app and previews usable.
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
                .task {
                    await authViewModel.bootstrap()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        switch authViewModel.state {
        case .loading:
            ZStack {
                LinearGradient(
                    colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ProgressView("Loading account...")
            }
        case .loggedOut:
            LoginView()
        case .loggedIn:
            RootTabView()
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "sparkles")
                }
                .tag(AppTab.home)

            ATSScannerView()
                .tabItem {
                    Label("Scanner", systemImage: "doc.text.magnifyingglass")
                }
                .tag(AppTab.scanner)

            TailoringStudioView()
                .tabItem {
                    Label("Tailor", systemImage: "wand.and.stars")
                }
                .tag(AppTab.tailoring)

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.analytics)

            ApplicationTrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "checklist")
                }
                .tag(AppTab.tracker)
        }
        .tint(BoostaColor.accent)
    }
}
#if DEBUG
struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(AuthViewModel())
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
            ATSInsight.self
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
