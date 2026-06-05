import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @State private var historyItems: [HistoryListItem] = []
    @State private var latestHistoryDetail: HistoryDetailResponse?
    @State private var isLoadingHistory = false
    @State private var errorMessage: String?
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

    private var responseRate: Int {
        guard !trackedApplications.isEmpty else { return 0 }
        let responsive = trackedApplications.filter { $0.status == .interview || $0.status == .offer }.count
        return Int((Double(responsive) / Double(trackedApplications.count)) * 100)
    }

    private var weeklyApplications: Int {
        let calendar = Calendar.current
        let now = Date()
        return trackedApplications.filter {
            calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear)
        }.count
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

    private var trendScores: [Int] {
        Array(scans.suffix(7).map(\.atsScore))
    }

    private var missingKeywords: [String] {
        Array((latestHistoryDetail?.missingSkills ?? []).prefix(3))
    }

    private var quickInsights: [HomeInsight] {
        [
            .init(title: "Career Score", value: careerScore == 0 ? "—" : "\(careerScore)", tint: BoostaColor.accent),
            .init(title: "Response Rate", value: responseRate == 0 ? "—" : "\(responseRate)%", tint: BoostaColor.success),
            .init(title: "This Week", value: "\(weeklyApplications)", tint: BoostaColor.warning),
            .init(title: "Streak", value: streakDays == 0 ? "Start" : "\(streakDays)d", tint: BoostaColor.accentSecondary)
        ]
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
                            subtitle: "Your home base for CVBoosta."
                        )

                        heroCard
                        compactStatsCard
                        recentActivityCard
                        actionsCard
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Home")
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
                withAnimation(.easeOut(duration: 0.7)) {
                    animateSparkline = true
                }
            }
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .center, spacing: BoostaSpace.md) {
                    ScoreRing(score: careerScore)
                        .frame(width: 108, height: 108)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Career snapshot")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(careerScore == 0 ? "Run your first scan" : "You’re building momentum.")
                            .font(BoostaType.section)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(summaryText)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                NavigationLink {
                    StatisticsView()
                        .environmentObject(authViewModel)
                        .environmentObject(appRouter)
                } label: {
                    HStack(spacing: BoostaSpace.xs) {
                        Text("View full statistics")
                            .font(BoostaType.bodyStrong)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BoostaColor.auroraGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: BoostaColor.accent.opacity(0.18), radius: 18, x: 0, y: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var compactStatsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Quick Statistics", subtitle: "Compressed view of your progress")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    ForEach(quickInsights) { insight in
                        MetricPill(title: insight.title, value: insight.value, color: insight.tint)
                    }
                }

                VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                    HStack {
                        Text("ATS trend")
                            .font(BoostaType.bodyStrong)
                        Spacer()
                        Text(trendLabel)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }

                    CompactTrendView(scores: trendScores, isAnimated: animateSparkline)
                        .frame(height: 72)

                    if !missingKeywords.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(missingKeywords, id: \.self) { keyword in
                                KeywordChip(text: keyword, status: .missing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentActivityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Recent Activity",
                    subtitle: isLoadingHistory ? "Syncing browser + app history..." : "Shared account activity"
                )

                if historyItems.isEmpty {
                    Text(isLoadingHistory ? "Loading history..." : "Your shared CVBoosta history will appear here.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ForEach(historyItems.prefix(3)) { item in
                        Button {
                            Task {
                                await openHistoryPDF(for: item)
                            }
                        } label: {
                            HStack(spacing: BoostaSpace.md) {
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

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Next Step", subtitle: "Keep momentum high")

                HStack(spacing: BoostaSpace.sm) {
                    PrimaryButton(title: "Analyze Resume") {
                        appRouter.open(.scanner)
                    }

                    SecondaryButton(title: "Open Tailoring") {
                        appRouter.open(.tailoring)
                    }
                }
            }
        }
    }

    private var summaryText: String {
        if careerScore == 0 {
            return "Scan your resume, sync your browser history, and start building a real performance baseline."
        }

        return "\(weeklyApplications) applications this week, \(responseRate == 0 ? "no responses yet" : "\(responseRate)% response rate"), and a \(streakDays == 0 ? "fresh" : "\(streakDays)-day") streak."
    }

    private var trendLabel: String {
        guard let first = trendScores.first, let last = trendScores.last, trendScores.count > 1 else {
            return "Not enough data"
        }
        let delta = last - first
        return delta == 0 ? "Stable" : delta > 0 ? "+\(delta)" : "\(delta)"
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
                title: item.role ?? "CV Optimization",
                subtitle: item.company ?? "CVBoosta",
                score: detail.matchAfter ?? detail.score,
                body: detail.optimizedCV
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
}

private struct HomeInsight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

struct CompactTrendView: View {
    let scores: [Int]
    let isAnimated: Bool

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                    .fill(BoostaColor.surfaceMuted)

                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: points[0].x, y: proxy.size.height - 10))
                    path.addLine(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height - 10))
                    path.closeSubpath()
                }
                .fill(BoostaColor.accent.opacity(0.14))
                .opacity(isAnimated ? 1 : 0)

                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .trim(from: 0, to: isAnimated ? 1 : 0)
                .stroke(BoostaColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .animation(.easeOut(duration: 0.9), value: isAnimated)
            }
        }
        .accessibilityLabel("Compact ATS trend")
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard scores.count > 1 else { return [] }
        let inset: CGFloat = 10
        let minScore = CGFloat(scores.min() ?? 0)
        let maxScore = CGFloat(scores.max() ?? 100)
        let range = max(maxScore - minScore, 1)
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)

        return scores.enumerated().map { index, score in
            let x = inset + (CGFloat(index) / CGFloat(max(scores.count - 1, 1))) * width
            let normalized = (CGFloat(score) - minScore) / range
            let y = inset + (1 - normalized) * height
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
        .modelContainer(PreviewModelContainer.shared)
}
