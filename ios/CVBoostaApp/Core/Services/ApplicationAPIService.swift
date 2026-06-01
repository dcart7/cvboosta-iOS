import Foundation

enum TrackerStatus: String, CaseIterable, Codable {
    case saved = "saved"
    case applied = "applied"
    case interview = "interview"
    case offer = "offer"
    case rejected = "rejected"

    var title: String {
        rawValue.capitalized
    }
}

struct JobApplication: Codable, Identifiable {
    let id: UUID
    let company: String
    let role: String
    let status: String
    let source: String?
    let appliedAt: Date
    let interviewAt: Date?
    let notes: String?
    let resumeUsed: String?
    let jobLink: String?
    let atsScore: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case role
        case status
        case source
        case appliedAt = "applied_at"
        case interviewAt = "interview_at"
        case notes
        case resumeUsed = "resume_used"
        case jobLink = "job_link"
        case atsScore = "ats_score"
    }
}

struct CreateApplicationRequest: Encodable {
    let company: String
    let role: String
    let status: String
    let source: String?
    let appliedAt: Date
    let interviewAt: Date?
    let notes: String?
    let resumeUsed: String?
    let jobLink: String?

    enum CodingKeys: String, CodingKey {
        case company
        case role
        case status
        case source
        case appliedAt = "applied_at"
        case interviewAt = "interview_at"
        case notes
        case resumeUsed = "resume_used"
        case jobLink = "job_link"
    }
}

struct UpdateApplicationRequest: Encodable {
    let company: String?
    let role: String?
    let status: String?
    let source: String?
    let appliedAt: Date?
    let interviewAt: Date?
    let notes: String?
    let resumeUsed: String?
    let jobLink: String?

    enum CodingKeys: String, CodingKey {
        case company
        case role
        case status
        case source
        case appliedAt = "applied_at"
        case interviewAt = "interview_at"
        case notes
        case resumeUsed = "resume_used"
        case jobLink = "job_link"
    }
}

final class ApplicationAPIService {
    static let shared = ApplicationAPIService()

    private let client: AuthenticatedAPIClient

    init(client: AuthenticatedAPIClient = .shared) {
        self.client = client
    }

    func fetchApplications() async throws -> [JobApplication] {
        try await client.getJSON(path: "/applications")
    }

    func createApplication(_ request: CreateApplicationRequest) async throws -> JobApplication {
        try await client.postJSON(path: "/applications", body: request)
    }

    func updateApplication(id: UUID, payload: UpdateApplicationRequest) async throws -> JobApplication {
        try await client.patchJSON(path: "/applications/\(id.uuidString)", body: payload)
    }

    func deleteApplication(id: UUID) async throws {
        try await client.delete(path: "/applications/\(id.uuidString)")
    }
}
