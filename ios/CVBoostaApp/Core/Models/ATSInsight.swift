import Foundation
import SwiftData

@Model
final class ATSInsight {
    @Attribute(.unique) var id: UUID
    var category: String
    var severity: Int
    var message: String
    var suggestion: String

    init(
        id: UUID = UUID(),
        category: String,
        severity: Int,
        message: String,
        suggestion: String
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.message = message
        self.suggestion = suggestion
    }
}
