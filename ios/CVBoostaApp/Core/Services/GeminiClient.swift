import Foundation

/// Client-side AI facade for CVBoosta.
/// The backend is the single Gemini integration point.
final class GeminiClient: AIService {
    private let resumeAPIService: ResumeAPIServiceProtocol
    private let apiClient: APIClient

    init(resumeAPIService: ResumeAPIServiceProtocol = ResumeAPIService(), apiClient: APIClient = .shared) {
        self.resumeAPIService = resumeAPIService
        self.apiClient = apiClient
    }

    func scanResumePDF(fileURL: URL, targetRole: String) async throws -> ResumeScanResponse {
        try await resumeAPIService.scanPDF(fileURL: fileURL, targetRole: targetRole)
    }

    func rewriteBullets(targetRole: String, bullets: [String]) async throws -> [String] {
        let response: RewriteResponse = try await apiClient.postJSON(
            path: "/v1/resume/rewrite",
            body: RewriteRequest(targetRole: targetRole, bullets: bullets)
        )
        return response.rewrittenBullets
    }
}
