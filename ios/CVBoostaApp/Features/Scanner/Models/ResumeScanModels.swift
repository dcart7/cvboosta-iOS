import Foundation

struct ATSFinding: Codable, Hashable, Identifiable {
    let category: String
    let severity: Int
    let message: String
    let suggestion: String

    var id: String { "\(category)-\(message)" }
}

struct ResumeScanRequest: Encodable {
    let resumeText: String
    let targetRole: String

    enum CodingKeys: String, CodingKey {
        case resumeText = "resume_text"
        case targetRole = "target_role"
    }
}

struct ResumeScanResponse: Codable, Hashable {
    let atsScore: Int
    let keywordCoverage: Double
    let measurableImpactRatio: Double
    let readabilityScore: Double
    let recruiterSignalScore: Double
    let keywordGaps: [String]
    let priorityFixes: [String]
    let weakBulletExamples: [String]
    let rewriteSuggestions: [String]
    let findings: [ATSFinding]

    enum CodingKeys: String, CodingKey {
        case atsScore = "ats_score"
        case keywordCoverage = "keyword_coverage"
        case measurableImpactRatio = "measurable_impact_ratio"
        case readabilityScore = "readability_score"
        case recruiterSignalScore = "recruiter_signal_score"
        case keywordGaps = "keyword_gaps"
        case priorityFixes = "priority_fixes"
        case weakBulletExamples = "weak_bullet_examples"
        case rewriteSuggestions = "rewrite_suggestions"
        case findings
    }
}

struct ResumeScanResult: Hashable {
    let response: ResumeScanResponse
    let isDemo: Bool
    let resumeName: String
    let targetRole: String
    let experienceLevel: String
    let targetMarket: String
}

struct RewriteRequest: Encodable {
    let targetRole: String
    let bullets: [String]

    enum CodingKeys: String, CodingKey {
        case targetRole = "target_role"
        case bullets
    }
}

struct RewriteResponse: Codable, Hashable {
    let rewrittenBullets: [String]

    enum CodingKeys: String, CodingKey {
        case rewrittenBullets = "rewritten_bullets"
    }
}
