import SwiftUI
import SwiftData

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
        trackedApplications.count
    }

    private var interviewsCount: Int {
        trackedApplications.filter { $0.status == .interview }.count
    }

    private var latestScore: Int {
        authViewModel.me?.scanHistory.first?.atsScore ?? 0
    }

    private var avgScore: Int {
        guard let scans = authViewModel.me?.scanHistory, !scans.isEmpty else { return 0 }
        let total = scans.reduce(0) { $0 + $1.atsScore }
        return total / scans.count
    }

    private var atsTrendScores: [Int] {
        let scans = authViewModel.me?.scanHistory.prefix(12) ?? []
        return scans.reversed().map(\.atsScore)
    }

    private var streakDays: Int {
        guard let scans = authViewModel.me?.scanHistory else { return 0 }
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
                    ScrollView {
                        content(width: proxy.size.width)
                            .padding(.horizontal, BoostaSpace.xl)
                            .padding(.top, BoostaSpace.lg)
                            .padding(.bottom, BoostaSpace.xl)
                            .frame(maxWidth: 1400)
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
    private func content(width: CGFloat) -> some View {
        let columnCount = workspaceColumnCount(for: width)
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 320), spacing: BoostaSpace.lg, alignment: .top),
            count: columnCount
        )

        LazyVGrid(columns: columns, alignment: .leading, spacing: BoostaSpace.lg) {
            headerCard
                .gridCellColumns(columnCount)

            overviewCard
                .gridCellColumns(min(2, columnCount))

            atsTrendCard
            interviewPipelineCard

            if latestPayload != nil || latestHistoryDetail != nil {
                insightsCard
                    .gridCellColumns(columnCount)
            } else {
                emptyStateCard
                    .gridCellColumns(columnCount)
            }

            streakCard
            recentScanCard
            sharedHistoryCard
            weeklySummaryCard
        }
        .animation(BoostaMotion.smooth, value: columnCount)
    }

    private func workspaceColumnCount(for width: CGFloat) -> Int {
        if width >= 1220 { return 3 }
        if width >= 860 { return 2 }
        return 1
    }

    private var headerCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            HStack(alignment: .top, spacing: BoostaSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hi, \(firstName)")
                        .font(BoostaType.title)
                        .foregroundStyle(BoostaColor.primaryText)
                    Text("Your career intelligence workspace — shared across web and iPad.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                Spacer()

                HStack(spacing: BoostaSpace.sm) {
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
        }
    }

    private var overviewCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Today")

                HStack(alignment: .top, spacing: BoostaSpace.lg) {
                    HStack(spacing: BoostaSpace.md) {
                        ScoreRing(score: latestScore)
                            .frame(width: 120, height: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(latestScore == 0 ? "No scans yet" : "Latest ATS Score")
                                .font(BoostaType.bodyStrong)
                            Text(latestScore == 0 ? "Run one scan to get a baseline and unlock insights." : "Keep refining role keywords and measurable impact.")
                                .font(BoostaType.body)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                        HStack(spacing: BoostaSpace.sm) {
                            MetricPill(title: "Applications", value: "\(applicationsCount)", color: BoostaColor.accent)
                            MetricPill(title: "Interviews", value: "\(interviewsCount)", color: BoostaColor.success)
                            MetricPill(title: "Avg. ATS", value: avgScore == 0 ? "—" : "\(avgScore)", color: BoostaColor.warning)
                        }

                        Divider()
                            .opacity(0.35)

                        Text("Focus: Tailor for one role, rescan, then apply.")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
    }

    private var atsTrendCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "ATS Trend",
                    subtitle: atsTrendScores.isEmpty ? "No trend yet" : "Last \(atsTrendScores.count) scans"
                )

                if atsTrendScores.count < 2 {
                    Text("Scan again to visualize progress over time.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                } else {
                    ATSSparkline(scores: atsTrendScores)
                        .frame(height: 78)

                    HStack {
                        Text("Avg \(avgScore == 0 ? "—" : "\(avgScore)")")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)

                        Spacer()

                        if let first = atsTrendScores.first, let last = atsTrendScores.last {
                            let delta = last - first
                            Text(delta == 0 ? "±0" : (delta > 0 ? "+\(delta)" : "\(delta)"))
                                .font(BoostaType.caption)
                                .foregroundStyle(delta >= 0 ? BoostaColor.success : BoostaColor.warning)
                        }
                    }
                }
            }
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
                    HStack(alignment: .top, spacing: BoostaSpace.lg) {
                        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                            Text("Top missing skills")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            let limit = subscriptionService.isPremium ? 12 : 6
                            let keywords = Array(payload.response.missingSkills.prefix(limit))

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

                        Divider()
                            .opacity(0.35)

                        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                            Text("Quick wins")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            let fixes = Array(payload.response.recommendations.prefix(4))
                            if fixes.isEmpty {
                                Text("No quick wins flagged yet.")
                                    .font(BoostaType.body)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            } else {
                                ForEach(fixes, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(BoostaType.body)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }
                            }
                        }
                    }
                } else if let detail = latestHistoryDetail {
                    HStack(alignment: .top, spacing: BoostaSpace.lg) {
                        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                            Text("Top missing skills")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            let keywords = Array(detail.missingSkills.prefix(subscriptionService.isPremium ? 12 : 6))
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

                        Divider()
                            .opacity(0.35)

                        VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                            Text("Quick wins")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)

                            let fixes = Array(detail.recommendations.prefix(4))
                            if fixes.isEmpty {
                                Text("No quick wins flagged yet.")
                                    .font(BoostaType.body)
                                    .foregroundStyle(BoostaColor.secondaryText)
                            } else {
                                ForEach(fixes, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(BoostaType.body)
                                        .foregroundStyle(BoostaColor.secondaryText)
                                }
                            }
                        }
                    }
                } else {
                    Text("Run a scan to unlock personalized insights.")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
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
            }
        }
    }

    private var sharedHistoryCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(
                    title: "Shared Account History",
                    subtitle: isLoadingHistory ? "Syncing web + iPad activity..." : "Browser-generated scans and optimizations"
                )

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

                                MetricPill(
                                    title: "ATS",
                                    value: "\(item.matchAfter ?? item.score)",
                                    color: BoostaColor.accent
                                )
                            }
                            .padding(.vertical, 6)
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

                Text("ATS \(latestDelta >= 0 ? "+" : "")\(latestDelta), \(applicationsCount) tracked applications, \(interviewsCount) interviews in pipeline, \(keywordsImproved) keywords improved.")
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
                .background(Color.white.opacity(0.55))
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

private struct ATSSparkline: View {
    let scores: [Int]
    @State private var isRevealed = false

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .trim(from: 0, to: isRevealed ? 1 : 0)
                .stroke(BoostaColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .animation(.easeOut(duration: 0.9), value: isRevealed)

                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                    path.addLine(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(BoostaColor.accent.opacity(0.12))
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1)
            }
        }
        .onAppear {
            isRevealed = true
        }
        .onChange(of: scores) { _, _ in
            isRevealed = false
            DispatchQueue.main.async {
                isRevealed = true
            }
        }
        .accessibilityLabel("ATS score trend chart")
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard scores.count > 1 else { return [] }
        let minScore = max(CGFloat(scores.min() ?? 0), 0)
        let maxScore = max(CGFloat(scores.max() ?? 0), 1)
        let range = max(maxScore - minScore, 1)

        let inset: CGFloat = 6
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)

        return scores.enumerated().map { idx, raw in
            let x = inset + (CGFloat(idx) / CGFloat(scores.count - 1)) * width
            let clamped = min(max(CGFloat(raw), minScore), maxScore)
            let normalized = (clamped - minScore) / range
            let y = inset + (1 - normalized) * height
            return CGPoint(x: x, y: y)
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
