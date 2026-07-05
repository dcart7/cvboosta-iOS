import Foundation
import SwiftData

enum ApplicationStatus: String, Codable, CaseIterable {
    case saved
    case applied
    case interview
    case offer
    case rejected
    case archived

    static var userSelectableCases: [ApplicationStatus] {
        [.saved, .applied, .interview, .offer, .rejected]
    }

    var isArchiveBucket: Bool {
        self == .rejected || self == .archived
    }
}

@Model
final class ApplicationFolder {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "\u{1F5C2}"
    var isAccountBacked: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🗂",
        isAccountBacked: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.isAccountBacked = isAccountBacked
        self.createdAt = createdAt
    }
}

@Model
final class ApplicationRecord {
    var id: UUID = UUID()
    var company: String = ""
    var role: String = ""
    var statusRawValue: String = ApplicationStatus.applied.rawValue
    var appliedAt: Date = Date()
    var source: String = "LinkedIn"
    var interviewAt: Date?
    var notes: String?
    var resumeUsed: String?
    var jobLink: String?
    var folderID: UUID?
    var atsScore: Int?
    var interviewReflectionRating: Int?
    var interviewReflectionOutcome: String?
    var interviewReflectionNotes: String?
    var interviewReflectionSubmittedAt: Date?
    var isAccountBacked: Bool = false

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRawValue) ?? .applied }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        company: String,
        role: String,
        status: ApplicationStatus = .applied,
        appliedAt: Date = .now,
        source: String = "LinkedIn",
        interviewAt: Date? = nil,
        notes: String? = nil,
        resumeUsed: String? = nil,
        jobLink: String? = nil,
        folderID: UUID? = nil,
        atsScore: Int? = nil,
        interviewReflectionRating: Int? = nil,
        interviewReflectionOutcome: String? = nil,
        interviewReflectionNotes: String? = nil,
        interviewReflectionSubmittedAt: Date? = nil,
        isAccountBacked: Bool = false
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.statusRawValue = status.rawValue
        self.appliedAt = appliedAt
        self.source = source
        self.interviewAt = interviewAt
        self.notes = notes
        self.resumeUsed = resumeUsed
        self.jobLink = jobLink
        self.folderID = folderID
        self.atsScore = atsScore
        self.interviewReflectionRating = interviewReflectionRating
        self.interviewReflectionOutcome = interviewReflectionOutcome
        self.interviewReflectionNotes = interviewReflectionNotes
        self.interviewReflectionSubmittedAt = interviewReflectionSubmittedAt
        self.isAccountBacked = isAccountBacked
    }
}
