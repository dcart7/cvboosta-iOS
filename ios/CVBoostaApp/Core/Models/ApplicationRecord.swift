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

    init(
        id: UUID = UUID(),
        company: String,
        role: String,
        status: ApplicationStatus = .applied,
        appliedAt: Date = .now,
        source: String = "LinkedIn"
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.status = status
        self.appliedAt = appliedAt
        self.source = source
    }
}
