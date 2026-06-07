import Foundation

struct CVBoostaWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var firstName: String?
    var currentATSScore: Int
    var weeklyATSDelta: Int
    var streakDays: Int
    var streakStatusTitle: String
    var streakStatusDetail: String
    var weeklyActiveDays: Int
    var careerLevel: String
    var nextMilestoneTitle: String
    var applicationsCount: Int
    var interviewsCount: Int
    var offersCount: Int
    var responseRate: Int
    var dailyFocusTitle: String
    var dailyFocusDetail: String
    var momentumTitle: String
    var momentumDetail: String
    var strongestArea: String
    var weakestArea: String
    var missingKeywords: [String]
    var recentRole: String?
    var recentCompany: String?
    var recentScanDate: Date?
    var nextInterviewTitle: String?
    var nextInterviewDate: Date?
    var nextInterviewCompany: String?

    static let placeholder = CVBoostaWidgetSnapshot(
        updatedAt: .now,
        firstName: "Denys",
        currentATSScore: 82,
        weeklyATSDelta: 6,
        streakDays: 5,
        streakStatusTitle: "Streak protected",
        streakStatusDetail: "Your future recruiter would approve.",
        weeklyActiveDays: 5,
        careerLevel: "Recruiter-visible",
        nextMilestoneTitle: "7 day milestone",
        applicationsCount: 24,
        interviewsCount: 3,
        offersCount: 1,
        responseRate: 18,
        dailyFocusTitle: "Today's Focus",
        dailyFocusDetail: "Fix 3 ATS keyword gaps for Backend Engineer roles.",
        momentumTitle: "Career Momentum",
        momentumDetail: "ATS +6 this week. Response rate is trending up.",
        strongestArea: "Formatting",
        weakestArea: "Quantified impact",
        missingKeywords: ["Kubernetes", "Redis", "CI/CD"],
        recentRole: "Backend Engineer",
        recentCompany: "Stripe",
        recentScanDate: .now.addingTimeInterval(-7200),
        nextInterviewTitle: "Stripe Interview",
        nextInterviewDate: .now.addingTimeInterval(60 * 60 * 24),
        nextInterviewCompany: "Stripe"
    )

    static let empty = CVBoostaWidgetSnapshot(
        updatedAt: .now,
        firstName: nil,
        currentATSScore: 0,
        weeklyATSDelta: 0,
        streakDays: 0,
        streakStatusTitle: "Start your streak",
        streakStatusDetail: "One useful career action starts momentum.",
        weeklyActiveDays: 0,
        careerLevel: "Starting",
        nextMilestoneTitle: "3 day milestone",
        applicationsCount: 0,
        interviewsCount: 0,
        offersCount: 0,
        responseRate: 0,
        dailyFocusTitle: "Today's Focus",
        dailyFocusDetail: "Run your first ATS scan to unlock live career insights.",
        momentumTitle: "Career Momentum",
        momentumDetail: "Start with one scan and one tailored application.",
        strongestArea: "—",
        weakestArea: "—",
        missingKeywords: [],
        recentRole: nil,
        recentCompany: nil,
        recentScanDate: nil,
        nextInterviewTitle: nil,
        nextInterviewDate: nil,
        nextInterviewCompany: nil
    )
}

enum CVBoostaWidgetStore {
    static let appGroupID = "group.com.cvboosta.shared"
    static let snapshotKey = "cvboosta.widget.snapshot"

    static func loadSnapshot() -> CVBoostaWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(CVBoostaWidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    static func saveSnapshot(_ snapshot: CVBoostaWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func clear() {
        UserDefaults(suiteName: appGroupID)?.removeObject(forKey: snapshotKey)
    }
}
