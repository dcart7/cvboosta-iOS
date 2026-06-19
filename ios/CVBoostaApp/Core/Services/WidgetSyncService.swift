import Foundation
import WidgetKit

@MainActor
final class WidgetSyncService {
    static let shared = WidgetSyncService()

    private var cachedSnapshot: CVBoostaWidgetSnapshot = CVBoostaWidgetStore.loadSnapshot()

    private init() {}

    func applyAuthenticatedSnapshot(_ snapshot: AuthMePayload) {
        let scans = snapshot.scanHistory.sorted(by: { $0.createdAt < $1.createdAt })
        let currentScore = scans.last?.matchAfter ?? scans.last?.atsScore ?? 0
        let weeklyDelta = weeklyDelta(from: scans)
        let accountBackedApplications = snapshot.applications.map {
            ApplicationRecord(
                id: $0.id,
                company: $0.company,
                role: $0.role,
                status: ApplicationStatus(rawValue: $0.status.lowercased()) ?? .applied,
                appliedAt: $0.appliedAt,
                source: $0.source ?? "Account",
                interviewAt: $0.interviewAt
            )
        }
        let streakSummary = StreakEngine.build(
            now: .now,
            user: snapshot.user,
            scans: scans,
            applications: accountBackedApplications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )

        cachedSnapshot.updatedAt = .now
        cachedSnapshot.firstName = displayName(from: snapshot.user)
        cachedSnapshot.currentATSScore = currentScore
        cachedSnapshot.weeklyATSDelta = weeklyDelta
        cachedSnapshot.streakDays = streakSummary.currentStreak
        cachedSnapshot.streakStatusTitle = streakSummary.statusTitle
        cachedSnapshot.streakStatusDetail = streakSummary.microcopy
        cachedSnapshot.weeklyActiveDays = streakSummary.weeklyActiveDays
        cachedSnapshot.careerLevel = streakSummary.careerLevel
        cachedSnapshot.nextMilestoneTitle = streakSummary.milestones.first(where: { !$0.isReached })?.title ?? "Elite"
        cachedSnapshot.applicationsCount = snapshot.applications.count
        cachedSnapshot.interviewsCount = snapshot.applications.filter { $0.status.lowercased() == "interview" }.count
        cachedSnapshot.offersCount = snapshot.applications.filter { $0.status.lowercased() == "offer" }.count
        cachedSnapshot.responseRate = cachedSnapshot.applicationsCount == 0 ? 0 : Int((Double(cachedSnapshot.interviewsCount + cachedSnapshot.offersCount) / Double(cachedSnapshot.applicationsCount)) * 100)
        cachedSnapshot.recentRole = scans.last?.targetRole.nilIfEmpty
        cachedSnapshot.recentCompany = scans.last?.company?.nilIfEmpty
        cachedSnapshot.recentScanDate = scans.last?.createdAt

        if currentScore >= 85 {
            cachedSnapshot.strongestArea = "Keyword match"
            cachedSnapshot.weakestArea = "Leadership signals"
        } else if currentScore >= 70 {
            cachedSnapshot.strongestArea = "Formatting"
            cachedSnapshot.weakestArea = "Quantified impact"
        } else {
            cachedSnapshot.strongestArea = "Readability"
            cachedSnapshot.weakestArea = "ATS alignment"
        }

        let roleText = scans.last?.targetRole.nilIfEmpty ?? "your target roles"
        cachedSnapshot.dailyFocusTitle = "Today's Focus"
        cachedSnapshot.dailyFocusDetail = streakSummary.todayActions.first?.detail
            ?? (currentScore == 0
            ? "Run your first ATS scan to unlock personalized career guidance."
            : "Tailor for \(roleText) and improve recruiter-facing impact bullets.")

        cachedSnapshot.momentumTitle = "Career Momentum"
        cachedSnapshot.momentumDetail = momentumDetail(score: currentScore, delta: weeklyDelta, streak: streakSummary.currentStreak)

        if let nextInterview = snapshot.applications
            .filter({ $0.status.lowercased() == "interview" && ($0.interviewAt ?? .distantPast) > .now })
            .sorted(by: { ($0.interviewAt ?? .distantFuture) < ($1.interviewAt ?? .distantFuture) })
            .first {
            cachedSnapshot.nextInterviewTitle = "\(nextInterview.company) Interview"
            cachedSnapshot.nextInterviewDate = nextInterview.interviewAt
            cachedSnapshot.nextInterviewCompany = nextInterview.company
        } else {
            cachedSnapshot.nextInterviewTitle = nil
            cachedSnapshot.nextInterviewDate = nil
            cachedSnapshot.nextInterviewCompany = nil
        }

        persist()
    }

    func mergeLatestScan(result: ResumeScanResult) {
        let predictedStreak = streakDaysAfterToday(existing: cachedSnapshot.streakDays, recentScanDate: cachedSnapshot.recentScanDate)
        cachedSnapshot.updatedAt = .now
        cachedSnapshot.currentATSScore = result.response.matchAfter ?? result.response.atsScore
        cachedSnapshot.weeklyATSDelta = max((result.response.matchAfter ?? result.response.atsScore) - (result.response.matchBefore ?? result.response.atsScore), 0)
        cachedSnapshot.missingKeywords = Array(result.response.missingSkills.prefix(3))
        cachedSnapshot.recentRole = result.targetRole
        cachedSnapshot.recentCompany = nil
        cachedSnapshot.recentScanDate = .now
        cachedSnapshot.streakDays = predictedStreak
        cachedSnapshot.weeklyActiveDays = max(cachedSnapshot.weeklyActiveDays, min(predictedStreak, 7))
        cachedSnapshot.streakStatusTitle = "Streak protected 🔥"
        cachedSnapshot.streakStatusDetail = "Small improvements. Bigger interview chances."
        cachedSnapshot.dailyFocusTitle = "Today's Focus"
        cachedSnapshot.dailyFocusDetail = result.response.missingSkills.isEmpty
            ? "Your resume is in a healthy spot. Start applying while momentum is high."
            : "Fix \(min(result.response.missingSkills.count, 3)) ATS keyword gaps for \(result.targetRole)."
        cachedSnapshot.momentumTitle = "Career Momentum"
        cachedSnapshot.momentumDetail = "Latest ATS run finished at \(result.response.matchAfter ?? result.response.atsScore)/100."
        persist()
    }

    func syncAfterLatestScan(
        result: ResumeScanResult,
        user: AuthUser?,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord]
    ) {
        let now = Date()
        let projectedScans = projectedScans(afterMerging: result, into: scans, now: now)
        let currentScore = projectedScans.last?.matchAfter ?? projectedScans.last?.atsScore ?? (result.response.matchAfter ?? result.response.atsScore)
        let streakSummary = StreakEngine.build(
            now: now,
            user: user,
            scans: projectedScans,
            applications: applications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )

        cachedSnapshot.updatedAt = now
        if let user {
            cachedSnapshot.firstName = displayName(from: user)
        }
        cachedSnapshot.currentATSScore = currentScore
        cachedSnapshot.weeklyATSDelta = weeklyDelta(from: projectedScans)
        cachedSnapshot.streakDays = streakSummary.currentStreak
        cachedSnapshot.streakStatusTitle = streakSummary.statusTitle
        cachedSnapshot.streakStatusDetail = streakSummary.microcopy
        cachedSnapshot.weeklyActiveDays = streakSummary.weeklyActiveDays
        cachedSnapshot.careerLevel = streakSummary.careerLevel
        cachedSnapshot.nextMilestoneTitle = streakSummary.milestones.first(where: { !$0.isReached })?.title ?? "Elite"
        cachedSnapshot.applicationsCount = applications.count
        cachedSnapshot.interviewsCount = applications.filter { $0.status == .interview }.count
        cachedSnapshot.offersCount = applications.filter { $0.status == .offer }.count
        cachedSnapshot.responseRate = applications.isEmpty ? 0 : Int((Double(cachedSnapshot.interviewsCount + cachedSnapshot.offersCount) / Double(applications.count)) * 100)
        cachedSnapshot.missingKeywords = Array(result.response.missingSkills.prefix(3))
        cachedSnapshot.recentRole = result.targetRole.nilIfEmpty
        cachedSnapshot.recentCompany = nil
        cachedSnapshot.recentScanDate = now
        cachedSnapshot.dailyFocusTitle = "Today's Focus"
        cachedSnapshot.dailyFocusDetail = streakSummary.todayActions.first?.detail
            ?? (result.response.missingSkills.isEmpty
            ? "Your resume is in a healthy spot. Start applying while momentum is high."
            : "Fix \(min(result.response.missingSkills.count, 3)) ATS keyword gaps for \(result.targetRole).")
        cachedSnapshot.momentumTitle = "Career Momentum"
        cachedSnapshot.momentumDetail = momentumDetail(
            score: currentScore,
            delta: cachedSnapshot.weeklyATSDelta,
            streak: streakSummary.currentStreak
        )

        if let nextInterview = applications
            .filter({ $0.status == .interview && ($0.interviewAt ?? .distantPast) > now })
            .sorted(by: { ($0.interviewAt ?? .distantFuture) < ($1.interviewAt ?? .distantFuture) })
            .first {
            cachedSnapshot.nextInterviewTitle = "\(nextInterview.company) Interview"
            cachedSnapshot.nextInterviewDate = nextInterview.interviewAt
            cachedSnapshot.nextInterviewCompany = nextInterview.company
        } else {
            cachedSnapshot.nextInterviewTitle = nil
            cachedSnapshot.nextInterviewDate = nil
            cachedSnapshot.nextInterviewCompany = nil
        }

        persist()
    }

    func mergeLocalApplications(_ applications: [ApplicationRecord]) {
        let streakSummary = StreakEngine.build(
            now: .now,
            user: nil,
            scans: [],
            applications: applications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )
        cachedSnapshot.updatedAt = .now
        cachedSnapshot.applicationsCount = applications.count
        cachedSnapshot.interviewsCount = applications.filter { $0.status == .interview }.count
        cachedSnapshot.offersCount = applications.filter { $0.status == .offer }.count
        cachedSnapshot.responseRate = applications.isEmpty ? 0 : Int((Double(cachedSnapshot.interviewsCount + cachedSnapshot.offersCount) / Double(applications.count)) * 100)
        cachedSnapshot.streakDays = streakSummary.currentStreak
        cachedSnapshot.streakStatusTitle = streakSummary.statusTitle
        cachedSnapshot.streakStatusDetail = streakSummary.microcopy
        cachedSnapshot.weeklyActiveDays = streakSummary.weeklyActiveDays
        cachedSnapshot.careerLevel = streakSummary.careerLevel
        cachedSnapshot.nextMilestoneTitle = streakSummary.milestones.first(where: { !$0.isReached })?.title ?? cachedSnapshot.nextMilestoneTitle

        if let nextInterview = applications
            .filter({ $0.status == .interview && ($0.interviewAt ?? .distantPast) > .now })
            .sorted(by: { ($0.interviewAt ?? .distantFuture) < ($1.interviewAt ?? .distantFuture) })
            .first {
            cachedSnapshot.nextInterviewTitle = "\(nextInterview.company) Interview"
            cachedSnapshot.nextInterviewDate = nextInterview.interviewAt
            cachedSnapshot.nextInterviewCompany = nextInterview.company
        } else {
            cachedSnapshot.nextInterviewTitle = nil
            cachedSnapshot.nextInterviewDate = nil
            cachedSnapshot.nextInterviewCompany = nil
        }

        persist()
    }

    func syncStreakState(
        user: AuthUser?,
        scans: [ScanHistorySnapshot],
        applications: [ApplicationRecord]
    ) {
        let streakSummary = StreakEngine.build(
            now: .now,
            user: user,
            scans: scans,
            applications: applications,
            manuallyProtectedDayStamps: SharedStreakState.protectedDayStamps()
        )

        cachedSnapshot.updatedAt = .now
        cachedSnapshot.streakDays = streakSummary.currentStreak
        cachedSnapshot.streakStatusTitle = streakSummary.statusTitle
        cachedSnapshot.streakStatusDetail = streakSummary.microcopy
        cachedSnapshot.weeklyActiveDays = streakSummary.weeklyActiveDays
        cachedSnapshot.careerLevel = streakSummary.careerLevel
        cachedSnapshot.nextMilestoneTitle = streakSummary.milestones.first(where: { !$0.isReached })?.title ?? "Elite"
        persist()
    }

    func clear() {
        cachedSnapshot = .empty
        CVBoostaWidgetStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persist() {
        CVBoostaWidgetStore.saveSnapshot(cachedSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func weeklyDelta(from scans: [ScanHistorySnapshot]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekly = scans.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear) }
        guard let first = weekly.first, let last = weekly.last else { return 0 }
        return (last.matchAfter ?? last.atsScore) - (first.matchAfter ?? first.atsScore)
    }

    private func displayName(from user: AuthUser) -> String? {
        if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName.split(separator: " ").first.map(String.init)
        }
        return user.email.split(separator: "@").first.map(String.init)
    }

    private func momentumDetail(score: Int, delta: Int, streak: Int) -> String {
        if score == 0 {
            return "Start with one scan and one tailored application."
        }
        if delta > 0 {
            return "ATS +\(delta) this week and a \(streak == 0 ? "fresh" : "\(streak)-day") streak."
        }
        if streak > 0 {
            return "Consistency is holding with a \(streak)-day streak."
        }
        return "Resume health is stable. One more optimization can move it up."
    }

    private func streakDaysAfterToday(existing: Int, recentScanDate: Date?) -> Int {
        if let recentScanDate, Calendar.current.isDateInToday(recentScanDate) {
            return existing
        }
        return max(existing, 0) + 1
    }

    private func projectedScans(afterMerging result: ResumeScanResult, into scans: [ScanHistorySnapshot], now: Date) -> [ScanHistorySnapshot] {
        var projected = scans.sorted(by: { $0.createdAt < $1.createdAt })
        let projectedScan = ScanHistorySnapshot(
            id: result.response.analysisID ?? syntheticScanID(from: now),
            resumeFileName: result.resumeName,
            targetRole: result.targetRole,
            atsScore: result.response.atsScore,
            createdAt: now,
            matchBefore: result.response.matchBefore,
            matchAfter: result.response.matchAfter,
            company: nil
        )
        projected.append(projectedScan)
        return projected
    }

    private func syntheticScanID(from date: Date) -> Int {
        -max(Int(date.timeIntervalSince1970), 1)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
