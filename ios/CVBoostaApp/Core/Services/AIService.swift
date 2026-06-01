import Foundation

protocol AIService {
    func scanResumePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse
    func rewriteBullets(targetRole: String, bullets: [String]) async throws -> [String]
}
