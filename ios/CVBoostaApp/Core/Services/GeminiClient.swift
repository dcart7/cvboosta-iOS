import Foundation

/// Client-side AI facade for CVBoosta.
/// The backend is the single Gemini integration point.
final class GeminiClient: AIService {
    private let resumeAPIService: ResumeAPIServiceProtocol
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        resumeAPIService: ResumeAPIServiceProtocol = ResumeAPIService(),
        authenticatedAPIClient: AuthenticatedAPIClient = .shared
    ) {
        self.resumeAPIService = resumeAPIService
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func scanResumePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse {
        try await resumeAPIService.scanPDF(
            fileURL: fileURL,
            targetRole: targetRole,
            jobDescription: jobDescription,
            experienceLevel: experienceLevel,
            targetMarket: targetMarket
        )
    }

    func rewriteBullets(targetRole: String, bullets: [String]) async throws -> [String] {
        let response: RewriteResponse = try await authenticatedAPIClient.postJSON(
            path: "/v1/resume/rewrite",
            body: RewriteRequest(targetRole: targetRole, bullets: bullets)
        )
        return response.rewrittenBullets
    }
}
