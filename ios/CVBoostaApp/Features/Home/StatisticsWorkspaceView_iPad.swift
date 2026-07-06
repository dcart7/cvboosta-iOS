import SwiftUI
import SwiftData
import Charts

/// iPad-only full statistics workspace.
/// The compact iPad home landing remains in `HomeWorkspaceView_iPad`.
struct StatisticsWorkspaceView_iPad: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @Query(filter: #Predicate<LatestScanReport> { $0.id == "latest" })
    private var latestReports: [LatestScanReport]

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @State private var historyItems: [HistoryListItem] = []
    @State private var latestHistoryDetail: HistoryDetailResponse?
    @State private var isLoadingHistory = false
    @State private var previewDocument: HistoryPDFPreviewDocument?
    @State private var historyErrorMessage: String?
    @State private var selectedSection: StatisticsWorkspaceSection = .overview
    @State private var selectedRange: StatisticsTimeRange_iPad = .thirtyDays
    @State private var showStreakCenter = false
    @State private var snapshot = StatisticsSnapshot.empty
    @State private var selectedHeatmapDay: StatisticsHeatmapDay?
    @State private var hasLoadedSharedHistory = false
    @State private var historyDetailTask: Task<Void, Never>?

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

    private var historySignature: Int {
        StatisticsSnapshotBuilder.signature(for: historyItems)
    }

    private var applicationsSignature: Int {
        StatisticsSnapshotBuilder.signature(for: trackedApplications)
    }

    private var scanSignature: Int {
        StatisticsSnapshotBuilder.signature(for: authViewModel.me?.scanHistory ?? [])
    }

    private var statisticsInputSignature: Int {
        var hasher = Hasher()
        hasher.combine(selectedRange.rawValue)
        hasher.combine(historySignature)
        hasher.combine(applicationsSignature)
        hasher.combine(scanSignature)
        hasher.combine(latestHistoryDetail?.id ?? -1)
        hasher.combine(latestHistoryDetail?.matchAfter ?? -1)
        hasher.combine(authViewModel.me?.user.id ?? -1)
        return hasher.finalize()
    }

    private var latestPayload: LatestScanPayload? {
        guard let data = latestReports.first?.payloadJSON else { return nil }
        return try? JSONDecoder().decode(LatestScanPayload.self, from: data)
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
                    .scrollIndicators(.visible)
                }
            }
            .navigationTitle("Statistics")
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
                        appRouter.open(.tailoring)
                    } label: {
                        Label("Tailoring", systemImage: "wand.and.stars")
                    }
                    .keyboardShortcut("t", modifiers: .command)
                    .hoverEffect(.lift)

                    Button {
                        appRouter.open(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    .hoverEffect(.highlight)
                }
            }
            .task {
                await authViewModel.refreshSharedState()
                await ensureSharedHistoryLoaded()
            }
            .task(id: statisticsInputSignature) {
                rebuildSnapshot()
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
            .overlay(alignment: .top) {
                if let historyErrorMessage {
                    ErrorBanner(message: historyErrorMessage)
                        .padding(.horizontal, BoostaSpace.xl)
                        .padding(.top, BoostaSpace.sm)
                }
            }
            .onDisappear {
                historyDetailTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private func content(width: CGFloat, horizontalPadding: CGFloat) -> some View {
        let columnCount = workspaceColumnCount(for: width, horizontalPadding: horizontalPadding)

        WorkspaceMasonryLayout(columns: columnCount, spacing: WorkspaceLayoutMetrics.gridSpacing) {
            headerCard
                .workspaceColumnSpan(columnCount)

            sectionPicker
                .workspaceColumnSpan(columnCount)

            visibleCards(for: columnCount)
        }
        .animation(BoostaMotion.smooth, value: columnCount)
    }

    private func workspaceColumnCount(for width: CGFloat, horizontalPadding: CGFloat) -> Int {
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
                    headerContent
                    Spacer(minLength: 0)
                    headerActions
                }

                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    headerContent
                    headerActions
                }
            }
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hi, \(firstName)")
                .font(BoostaType.title)
                .foregroundStyle(BoostaColor.primaryText)
            Text("Your career intelligence workspace — shared across web and iPad.")
                .font(BoostaType.body)
                .foregroundStyle(BoostaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BoostaSpace.sm) {
                headerActionButtons
            }

            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                headerActionButtons
            }
        }
    }

    private var headerActionButtons: some View {
        Group {
            WorkspaceActionButton(
                title: "Scan Resume",
                systemImage: "doc.text.magnifyingglass"
            ) {
                appRouter.open(.scanner)
            }

            WorkspaceActionButton(
                title: "Tailor",
                systemImage: "wand.and.stars"
            ) {
                appRouter.open(.tailoring)
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Statistics section", selection: $selectedSection) {
            ForEach(StatisticsWorkspaceSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .frame(maxWidth: .infinity)
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func visibleCards(for columnCount: Int) -> some View {
        switch selectedSection {
        case .overview:
            overviewCard
                .workspaceColumnSpan(min(2, columnCount))
            streakCard
            weeklySummaryCard
            sharedHistoryCard
        case .ats:
            overviewCard
                .workspaceColumnSpan(min(2, columnCount))
            atsTrendCard
                .workspaceColumnSpan(min(2, columnCount))
            activityHeatmapCard
            recentScanCard
            if latestPayload != nil || latestHistoryDetail != nil {
                insightsCard
                    .workspaceColumnSpan(max(min(2, columnCount), 1))
            } else {
                emptyStateCard
                    .workspaceColumnSpan(max(min(2, columnCount), 1))
            }
        case .funnel:
            interviewPipelineCard
                .workspaceColumnSpan(min(2, columnCount))
            streakCard
            weeklySummaryCard
            sharedHistoryCard
        case .insights:
            if latestPayload != nil || latestHistoryDetail != nil {
                insightsCard
                    .workspaceColumnSpan(max(min(2, columnCount), 1))
            } else {
                emptyStateCard
                    .workspaceColumnSpan(max(min(2, columnCount), 1))
            }
            recentScanCard
            sharedHistoryCard
        }
    }

    private var overviewCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Today")

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: BoostaSpace.lg) {
                        overviewLead
                        Spacer(minLength: 0)
                        overviewMetrics
                    }

                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        overviewLead
                        overviewMetrics
                    }
                }
            }
        }
        .frame(minHeight: 230, alignment: .top)
    }

    private var overviewLead: some View {
        HStack(spacing: BoostaSpace.md) {
            ScoreRing(score: snapshot.careerScore)
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.careerScore == 0 ? "No scans yet" : "Latest ATS Score")
                    .font(BoostaType.bodyStrong)
                Text(snapshot.careerScore == 0 ? "Run one scan to get a baseline and unlock insights." : "Keep refining role keywords and measurable impact.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var overviewMetrics: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BoostaSpace.sm) {
                    overviewMetricPills
                }

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    overviewMetricPills
                }
            }

            HStack(spacing: BoostaSpace.sm) {
                StatisticsMetricRing_iPad(title: "Career", value: snapshot.careerScore == 0 ? "—" : "\(snapshot.careerScore)", progress: Double(snapshot.careerScore) / 100, tint: BoostaColor.accent)
                StatisticsMetricRing_iPad(title: "Interviews", value: "\(snapshot.interviewsCount)", progress: min(Double(snapshot.interviewsCount) / 5, 1), tint: BoostaColor.success)
                StatisticsMetricRing_iPad(title: "Streak", value: snapshot.streakDays == 0 ? "Start" : "\(snapshot.streakDays)d", progress: min(Double(snapshot.streakDays) / 10, 1), tint: BoostaColor.warning)
            }

            Divider()
                .opacity(0.35)

            Text("Focus: Tailor for one role, rescan, then apply.")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        }
    }

    private var overviewMetricPills: some View {
        Group {
            MetricPill(title: "Applications", value: "\(snapshot.applicationsCount)", color: BoostaColor.accent)
            MetricPill(title: "Interviews", value: "\(snapshot.interviewsCount)", color: BoostaColor.success)
            MetricPill(title: "Avg. ATS", value: snapshot.averageScore == 0 ? "—" : "\(snapshot.averageScore)", color: BoostaColor.warning)
        }
    }

    private var atsTrendCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "ATS Trend",
                    subtitle: snapshot.trendSubtitle
                )

                Picker("Trend range", selection: $selectedRange) {
                    ForEach(StatisticsTimeRange_iPad.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .frame(maxWidth: .infinity)
                .pickerStyle(.segmented)

                if snapshot.trendPoints.count < 2 {
                    Text("More shared history will make the full account trend clearer.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    StatisticsTrendChartView(
                        points: snapshot.trendPoints,
                        axisDates: snapshot.trendAxisDates,
                        benchmarkScore: snapshot.benchmarkScore
                    )
                    .frame(height: 232)

                    HStack {
                        Text("Avg \(snapshot.averageScore == 0 ? "—" : "\(snapshot.averageScore)")")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        Spacer()

                        Text(deltaLabel(snapshot.monthlyDelta))
                            .font(BoostaType.caption)
                            .foregroundStyle(snapshot.monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }

                    HStack(spacing: BoostaSpace.sm) {
                        MetricPill(title: "Current", value: "\(snapshot.careerScore)", color: BoostaColor.accent)
                        MetricPill(title: "Benchmark", value: "\(snapshot.benchmarkScore)", color: BoostaColor.secondaryText)
                        MetricPill(title: "Scans", value: "\(snapshot.trendPoints.count)", color: BoostaColor.warning)
                    }

                    Text(snapshot.trendInsight)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
        .frame(minHeight: 264, alignment: .top)
    }

    private var activityHeatmapCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "ATS Activity Heatmap", subtitle: "When you scanned and improved")

                StatisticsHeatmapGrid(days: snapshot.heatmapDays, selectedDay: $selectedHeatmapDay)

                if let selectedHeatmapDay {
                    Text(selectedHeatmapDay.detailLine)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Text("Tap any day to inspect ATS activity intensity.")
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var interviewPipelineCard: some View {
        let readiness = min(Double(snapshot.interviewsCount) / max(Double(snapshot.applicationsCount), 1), 1)

        return GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Interview Readiness")

                HStack(alignment: .top, spacing: BoostaSpace.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(snapshot.interviewsCount) interview\(snapshot.interviewsCount == 1 ? "" : "s")")
                            .font(BoostaType.bodyStrong)
                        Text("from \(snapshot.applicationsCount) application\(snapshot.applicationsCount == 1 ? "" : "s")")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    Spacer(minLength: 0)

                    ProgressView(value: readiness)
                        .tint(BoostaColor.success)
                        .frame(width: 160)
                        .accessibilityLabel("Interview readiness \(Int(readiness * 100)) percent")
                }

                Divider()
                    .opacity(0.35)

                VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                    readinessRow("Tailor resume for role", done: snapshot.careerScore > 0)
                    readinessRow("Scan with job description", done: (authViewModel.me?.scanHistory.first?.targetRole.isEmpty == false))
                    readinessRow("Track applications consistently", done: snapshot.applicationsCount > 0)
                }
            }
        }
    }

    private var insightsCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(
                    title: "Improvement Insights",
                    subtitle: "From your shared CVBoosta account history"
                )

                if let payload = latestPayload {
                    responsiveInsightsLayout(
                        keywords: Array(payload.response.missingSkills.prefix(subscriptionService.isPremium ? 12 : 6)),
                        recommendations: Array(payload.response.recommendations.prefix(4))
                    )
                } else if let detail = latestHistoryDetail {
                    responsiveInsightsLayout(
                        keywords: Array(detail.missingSkills.prefix(subscriptionService.isPremium ? 12 : 6)),
                        recommendations: Array(detail.recommendations.prefix(4))
                    )
                } else {
                    Text("Run a scan to unlock personalized insights.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func responsiveInsightsLayout(keywords: [String], recommendations: [String]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                insightsKeywordsSection(keywords: keywords)

                Divider()
                    .opacity(0.35)

                insightsRecommendationsSection(recommendations: recommendations)
            }

            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                insightsKeywordsSection(keywords: keywords)

                Divider()
                    .opacity(0.35)

                insightsRecommendationsSection(recommendations: recommendations)
            }
        }
    }

    private func insightsKeywordsSection(keywords: [String]) -> some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            Text("Top missing skills")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)

            if keywords.isEmpty {
                Text("No major gaps detected.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        KeywordChip(text: keyword, status: .missing)
                    }
                }
            }
        }
    }

    private func insightsRecommendationsSection(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
            Text("Quick wins")
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)

            if recommendations.isEmpty {
                Text("No quick wins flagged yet.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            } else {
                ForEach(recommendations, id: \.self) { item in
                    Text("• \(item)")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "No insights yet",
                    subtitle: "Scan a resume to unlock trend + improvement widgets."
                )

                WorkspaceActionButton(title: "Start First Scan", systemImage: "doc.text.magnifyingglass") {
                    appRouter.open(.scanner)
                }
            }
        }
    }

    private var streakCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                SectionHeader(title: "Job Search Streak")
                Text(snapshot.streakDays == 0 ? "Start your streak today." : "\(snapshot.streakDays) active day\(snapshot.streakDays == 1 ? "" : "s")")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                WorkspaceActionButton(title: "Open Streak Center", systemImage: "flame.fill") {
                    showStreakCenter = true
                }
            }
        }
    }

    private var sharedHistoryCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(
                        title: "Shared Account History",
                        subtitle: isLoadingHistory ? "Syncing web + iPad activity..." : "Browser-generated scans and optimizations"
                    )
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
                    Text(isLoadingHistory ? "Loading shared history..." : "No history found yet.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(historyItems.prefix(5)) { item in
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
                                    Text(historySubtitle(for: item))
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

    private var weeklySummaryCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weekly Summary", subtitle: "Momentum across your shared account")

                let keywordsImproved = latestHistoryDetail?.addedKeywords.count ?? latestPayload?.response.addedKeywords.count ?? 0

                Text(weeklySummaryText(delta: snapshot.monthlyDelta, keywordsImproved: keywordsImproved))
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var recentScanCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                SectionHeader(title: "Recent Scan")
                if let item = historyItems.first {
                    Text(item.role ?? "CV Optimization")
                        .font(BoostaType.bodyStrong)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                    if let company = item.company, !company.isEmpty {
                        Text(company)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                } else if let scan = authViewModel.me?.scanHistory.first {
                    Text(scan.resumeFileName)
                        .font(BoostaType.bodyStrong)
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Text("No scans yet.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
        .frame(minHeight: 148, alignment: .top)
    }

    private func readinessRow(_ title: String, done: Bool) -> some View {
        HStack(spacing: BoostaSpace.xs) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? BoostaColor.success : BoostaColor.secondaryText.opacity(0.5))
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
            Spacer(minLength: 0)
        }
    }

    private func deltaLabel(_ delta: Int) -> String {
        if delta == 0 { return "Stable" }
        if delta > 0 { return "+\(delta)" }
        return "Rescan advised"
    }

    private func weeklySummaryText(delta: Int, keywordsImproved: Int) -> String {
        let atsSummary = delta >= 0
            ? "ATS is up \(delta)"
            : "ATS is \(abs(delta)) below your strongest baseline"
        return "\(atsSummary), \(snapshot.applicationsCount) tracked applications, \(snapshot.interviewsCount) interviews in pipeline, \(keywordsImproved) keywords improved."
    }

    private func historySubtitle(for item: HistoryListItem) -> String {
        let date = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        if let company = item.company, !company.isEmpty {
            return "\(company) • \(date)"
        }
        return date
    }

    private func ensureSharedHistoryLoaded() async {
        guard !hasLoadedSharedHistory else { return }
        hasLoadedSharedHistory = true
        await loadSharedHistory()
    }

    private func loadSharedHistory() async {
        historyDetailTask?.cancel()
        isLoadingHistory = true

        do {
            let items = try await resumeService.history().sorted { $0.createdAt > $1.createdAt }
            historyItems = items
            latestHistoryDetail = nil
            historyErrorMessage = nil
            isLoadingHistory = false
            if let first = items.first {
                historyDetailTask = Task {
                    let detail = try? await resumeService.historyDetail(id: first.id)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if self.historyItems.first?.id == first.id {
                            self.latestHistoryDetail = detail
                        }
                    }
                }
            }
        } catch {
            isLoadingHistory = false
            historyErrorMessage = "Could not load shared account history."
        }
    }

    private func openHistoryPDF(for item: HistoryListItem) async {
        do {
            let detail = try await resumeService.historyDetail(id: item.id)
            let watermarkText = await MainActor.run {
                SubscriptionService.shared.isPremium ? nil : SharedHistoryPDFBuilder.freeWatermarkText
            }
            let url = try SharedHistoryPDFBuilder.makeResumePDF(
                item: item,
                detail: detail,
                watermarkText: watermarkText
            )
            previewDocument = HistoryPDFPreviewDocument(
                id: item.id,
                title: item.role ?? "CV Optimization",
                fileURL: url,
                resumeName: SharedHistoryPDFBuilder.resumeName(for: item, detail: detail),
                optimizedText: detail.optimizedCV,
                watermarkText: watermarkText
            )
            historyErrorMessage = nil
        } catch {
            historyErrorMessage = "Could not open browser-generated PDF in the app."
        }
    }

    private func rebuildSnapshot() {
        snapshot = StatisticsSnapshotBuilder.build(
            historyItems: historyItems,
            latestHistoryDetail: latestHistoryDetail,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            user: authViewModel.me?.user,
            selectedDayWindow: selectedRange.dayWindow
        )

        if let selectedHeatmapDay {
            self.selectedHeatmapDay = snapshot.heatmapDays.first(where: { $0.id == selectedHeatmapDay.id })
        }
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .workspaceButtonLabelLayout()
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(BoostaColor.surfaceInteractive)
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(BoostaDepthButtonStyle())
        .hoverEffect(.lift)
        .accessibilityLabel(title)
    }
}

private enum StatisticsWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case ats
    case funnel
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .ats: return "ATS"
        case .funnel: return "Funnel"
        case .insights: return "Insights"
        }
    }
}

private enum StatisticsTimeRange_iPad: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .all: return "All"
        }
    }

    var dayWindow: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .all: return nil
        }
    }
}

private struct StatisticsMetricRing_iPad: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(BoostaColor.ringTrack, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(colors: [tint.opacity(0.4), tint], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(value)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 78, height: 78)

            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, minHeight: WorkspaceLayoutMetrics.ringCardMinHeight)
        .padding(.vertical, 6)
        .background(BoostaColor.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.86)) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.86)) {
                animatedProgress = min(max(newValue, 0), 1)
            }
        }
    }
}

#if DEBUG
#Preview("Statistics Workspace (iPad)") {
    StatisticsWorkspaceView_iPad()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
#endif
