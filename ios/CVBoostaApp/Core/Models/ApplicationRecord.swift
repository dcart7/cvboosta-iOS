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
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🗂",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

@Model
final class ApplicationRecord {
    @Attribute(.unique) var id: UUID
    var company: String
    var role: String
    var status: ApplicationStatus
    var appliedAt: Date
    var source: String
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
        interviewReflectionSubmittedAt: Date? = nil
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.status = status
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
    }
}
