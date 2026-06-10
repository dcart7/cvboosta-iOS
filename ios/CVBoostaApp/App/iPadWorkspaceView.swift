import SwiftUI

/// iPad-only premium workspace container.
/// iPhone continues to use the existing `TabView` unchanged.
struct iPadWorkspaceView: View {
    @EnvironmentObject private var appRouter: AppRouter

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(BoostaColor.accent)
    }

    private var sidebar: some View {
        List {
            Section("Workspace") {
                sidebarRow(.home, title: "Home", systemImage: "house")
                sidebarRow(.statistics, title: "Statistics", systemImage: "chart.line.uptrend.xyaxis")
                sidebarRow(.scanner, title: "Scanner", systemImage: "doc.text.magnifyingglass")
                sidebarRow(.tailoring, title: "Tailoring", systemImage: "wand.and.stars")
                sidebarRow(.tracker, title: "Tracker", systemImage: "list.bullet.clipboard")
            }

            Section("Account") {
                sidebarRow(.settings, title: "Settings", systemImage: "gearshape")
            }
        }
        .navigationTitle("CVBoosta")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 244, max: 270)
    }

    @ViewBuilder
    private var detail: some View {
        switch appRouter.selectedTab {
        case .home:
            HomeWorkspaceView_iPad()
        case .statistics:
            StatisticsWorkspaceView_iPad()
        case .scanner:
            ATSScannerWorkspaceView_iPad()
        case .tailoring:
            TailoringWorkspaceView_iPad()
        case .tracker:
            ApplicationTrackerWorkspaceView_iPad()
        case .settings:
            SettingsWorkspaceView_iPad()
        }
    }

    private func sidebarRow(_ tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            appRouter.open(tab)
        } label: {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .listRowBackground(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .fill(appRouter.selectedTab == tab ? BoostaColor.surfaceInteractiveStrong : Color.clear)
        )
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview("iPad Workspace") {
    iPadWorkspaceView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
