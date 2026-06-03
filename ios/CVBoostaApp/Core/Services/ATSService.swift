import Foundation

/// ATS + rewrite API facade.
/// The backend is the single analysis/orchestration point.
protocol ATSServiceProtocol {
    func scanResumePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse
}

final class ATSService: ATSServiceProtocol {
    static let shared = ATSService()

    private let resumeService: ResumeAPIServiceProtocol

    init(
        resumeService: ResumeAPIServiceProtocol = ResumeAPIService()
    ) {
        self.resumeService = resumeService
    }

    func scanResumePDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse {
        try await resumeService.optimizePDF(
            fileURL: fileURL,
            targetRole: targetRole,
            jobDescription: jobDescription,
            experienceLevel: experienceLevel,
            targetMarket: targetMarket
        )
    }
}
