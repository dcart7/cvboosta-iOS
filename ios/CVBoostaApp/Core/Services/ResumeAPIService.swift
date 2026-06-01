import Foundation

protocol ResumeAPIServiceProtocol {
    func scanPDF(fileURL: URL, targetRole: String) async throws -> ResumeScanResponse
}

final class ResumeAPIService: ResumeAPIServiceProtocol {
    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func scanPDF(fileURL: URL, targetRole: String) async throws -> ResumeScanResponse {
        let pdfData = try Data(contentsOf: fileURL)
        return try await client.uploadMultipart(
            path: "/v1/resume/scan-file",
            fields: ["target_role": targetRole],
            fileFieldName: "file",
            fileName: fileURL.lastPathComponent,
            mimeType: "application/pdf",
            fileData: pdfData
        )
    }
}
