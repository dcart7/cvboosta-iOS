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

    private var latestScore: Int {
        scans.last?.atsScore ?? 0
    }

    private var careerScore: Int {
        latestHistoryDetail?.matchAfter ?? latestScore
    }

    private var applicationsCount: Int {
        trackedApplications.count
    }

    private var interviewsCount: Int {
        trackedApplications.filter { $0.status == .interview }.count
    }

    private var offersCount: Int {
        trackedApplications.filter { $0.status == .offer }.count
    }

    private var avgScore: Int {
        guard !scans.isEmpty else { return 0 }
        let total = scans.reduce(0) { $0 + $1.atsScore }
        return total / scans.count
    }

    private var monthlyDelta: Int {
        guard scans.count > 1 else { return 0 }
        return (scans.last?.atsScore ?? 0) - (scans.first?.atsScore ?? 0)
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(scans.map { calendar.startOfDay(for: $0.createdAt) })
        guard !uniqueDays.isEmpty else { return 0 }

        var current = calendar.startOfDay(for: Date())
        var streak = 0
        while uniqueDays.contains(current) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return streak
    }

    private var weeklyApplications: Int {
        let calendar = Calendar.current
        let now = Date()
        return trackedApplications.filter {
            calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var scansThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return scans.filter {
            calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    private var responseRate: Int {
        guard !trackedApplications.isEmpty else { return 0 }
        let responsive = trackedApplications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responsive) / Double(trackedApplications.count)) * 100)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return Array(scans.suffix(6)).enumerated().map { index, scan in
            CareerTrendPoint(id: index, label: formatter.string(from: scan.createdAt), atsScore: scan.atsScore)
        }
    }

    private var funnelData: [CareerFunnelStage] {
        [
            .init(title: "Saved", count: trackedApplications.filter { $0.status == .saved }.count, color: BoostaColor.secondaryText),
            .init(title: "Applied", count: trackedApplications.filter { $0.status == .applied }.count, color: BoostaColor.accent),
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

                        heroCard
                        trendCard
                        funnelCard
                        responseRateCard
                        breakdownCard
                        keywordsCard
                        aiInsightsCard
                        streakCard
                        weeklySummaryCard
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
            .task {
                await authViewModel.refreshSharedState()
                await loadSharedHistory()
                animateTrend()
            }
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
                        Text(monthlyDelta == 0 ? "No monthly trend yet" : "\(monthlyDelta > 0 ? "+" : "")\(monthlyDelta) this month")
                            .font(BoostaType.caption)
                            .foregroundStyle(monthlyDelta >= 0 ? BoostaColor.success : BoostaColor.warning)
                    }
                }

                HStack(spacing: 8) {
                    KeywordChip(text: "ATS Readiness", status: careerScore >= 80 ? .present : careerScore >= 60 ? .weak : .missing)
                    KeywordChip(text: "Interview Rate", status: responseRate >= 20 ? .present : responseRate >= 10 ? .weak : .missing)
                    KeywordChip(text: "Resume Strength", status: avgScore >= 75 ? .present : avgScore >= 60 ? .weak : .missing)
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
                SectionHeader(title: "Performance Over Time", subtitle: "ATS score progression")

                if trendPoints.count < 2 {
                    Text("Scan more resumes to visualize progress over time.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    Chart(Array(trendPoints.prefix(max(animatedTrendCount, 0)))) { point in
                        LineMark(x: .value("Date", point.label), y: .value("ATS", point.atsScore))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(BoostaColor.accent)

                        AreaMark(x: .value("Date", point.label), y: .value("ATS", point.atsScore))
                            .foregroundStyle(BoostaColor.accent.opacity(0.12))
                    }
                    .frame(height: 180)
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
            }
        }
    }

    private var weeklySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Weekly Report", subtitle: "Progress, momentum, control")

                Text("ATS \(monthlyDelta >= 0 ? "+" : "")\(monthlyDelta), \(weeklyApplications) applications sent, \(interviewsCount) interviews in pipeline, \(weeklyKeywordsImproved) keywords improved.")
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
}

private struct CareerTrendPoint: Identifiable {
    let id: Int
    let label: String
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

#Preview {
    StatisticsView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
