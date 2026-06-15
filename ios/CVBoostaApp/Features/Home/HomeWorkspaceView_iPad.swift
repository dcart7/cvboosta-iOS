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
    @State private var showStreakCenter = false

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

    private var streakSummary: StreakSummary {
        StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            manuallyProtectedDayStamps: []
        )
    }

    private func normalizedATSScore(_ raw: Int) -> Int {
        if raw > 100 {
            return min(max(Int((Double(raw) / 10.0).rounded()), 0), 100)
        }
        return min(max(raw, 0), 100)
    }

    private var careerScore: Int {
        normalizedATSScore(latestHistoryDetail?.matchAfter ?? scans.last?.matchAfter ?? scans.last?.atsScore ?? 0)
    }

    private var momentumScore: Int {
        min(100, max(0, Int(Double(careerScore) * 0.55) + min(weeklyApplications * 8, 24) + min(responseRate / 2, 18) + min(bodyKeywords.count * 4, 16)))
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
        Array(scans.suffix(7).map { normalizedATSScore($0.matchAfter ?? $0.atsScore) })
    }

    private var bodyKeywords: [String] {
        Array((latestHistoryDetail?.missingSkills ?? []).prefix(4))
    }

    private var overdueFollowUps: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return trackedApplications.filter { app in
            app.status == .applied
                && calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: app.appliedAt)).map { $0 <= today } == true
        }.count
    }

    private var upcomingInterviews: Int {
        let now = Date()
        guard let sevenDays = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return 0 }
        return trackedApplications.filter { app in
            guard app.status == .interview, let interviewAt = app.interviewAt else { return false }
            return interviewAt >= now && interviewAt <= sevenDays
        }.count
    }

    private var todayItems: [HomeWorkspaceTodayItem] {
        var items: [HomeWorkspaceTodayItem] = []

        if overdueFollowUps > 0 {
            items.append(.init(title: "Follow up today", detail: "\(overdueFollowUps) applications are ready for a recruiter nudge.", tint: BoostaColor.warning))
        }
        if upcomingInterviews > 0 {
            items.append(.init(title: "Interview prep", detail: "\(upcomingInterviews) interviews are coming up this week.", tint: BoostaColor.success))
        }
        if !bodyKeywords.isEmpty {
            items.append(.init(title: "Keyword gaps", detail: "Add \(bodyKeywords.prefix(2).joined(separator: ", ")) to role-specific bullets.", tint: BoostaColor.accent))
        }
        if items.isEmpty {
            items.append(.init(title: "Keep momentum", detail: careerScore == 0 ? "Run your first ATS scan to create a benchmark." : "Open statistics or tailoring to keep improving.", tint: BoostaColor.accentSecondary))
        }

        return Array(items.prefix(3))
    }

    private var streakInsight: (title: String, value: String, tint: Color) {
        if streakSummary.currentStreak > 0 {
            return ("Streak", "\(streakSummary.currentStreak)d", BoostaColor.success)
        }
        if streakSummary.pendingStreak > 0 {
            return ("Protect Streak", "\(streakSummary.pendingStreak)d", BoostaColor.warning)
        }
        if streakSummary.canUseRecovery {
            return ("Recover Streak", "Restore", BoostaColor.warning)
        }
        return ("Streak", "Start", BoostaColor.accentSecondary)
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
                        content(width: proxy.size.width, horizontalPadding: horizontalPadding)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, BoostaSpace.md)
                            .padding(.bottom, BoostaSpace.xl)
                            .frame(maxWidth: 1560)
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
            .sheet(isPresented: $showStreakCenter) {
                NavigationStack {
                    StreakCenterView()
                        .environmentObject(authViewModel)
                }
            }
            .task {
                await authViewModel.refreshSharedState()
                await loadSharedHistory()
                withAnimation(.easeOut(duration: 0.7)) {
                    animateSparkline = true
                }
                syncSupportLiveActivity()
            }
            .onChange(of: authViewModel.me?.scanHistory.count ?? 0) { _, _ in
                syncSupportLiveActivity()
            }
            .onChange(of: trackedApplications.count) { _, _ in
                syncSupportLiveActivity()
            }
        }
    }

    private func syncSupportLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        let summary = StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            manuallyProtectedDayStamps: []
        )
        let hour = Calendar.current.component(.hour, from: .now)
        Task {
            guard !summary.todayActions.isEmpty,
                  summary.currentStreak > 0,
                  !summary.statusTitle.contains("protected"),
                  hour >= 18 else {
                await LiveActivityManager.shared.clearStreakProtection()
                return
            }

            await LiveActivityManager.shared.showStreakProtection(
                dayCount: summary.currentStreak,
                detail: summary.todayActions.first?.detail ?? summary.todayDetail
            )
        }
    }

    @ViewBuilder
    private func content(width: CGFloat, horizontalPadding: CGFloat) -> some View {
        let columnCount = WorkspaceLayoutMetrics.columnCount(
            for: width,
            minCardWidth: 320,
            maxColumns: 2,
            horizontalPadding: horizontalPadding
        )
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 320), spacing: BoostaSpace.lg, alignment: .top),
            count: columnCount
        )

        LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
            heroCard
                .gridCellColumns(columnCount)

            quickStatsCard
            todayCard
            recentActivityCard
                .gridCellColumns(columnCount)

            actionsCard
                .gridCellColumns(columnCount)
        }
        .animation(BoostaMotion.smooth, value: columnCount)
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: BoostaSpace.lg) {
                    heroRing
                    heroContent
                }

                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    heroRing
                    heroContent
                }
            }
        }
    }

    private var heroRing: some View {
        ScoreRing(score: careerScore)
            .frame(width: 132, height: 132)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back, \(firstName)")
                .font(BoostaType.title)
                .foregroundStyle(BoostaColor.primaryText)
            Text("Career momentum: \(momentumScore == 0 ? "Start your baseline" : "\(momentumScore)/100") • review today's actions, then jump into the deeper dashboard.")
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: BoostaSpace.sm) {
                    heroPrimaryActions
                }

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    heroPrimaryActions
                }
            }
        }
    }

    private var heroPrimaryActions: some View {
        Group {
            WorkspaceCTAButton(title: "View Full Statistics", systemImage: "chart.line.uptrend.xyaxis") {
                appRouter.open(.statistics)
            }

            WorkspaceCTAButton(title: "Analyze Resume", systemImage: "doc.text.magnifyingglass") {
                appRouter.open(.scanner)
            }
        }
    }

    private var quickStatsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Compact Statistics", subtitle: "A compressed read of your current momentum")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    HomeStatCard(title: "Career Score", value: careerScore == 0 ? "—" : "\(careerScore)", color: BoostaColor.accent)
                    HomeStatCard(title: "Momentum", value: momentumScore == 0 ? "—" : "\(momentumScore)", color: BoostaColor.accentSecondary)
                    HomeStatCard(title: "Response Rate", value: responseRate == 0 ? "—" : "\(responseRate)%", color: BoostaColor.success)
                    Button {
                        showStreakCenter = true
                    } label: {
                        HomeStatCard(title: streakInsight.title, value: streakInsight.value, color: streakInsight.tint, icon: "flame.fill")
                    }
                    .buttonStyle(.plain)
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
        .frame(minHeight: 316, alignment: .top)
    }

    private var todayCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Today", subtitle: "The next actions that move your search forward")

                ForEach(todayItems) { item in
                    HStack(alignment: .top, spacing: BoostaSpace.sm) {
                        Circle()
                            .fill(item.tint.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(item.tint)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.primaryText)
                            Text(item.detail)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(BoostaSpace.sm)
                    .background(BoostaColor.surfaceInteractive)
                    .overlay(
                        RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                            .stroke(BoostaColor.glassStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                }
            }
        }
        .frame(minHeight: 316, alignment: .top)
    }

    private var recentActivityCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(title: "Recent Activity", subtitle: isLoadingHistory ? "Syncing shared account..." : "Shared browser + iPad history")
                    Spacer()
                    if !historyItems.isEmpty {
                        NavigationLink("View all") {
                            AccountHistoryView()
                        }
                        .font(BoostaType.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(BoostaColor.accent)
                    }
                }

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
                            HStack(alignment: .center, spacing: BoostaSpace.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.role ?? "CV Optimization")
                                        .font(BoostaType.bodyStrong)
                                        .foregroundStyle(BoostaColor.primaryText)
                                    Text(historyRowSubtitle(for: item))
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }

                                Spacer()

                                MetricPill(
                                    title: "ATS",
                                    value: "\(item.matchAfter ?? item.score)",
                                    color: BoostaColor.accent
                                )
                            }
                            .padding(.vertical, 4)
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BoostaSpace.sm) {
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        actionButtons
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        Group {
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
                item: item,
                detail: detail
            )
            previewDocument = HistoryPDFPreviewDocument(id: item.id, title: item.role ?? "CV Optimization", fileURL: url)
            historyErrorMessage = nil
        } catch {
            historyErrorMessage = "Could not open browser-generated PDF in the app."
        }
    }

    private func historyRowSubtitle(for item: HistoryListItem) -> String {
        let date = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        if let company = item.company, !company.isEmpty {
            return "\(company) • \(date)"
        }
        return date
    }
}

private struct HomeWorkspaceTodayItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
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
                .background(BoostaColor.surfaceInteractive)
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
