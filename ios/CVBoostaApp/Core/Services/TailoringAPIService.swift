import Foundation

struct TailoringGenerateRequest: Encodable {
    let resumeId: UUID?
    let resumeText: String?
    let jobTitle: String
    let companyName: String?
    let jobDescription: String
    let tone: String

    enum CodingKeys: String, CodingKey {
        case resumeId = "resume_id"
        case resumeText = "resume_text"
        case jobTitle = "job_title"
        case companyName = "company_name"
        case jobDescription = "job_description"
        case tone
    }
}

struct TailoringGenerateResponse: Decodable {
    let tailoredSummary: String
    let bulletRewrites: [String]
    let missingKeywords: [String]
    let coverLetter: String

    enum CodingKeys: String, CodingKey {
        case tailoredSummary = "tailored_summary"
        case bulletRewrites = "bullet_rewrites"
        case missingKeywords = "missing_keywords"
        case coverLetter = "cover_letter"
    }
}

final class TailoringAPIService {
    static let shared = TailoringAPIService()

    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func generate(_ request: TailoringGenerateRequest) async throws -> TailoringGenerateResponse {
        try await client.postJSON(path: "/tailoring/generate", body: request)
    }
}
