import Foundation

final class TrackerSyncService {
    static let shared = TrackerSyncService()

    private let apiClient: AuthenticatedAPIClient

    init(apiClient: AuthenticatedAPIClient = .shared) {
        self.apiClient = apiClient
    }

    func createApplication(id: UUID, draft: NewApplicationDraft) async throws {
        let payload = TrackerApplicationCreatePayload(
            id: id,
            company: draft.company,
            role: draft.role,
            status: draft.status.rawValue,
            source: "iOS",
            appliedAt: draft.appliedAt,
            interviewAt: draft.interviewAt,
            notes: draft.notes,
            resumeUsed: draft.resumeUsed,
            jobLink: draft.jobLink,
            folderID: draft.folderID,
            atsScore: nil,
            interviewReflectionRating: nil,
            interviewReflectionOutcome: nil,
            interviewReflectionNotes: nil,
            interviewReflectionSubmittedAt: nil
        )

        let _: TrackerMutationResponse = try await apiClient.postJSON(path: "/tracker/applications", body: payload)
    }

    func updateApplication(id: UUID, draft: NewApplicationDraft) async throws {
        let payload = TrackerApplicationPatchPayload(
            company: draft.company,
            role: draft.role,
            status: draft.status.rawValue,
            appliedAt: draft.appliedAt,
            interviewAt: draft.interviewAt,
            notes: draft.notes,
            resumeUsed: draft.resumeUsed,
            jobLink: draft.jobLink,
            folderID: draft.folderID
        )

        let _: TrackerMutationResponse = try await apiClient.patchJSON(
            path: "/tracker/applications/\(id.uuidString)",
            body: payload
        )
    }

    func updateStatus(id: UUID, status: ApplicationStatus) async throws {
        let payload = TrackerApplicationPatchPayload(status: status.rawValue)
        let _: TrackerMutationResponse = try await apiClient.patchJSON(
            path: "/tracker/applications/\(id.uuidString)",
            body: payload
        )
    }

    func deleteApplication(id: UUID) async throws {
        try await apiClient.delete(path: "/tracker/applications/\(id.uuidString)")
    }

    func saveInterviewReflection(id: UUID, reflection: InterviewReflectionDraft) async throws {
        let payload = TrackerApplicationPatchPayload(
            interviewReflectionRating: reflection.rating,
            interviewReflectionOutcome: reflection.outcome,
            interviewReflectionNotes: reflection.notes,
            interviewReflectionSubmittedAt: .now
        )
        let _: TrackerMutationResponse = try await apiClient.patchJSON(
            path: "/tracker/applications/\(id.uuidString)",
            body: payload
        )
    }

    func assignFolder(_ folderID: UUID?, to applicationID: UUID) async throws {
        let payload = TrackerApplicationPatchPayload(folderID: folderID)
        let _: TrackerMutationResponse = try await apiClient.patchJSON(
            path: "/tracker/applications/\(applicationID.uuidString)",
            body: payload
        )
    }

    func createFolder(id: UUID, draft: FolderCreationDraft) async throws {
        let payload = TrackerFolderCreatePayload(
            id: id,
            name: draft.folder.name,
            emoji: draft.folder.emoji,
            applicationIDs: Array(draft.applicationIDs)
        )
        let _: TrackerFolderMutationResponse = try await apiClient.postJSON(path: "/tracker/folders", body: payload)
    }

    func updateFolder(id: UUID, draft: FolderDraft) async throws {
        let payload = TrackerFolderPatchPayload(name: draft.name, emoji: draft.emoji)
        let _: TrackerFolderMutationResponse = try await apiClient.patchJSON(
            path: "/tracker/folders/\(id.uuidString)",
            body: payload
        )
    }

    func deleteFolder(id: UUID) async throws {
        try await apiClient.delete(path: "/tracker/folders/\(id.uuidString)")
    }
}

private struct TrackerMutationResponse: Decodable {
    let id: UUID
}

private struct TrackerFolderMutationResponse: Decodable {
    let id: UUID
}

private struct TrackerFolderCreatePayload: Encodable {
    let id: UUID
    let name: String
    let emoji: String
    let applicationIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case applicationIDs = "application_ids"
    }
}

private struct TrackerFolderPatchPayload: Encodable {
    let name: String?
    let emoji: String?
}

private struct TrackerApplicationCreatePayload: Encodable {
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
    let folderID: UUID?
    let atsScore: Int?
    let interviewReflectionRating: Int?
    let interviewReflectionOutcome: String?
    let interviewReflectionNotes: String?
    let interviewReflectionSubmittedAt: Date?

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
        case folderID = "folder_id"
        case atsScore = "ats_score"
        case interviewReflectionRating = "interview_reflection_rating"
        case interviewReflectionOutcome = "interview_reflection_outcome"
        case interviewReflectionNotes = "interview_reflection_notes"
        case interviewReflectionSubmittedAt = "interview_reflection_submitted_at"
    }
}

private struct TrackerApplicationPatchPayload: Encodable {
    let company: String?
    let role: String?
    let status: String?
    let source: String?
    let appliedAt: Date?
    let interviewAt: Date?
    let notes: String?
    let resumeUsed: String?
    let jobLink: String?
    let folderID: UUID?
    let atsScore: Int?
    let interviewReflectionRating: Int?
    let interviewReflectionOutcome: String?
    let interviewReflectionNotes: String?
    let interviewReflectionSubmittedAt: Date?

    init(
        company: String? = nil,
        role: String? = nil,
        status: String? = nil,
        source: String? = nil,
        appliedAt: Date? = nil,
        interviewAt: Date? = nil,
        notes: String? = nil,
        resumeUsed: String? = nil,
        jobLink: String? = nil,
        folderID: UUID? = nil,
        atsScore: Int? = nil,
        interviewReflectionRating: Int? = nil,
        interviewReflectionOutcome: String? = nil,
        interviewReflectionNotes: String? = nil,
        interviewReflectionSubmittedAt: Date? = nil
    ) {
        self.company = company
        self.role = role
        self.status = status
        self.source = source
        self.appliedAt = appliedAt
        self.interviewAt = interviewAt
        self.notes = notes
        self.resumeUsed = resumeUsed
        self.jobLink = jobLink
        self.folderID = folderID
        self.atsScore = atsScore
        self.interviewReflectionRating = interviewReflectionRating
        self.interviewReflectionOutcome = interviewReflectionOutcome
        self.interviewReflectionNotes = interviewReflectionNotes
        self.interviewReflectionSubmittedAt = interviewReflectionSubmittedAt
    }

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
        case folderID = "folder_id"
        case atsScore = "ats_score"
        case interviewReflectionRating = "interview_reflection_rating"
        case interviewReflectionOutcome = "interview_reflection_outcome"
        case interviewReflectionNotes = "interview_reflection_notes"
        case interviewReflectionSubmittedAt = "interview_reflection_submitted_at"
    }
}
