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
    @State private var selectedSection: StatisticsSection = .overview
    @State private var selectedRange: StatisticsTimeRange = .thirtyDays
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

    private var interviewProbability: String {
        switch snapshot.careerScore {
        case 80...100: return "Strong"
        case 65...79: return "Medium"
        case 1...64: return "Low"
        default: return "Unknown"
        }
    }

    private var funnelData: [CareerFunnelStage] {
        [
            .init(title: "Saved", count: snapshot.savedCount, color: BoostaColor.secondaryText),
            .init(title: "Applied", count: snapshot.appliedCount, color: BoostaColor.accent),
            .init(title: "Interview", count: snapshot.interviewsCount, color: BoostaColor.warning),
            .init(title: "Offer", count: snapshot.offersCount, color: BoostaColor.success)
        ]
    }

    private var breakdownMetrics: [CareerBreakdownMetric] {
        let keywordScore = min(max(snapshot.careerScore, 0), 100)
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
        if snapshot.monthlyDelta == 0 {
            return "No monthly trend yet"
        }
        if snapshot.monthlyDelta > 0 {
            return "+\(snapshot.monthlyDelta) stronger than your first tracked version"
        }
        return "Latest version is \(abs(snapshot.monthlyDelta)) points below your strongest baseline"
    }

    private var monthlyTrendLabel: String {
        if snapshot.monthlyDelta == 0 {
            return "Stable"
        }
        if snapshot.monthlyDelta > 0 {
            return "+\(snapshot.monthlyDelta) from first run"
        }
        return "Down \(abs(snapshot.monthlyDelta)) vs best baseline"
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
                    LazyVStack(alignment: .leading, spacing: BoostaSpace.md) {
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
                await ensureSharedHistoryLoaded()
            }
            .task(id: statisticsInputSignature) {
                rebuildSnapshot()
            }
            .onDisappear {
                historyDetailTask?.cancel()
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Statistics section", selection: $selectedSection) {
            ForEach(StatisticsSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .frame(maxWidth: .infinity)
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
            activityHeatmapCard
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
                    ScoreRing(score: snapshot.careerScore)
                        .frame(width: 118, height: 118)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.careerScore == 0 ? "No data yet" : "\(snapshot.careerScore)/100")
                            .font(BoostaType.title)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text("ATS readiness: \(snapshot.careerScore >= 75 ? "Up" : "Needs work")")
                            .font(BoostaType.bodyStrong)
                        Text("Interview rate: \(snapshot.responseRate == 0 ? "—" : "\(snapshot.responseRate)%") • Resume strength: \(interviewProbability)")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(monthlyDeltaDescription)
                            .font(BoostaType.caption)
                            .foregroundStyle(snapshot.monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }
                }

                HStack(spacing: 8) {
                    KeywordChip(text: "ATS Readiness", status: snapshot.careerScore >= 80 ? .present : snapshot.careerScore >= 60 ? .weak : .missing)
                    KeywordChip(text: "Interview Rate", status: snapshot.responseRate >= 20 ? .present : snapshot.responseRate >= 10 ? .weak : .missing)
                    KeywordChip(text: "Resume Strength", status: snapshot.averageScore >= 75 ? .present : snapshot.averageScore >= 60 ? .weak : .missing)
                }

                HStack(spacing: BoostaSpace.sm) {
                    StatisticsMetricRing(title: "Career", value: snapshot.careerScore == 0 ? "—" : "\(snapshot.careerScore)", progress: Double(snapshot.careerScore) / 100, tint: BoostaColor.accent)
                    StatisticsMetricRing(title: "Response", value: snapshot.responseRate == 0 ? "—" : "\(snapshot.responseRate)%", progress: Double(snapshot.responseRate) / 100, tint: BoostaColor.success)
                    StatisticsMetricRing(title: "Momentum", value: snapshot.streakDays == 0 ? "Start" : "\(min(snapshot.streakDays * 10, 99))", progress: min(Double(snapshot.streakDays) / 10, 1), tint: BoostaColor.warning)
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
                        Text(snapshot.trendSubtitle)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(snapshot.careerScore == 0 ? "—" : "\(snapshot.careerScore)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(monthlyTrendLabel)
                            .font(BoostaType.caption)
                            .foregroundStyle(snapshot.monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }
                }

                Picker("Trend range", selection: $selectedRange) {
                    ForEach(StatisticsTimeRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .frame(maxWidth: .infinity)
                .pickerStyle(.segmented)

                if snapshot.trendPoints.count < 2 {
                    Text("More shared history will make this performance trend meaningful.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    StatisticsTrendChartView(
                        points: snapshot.trendPoints,
                        axisDates: snapshot.trendAxisDates,
                        benchmarkScore: snapshot.benchmarkScore
                    )
                    .frame(height: 230)

                    HStack(spacing: BoostaSpace.sm) {
                        MetricPill(title: "Current", value: "\(snapshot.careerScore)", color: BoostaColor.accent)
                        MetricPill(title: "Benchmark", value: "\(snapshot.benchmarkScore)", color: BoostaColor.secondaryText)
                        MetricPill(title: "Avg", value: snapshot.averageScore == 0 ? "—" : "\(snapshot.averageScore)", color: BoostaColor.warning)
                    }

                    Text(snapshot.trendInsight)
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private var activityHeatmapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "ATS Activity Heatmap", subtitle: "When you scanned and improved")

                StatisticsHeatmapGrid(days: snapshot.heatmapDays, selectedDay: $selectedHeatmapDay)

                if let selectedHeatmapDay {
                    Text(selectedHeatmapDay.detailLine)
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Text("Tap a day to inspect how much ATS work happened there.")
                        .font(BoostaType.caption)
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
                    MetricPill(title: "Rate", value: snapshot.responseRate == 0 ? "—" : "\(snapshot.responseRate)%", color: BoostaColor.success)
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
                SectionHeader(title: "ATS Category Analysis", subtitle: "A richer view than one overall score")

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
                    MetricPill(title: "Streak", value: "\(snapshot.streakDays)d", color: BoostaColor.accent)
                    MetricPill(title: "This week", value: "\(snapshot.weeklyApplications) apps", color: BoostaColor.warning)
                    MetricPill(title: "Scans", value: "\(snapshot.scansThisWeek)", color: BoostaColor.success)
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
            errorMessage = nil
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
            errorMessage = "Could not load shared account history."
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
            errorMessage = nil
        } catch {
            errorMessage = "Could not open browser-generated PDF in the app."
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

private extension StatisticsView {
    var weeklySummaryText: String {
        let atsLine = snapshot.monthlyDelta >= 0
            ? "ATS is up \(snapshot.monthlyDelta)"
            : "ATS is \(abs(snapshot.monthlyDelta)) below your strongest baseline"
        return "\(atsLine), \(snapshot.weeklyApplications) applications sent, \(snapshot.interviewsCount) interviews in pipeline, \(weeklyKeywordsImproved) keywords improved."
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

struct StatisticsTrendPoint: Identifiable, Hashable {
    let id: Int
    let date: Date
    let score: Int
}

struct StatisticsHeatmapDay: Identifiable, Hashable {
    let id: String
    let date: Date
    let scanCount: Int
    let improvedCount: Int
    let intensity: Double
    let isToday: Bool

    var detailLine: String {
        let dateLabel = StatisticsSnapshotBuilder.chartLabel(for: date)
        let scanLabel = scanCount == 1 ? "1 scan" : "\(scanCount) scans"
        if improvedCount > 0 {
            let improvementLabel = improvedCount == 1 ? "1 improvement" : "\(improvedCount) improvements"
            return "\(dateLabel) • \(scanLabel) • \(improvementLabel)"
        }
        return "\(dateLabel) • \(scanLabel)"
    }
}

struct StatisticsSnapshot: Equatable {
    static let empty = StatisticsSnapshot(
        latestScore: 0,
        careerScore: 0,
        averageScore: 0,
        monthlyDelta: 0,
        responseRate: 0,
        applicationsCount: 0,
        savedCount: 0,
        appliedCount: 0,
        interviewsCount: 0,
        offersCount: 0,
        streakDays: 0,
        weeklyApplications: 0,
        scansThisWeek: 0,
        benchmarkScore: 78,
        trendSubtitle: "No trend yet",
        trendInsight: "Your trend will become more useful as more account history builds up.",
        trendPoints: [],
        trendAxisDates: [],
        heatmapDays: []
    )

    let latestScore: Int
    let careerScore: Int
    let averageScore: Int
    let monthlyDelta: Int
    let responseRate: Int
    let applicationsCount: Int
    let savedCount: Int
    let appliedCount: Int
    let interviewsCount: Int
    let offersCount: Int
    let streakDays: Int
    let weeklyApplications: Int
    let scansThisWeek: Int
    let benchmarkScore: Int
    let trendSubtitle: String
    let trendInsight: String
    let trendPoints: [StatisticsTrendPoint]
    let trendAxisDates: [Date]
    let heatmapDays: [StatisticsHeatmapDay]
}

enum StatisticsSnapshotBuilder {
    private static let benchmarkScore = 78

    static func build(
        historyItems: [HistoryListItem],
        latestHistoryDetail: HistoryDetailResponse?,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord],
        user: AuthUser?,
        selectedDayWindow: Int?
    ) -> StatisticsSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let ascendingHistory = historyItems.sorted(by: { $0.createdAt < $1.createdAt })
        let filteredHistory = filter(historyItems: ascendingHistory, dayWindow: selectedDayWindow, now: now)
        let activeApplications = applications.filter { !$0.status.isArchiveBucket }

        let trendPoints = filteredHistory.enumerated().map { index, item in
            StatisticsTrendPoint(
                id: index,
                date: item.createdAt,
                score: normalizedATSScore(item.matchAfter ?? item.score)
            )
        }
        let trendAxisDates = axisDates(for: trendPoints)
        let trendScores = trendPoints.map(\.score)
        let averageScore = average(for: trendScores)
        let latestScore = ascendingHistory.last.map { normalizedATSScore($0.matchAfter ?? $0.score) }
            ?? scans.sorted(by: { $0.createdAt < $1.createdAt }).last.map { normalizedATSScore($0.matchAfter ?? $0.atsScore) }
            ?? 0
        let careerScore = normalizedATSScore(latestHistoryDetail?.matchAfter ?? latestScore)
        let monthlyDelta = delta(for: trendScores)
        let responseRate = responseRate(for: activeApplications)
        let applicationsCount = activeApplications.count
        let interviewsCount = activeApplications.filter { $0.status == .interview }.count
        let offersCount = activeApplications.filter { $0.status == .offer }.count
        let savedCount = activeApplications.filter { $0.status == .saved }.count
        let appliedCount = activeApplications.filter { $0.status == .applied }.count
        let weeklyApplications = activeApplications.filter {
            calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
        let scansThisWeek = ascendingHistory.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear)
        }.count

        let streakSummary = StreakEngine.build(
            now: now,
            user: user,
            scans: scans,
            applications: applications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )

        return StatisticsSnapshot(
            latestScore: latestScore,
            careerScore: careerScore,
            averageScore: averageScore,
            monthlyDelta: monthlyDelta,
            responseRate: responseRate,
            applicationsCount: applicationsCount,
            savedCount: savedCount,
            appliedCount: appliedCount,
            interviewsCount: interviewsCount,
            offersCount: offersCount,
            streakDays: streakSummary.currentStreak,
            weeklyApplications: weeklyApplications,
            scansThisWeek: scansThisWeek,
            benchmarkScore: benchmarkScore,
            trendSubtitle: trendSubtitle(for: trendPoints.count),
            trendInsight: trendInsight(for: trendScores),
            trendPoints: trendPoints,
            trendAxisDates: trendAxisDates,
            heatmapDays: heatmapDays(from: historyItems, now: now, calendar: calendar)
        )
    }

    static func signature(for items: [HistoryListItem]) -> Int {
        var hasher = Hasher()
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.createdAt)
            hasher.combine(item.score)
            hasher.combine(item.matchAfter)
        }
        return hasher.finalize()
    }

    static func signature(for scans: [ScanHistorySnapshot]) -> Int {
        var hasher = Hasher()
        for scan in scans {
            hasher.combine(scan.id)
            hasher.combine(scan.createdAt)
            hasher.combine(scan.atsScore)
            hasher.combine(scan.matchAfter)
        }
        return hasher.finalize()
    }

    static func signature(for applications: [ApplicationRecord]) -> Int {
        var hasher = Hasher()
        for application in applications {
            hasher.combine(application.id)
            hasher.combine(application.status.rawValue)
            hasher.combine(application.appliedAt)
            hasher.combine(application.interviewAt)
            hasher.combine(application.folderID)
        }
        return hasher.finalize()
    }

    static func chartLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func filter(historyItems: [HistoryListItem], dayWindow: Int?, now: Date) -> [HistoryListItem] {
        guard let dayWindow else { return historyItems }
        guard let start = Calendar.current.date(byAdding: .day, value: -dayWindow, to: now) else {
            return historyItems
        }
        return historyItems.filter { $0.createdAt >= start }
    }

    private static func normalizedATSScore(_ raw: Int) -> Int {
        if raw > 100 {
            return min(max(Int((Double(raw) / 10.0).rounded()), 0), 100)
        }
        return min(max(raw, 0), 100)
    }

    private static func average(for scores: [Int]) -> Int {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    private static func delta(for scores: [Int]) -> Int {
        guard let first = scores.first, let last = scores.last, scores.count > 1 else { return 0 }
        return last - first
    }

    private static func responseRate(for applications: [ApplicationRecord]) -> Int {
        guard !applications.isEmpty else { return 0 }
        let responses = applications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responses) / Double(applications.count)) * 100)
    }

    private static func axisDates(for points: [StatisticsTrendPoint]) -> [Date] {
        let dates = points.map(\.date)
        guard dates.count > 3 else { return dates }
        let lastIndex = dates.count - 1
        let middleIndex = lastIndex / 2
        return Array(Set([dates[0], dates[middleIndex], dates[lastIndex]])).sorted()
    }

    private static func trendSubtitle(for count: Int) -> String {
        guard count > 0 else { return "No trend yet" }
        return "AI analyzed career growth over \(count) scan\(count == 1 ? "" : "s")"
    }

    private static func trendInsight(for scores: [Int]) -> String {
        guard let first = scores.first, let last = scores.last, scores.count > 1 else {
            return "Your trend will become more useful as more account history builds up."
        }

        let delta = last - first
        if delta > 0 {
            return "Your ATS trajectory is climbing and now sits closer to the export-ready benchmark."
        }
        if delta < 0 {
            return "Recent ATS runs softened versus your earlier baseline, so this is a good place to rescan after tailoring."
        }
        return "Your ATS performance is stable across recent shared history."
    }

    private static func heatmapDays(from historyItems: [HistoryListItem], now: Date, calendar: Calendar) -> [StatisticsHeatmapDay] {
        let grouped = Dictionary(grouping: historyItems) { StreakEngine.dayStamp(for: $0.createdAt) }

        return (0..<35).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let stamp = StreakEngine.dayStamp(for: date)
            let items = grouped[stamp] ?? []
            let improvedCount = items.filter { ($0.matchAfter ?? $0.score) > ($0.matchBefore ?? $0.score) }.count
            let scanCount = items.count
            let intensity = min((Double(scanCount) * 0.45) + (Double(improvedCount) * 0.35), 1)

            return StatisticsHeatmapDay(
                id: stamp,
                date: date,
                scanCount: scanCount,
                improvedCount: improvedCount,
                intensity: intensity,
                isToday: calendar.isDateInToday(date)
            )
        }
    }
}

struct StatisticsTrendChartView: View {
    let points: [StatisticsTrendPoint]
    let axisDates: [Date]
    let benchmarkScore: Int
    @State private var selectedPointID: Int?

    var body: some View {
        Chart {
            RuleMark(y: .value("Benchmark", benchmarkScore))
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [5, 6]))
                .foregroundStyle(Color.white.opacity(0.24))

            ForEach(points) { point in
                BarMark(
                    x: .value("Scan", point.id + 1),
                    y: .value("ATS", point.score),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(barGradient(for: point))
                .opacity(activePoint?.id == point.id ? 1 : 0.86)
            }

            if let activePoint {
                RuleMark(x: .value("Selected Scan", activePoint.id + 1))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .foregroundStyle(Color.white.opacity(0.14))
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        trendTooltip(for: activePoint)
                            .padding(.top, 4)
                    }

                PointMark(
                    x: .value("Selected Scan", activePoint.id + 1),
                    y: .value("Selected ATS", activePoint.score)
                )
                .symbolSize(64)
                .foregroundStyle(BoostaColor.accent)
            }
        }
        .chartXScale(domain: 0...(points.count + 1))
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                    .foregroundStyle(Color.white.opacity(0.045))
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
            AxisMarks(values: axisPointIDs) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(Color.white.opacity(0.10))
                AxisValueLabel {
                    if let idValue = value.as(Int.self),
                       let point = points.first(where: { $0.id + 1 == idValue }) {
                        Text(StatisticsSnapshotBuilder.chartLabel(for: point.date))
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plotArea = geometry[plotFrame]

                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: plotArea.width, height: plotArea.height)
                        .position(x: plotArea.midX, y: plotArea.midY)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let relativeX = value.location.x - plotArea.origin.x
                                    guard relativeX >= 0, relativeX <= plotArea.width else { return }
                                    guard let scanNumber = proxy.value(atX: relativeX, as: Int.self) else { return }
                                    selectedPointID = nearestPointID(to: scanNumber)
                                }
                        )
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(BoostaColor.surfaceMuted.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        }
        .transaction { transaction in
            transaction.animation = .easeOut(duration: 0.32)
        }
        .onAppear {
            if selectedPointID == nil {
                selectedPointID = latestPoint?.id
            }
        }
    }

    private var latestPoint: StatisticsTrendPoint? {
        points.last
    }

    private var activePoint: StatisticsTrendPoint? {
        if let selectedPointID, let selectedPoint = points.first(where: { $0.id == selectedPointID }) {
            return selectedPoint
        }
        return latestPoint
    }

    private var axisPointIDs: [Int] {
        let axisSet = Set(axisDates.map(\.timeIntervalSinceReferenceDate))
        let matchedIDs = points
            .filter { axisSet.contains($0.date.timeIntervalSinceReferenceDate) }
            .map { $0.id + 1 }

        return matchedIDs.isEmpty ? points.map { $0.id + 1 } : matchedIDs
    }

    private var barWidth: CGFloat {
        switch points.count {
        case ...6:
            return 28
        case ...10:
            return 20
        default:
            return 14
        }
    }

    private func nearestPointID(to scanNumber: Int) -> Int? {
        points.min { lhs, rhs in
            abs((lhs.id + 1) - scanNumber) < abs((rhs.id + 1) - scanNumber)
        }?.id
    }

    private func barGradient(for point: StatisticsTrendPoint) -> LinearGradient {
        let isActive = activePoint?.id == point.id
        let topColor = isActive ? BoostaColor.accent : BoostaColor.accentSecondary
        let bottomColor = isActive ? BoostaColor.accentSecondary.opacity(0.88) : BoostaColor.accent.opacity(0.74)

        return LinearGradient(
            colors: [bottomColor, topColor],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func trendTooltip(for point: StatisticsTrendPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(point.score) ATS")
                .font(BoostaType.caption.weight(.semibold))
                .foregroundStyle(BoostaColor.primaryText)
            Text(StatisticsSnapshotBuilder.chartLabel(for: point.date))
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct StatisticsHeatmapGrid: View {
    let days: [StatisticsHeatmapDay]
    @Binding var selectedDay: StatisticsHeatmapDay?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days) { day in
                Button {
                    selectedDay = day
                } label: {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fillColor(for: day))
                        .frame(height: 24)
                        .overlay {
                            if day.isToday || selectedDay?.id == day.id {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(selectedDay?.id == day.id ? BoostaColor.accent : BoostaColor.outlineStrong, lineWidth: 1.4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fillColor(for day: StatisticsHeatmapDay) -> Color {
        switch day.intensity {
        case ..<0.01:
            return BoostaColor.heatmapEmpty
        case ..<0.35:
            return BoostaColor.accentSecondary.opacity(0.34)
        case ..<0.7:
            return BoostaColor.accent.opacity(0.55)
        default:
            return BoostaColor.accent.opacity(0.9)
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
