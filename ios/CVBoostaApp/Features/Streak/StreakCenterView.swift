import SwiftUI
import SwiftData

struct StreakCenterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @Query(sort: \ApplicationRecord.appliedAt, order: .reverse)
    private var trackedApplications: [ApplicationRecord]

    @AppStorage("cvboosta.streak.restore.day") private var restoredDayStamp = ""
    @AppStorage("cvboosta.streak.freeze.day") private var frozenDayStamp = ""

    @State private var usedRecoveryThisSession = false

    private var summary: StreakSummary {
        StreakEngine.build(
            now: .now,
            user: authViewModel.me?.user,
            scans: authViewModel.me?.scanHistory ?? [],
            applications: trackedApplications,
            manuallyProtectedDayStamps: Set([restoredDayStamp, frozenDayStamp].filter { !$0.isEmpty })
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BoostaColor.pageTop, BoostaColor.pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BoostaSpace.md) {
                    heroCard
                    todayCard
                    heatmapCard
                    milestonesCard
                    missionsCard
                    achievementsCard
                    remindersCard
                }
                .padding(BoostaSpace.md)
            }
        }
        .navigationTitle("Streak")
    }

    private var heroCard: some View {
        GlassCard(padding: BoostaSpace.lg) {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                HStack(alignment: .center, spacing: BoostaSpace.md) {
                    ZStack {
                        ScoreRing(score: summary.progressToNextMilestonePercent)
                            .frame(width: 118, height: 118)

                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("\(summary.currentStreak)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(BoostaColor.primaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.identityLine)
                            .font(BoostaType.section)
                            .foregroundStyle(BoostaColor.primaryText)
                        Text(summary.statusTitle)
                            .font(BoostaType.bodyStrong)
                            .foregroundStyle(summary.statusTint)
                        Text(summary.microcopy)
                            .font(BoostaType.body)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }

                HStack(spacing: BoostaSpace.sm) {
                    MetricPill(title: "Weekly", value: "\(summary.weeklyActiveDays)/7", color: BoostaColor.accent)
                    MetricPill(title: "Level", value: summary.careerLevel, color: BoostaColor.accentSecondary)
                    MetricPill(title: "Best", value: "\(summary.longestStreak)d", color: BoostaColor.success)
                }
            }
        }
    }

    private var todayCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Today", subtitle: summary.todayTitle)

                Text(summary.todayDetail)
                    .font(BoostaType.body)
                    .foregroundStyle(BoostaColor.secondaryText)

                VStack(spacing: BoostaSpace.sm) {
                    ForEach(summary.todayActions) { action in
                        HStack(alignment: .top, spacing: BoostaSpace.sm) {
                            Circle()
                                .fill(action.tint.opacity(0.18))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 12, weight: .bold))
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

                            Spacer()
                        }
                        .padding(BoostaSpace.sm)
                        .background(Color.white.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                                .stroke(BoostaColor.glassStroke, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    }
                }

                if summary.canUseRecovery, !usedRecoveryThisSession {
                    HStack(spacing: BoostaSpace.sm) {
                        SecondaryButton(title: "Use Streak Restore") {
                            restoreYesterday()
                        }

                        SecondaryButton(title: "Freeze Today") {
                            freezeToday()
                        }
                    }
                }
            }
        }
    }

    private var heatmapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Monthly Heatmap", subtitle: "Visible momentum beats fake motivation")

                HeatmapGrid(days: summary.heatmapDays)
                Text("1 useful career action protects the day. Scan, tailor, apply, prep, or improve.")
                    .font(BoostaType.caption)
                    .foregroundStyle(BoostaColor.secondaryText)
            }
        }
    }

    private var milestonesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Milestones", subtitle: "Consistency creates recruiter visibility")

                ForEach(summary.milestones) { milestone in
                    HStack(spacing: BoostaSpace.sm) {
                        ZStack {
                            Circle()
                                .fill(milestone.isReached ? milestone.tint.opacity(0.22) : Color.white.opacity(0.35))
                                .frame(width: 38, height: 38)
                            Image(systemName: milestone.isReached ? "flame.fill" : "circle")
                                .foregroundStyle(milestone.isReached ? milestone.tint : BoostaColor.secondaryText)
                        }
                        .shadow(color: milestone.isReached ? milestone.tint.opacity(0.22) : .clear, radius: 12, x: 0, y: 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(milestone.dayCount) days • \(milestone.title)")
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.primaryText)
                            Text(milestone.description)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }

                        Spacer()

                        if milestone.isReached {
                            Text("Unlocked")
                                .font(BoostaType.caption)
                                .foregroundStyle(milestone.tint)
                        }
                    }
                }
            }
        }
    }

    private var missionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Weekly Missions", subtitle: "Real actions, not fake productivity")

                ForEach(summary.missions) { mission in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(mission.title)
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.primaryText)
                            Spacer()
                            Text("\(mission.progress)/\(mission.goal)")
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }

                        ProgressView(value: Double(mission.progress), total: Double(max(mission.goal, 1)))
                            .tint(mission.tint)

                        Text(mission.detail)
                            .font(BoostaType.caption)
                            .foregroundStyle(BoostaColor.secondaryText)
                    }
                }
            }
        }
    }

    private var achievementsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Achievements", subtitle: "Professional energy, subtle dopamine")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BoostaSpace.sm) {
                    ForEach(summary.achievements) { achievement in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(achievement.title)
                                .font(BoostaType.bodyStrong)
                                .foregroundStyle(BoostaColor.primaryText)
                            Text(achievement.detail)
                                .font(BoostaType.caption)
                                .foregroundStyle(BoostaColor.secondaryText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .padding(BoostaSpace.sm)
                        .background(Color.white.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous)
                                .stroke(achievement.tint.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BoostaRadius.md, style: .continuous))
                    }
                }
            }
        }
    }

    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BoostaSpace.md) {
                SectionHeader(title: "Reminder Style", subtitle: "Friendly, short, not cringe")

                ForEach(summary.notificationIdeas, id: \.self) { line in
                    Text("• \(line)")
                        .font(BoostaType.body)
                        .foregroundStyle(BoostaColor.secondaryText)
                }
            }
        }
    }

    private func restoreYesterday() {
        restoredDayStamp = StreakEngine.dayStamp(for: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
        usedRecoveryThisSession = true
    }

    private func freezeToday() {
        frozenDayStamp = StreakEngine.dayStamp(for: .now)
        usedRecoveryThisSession = true
    }
}

enum StreakActionKind: String, CaseIterable, Identifiable {
    case atsScan
    case optimizeCV
    case tailorResume
    case applyToJob
    case saveJob
    case improveATSScore
    case interviewPrep
    case uploadResumeVersion
    case fillProfileProgress
    case dailyCareerTask

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .atsScan: return "doc.text.magnifyingglass"
        case .optimizeCV: return "wand.and.stars"
        case .tailorResume: return "slider.horizontal.3"
        case .applyToJob: return "paperplane.fill"
        case .saveJob: return "bookmark.fill"
        case .improveATSScore: return "chart.line.uptrend.xyaxis"
        case .interviewPrep: return "person.crop.rectangle.stack"
        case .uploadResumeVersion: return "square.and.arrow.up"
        case .fillProfileProgress: return "person.crop.circle.badge.checkmark"
        case .dailyCareerTask: return "checklist"
        }
    }
}

struct StreakHeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let intensity: Double
    let isToday: Bool
}

struct StreakMilestone: Identifiable {
    let id = UUID()
    let dayCount: Int
    let title: String
    let description: String
    let tint: Color
    let isReached: Bool
}

struct StreakMission: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let progress: Int
    let goal: Int
    let tint: Color
}

struct StreakAchievement: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let tint: Color
}

struct StreakTodayAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}

struct StreakSummary {
    let currentStreak: Int
    let longestStreak: Int
    let weeklyActiveDays: Int
    let progressToNextMilestonePercent: Int
    let careerLevel: String
    let identityLine: String
    let statusTitle: String
    let statusTint: Color
    let microcopy: String
    let todayTitle: String
    let todayDetail: String
    let todayActions: [StreakTodayAction]
    let canUseRecovery: Bool
    let heatmapDays: [StreakHeatmapDay]
    let milestones: [StreakMilestone]
    let missions: [StreakMission]
    let achievements: [StreakAchievement]
    let notificationIdeas: [String]
}

enum StreakEngine {
    static func build(
        now: Date,
        user: AuthUser?,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord],
        manuallyProtectedDayStamps: Set<String>
    ) -> StreakSummary {
        let calendar = Calendar.current
        let actionsByDay = collectActions(
            calendar: calendar,
            user: user,
            scans: scans,
            applications: applications,
            manuallyProtectedDayStamps: manuallyProtectedDayStamps
        )

        let orderedDays = actionsByDay.keys.sorted()
        let currentStreak = streakLength(endingAt: now, using: actionsByDay, calendar: calendar)
        let longestStreak = longestStreak(in: orderedDays, calendar: calendar)
        let weeklyActiveDays = activeDays(inLast: 7, actionsByDay: actionsByDay, now: now, calendar: calendar)
        let monthlyActiveDays = activeDays(inLast: 30, actionsByDay: actionsByDay, now: now, calendar: calendar)
        let todayStamp = dayStamp(for: now)
        let yesterdayStamp = dayStamp(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        let todayProtected = actionsByDay[todayStamp] != nil
        let yesterdayProtected = actionsByDay[yesterdayStamp] != nil

        let milestonesConfig: [(Int, String, String, Color)] = [
            (3, "Consistency Started", "You’ve begun the habit loop.", .orange),
            (7, "Career Discipline", "A full week of useful career motion.", .orange),
            (14, "ATS Survivor", "You’re building real search consistency.", .yellow),
            (30, "Interview Machine", "Thirty days of momentum compounds fast.", .green),
            (60, "Top 5% Consistency", "Most applicants won’t stay this steady.", .blue),
            (100, "Elite Career Operator", "You’ve built identity-level consistency.", .purple)
        ]

        let nextMilestone = milestonesConfig.first(where: { currentStreak < $0.0 }) ?? milestonesConfig.last!
        let previousMilestone = milestonesConfig.last(where: { currentStreak >= $0.0 })?.0 ?? 0
        let progressDenominator = max(nextMilestone.0 - previousMilestone, 1)
        let progressValue = min(max(currentStreak - previousMilestone, 0), progressDenominator)
        let progressPercent = Int((Double(progressValue) / Double(progressDenominator)) * 100)

        let careerLevel: String = {
            switch currentStreak {
            case 100...: return "Elite"
            case 60...: return "Top 5%"
            case 30...: return "Interview-ready"
            case 14...: return "Recruiter-visible"
            case 7...: return "Disciplined"
            case 1...: return "Building"
            default: return "Starting"
            }
        }()

        let todayActions = buildTodayActions(
            todayProtected: todayProtected,
            scans: scans,
            applications: applications,
            weeklyActiveDays: weeklyActiveDays,
            calendar: calendar,
            now: now
        )

        let statusTitle: String
        let statusTint: Color
        let microcopy: String
        let todayTitle: String
        let todayDetail: String
        let canUseRecovery = !todayProtected && !yesterdayProtected && currentStreak == 0 && longestStreak >= 2

        if todayProtected {
            statusTitle = "Streak protected 🔥"
            statusTint = BoostaColor.success
            microcopy = [
                "Your future recruiter would approve.",
                "Small improvements. Bigger interview chances.",
                "Career momentum maintained."
            ].randomElement() ?? "Career momentum maintained."
            todayTitle = "Protected"
            todayDetail = "You’ve already done enough today to keep momentum alive."
        } else if yesterdayProtected {
            statusTitle = "At risk today"
            statusTint = BoostaColor.warning
            microcopy = [
                "1 useful action keeps your momentum alive.",
                "You’re closer than you think.",
                "Future-you says thanks."
            ].randomElement() ?? "1 useful action keeps your momentum alive."
            todayTitle = "One action protects today"
            todayDetail = "Scan, tailor, apply, or prep once today and your streak keeps moving."
        } else {
            statusTitle = canUseRecovery ? "Recovery available" : "Start a fresh run"
            statusTint = canUseRecovery ? BoostaColor.warning : BoostaColor.accent
            microcopy = canUseRecovery
                ? "You were close. Continue today."
                : "Identity starts with one good career action."
            todayTitle = canUseRecovery ? "Use restore or act today" : "Begin today's momentum"
            todayDetail = canUseRecovery
                ? "You missed a day, but you can recover gracefully and keep going."
                : "One useful career action starts the next streak."
        }

        let heatmapDays = (0..<35).reversed().map { offset -> StreakHeatmapDay in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let stamp = dayStamp(for: date)
            let intensity = min(Double(actionsByDay[stamp]?.count ?? 0) / 3.0, 1)
            return StreakHeatmapDay(date: date, intensity: intensity, isToday: calendar.isDateInToday(date))
        }

        let milestones = milestonesConfig.map {
            StreakMilestone(dayCount: $0.0, title: $0.1, description: $0.2, tint: $0.3, isReached: currentStreak >= $0.0)
        }

        let applicationsThisWeek = applications.filter { calendar.isDate($0.appliedAt, equalTo: now, toGranularity: .weekOfYear) }.count
        let improvedScans = scans.filter { ($0.matchAfter ?? $0.atsScore) > ($0.matchBefore ?? $0.atsScore) }.count

        let missions = [
            StreakMission(title: "Protect the streak", detail: "1 useful action every day keeps momentum alive.", progress: min(weeklyActiveDays, 7), goal: 7, tint: BoostaColor.accent),
            StreakMission(title: "Send applications", detail: "Applied jobs create real interview surface area.", progress: min(applicationsThisWeek, 5), goal: 5, tint: BoostaColor.warning),
            StreakMission(title: "Improve ATS", detail: "More role-aligned scans raise recruiter visibility.", progress: min(improvedScans, 3), goal: 3, tint: BoostaColor.success)
        ]

        var achievements: [StreakAchievement] = milestones.filter(\.isReached).suffix(2).map {
            StreakAchievement(title: $0.title, detail: "\($0.dayCount)-day milestone reached.", tint: $0.tint)
        }
        if scans.contains(where: { ($0.matchAfter ?? $0.atsScore) >= 80 }) {
            achievements.append(.init(title: "Recruiter Visible", detail: "You pushed at least one score to 80+.", tint: BoostaColor.success))
        }
        if applications.contains(where: { $0.status == .interview || $0.status == .offer }) {
            achievements.append(.init(title: "Pipeline Real", detail: "You moved at least one opportunity past application stage.", tint: BoostaColor.warning))
        }
        if achievements.isEmpty {
            achievements = [
                .init(title: "First Spark", detail: "One action is enough to start your momentum loop.", tint: BoostaColor.accent)
            ]
        }

        let identityLine = monthlyActiveDays >= 20
            ? "You’re the type of person who improves career daily."
            : "Consistency turns ATS work into interview momentum."

        return StreakSummary(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            weeklyActiveDays: weeklyActiveDays,
            progressToNextMilestonePercent: progressPercent,
            careerLevel: careerLevel,
            identityLine: identityLine,
            statusTitle: statusTitle,
            statusTint: statusTint,
            microcopy: microcopy,
            todayTitle: todayTitle,
            todayDetail: todayDetail,
            todayActions: todayActions,
            canUseRecovery: canUseRecovery,
            heatmapDays: heatmapDays,
            milestones: milestones,
            missions: missions,
            achievements: achievements,
            notificationIdeas: [
                "Your streak is waiting.",
                "1 quick scan keeps your momentum alive.",
                "Don’t let your career streak expire.",
                "Future-you says thanks.",
                "2 mins today > regret tomorrow."
            ]
        )
    }

    static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func collectActions(
        calendar: Calendar,
        user: AuthUser?,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord],
        manuallyProtectedDayStamps: Set<String>
    ) -> [String: Set<StreakActionKind>] {
        var result: [String: Set<StreakActionKind>] = [:]

        func add(_ action: StreakActionKind, on date: Date) {
            let key = dayStamp(for: date)
            var actions = result[key] ?? []
            actions.insert(action)
            result[key] = actions
        }

        for scan in scans {
            add(.atsScan, on: scan.createdAt)
            add(.optimizeCV, on: scan.createdAt)
            if (scan.matchAfter ?? scan.atsScore) > (scan.matchBefore ?? scan.atsScore) {
                add(.improveATSScore, on: scan.createdAt)
            }
        }

        for application in applications {
            switch application.status {
            case .saved:
                add(.saveJob, on: application.appliedAt)
            case .applied:
                add(.applyToJob, on: application.appliedAt)
            case .interview:
                add(.applyToJob, on: application.appliedAt)
                add(.interviewPrep, on: application.interviewAt ?? application.appliedAt)
            case .offer:
                add(.applyToJob, on: application.appliedAt)
                add(.interviewPrep, on: application.interviewAt ?? application.appliedAt)
            case .rejected:
                add(.applyToJob, on: application.appliedAt)
            }
        }

        if let user, !(user.displayName?.isEmpty ?? true) {
            add(.fillProfileProgress, on: user.createdAt)
        }

        for stamp in manuallyProtectedDayStamps {
            if result[stamp] == nil {
                result[stamp] = [.dailyCareerTask]
            }
        }

        return result
    }

    private static func streakLength(endingAt now: Date, using actionsByDay: [String: Set<StreakActionKind>], calendar: Calendar) -> Int {
        var current = calendar.startOfDay(for: now)
        var streak = 0
        while actionsByDay[dayStamp(for: current)] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return streak
    }

    private static func longestStreak(in orderedDayStamps: [String], calendar: Calendar) -> Int {
        guard !orderedDayStamps.isEmpty else { return 0 }
        let dates = orderedDayStamps.compactMap { stampToDate($0) }.sorted()
        guard let first = dates.first else { return 0 }

        var longest = 1
        var current = 1
        var previous = first

        for date in dates.dropFirst() {
            let difference = calendar.dateComponents([.day], from: previous, to: date).day ?? 0
            if difference == 1 {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    private static func activeDays(inLast count: Int, actionsByDay: [String: Set<StreakActionKind>], now: Date, calendar: Calendar) -> Int {
        (0..<count).reduce(0) { total, offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            return total + (actionsByDay[dayStamp(for: date)] == nil ? 0 : 1)
        }
    }

    private static func buildTodayActions(
        todayProtected: Bool,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord],
        weeklyActiveDays: Int,
        calendar: Calendar,
        now: Date
    ) -> [StreakTodayAction] {
        if todayProtected {
            return [
                .init(title: "Career momentum maintained", detail: "Today already counts. Keep going only if it helps your real search.", icon: "flame.fill", tint: BoostaColor.success)
            ]
        }

        let followUps = applications.filter {
            $0.status == .applied &&
            (calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: $0.appliedAt)) ?? .distantFuture) <= calendar.startOfDay(for: now)
        }.count

        var actions: [StreakTodayAction] = []

        if followUps > 0 {
            actions.append(.init(title: "Follow up today", detail: "\(followUps) applications are ready for a recruiter nudge.", icon: "paperplane.fill", tint: BoostaColor.warning))
        }

        if let latest = scans.last, (latest.matchAfter ?? latest.atsScore) < 80 {
            actions.append(.init(title: "Run one ATS scan", detail: "One quick scan can raise recruiter visibility for \(latest.targetRole.isEmpty ? "your next role" : latest.targetRole).", icon: "doc.text.magnifyingglass", tint: BoostaColor.accent))
        }

        let upcomingInterviews = applications.filter {
            guard $0.status == .interview, let interviewAt = $0.interviewAt else { return false }
            return interviewAt >= now && interviewAt <= (calendar.date(byAdding: .day, value: 3, to: now) ?? now)
        }.count
        if upcomingInterviews > 0 {
            actions.append(.init(title: "Interview prep", detail: "\(upcomingInterviews) interview\(upcomingInterviews == 1 ? "" : "s") are close enough to prep today.", icon: "person.crop.rectangle.stack", tint: BoostaColor.success))
        }

        if actions.isEmpty {
            actions.append(.init(title: "Protect the streak", detail: weeklyActiveDays >= 4 ? "One small action keeps a strong week intact." : "Start with one useful career action today.", icon: "checklist", tint: BoostaColor.accentSecondary))
        }

        return Array(actions.prefix(3))
    }

    private static func stampToDate(_ stamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: stamp)
    }
}

private struct HeatmapGrid: View {
    let days: [StreakHeatmapDay]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(heatColor(for: day))
                    .frame(height: 24)
                    .overlay {
                        if day.isToday {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    private func heatColor(for day: StreakHeatmapDay) -> Color {
        if day.intensity == 0 { return Color.white.opacity(0.18) }
        if day.intensity < 0.35 { return Color.orange.opacity(0.38) }
        if day.intensity < 0.7 { return Color.orange.opacity(0.6) }
        return Color.orange.opacity(0.9)
    }
}
