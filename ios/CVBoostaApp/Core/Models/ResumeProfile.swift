import Foundation
import SwiftData

@Model
final class ResumeProfile {
    @Attribute(.unique) var id: UUID
    var targetRole: String
    var atsScore: Int
    var keywordCoverage: Double
    var measurableImpactRatio: Double
    var lastAnalyzedAt: Date

    init(
        id: UUID = UUID(),
        targetRole: String,
        atsScore: Int = 58,
        keywordCoverage: Double = 0.46,
        measurableImpactRatio: Double = 0.39,
        lastAnalyzedAt: Date = .now
    ) {
        self.id = id
        self.targetRole = targetRole
        self.atsScore = atsScore
        self.keywordCoverage = keywordCoverage
        self.measurableImpactRatio = measurableImpactRatio
        self.lastAnalyzedAt = lastAnalyzedAt
    }
}
