import Foundation

protocol ResumeAPIServiceProtocol {
    func scanPDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse
}

final class ResumeAPIService: ResumeAPIServiceProtocol {
    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func scanPDF(
        fileURL: URL,
        targetRole: String,
        jobDescription: String?,
        experienceLevel: String,
        targetMarket: String
    ) async throws -> ResumeScanResponse {
        let pdfData = try Data(contentsOf: fileURL)
        var fields: [String: String] = [
            "target_role": targetRole,
            "experience_level": experienceLevel,
            "target_market": targetMarket,
        ]
        if let jobDescription, !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["job_description"] = jobDescription
        }
        return try await client.uploadMultipart(
            path: "/resumes/scan",
            fields: fields,
            fileFieldName: "file",
            fileName: fileURL.lastPathComponent,
            mimeType: "application/pdf",
            fileData: pdfData
        )
    }
}
