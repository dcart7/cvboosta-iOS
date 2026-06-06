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
        let streak = streakDays(from: scans)

        cachedSnapshot.updatedAt = .now
        cachedSnapshot.firstName = displayName(from: snapshot.user)
        cachedSnapshot.currentATSScore = currentScore
        cachedSnapshot.weeklyATSDelta = weeklyDelta
        cachedSnapshot.streakDays = streak
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
        cachedSnapshot.dailyFocusDetail = currentScore == 0
            ? "Run your first ATS scan to unlock personalized career guidance."
            : "Tailor for \(roleText) and improve recruiter-facing impact bullets."

        cachedSnapshot.momentumTitle = "Career Momentum"
        cachedSnapshot.momentumDetail = momentumDetail(score: currentScore, delta: weeklyDelta, streak: streak)

        persist()
    }

    func mergeLatestScan(result: ResumeScanResult) {
        cachedSnapshot.updatedAt = .now
        cachedSnapshot.currentATSScore = result.response.matchAfter ?? result.response.atsScore
        cachedSnapshot.weeklyATSDelta = max((result.response.matchAfter ?? result.response.atsScore) - (result.response.matchBefore ?? result.response.atsScore), 0)
        cachedSnapshot.missingKeywords = Array(result.response.missingSkills.prefix(3))
        cachedSnapshot.recentRole = result.targetRole
        cachedSnapshot.recentCompany = nil
        cachedSnapshot.recentScanDate = .now
        cachedSnapshot.dailyFocusTitle = "Today's Focus"
        cachedSnapshot.dailyFocusDetail = result.response.missingSkills.isEmpty
            ? "Your resume is in a healthy spot. Start applying while momentum is high."
            : "Fix \(min(result.response.missingSkills.count, 3)) ATS keyword gaps for \(result.targetRole)."
        cachedSnapshot.momentumTitle = "Career Momentum"
        cachedSnapshot.momentumDetail = "Latest ATS run finished at \(result.response.matchAfter ?? result.response.atsScore)/100."
        persist()
    }

    func mergeLocalApplications(_ applications: [ApplicationRecord]) {
        cachedSnapshot.updatedAt = .now
        cachedSnapshot.applicationsCount = applications.count
        cachedSnapshot.interviewsCount = applications.filter { $0.status == .interview }.count
        cachedSnapshot.offersCount = applications.filter { $0.status == .offer }.count
        cachedSnapshot.responseRate = applications.isEmpty ? 0 : Int((Double(cachedSnapshot.interviewsCount + cachedSnapshot.offersCount) / Double(applications.count)) * 100)

        if let nextInterview = applications
            .filter({ $0.status == .interview && $0.interviewAt != nil })
            .sorted(by: { ($0.interviewAt ?? .distantFuture) < ($1.interviewAt ?? .distantFuture) })
            .first {
            cachedSnapshot.nextInterviewTitle = "\(nextInterview.company) Interview"
            cachedSnapshot.nextInterviewDate = nextInterview.interviewAt
        } else {
            cachedSnapshot.nextInterviewTitle = nil
            cachedSnapshot.nextInterviewDate = nil
        }

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

    private func streakDays(from scans: [ScanHistorySnapshot]) -> Int {
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
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
