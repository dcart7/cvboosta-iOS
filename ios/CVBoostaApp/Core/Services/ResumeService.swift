import Foundation

struct HistoryListResponse: Decodable, Hashable {
    let items: [HistoryListItem]
}

struct HistoryListItem: Decodable, Hashable, Identifiable {
    let id: Int
    let role: String?
    let company: String?
    let score: Int
    let createdAt: Date
    let matchBefore: Int?
    let matchAfter: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case company
        case score
        case createdAt = "created_at"
        case matchBefore = "match_before"
        case matchAfter = "match_after"
    }
}

struct HistoryDetailResponse: Decodable, Hashable {
    let id: Int
    let role: String?
    let company: String?
    let score: Int
    let createdAt: Date
    let optimizedCV: String
    let jobDescription: String
    let missingSkills: [String]
    let recommendations: [String]
    let matchBefore: Int?
    let matchAfter: Int?
    let addedKeywords: [String]
    let coverLetter: String?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case company
        case score
        case createdAt = "created_at"
        case optimizedCV = "optimized_cv"
        case jobDescription = "job_description"
        case missingSkills = "missing_skills"
        case recommendations
        case matchBefore = "match_before"
        case matchAfter = "match_after"
        case addedKeywords = "added_keywords"
        case coverLetter = "cover_letter"
    }
}

final class ResumeService {
    static let shared = ResumeService()

    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func history() async throws -> [HistoryListItem] {
        let response: HistoryListResponse = try await client.getJSON(path: "/history")
        return response.items
    }

    func historyDetail(id: Int) async throws -> HistoryDetailResponse {
        try await client.getJSON(path: "/history/\(id)")
    }
}
