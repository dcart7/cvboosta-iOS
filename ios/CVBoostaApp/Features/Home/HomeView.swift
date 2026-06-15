import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @AppStorage(SharedStreakState.restoreDayKey, store: SharedStreakState.sharedDefaults)
    private var restoredDayStamp = ""
    @AppStorage(SharedStreakState.freezeDayKey, store: SharedStreakState.sharedDefaults)
    private var frozenDayStamp = ""

    @State private var historyItems: [HistoryListItem] = []
    @State private var latestHistoryDetail: HistoryDetailResponse?
    @State private var isLoadingHistory = false
    @State private var errorMessage: String?
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
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps(
                restoredDayStamp: restoredDayStamp,
                frozenDayStamp: frozenDayStamp
            )
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
        min(100, max(0, Int(Double(careerScore) * 0.55) + min(weeklyApplications * 8, 24) + min(streakDays * 4, 16) + min(responseRate / 2, 18)))
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
        streakSummary.currentStreak
    }

    private var trendScores: [Int] {
        Array(scans.suffix(7).map { normalizedATSScore($0.matchAfter ?? $0.atsScore) })
    }

    private var missingKeywords: [String] {
        Array((latestHistoryDetail?.missingSkills ?? []).prefix(3))
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

    private var momentumTier: String {
        switch momentumScore {
        case 85...100: return "Interview Ready"
        case 70...84: return "Recruiter Visible"
        case 50...69: return "Momentum Building"
        case 1...49: return "Baseline Building"
        default: return "Start Strong"
        }
    }

    private var momentumSummary: String {
        if careerScore == 0 {
            return "Run your first ATS scan to unlock your career momentum baseline."
        }
        if overdueFollowUps > 0 {
            return "\(overdueFollowUps) follow-up\(overdueFollowUps == 1 ? "" : "s") can lift your response rate today."
        }
        if upcomingInterviews > 0 {
            return "\(upcomingInterviews) interview\(upcomingInterviews == 1 ? "" : "s") need prep soon — your pipeline is moving."
        }
        if !missingKeywords.isEmpty {
            return "You can raise visibility by closing \(missingKeywords.count) keyword gap\(missingKeywords.count == 1 ? "" : "s")."
        }
        return "Momentum is healthy — keep scanning and applying to hold recruiter visibility."
    }

    private var todayActions: [TodayAction] {
        var items: [TodayAction] = []

        if overdueFollowUps > 0 {
            items.append(
                TodayAction(
                    title: "Follow up today",
                    detail: "\(overdueFollowUps) application\(overdueFollowUps == 1 ? "" : "s") are ready for a recruiter nudge.",
                    tint: BoostaColor.warning
                )
            )
        }

        if !missingKeywords.isEmpty {
            items.append(
                TodayAction(
                    title: "Close ATS gaps",
                    detail: "Add \(missingKeywords.prefix(2).joined(separator: ", ")) to role-specific bullets.",
                    tint: BoostaColor.accent
                )
            )
        }

        if upcomingInterviews > 0 {
            items.append(
                TodayAction(
                    title: "Prepare interviews",
                    detail: "\(upcomingInterviews) interview\(upcomingInterviews == 1 ? "" : "s") are scheduled in the next 7 days.",
                    tint: BoostaColor.success
                )
            )
        }

        if items.isEmpty {
            items.append(
                TodayAction(
                    title: "Keep momentum alive",
                    detail: careerScore == 0
                        ? "Start with one ATS scan to create your first benchmark."
                        : "Scan one role-specific resume variation to keep improving consistency.",
                    tint: BoostaColor.accentSecondary
                )
            )
        }

        return Array(items.prefix(3))
    }

    private var quickInsights: [HomeInsight] {
        [
            .init(title: "Career Score", value: careerScore == 0 ? "—" : "\(careerScore)", tint: BoostaColor.accent),
            .init(title: "Momentum", value: momentumScore == 0 ? "—" : "\(momentumScore)", tint: BoostaColor.accentSecondary),
            .init(title: "Response Rate", value: responseRate == 0 ? "—" : "\(responseRate)%", tint: BoostaColor.success),
            streakInsight
        ]
    }

    private var streakInsight: HomeInsight {
        if streakSummary.currentStreak > 0 {
            return .init(title: "Streak", value: "\(streakSummary.currentStreak)d", tint: BoostaColor.warning, isStreak: true)
        }
        if streakSummary.pendingStreak > 0 {
            return .init(title: "Protect Streak", value: "\(streakSummary.pendingStreak)d", tint: BoostaColor.warning, isStreak: true)
        }
        if streakSummary.canUseRecovery {
            return .init(title: "Recover Streak", value: "Restore", tint: BoostaColor.warning, isStreak: true)
        }
        return .init(title: "Streak", value: "Start", tint: BoostaColor.accentSecondary, isStreak: true)
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
                        todayCard
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
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps(
                restoredDayStamp: restoredDayStamp,
                frozenDayStamp: frozenDayStamp
            )
        )
        let hour = Calendar.current.component(.hour, from: .now)
        Task {
            guard !summary.todayActions.isEmpty,
                  summary.currentStreak >= 2,
                  !summary.statusTitle.contains("protected"),
                  hour >= 20 else {
                await LiveActivityManager.shared.clearStreakProtection()
                return
            }

            await LiveActivityManager.shared.showStreakProtection(
                dayCount: summary.currentStreak,
                detail: summary.todayActions.first?.detail ?? summary.todayDetail
            )
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .center, spacing: BoostaSpace.md) {
                    ScoreRing(score: careerScore)
                        .frame(width: 108, height: 108)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Career Momentum")
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                        Text(momentumScore == 0 ? "Start your baseline" : "\(momentumScore)/100 • \(momentumTier)")
                            .font(BoostaType.section)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(momentumSummary)
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
                            .stroke(BoostaColor.outlineSoft, lineWidth: 1)
                    )
                    .shadow(color: BoostaColor.accent.opacity(0.18), radius: 18, x: 0, y: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var todayCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Today", subtitle: "What moves your search forward right now")

                VStack(spacing: BoostaSpace.sm) {
                    ForEach(todayActions) { action in
                        TodayActionRow(action: action)
                    }
                }

                HStack(spacing: BoostaSpace.sm) {
                    SecondaryButton(title: "Open Tracker") {
                        appRouter.open(.tracker)
                    }

                    SecondaryButton(title: "Check ATS Score") {
                        appRouter.open(.scanner)
                    }
                }
            }
        }
    }

    private var compactStatsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Quick Statistics", subtitle: "Compressed view of your progress")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    ForEach(quickInsights) { insight in
                        if insight.isStreak {
                            Button {
                                showStreakCenter = true
                            } label: {
                                HomeStatCard(title: insight.title, value: insight.value, color: insight.tint, icon: "flame.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            HomeStatCard(title: insight.title, value: insight.value, color: insight.tint)
                        }
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
                HStack(alignment: .top, spacing: BoostaSpace.sm) {
                    SectionHeader(
                        title: "Recent Activity",
                        subtitle: isLoadingHistory ? "Syncing browser + app history..." : "Shared account activity"
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
                SectionHeader(title: "Career OS", subtitle: "Scanner → Tailor → Apply → Track → Improve")

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

    private var trendLabel: String {
        guard let first = trendScores.first, let last = trendScores.last, trendScores.count > 1 else {
            return "Not enough data"
        }
        let delta = last - first
        if delta > 0 { return "+\(delta) improving" }
        if delta < 0 { return "Rescan advised" }
        return "Stable"
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
}

private struct HomeInsight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
    var isStreak: Bool = false
}

private struct TodayAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
}

struct HomeStatCard: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BoostaSpace.xs) {
            Text(title)
                .font(BoostaType.caption)
                .foregroundStyle(BoostaColor.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                }

                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(BoostaSpace.sm)
        .background(BoostaColor.surfaceInteractive)
        .overlay(
            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                .stroke(BoostaColor.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
    }
}

private struct TodayActionRow: View {
    let action: TodayAction

    var body: some View {
        HStack(alignment: .top, spacing: BoostaSpace.sm) {
            Circle()
                .fill(action.tint.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(action.tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(BoostaType.bodyStrong)
                    .foregroundStyle(BoostaColor.primaryText)
                Text(action.detail)
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
