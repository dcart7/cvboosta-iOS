import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

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
        authViewModel.me?.applications.count ?? 0
    }

    private var interviewsCount: Int {
        authViewModel.me?.applications.filter { $0.status.lowercased() == "interview" }.count ?? 0
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
                            MetricPill(title: "Interviews", value: "\(interviewsCount)", color: BoostaColor.success)
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
                Text("Your latest resume score")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)

                HStack(spacing: BoostaSpace.md) {
                    ScoreRing(score: latestScore)
                        .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: BoostaSpace.xs) {
                        Text(latestScore == 0 ? "No scans yet" : "Current ATS Score")
                            .font(BoostaType.bodyStrong)
                        Text(latestScore == 0 ? "Start with one scan to get a baseline." : "Keep refining role keywords and measurable impact.")
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                PrimaryButton(title: "Scan New Resume") {
                    appRouter.open(.scanner)
                }
            }
        }
    }

    private var resumeHealthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.sm) {
                SectionHeader(title: "Resume Health")
                Text("• Improve measurable outcomes in top bullets")
                Text("• Add role-specific keywords from target jobs")
                Text("• Strengthen summary with technical impact")
            }
            .font(BoostaType.body)
            .foregroundStyle(BoostaColor.secondaryText)
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
                Text(streakDays == 0 ? "Start your streak today." : "\(streakDays) active day\(streakDays == 1 ? "" : "s")")
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
