import Foundation
import SwiftData

enum ApplicationStatus: String, Codable, CaseIterable {
    case saved
    case applied
    case interview
    case offer
    case rejected
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
    var atsScore: Int?

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
        atsScore: Int? = nil
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
        self.atsScore = atsScore
    }
}
