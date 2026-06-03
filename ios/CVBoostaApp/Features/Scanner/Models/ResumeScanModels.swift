import Foundation

struct ResumeScanResponse: Codable, Hashable {
    /// Baseline match/ATS score (0-100).
    let atsScore: Int
    let matchBefore: Int?
    let matchAfter: Int?

    /// Missing skills/keywords extracted by the backend.
    let missingSkills: [String]
    let addedKeywords: [String]

    /// Backend-provided action list (keep UI lightweight; no client-side logic).
    let recommendations: [String]

    /// ATS-optimized resume produced by the backend.
    let optimizedCV: String
    let feedback: String

    /// Parsed original CV text (from `/analyze/upload`) so iPad Tailoring can show side-by-side.
    let originalCVText: String
    let jobText: String

    /// Optional backend history identifier (used for cover letter generation, history, etc.).
    let analysisID: Int?

    enum CodingKeys: String, CodingKey {
        case atsScore = "ats_score"
        case matchBefore = "match_before"
        case matchAfter = "match_after"
        case missingSkills = "missing_skills"
        case addedKeywords = "added_keywords"
        case recommendations
        case optimizedCV = "optimized_cv"
        case feedback
        case originalCVText = "original_cv_text"
        case jobText = "job_text"
        case analysisID = "analysis_id"
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
