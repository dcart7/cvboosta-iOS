import SwiftUI
import SwiftData

/// iPad-only home workspace.
/// Full analytics live in `StatisticsWorkspaceView_iPad`.
struct HomeWorkspaceView_iPad: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @State private var historyItems: [HistoryListItem] = []
    @State private var latestHistoryDetail: HistoryDetailResponse?
    @State private var isLoadingHistory = false
    @State private var historyErrorMessage: String?
    @State private var previewDocument: HistoryPDFPreviewDocument?
    @State private var animateSparkline = false

    private let resumeService = ResumeService.shared

    private var firstName: String {
        if let raw = authViewModel.me?.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw.split(separator: " ").first.map(String.init) ?? raw
        }

        if let email = authViewModel.me?.user.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }

        return "there"
    }

    private var scans: [ScanHistorySnapshot] {
        authViewModel.me?.scanHistory.sorted(by: { $0.createdAt < $1.createdAt }) ?? []
    }

    private var careerScore: Int {
        latestHistoryDetail?.matchAfter ?? scans.last?.matchAfter ?? scans.last?.atsScore ?? 0
    }

    private var weeklyApplications: Int {
        let calendar = Calendar.current
        let now = Date()
        return trackedApplications.filter {
            calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var responseRate: Int {
        guard !trackedApplications.isEmpty else { return 0 }
        let responsive = trackedApplications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responsive) / Double(trackedApplications.count)) * 100)
    }

    private var trendScores: [Int] {
        Array(scans.suffix(7).map(\.atsScore))
    }

    private var bodyKeywords: [String] {
        Array((latestHistoryDetail?.missingSkills ?? []).prefix(4))
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
                        content(width: proxy.size.width)
                            .padding(.horizontal, BoostaSpace.xl)
                            .padding(.top, BoostaSpace.lg)
                            .padding(.bottom, BoostaSpace.xl)
                            .frame(maxWidth: 1400)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        appRouter.open(.scanner)
                    } label: {
                        Label("Scan", systemImage: "doc.text.magnifyingglass")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .hoverEffect(.lift)

                    Button {
                        appRouter.open(.statistics)
                    } label: {
                        Label("Statistics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .hoverEffect(.lift)
                }
            }
            .overlay(alignment: .top) {
                if let historyErrorMessage {
                    ErrorBanner(message: historyErrorMessage)
                        .padding(.horizontal, BoostaSpace.xl)
                        .padding(.top, BoostaSpace.sm)
                }
            }
            .sheet(item: $previewDocument) { document in
                HistoryPDFPreviewSheet(document: document)
            }
            .task {
                await authViewModel.refreshSharedState()
                await loadSharedHistory()
                withAnimation(.easeOut(duration: 0.7)) {
                    animateSparkline = true
                }
            }
        }
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        let columns = width >= 1180
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]

        LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
            heroCard
                .gridCellColumns(columns.count)

            quickStatsCard
            recentActivityCard

            actionsCard
                .gridCellColumns(columns.count)
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            HStack(alignment: .center, spacing: BoostaSpace.lg) {
                ScoreRing(score: careerScore)
                    .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome back, \(firstName)")
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text("This is your compact workspace. Review the essentials here, then open full statistics when you want the deeper career dashboard.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)

                    HStack(spacing: BoostaSpace.sm) {
                        WorkspaceCTAButton(title: "View Full Statistics", systemImage: "chart.line.uptrend.xyaxis") {
                            appRouter.open(.statistics)
                        }

                        WorkspaceCTAButton(title: "Analyze Resume", systemImage: "doc.text.magnifyingglass") {
                            appRouter.open(.scanner)
                        }
                    }
                }
            }
        }
    }

    private var quickStatsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Compact Statistics", subtitle: "A compressed read of your current momentum")

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Career Score", value: careerScore == 0 ? "—" : "\(careerScore)", color: BoostaColor.accent)
                    MetricPill(title: "Response", value: responseRate == 0 ? "—" : "\(responseRate)%", color: BoostaColor.success)
                    MetricPill(title: "This Week", value: "\(weeklyApplications)", color: BoostaColor.warning)
                }

                CompactTrendView(scores: trendScores, isAnimated: animateSparkline)
                    .frame(height: 84)

                if !bodyKeywords.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                        ForEach(bodyKeywords, id: \.self) { keyword in
                            KeywordChip(text: keyword, status: .missing)
                        }
                    }
                }
            }
        }
    }

    private var recentActivityCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Recent Activity", subtitle: isLoadingHistory ? "Syncing shared account..." : "Shared browser + iPad history")

                if historyItems.isEmpty {
                    Text(isLoadingHistory ? "Loading history..." : "No shared history yet.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(historyItems.prefix(4)) { item in
                        Button {
                            Task {
                                await openHistoryPDF(for: item)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.role ?? "CV Optimization")
                                        .font(BoostaType.bodyStrong)
                                        .foregroundStyle(BoostaColor.primaryText)
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }

                                Spacer()

                                Text("\(item.matchAfter ?? item.score)")
                                    .font(BoostaType.bodyStrong)
                                    .foregroundStyle(BoostaColor.accent)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Quick Actions", subtitle: "Jump back into the workflow")

                HStack(spacing: BoostaSpace.sm) {
                    WorkspaceCTAButton(title: "Tailoring", systemImage: "wand.and.stars") {
                        appRouter.open(.tailoring)
                    }
                    WorkspaceCTAButton(title: "Tracker", systemImage: "list.bullet.clipboard") {
                        appRouter.open(.tracker)
                    }
                    WorkspaceCTAButton(title: "Settings", systemImage: "gearshape") {
                        appRouter.open(.settings)
                    }
                }
            }
        }
    }

    private func loadSharedHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let items = try await resumeService.history().sorted { $0.createdAt > $1.createdAt }
            historyItems = items
            historyErrorMessage = nil
            if let first = items.first {
                latestHistoryDetail = try? await resumeService.historyDetail(id: first.id)
            }
        } catch {
            historyErrorMessage = "Could not load shared account history."
        }
    }

    private func openHistoryPDF(for item: HistoryListItem) async {
        do {
            let detail = try await resumeService.historyDetail(id: item.id)
            let url = try SharedHistoryPDFBuilder.makeResumePDF(
                title: item.role ?? "CV Optimization",
                subtitle: item.company ?? "CVBoosta",
                score: detail.matchAfter ?? detail.score,
                body: detail.optimizedCV
            )
            previewDocument = HistoryPDFPreviewDocument(id: item.id, title: item.role ?? "CV Optimization", fileURL: url)
            historyErrorMessage = nil
        } catch {
            historyErrorMessage = "Could not open browser-generated PDF in the app."
        }
    }
}

private struct WorkspaceCTAButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

#Preview("Home Workspace (iPad)") {
    HomeWorkspaceView_iPad()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
