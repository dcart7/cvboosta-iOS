import Foundation
import SwiftData

@Model
final class SavedTailoringSuggestion {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var resumeName: String
    var roleTitle: String
    var text: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        resumeName: String,
        roleTitle: String,
        text: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.resumeName = resumeName
        self.roleTitle = roleTitle
        self.text = text
    }
}

