import Foundation

struct AuthUser: Codable, Hashable {
    let id: UUID
    let email: String?
    let displayName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

struct AuthSubscription: Codable, Hashable {
    let entitlement: String?
    let isActive: Bool
    let expiresAt: Date?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case entitlement
        case isActive = "is_active"
        case expiresAt = "expires_at"
        case source
    }
}

struct AuthUsageLimits: Codable, Hashable {
    let plan: String
    let scansDailyLimit: Int?
    let scansUsedToday: Int
    let scansRemainingToday: Int?

    enum CodingKeys: String, CodingKey {
        case plan
        case scansDailyLimit = "scans_daily_limit"
        case scansUsedToday = "scans_used_today"
        case scansRemainingToday = "scans_remaining_today"
    }
}

struct SavedResumeSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let fileName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case createdAt = "created_at"
    }
}

struct ScanHistorySnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let resumeID: UUID
    let resumeFileName: String
    let targetRole: String
    let atsScore: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case resumeID = "resume_id"
        case resumeFileName = "resume_file_name"
        case targetRole = "target_role"
        case atsScore = "ats_score"
        case createdAt = "created_at"
    }
}

struct AccountApplicationSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let company: String
    let role: String
    let status: String
    let source: String?
    let appliedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case role
        case status
        case source
        case appliedAt = "applied_at"
    }
}

struct AuthMePayload: Codable, Hashable {
    let user: AuthUser
    let subscription: AuthSubscription
    let usageLimits: AuthUsageLimits
    let savedResumes: [SavedResumeSnapshot]
    let scanHistory: [ScanHistorySnapshot]
    let applications: [AccountApplicationSnapshot]

    enum CodingKeys: String, CodingKey {
        case user
        case subscription
        case usageLimits = "usage_limits"
        case savedResumes = "saved_resumes"
        case scanHistory = "scan_history"
        case applications
    }
}

struct StoredAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}

private struct AuthEnvelope: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let me: AuthMePayload

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case me
    }
}

private struct RegisterRequestPayload: Encodable {
    let email: String
    let password: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case displayName = "display_name"
    }
}

private struct LoginRequestPayload: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequestPayload: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct ForgotPasswordPayload: Encodable {
    let email: String
}

private struct ForgotPasswordResponsePayload: Decodable {
    let message: String
}

private struct LogoutRequestPayload: Encodable {
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct LogoutResponsePayload: Decodable {
    let message: String
}

actor AuthService {
    static let shared = AuthService()

    private let apiClient: APIClient
    private let keychain: KeychainService
    private let tokenStorageKey = "cvboosta.auth.tokens"

    private var cachedTokens: StoredAuthTokens?
    private var refreshTask: Task<StoredAuthTokens, Error>?

    init(apiClient: APIClient = .shared, keychain: KeychainService = .shared) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func restoreSession() async throws -> AuthMePayload? {
        guard let tokens = try loadTokens() else {
            return nil
        }

        do {
            return try await fetchMe(accessToken: tokens.accessToken)
        } catch let APIError.server(statusCode, _) where statusCode == 401 {
            do {
                _ = try await refreshTokens()
                guard let refreshed = cachedTokens else {
                    return nil
                }
                return try await fetchMe(accessToken: refreshed.accessToken)
            } catch {
                try clearStoredTokens()
                return nil
            }
        }
    }

    func register(email: String, password: String, displayName: String?) async throws -> AuthMePayload {
        let payload = RegisterRequestPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let response: AuthEnvelope = try await apiClient.postJSON(path: "/auth/register", body: payload)
        try saveTokens(from: response)
        return response.me
    }

    func login(email: String, password: String) async throws -> AuthMePayload {
        let payload = LoginRequestPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        let response: AuthEnvelope = try await apiClient.postJSON(path: "/auth/login", body: payload)
        try saveTokens(from: response)
        return response.me
    }

    func forgotPassword(email: String) async throws -> String {
        let payload = ForgotPasswordPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
        let response: ForgotPasswordResponsePayload = try await apiClient.postJSON(
            path: "/auth/forgot-password",
            body: payload
        )
        return response.message
    }

    func fetchCurrentUserState() async throws -> AuthMePayload {
        guard let tokens = try loadTokens() else {
            throw APIError.server(statusCode: 401, message: "Not authenticated.")
        }

        do {
            return try await fetchMe(accessToken: tokens.accessToken)
        } catch let APIError.server(statusCode, _) where statusCode == 401 {
            let newAccess = try await refreshAccessToken()
            return try await fetchMe(accessToken: newAccess)
        }
    }

    func currentAccessToken() throws -> String {
        guard let tokens = try loadTokens() else {
            throw APIError.server(statusCode: 401, message: "Not authenticated.")
        }
        return tokens.accessToken
    }

    func refreshAccessToken() async throws -> String {
        let tokens = try await refreshTokens()
        return tokens.accessToken
    }

    func logout() async {
        do {
            if let tokens = try loadTokens() {
                let _: LogoutResponsePayload = try await apiClient.postJSON(
                    path: "/auth/logout",
                    body: LogoutRequestPayload(refreshToken: tokens.refreshToken),
                    headers: ["Authorization": "Bearer \(tokens.accessToken)"]
                )
            }
        } catch {
            // Best effort remote logout.
        }

        do {
            try clearStoredTokens()
        } catch {
            // Local cleanup should not crash app.
        }
    }

    func clearSession() {
        do {
            try clearStoredTokens()
        } catch {
            // Ignore cleanup failures.
        }
    }

    private func fetchMe(accessToken: String) async throws -> AuthMePayload {
        try await apiClient.getJSON(
            path: "/auth/me",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
    }

    private func refreshTokens() async throws -> StoredAuthTokens {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<StoredAuthTokens, Error> {
            guard let existing = try loadTokens() else {
                throw APIError.server(statusCode: 401, message: "No refresh token.")
            }
            let response: AuthEnvelope = try await apiClient.postJSON(
                path: "/auth/refresh",
                body: RefreshRequestPayload(refreshToken: existing.refreshToken)
            )
            try saveTokens(from: response)
            guard let latest = cachedTokens else {
                throw APIError.invalidResponse
            }
            return latest
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func saveTokens(from response: AuthEnvelope) throws {
        let tokens = StoredAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn
        )
        let data = try JSONEncoder().encode(tokens)
        try keychain.set(data, for: tokenStorageKey)
        cachedTokens = tokens
    }

    private func loadTokens() throws -> StoredAuthTokens? {
        if let cachedTokens {
            return cachedTokens
        }
        guard let data = try keychain.getData(for: tokenStorageKey) else {
            return nil
        }
        let tokens = try JSONDecoder().decode(StoredAuthTokens.self, from: data)
        cachedTokens = tokens
        return tokens
    }

    private func clearStoredTokens() throws {
        cachedTokens = nil
        try keychain.delete(tokenStorageKey)
    }
}
