import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    private var firstName: String {
        if let raw = authViewModel.me?.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw.split(separator: " ").first.map(String.init) ?? raw
        }

        if let email = authViewModel.me?.user.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }

        return "there"
    }

    private var latestScore: Int {
        authViewModel.me?.scanHistory.first?.atsScore ?? 0
    }

    private var applicationsCount: Int {
        trackedApplications.count
    }

    private var interviewsCount: Int {
        trackedApplications.filter { $0.status == .interview }.count
    }

    private var avgScore: Int {
        guard let scans = authViewModel.me?.scanHistory, !scans.isEmpty else { return 0 }
        let total = scans.reduce(0) { $0 + $1.atsScore }
        return total / scans.count
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

    private var interviewProbability: String {
        switch latestScore {
        case 80...100: return "Strong"
        case 65...79: return "Medium"
        case 1...64: return "Low"
        default: return "Unknown"
        }
    }

    private var topBlocker: String {
        if avgScore >= 80 { return "You need stronger recruiter-facing proof in recent applications." }
        if avgScore >= 65 { return "Your resume likely misses measurable backend impact in key bullets." }
        if avgScore > 0 { return "Keyword coverage and impact language are blocking more interviews." }
        return "Run your first ATS scan to uncover what is blocking interviews."
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
        let responsiveStatuses: Set<ApplicationStatus> = [.interview, .offer]
        let responsive = trackedApplications.filter { responsiveStatuses.contains($0.status) }.count
        return Int((Double(responsive) / Double(trackedApplications.count)) * 100)
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
                            subtitle: "Let’s improve your interview chances today."
                        )

                        heroCard

                        HStack(spacing: BoostaSpace.sm) {
                            MetricPill(title: "Applications", value: "\(applicationsCount)", color: BoostaColor.accent)
                            MetricPill(title: "Response Rate", value: responseRate == 0 ? "—" : "\(responseRate)%", color: BoostaColor.success)
                            MetricPill(title: "Avg. ATS", value: avgScore == 0 ? "—" : "\(avgScore)", color: BoostaColor.warning)
                        }

                        if authViewModel.me?.scanHistory.isEmpty ?? true {
                            EmptyStateView(
                                title: "No resume scanned yet",
                                message: "Upload your resume to get your first ATS score.",
                                actionTitle: "Start First Scan"
                            ) {
                                appRouter.open(.scanner)
                            }
                        } else {
                            resumeHealthCard
                            insightCard
                            todayFocusCard
                            streakCard
                            recentScanCard
                        }
                    }
                    .padding(BoostaSpace.md)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appRouter.open(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await authViewModel.refreshSharedState()
            }
        }
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                Text("Career optimization snapshot")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: latestScore)
                        .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text(latestScore == 0 ? "No scans yet" : "Interview probability: \(interviewProbability)")
                            .font(BoostaType.bodyStrong)
                        Text(latestScore == 0 ? "Start with one scan to get a baseline." : topBlocker)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    KeywordChip(text: "ATS Parsing", status: latestScore >= 80 ? .present : latestScore >= 60 ? .weak : .missing)
                    KeywordChip(text: "Keyword Match", status: avgScore >= 75 ? .present : avgScore >= 60 ? .weak : .missing)
                    KeywordChip(text: "Role Alignment", status: applicationsCount > 0 ? .weak : .missing)
                }

                PrimaryButton(title: "Analyze Resume") {
                    appRouter.open(.scanner)
                }
            }
        }
    }

    private var resumeHealthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Fast wins")
                Text("• Add metrics to your strongest experience bullets")
                Text("• Mention target stack keywords from current job descriptions")
                Text("• Replace generic wording with clear backend impact")
            }
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.secondaryText)
        }
    }

    private var insightCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Live insights", subtitle: "What is most likely blocking interviews")

                Text(topBlocker)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.primaryText)

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "This week", value: "\(weeklyApplications)", color: BoostaColor.accent)
                    MetricPill(title: "Missing keywords", value: latestScore == 0 ? "—" : latestScore >= 80 ? "2" : latestScore >= 65 ? "5" : "7", color: BoostaColor.warning)
                }
            }
        }
    }

    private var todayFocusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Today’s Focus")
                Text("Tailor your resume for one high-priority role and rescan before applying.")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                SecondaryButton(title: "Open Tailoring") {
                    appRouter.open(.tailoring)
                }
            }
        }
    }

    private var streakCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                SectionHeader(title: "Job Search Streak")
                Text(streakDays == 0 ? "Start your streak today." : "\(streakDays) active day\(streakDays == 1 ? "" : "s") • \(weeklyApplications) applications this week")
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var recentScanCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                SectionHeader(title: "Recent Scan")
                if let scan = authViewModel.me?.scanHistory.first {
                    Text(scan.resumeFileName)
                        .font(BoostaType.bodyStrong)
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(BoostaType.caption)
                        .foregroundStyle(BoostaColor.secondaryText)
                }

                SecondaryButton(title: "Open Scanner") {
                    appRouter.open(.scanner)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppRouter())
}
