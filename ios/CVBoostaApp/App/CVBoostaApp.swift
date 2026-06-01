import SwiftUI
import SwiftData

@main
struct CVBoostaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ResumeProfile.self,
            ApplicationRecord.self,
            ATSInsight.self
        ])

        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        do {
            if isPreview {
                let previewConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: fallbackConfig) {
                return fallback
            }
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
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
#Preview("Root Tab") {
    RootTabView()
        .modelContainer(PreviewModelContainer.shared)
}

enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            ResumeProfile.self,
            ApplicationRecord.self,
            ATSInsight.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: configuration))
            ?? (try! ModelContainer(for: schema))
    }()
}
