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

    private var applicationsCount: Int {
        activeApplications.count
    }

    private var interviewsCount: Int {
        activeApplications.filter { $0.status == .interview }.count
    }

    private var sharedHistoryAscending: [HistoryListItem] {
        historyItems.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var filteredHistoryAscending: [HistoryListItem] {
        guard let days = selectedRange.dayWindow else { return sharedHistoryAscending }
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return sharedHistoryAscending
        }
        return sharedHistoryAscending.filter { $0.createdAt >= start }
    }

    private func normalizedATSScore(_ raw: Int) -> Int {
        if raw > 100 {
            return min(max(Int((Double(raw) / 10.0).rounded()), 0), 100)
        }
        return min(max(raw, 0), 100)
    }

    private var latestScore: Int {
        sharedHistoryAscending.last.map { normalizedATSScore($0.matchAfter ?? $0.score) }
            ?? authViewModel.me?.scanHistory.first.map { normalizedATSScore($0.matchAfter ?? $0.atsScore) }
            ?? 0
    }

    private var streakSummary: StreakSummary {
        StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )
    }

    private var activeApplications: [ApplicationRecord] {
        trackedApplications.filter { $0.status != .archived }
    }

    private var avgScore: Int {
        let values = filteredHistoryAscending.map { normalizedATSScore($0.matchAfter ?? $0.score) }
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return total / values.count
    }

    private var atsTrendScores: [Int] {
        filteredHistoryAscending.map { normalizedATSScore($0.matchAfter ?? $0.score) }
    }

    private var trendPoints: [StatisticsChartPoint] {
        filteredHistoryAscending.enumerated().map { index, item in
            StatisticsChartPoint(
                id: index,
                date: item.createdAt,
                score: normalizedATSScore(item.matchAfter ?? item.score)
            )
        }
    }

    private var streakDays: Int {
        streakSummary.currentStreak
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
                await loadSharedHistory()
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
        }
    }

    @ViewBuilder
    private func content(width: CGFloat, horizontalPadding: CGFloat) -> some View {
        let columnCount = workspaceColumnCount(for: width, horizontalPadding: horizontalPadding)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 300), spacing: BoostaSpace.lg, alignment: .top),
            count: columnCount
        )

        LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
            headerCard
                .gridCellColumns(columnCount)

            sectionPicker
                .gridCellColumns(columnCount)

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
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func visibleCards(for columnCount: Int) -> some View {
        switch selectedSection {
        case .overview:
            overviewCard
                .gridCellColumns(min(2, columnCount))
            streakCard
            weeklySummaryCard
            sharedHistoryCard
                .gridCellColumns(columnCount)
        case .ats:
            overviewCard
                .gridCellColumns(min(2, columnCount))
            atsTrendCard
                .gridCellColumns(min(2, columnCount))
            recentScanCard
            if latestPayload != nil || latestHistoryDetail != nil {
                insightsCard
                    .gridCellColumns(max(min(2, columnCount), 1))
            } else {
                emptyStateCard
                    .gridCellColumns(max(min(2, columnCount), 1))
            }
        case .funnel:
            interviewPipelineCard
                .gridCellColumns(min(2, columnCount))
            streakCard
            weeklySummaryCard
            sharedHistoryCard
                .gridCellColumns(columnCount)
        case .insights:
            if latestPayload != nil || latestHistoryDetail != nil {
                insightsCard
                    .gridCellColumns(max(min(2, columnCount), 1))
            } else {
                emptyStateCard
                    .gridCellColumns(max(min(2, columnCount), 1))
            }
            recentScanCard
            sharedHistoryCard
                .gridCellColumns(columnCount)
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
            ScoreRing(score: latestScore)
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                Text(latestScore == 0 ? "No scans yet" : "Latest ATS Score")
                    .font(BoostaType.bodyStrong)
                Text(latestScore == 0 ? "Run one scan to get a baseline and unlock insights." : "Keep refining role keywords and measurable impact.")
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
                StatisticsMetricRing_iPad(title: "Career", value: latestScore == 0 ? "—" : "\(latestScore)", progress: Double(latestScore) / 100, tint: BoostaColor.accent)
                StatisticsMetricRing_iPad(title: "Interviews", value: "\(interviewsCount)", progress: min(Double(interviewsCount) / 5, 1), tint: BoostaColor.success)
                StatisticsMetricRing_iPad(title: "Streak", value: streakDays == 0 ? "Start" : "\(streakDays)d", progress: min(Double(streakDays) / 10, 1), tint: BoostaColor.warning)
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
            MetricPill(title: "Applications", value: "\(applicationsCount)", color: BoostaColor.accent)
            MetricPill(title: "Interviews", value: "\(interviewsCount)", color: BoostaColor.success)
            MetricPill(title: "Avg. ATS", value: avgScore == 0 ? "—" : "\(avgScore)", color: BoostaColor.warning)
        }
    }

    private var atsTrendCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "ATS Trend",
                    subtitle: atsTrendScores.isEmpty ? "No trend yet" : "\(atsTrendScores.count) shared history items"
                )

                Picker("Trend range", selection: $selectedRange) {
                    ForEach(StatisticsTimeRange_iPad.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if atsTrendScores.count < 2 {
                    Text("More shared history will make the full account trend clearer.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Chart {
                        ForEach(trendPoints) { point in
                            BarMark(
                                x: .value("Date", point.date),
                                y: .value("ATS", point.score),
                                width: .fixed(14)
                            )
                            .foregroundStyle(
                                point.id == trendPoints.last?.id
                                    ? BoostaColor.accent
                                    : BoostaColor.accent.opacity(0.42)
                            )
                        }

                        RuleMark(y: .value("Average", avgScore))
                            .foregroundStyle(Color.white.opacity(0.18))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .topTrailing, alignment: .trailing) {
                                Text("Avg \(avgScore)")
                                    .font(BoostaType.caption)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                                .foregroundStyle(Color.white.opacity(0.08))
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(max(trendPoints.count, 2), 6))) { value in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisTick().foregroundStyle(Color.white.opacity(0.16))
                            AxisValueLabel {
                                if let dateValue = value.as(Date.self) {
                                    Text(dateValue.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(BoostaType.caption)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot
                            .background(BoostaColor.surfaceMuted.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    }
                    .frame(height: 180)

                    HStack {
                        Text("Avg \(avgScore == 0 ? "—" : "\(avgScore)")")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        Spacer()

                        if let first = atsTrendScores.first, let last = atsTrendScores.last {
                            let delta = last - first
                            Text(deltaLabel(delta))
                                .font(BoostaType.caption)
                                .foregroundStyle(delta >= 0 ? BoostaColor.success : BoostaColor.warning)
                        }
                    }

                    Text(trendInsight)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
        .frame(minHeight: 240, alignment: .top)
    }

    private var trendInsight: String {
        guard let first = atsTrendScores.first, let last = atsTrendScores.last, atsTrendScores.count > 1 else {
            return "Your trend becomes more valuable as shared account history grows."
        }

        let delta = last - first
        if delta > 0 {
            return "Your ATS performance is improving across the full shared history."
        } else if delta < 0 {
            return "Recent history is softer than your earlier baseline — worth revisiting targeting and tailoring."
        } else {
            return "ATS performance is stable across your shared account history."
        }
    }

    private var interviewPipelineCard: some View {
        let readiness = min(Double(interviewsCount) / max(Double(applicationsCount), 1), 1)

        return GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Interview Readiness")

                HStack(alignment: .top, spacing: BoostaSpace.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(interviewsCount) interview\(interviewsCount == 1 ? "" : "s")")
                            .font(BoostaType.bodyStrong)
                        Text("from \(applicationsCount) application\(applicationsCount == 1 ? "" : "s")")
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
                    readinessRow("Tailor resume for role", done: latestScore > 0)
                    readinessRow("Scan with job description", done: (authViewModel.me?.scanHistory.first?.targetRole.isEmpty == false))
                    readinessRow("Track applications consistently", done: applicationsCount > 0)
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
                Text(streakDays == 0 ? "Start your streak today." : "\(streakDays) active day\(streakDays == 1 ? "" : "s")")
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
                let latestDelta = {
                    guard let first = atsTrendScores.first, let last = atsTrendScores.last else { return 0 }
                    return last - first
                }()

                Text(weeklySummaryText(delta: latestDelta, keywordsImproved: keywordsImproved))
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
        return "\(atsSummary), \(applicationsCount) tracked applications, \(interviewsCount) interviews in pipeline, \(keywordsImproved) keywords improved."
    }

    private func historySubtitle(for item: HistoryListItem) -> String {
        let date = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        if let company = item.company, !company.isEmpty {
            return "\(company) • \(date)"
        }
        return date
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
            previewDocument = HistoryPDFPreviewDocument(
                id: item.id,
                title: item.role ?? "CV Optimization",
                fileURL: url
            )
            historyErrorMessage = nil
        } catch {
            historyErrorMessage = "Could not open browser-generated PDF in the app."
        }
    }
}

private struct WorkspaceActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BoostaType.bodyStrong)
                .foregroundStyle(BoostaColor.primaryText)
                .padding(.horizontal, BoostaSpace.md)
                .padding(.vertical, 10)
                .background(BoostaColor.surfaceInteractive)
                .overlay(
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(BoostaColor.glassStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
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

private struct StatisticsChartPoint: Identifiable {
    let id: Int
    let date: Date
    let score: Int
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
            }
            .frame(width: 78, height: 78)

            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
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
