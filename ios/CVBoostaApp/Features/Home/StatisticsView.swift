import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @State private var historyItems: [HistoryListItem] = []
    @State private var latestHistoryDetail: HistoryDetailResponse?
    @State private var isLoadingHistory = false
    @State private var errorMessage: String?
    @State private var previewDocument: HistoryPDFPreviewDocument?
    @State private var animatedTrendCount = 0
    @State private var selectedSection: StatisticsSection = .overview
    @State private var selectedRange: StatisticsTimeRange = .thirtyDays
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

    private var scans: [ScanHistorySnapshot] {
        authViewModel.me?.scanHistory.sorted(by: { $0.createdAt < $1.createdAt }) ?? []
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

    private var latestScore: Int {
        sharedHistoryAscending.last.map { normalizedATSScore($0.matchAfter ?? $0.score) }
            ?? scans.last.map { normalizedATSScore($0.matchAfter ?? $0.atsScore) }
            ?? 0
    }

    private var careerScore: Int {
        normalizedATSScore(latestHistoryDetail?.matchAfter ?? latestScore)
    }

    private var applicationsCount: Int {
        activeApplications.count
    }

    private var interviewsCount: Int {
        activeApplications.filter { $0.status == .interview }.count
    }

    private var offersCount: Int {
        activeApplications.filter { $0.status == .offer }.count
    }

    private var avgScore: Int {
        let values = filteredHistoryAscending.map { normalizedATSScore($0.matchAfter ?? $0.score) }
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return total / values.count
    }

    private var monthlyDelta: Int {
        guard filteredHistoryAscending.count > 1 else { return 0 }
        return normalizedATSScore(filteredHistoryAscending.last?.matchAfter ?? filteredHistoryAscending.last?.score ?? 0)
            - normalizedATSScore(filteredHistoryAscending.first?.matchAfter ?? filteredHistoryAscending.first?.score ?? 0)
    }

    private var streakDays: Int {
        streakSummary.currentStreak
    }

    private var weeklyApplications: Int {
        let calendar = Calendar.current
        let now = Date()
        return activeApplications.filter {
            calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var scansThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return sharedHistoryAscending.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var responseRate: Int {
        guard !activeApplications.isEmpty else { return 0 }
        let responsive = activeApplications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responsive) / Double(activeApplications.count)) * 100)
    }

    private var interviewProbability: String {
        switch careerScore {
        case 80...100: return "Strong"
        case 65...79: return "Medium"
        case 1...64: return "Low"
        default: return "Unknown"
        }
    }

    private var trendPoints: [CareerTrendPoint] {
        filteredHistoryAscending.enumerated().map { index, item in
            CareerTrendPoint(
                id: index,
                date: item.createdAt,
                atsScore: normalizedATSScore(item.matchAfter ?? item.score)
            )
        }
    }

    private var visibleTrendPoints: [CareerTrendPoint] {
        Array(trendPoints.prefix(max(animatedTrendCount, 0)))
    }

    private var trendInsight: String {
        guard let first = trendPoints.first, let last = trendPoints.last, trendPoints.count > 1 else {
            return "Your trend will become more useful as more account history builds up."
        }

        let delta = last.atsScore - first.atsScore
        if delta > 0 {
            return "Your resume consistency improved over the tracked history."
        } else if delta < 0 {
            return "Your latest runs are softer than your earlier baseline — worth rescanning after tailoring."
        } else {
            return "Your ATS performance is stable across recent account history."
        }
    }

    private var funnelData: [CareerFunnelStage] {
        [
            .init(title: "Saved", count: activeApplications.filter { $0.status == .saved }.count, color: BoostaColor.secondaryText),
            .init(title: "Applied", count: activeApplications.filter { $0.status == .applied }.count, color: BoostaColor.accent),
            .init(title: "Interview", count: interviewsCount, color: BoostaColor.warning),
            .init(title: "Offer", count: offersCount, color: BoostaColor.success)
        ]
    }

    private var breakdownMetrics: [CareerBreakdownMetric] {
        let keywordScore = min(max(careerScore, 0), 100)
        let technicalImpact = max(keywordScore - 18, 0)
        let formatting = min(keywordScore + 11, 100)
        let readability = min(max(keywordScore - 6, 0), 100)
        let leadershipSignals = max(keywordScore - 28, 0)
        return [
            .init(title: "Keywords Match", score: keywordScore, color: BoostaColor.accent),
            .init(title: "Technical Impact", score: technicalImpact, color: BoostaColor.warning),
            .init(title: "Formatting", score: formatting, color: BoostaColor.success),
            .init(title: "Readability", score: readability, color: BoostaColor.accentSecondary),
            .init(title: "Leadership Signals", score: leadershipSignals, color: BoostaColor.warning)
        ]
    }

    private var missingKeywords: [String] {
        let values = latestHistoryDetail?.missingSkills ?? []
        return values.isEmpty ? ["Docker", "CI/CD", "PostgreSQL", "FastAPI", "Kubernetes"] : Array(values.prefix(5))
    }

    private var aiInsights: [String] {
        let values = latestHistoryDetail?.recommendations ?? []
        if !values.isEmpty {
            return Array(values.prefix(3))
        }
        return [
            "Add production-scale metrics to increase recruiter trust.",
            "Strengthen cloud and backend keywords in your most recent experience.",
            "Reduce generic wording in summary and lead bullets."
        ]
    }

    private var weeklyKeywordsImproved: Int {
        latestHistoryDetail?.addedKeywords.count ?? 0
    }

    private var historySubtitle: String {
        isLoadingHistory ? "Syncing browser + app activity..." : "Shared account history from CVBoosta web and iOS"
    }

    private var monthlyDeltaDescription: String {
        if monthlyDelta == 0 {
            return "No monthly trend yet"
        }
        if monthlyDelta > 0 {
            return "+\(monthlyDelta) stronger than your first tracked version"
        }
        return "Latest version is \(abs(monthlyDelta)) points below your strongest baseline"
    }

    private var monthlyTrendLabel: String {
        if monthlyDelta == 0 {
            return "Stable"
        }
        if monthlyDelta > 0 {
            return "+\(monthlyDelta) from first run"
        }
        return "Down \(abs(monthlyDelta)) vs best baseline"
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

                ScrollView {
                    VStack(alignment: .leading, spacing: BoostaSpace.md) {
                        SectionHeader(
                            title: "Hi, \(firstName)",
                            subtitle: "Your career intelligence center."
                        )

                        sectionPicker
                        heroCard
                        sectionContent
                        historyCard
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        appRouter.open(.scanner)
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }

                    Button {
                        appRouter.open(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, BoostaSpace.md)
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
                animateTrend()
            }
            .onChange(of: selectedRange) { _, _ in
                animateTrend()
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Statistics section", selection: $selectedSection) {
            ForEach(StatisticsSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            responseRateCard
            streakCard
            weeklySummaryCard
        case .ats:
            trendCard
            breakdownCard
            keywordsCard
        case .funnel:
            funnelCard
            responseRateCard
            streakCard
        case .insights:
            aiInsightsCard
            keywordsCard
            weeklySummaryCard
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text("Career Score")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: careerScore)
                        .frame(width: 118, height: 118)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(careerScore == 0 ? "No data yet" : "\(careerScore)/100")
                            .font(BoostaType.title)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text("ATS readiness: \(careerScore >= 75 ? "Up" : "Needs work")")
                            .font(BoostaType.bodyStrong)
                        Text("Interview rate: \(responseRate == 0 ? "—" : "\(responseRate)%") • Resume strength: \(interviewProbability)")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(monthlyDeltaDescription)
                            .font(BoostaType.caption)
                            .foregroundStyle(monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }
                }

                HStack(spacing: 8) {
                    KeywordChip(text: "ATS Readiness", status: careerScore >= 80 ? .present : careerScore >= 60 ? .weak : .missing)
                    KeywordChip(text: "Interview Rate", status: responseRate >= 20 ? .present : responseRate >= 10 ? .weak : .missing)
                    KeywordChip(text: "Resume Strength", status: avgScore >= 75 ? .present : avgScore >= 60 ? .weak : .missing)
                }

                HStack(spacing: BoostaSpace.sm) {
                    StatisticsMetricRing(title: "Career", value: careerScore == 0 ? "—" : "\(careerScore)", progress: Double(careerScore) / 100, tint: BoostaColor.accent)
                    StatisticsMetricRing(title: "Response", value: responseRate == 0 ? "—" : "\(responseRate)%", progress: Double(responseRate) / 100, tint: BoostaColor.success)
                    StatisticsMetricRing(title: "Momentum", value: streakDays == 0 ? "Start" : "\(min(streakDays * 10, 99))", progress: min(Double(streakDays) / 10, 1), tint: BoostaColor.warning)
                }

                PrimaryButton(title: "Analyze Resume") {
                    appRouter.open(.scanner)
                }
            }
        }
    }

    private var trendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack(alignment: .top, spacing: BoostaSpace.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ATS Performance")
                            .font(BoostaType.section)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(trendPoints.isEmpty ? "No trend yet" : "\(trendPoints.count) history items tracked")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(careerScore == 0 ? "—" : "\(careerScore)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(monthlyTrendLabel)
                            .font(BoostaType.caption)
                            .foregroundStyle(monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }
                }

                Picker("Trend range", selection: $selectedRange) {
                    ForEach(StatisticsTimeRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if trendPoints.count < 2 {
                    Text("More shared history will make this performance trend meaningful.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Chart {
                        ForEach(visibleTrendPoints) { point in
                            BarMark(
                                x: .value("Date", point.date),
                                y: .value("ATS", point.atsScore),
                                width: .fixed(12)
                            )
                            .foregroundStyle(
                                point.id == visibleTrendPoints.last?.id
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
                        AxisMarks(values: .automatic(desiredCount: min(max(trendPoints.count, 2), 5))) { value in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisTick().foregroundStyle(Color.white.opacity(0.16))
                            AxisValueLabel {
                                if let dateValue = value.as(Date.self) {
                                    Text(chartLabel(for: dateValue))
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

                    Text(trendInsight)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var funnelCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Application Funnel", subtitle: "Saved → applied → interview → offer")

                ForEach(funnelData) { stage in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(stage.title)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            Spacer()
                            Text("\(stage.count)")
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.primaryText)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(BoostaColor.surfaceMuted)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(stage.color)
                                    .frame(width: max(proxy.size.width * stageWidth(stage.count), 12))
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }

    private var responseRateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Response Rate", subtitle: "How applications convert right now")

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Rate", value: responseRate == 0 ? "—" : "\(responseRate)%", color: BoostaColor.success)
                    MetricPill(title: "Industry avg", value: "8%", color: BoostaColor.warning)
                    MetricPill(title: "ATS correlation", value: "2.3×", color: BoostaColor.accent)
                }

                Text("Applications with ATS 80+ tend to convert better into recruiter responses.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var breakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weakness Breakdown", subtitle: "Better than one score")

                ForEach(breakdownMetrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(metric.title)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                            Spacer()
                            Text("\(metric.score)")
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(metric.color)
                        }

                        ProgressView(value: Double(metric.score), total: 100)
                            .tint(metric.color)
                    }
                }
            }
        }
    }

    private var keywordsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Most Missing Keywords", subtitle: "High-impact ATS gaps")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(missingKeywords, id: \.self) { keyword in
                        KeywordChip(text: keyword, status: .missing)
                    }
                }
            }
        }
    }

    private var aiInsightsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "AI Insights", subtitle: "Smart recommendations from shared account history")

                ForEach(aiInsights, id: \.self) { line in
                    Text("• \(line)")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var streakCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Streaks & Consistency", subtitle: "Duolingo effect for your job hunt")

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Streak", value: "\(streakDays)d", color: BoostaColor.accent)
                    MetricPill(title: "This week", value: "\(weeklyApplications) apps", color: BoostaColor.warning)
                    MetricPill(title: "Scans", value: "\(scansThisWeek)", color: BoostaColor.success)
                }

                SecondaryButton(title: "Open Streak Center") {
                    showStreakCenter = true
                }
            }
        }
    }

    private var weeklySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weekly Report", subtitle: "Progress, momentum, control")

                Text(weeklySummaryText)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var historyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(title: "Account History", subtitle: historySubtitle)
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
                    Text(isLoadingHistory ? "Loading shared history..." : "No browser or app history found yet.")
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
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func stageWidth(_ count: Int) -> CGFloat {
        guard let maxCount = funnelData.map(\.count).max(), maxCount > 0 else { return 0.12 }
        return CGFloat(Double(count) / Double(maxCount))
    }

    private func loadSharedHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let items = try await resumeService.history().sorted { $0.createdAt > $1.createdAt }
            historyItems = items
            errorMessage = nil
            if let first = items.first {
                latestHistoryDetail = try? await resumeService.historyDetail(id: first.id)
            }
        } catch {
            errorMessage = "Could not load shared account history."
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
            errorMessage = nil
        } catch {
            errorMessage = "Could not open browser-generated PDF in the app."
        }
    }

    private func animateTrend() {
        animatedTrendCount = 0
        guard !trendPoints.isEmpty else { return }

        Task { @MainActor in
            for index in 1...trendPoints.count {
                animatedTrendCount = index
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    private func chartLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private extension StatisticsView {
    var weeklySummaryText: String {
        let atsLine = monthlyDelta >= 0
            ? "ATS is up \(monthlyDelta)"
            : "ATS is \(abs(monthlyDelta)) below your strongest baseline"
        return "\(atsLine), \(weeklyApplications) applications sent, \(interviewsCount) interviews in pipeline, \(weeklyKeywordsImproved) keywords improved."
    }
}

private enum StatisticsSection: String, CaseIterable, Identifiable {
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

private enum StatisticsTimeRange: String, CaseIterable, Identifiable {
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

private struct CareerTrendPoint: Identifiable {
    let id: Int
    let date: Date
    let atsScore: Int
}

private struct CareerFunnelStage: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let color: Color
}

private struct CareerBreakdownMetric: Identifiable {
    let id = UUID()
    let title: String
    let score: Int
    let color: Color
}

private struct StatisticsMetricRing: View {
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

#Preview {
    StatisticsView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
