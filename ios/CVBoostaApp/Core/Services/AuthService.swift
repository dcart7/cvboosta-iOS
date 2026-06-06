import Foundation

// MARK: - UI-facing snapshots (aggregated from production API)

struct AuthUser: Codable, Hashable {
    let id: Int
    let email: String
    let displayName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "full_name"
        case createdAt = "created_at"
    }
}

struct AuthSubscription: Hashable {
    let entitlement: String?
    let isActive: Bool
    let expiresAt: Date?
    let source: String?
}

struct AuthUsageLimits: Hashable {
    let plan: String
    let scansDailyLimit: Int?
    let scansUsedToday: Int
    let scansRemainingToday: Int?
}

struct SavedResumeSnapshot: Hashable, Identifiable {
    let id: Int
    let fileName: String
    let createdAt: Date
}

struct ScanHistorySnapshot: Hashable, Identifiable {
    let id: Int
    let resumeFileName: String
    let targetRole: String
    let atsScore: Int
    let createdAt: Date
    let matchBefore: Int?
    let matchAfter: Int?
    let company: String?
}

struct AccountApplicationSnapshot: Hashable, Identifiable {
    let id: UUID
    let company: String
    let role: String
    let status: String
    let source: String?
    let appliedAt: Date
}

struct AuthMePayload: Hashable {
    let user: AuthUser
    let subscription: AuthSubscription
    let usageLimits: AuthUsageLimits
    let savedResumes: [SavedResumeSnapshot]
    let scanHistory: [ScanHistorySnapshot]
    let applications: [AccountApplicationSnapshot]
}

struct StoredAuthSession: Codable {
    let accessToken: String
    let tokenType: String
}

// MARK: - Production API DTOs

private struct AuthResponse: Decodable {
    let accessToken: String
    let tokenType: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case email
    }
}

private struct RegisterRequestPayload: Encodable {
    let email: String
    let password: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case fullName = "full_name"
    }
}

private struct LoginRequestPayload: Encodable {
    let email: String
    let password: String
}

private struct ForgotPasswordPayload: Encodable {
    let email: String
}

private struct HistoryResponse: Decodable {
    let items: [HistoryItem]
}

private struct HistoryItem: Decodable, Hashable, Identifiable {
    let id: Int
    let company: String?
    let role: String?
    let score: Int
    let createdAt: Date
    let matchBefore: Int?
    let matchAfter: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case role
        case score
        case createdAt = "created_at"
        case matchBefore = "match_before"
        case matchAfter = "match_after"
    }
}

actor AuthService {
    static let shared = AuthService()

    private let apiClient: APIClient
    private let keychain: KeychainService
    private let tokenStorageKey = "cvboosta.auth.tokens"

    private var cachedSession: StoredAuthSession?

    init(apiClient: APIClient = .shared, keychain: KeychainService = .shared) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func restoreSession() async throws -> AuthMePayload? {
        guard let session = try loadSession() else {
            return nil
        }

        do {
            return try await fetchCurrentSnapshot(accessToken: session.accessToken)
        } catch let APIError.server(statusCode, _) where statusCode == 401 {
            try clearStoredSession()
            return nil
        }
    }

    func register(email: String, password: String, displayName: String?) async throws -> AuthMePayload {
        let payload = RegisterRequestPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            fullName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let response: AuthResponse = try await apiClient.postJSON(path: "/auth/register", body: payload)
        try saveSession(from: response)
        return try await fetchCurrentUserState()
    }

    func login(email: String, password: String) async throws -> AuthMePayload {
        let payload = LoginRequestPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        let response: AuthResponse = try await apiClient.postJSON(path: "/auth/login", body: payload)
        try saveSession(from: response)
        return try await fetchCurrentUserState()
    }

    func forgotPassword(email: String) async throws -> String {
        let payload = ForgotPasswordPayload(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
        _ = try await apiClient.postJSON(path: "/auth/forgot-password", body: payload) as [String: JSONValue]
        return "If the email exists, password reset instructions were sent."
    }

    func fetchCurrentUserState() async throws -> AuthMePayload {
        guard let session = try loadSession() else {
            throw APIError.server(statusCode: 401, message: "Not authenticated.")
        }

        return try await fetchCurrentSnapshot(accessToken: session.accessToken)
    }

    func currentAccessToken() throws -> String {
        guard let session = try loadSession() else {
            throw APIError.server(statusCode: 401, message: "Not authenticated.")
        }
        return session.accessToken
    }

    func logout() async {
        do {
            if let session = try loadSession() {
                _ = try await apiClient.postNoBody(
                    path: "/auth/logout",
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                ) as [String: String]
            }
        } catch {
            // Best effort remote logout.
        }

        do {
            try clearStoredSession()
        } catch {
            // Local cleanup should not crash app.
        }
    }

    func clearSession() {
        do {
            try clearStoredSession()
        } catch {
            // Ignore cleanup failures.
        }
    }

    private func fetchCurrentSnapshot(accessToken: String) async throws -> AuthMePayload {
        async let userPayload: [String: JSONValue] = apiClient.getJSON(
            path: "/auth/me",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        async let history: HistoryResponse = apiClient.getJSON(
            path: "/history",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        let billingRaw: [String: JSONValue] = (try? await apiClient.getJSON(
            path: "/billing/status",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )) ?? [:]

        let subscription = Self.mapSubscription(from: billingRaw)
        let usageLimits = Self.mapUsageLimits(from: billingRaw, subscription: subscription)
        let mePayload = try await userPayload
        let user = try Self.mapUser(from: mePayload)
        let applications = Self.mapApplications(from: mePayload)

        let historyItems = try await history
        let snapshots: [ScanHistorySnapshot] = historyItems.items.sorted(by: { $0.createdAt > $1.createdAt }).map {
            ScanHistorySnapshot(
                id: $0.id,
                resumeFileName: "CV Optimization",
                targetRole: $0.role ?? "",
                atsScore: $0.matchBefore ?? $0.score,
                createdAt: $0.createdAt,
                matchBefore: $0.matchBefore,
                matchAfter: $0.matchAfter,
                company: $0.company
            )
        }

        return AuthMePayload(
            user: user,
            subscription: subscription,
            usageLimits: usageLimits,
            savedResumes: [],
            scanHistory: snapshots,
            applications: applications
        )
    }

    private func saveSession(from response: AuthResponse) throws {
        let session = StoredAuthSession(
            accessToken: response.accessToken,
            tokenType: response.tokenType ?? "bearer"
        )
        let data = try JSONEncoder().encode(session)
        try keychain.set(data, for: tokenStorageKey)
        cachedSession = session
    }

    private func loadSession() throws -> StoredAuthSession? {
        if let cachedSession {
            return cachedSession
        }
        guard let data = try keychain.getData(for: tokenStorageKey) else {
            return nil
        }
        if let session = try? JSONDecoder().decode(StoredAuthSession.self, from: data) {
            cachedSession = session
            return session
        }
        // Backward compatibility: if old token shape is stored, force re-login.
        try clearStoredSession()
        return nil
    }

    private func clearStoredSession() throws {
        cachedSession = nil
        try keychain.delete(tokenStorageKey)
    }
}

private extension AuthService {
    struct AuthPayloadParseError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func mapSubscription(from payload: [String: JSONValue]) -> AuthSubscription {
        let isActive: Bool
        if let direct = payload.bool("is_active") ?? payload.bool("active") {
            isActive = direct
        } else {
            isActive = payload.string("status")?.lowercased() == "active"
        }

        let entitlement =
            payload.string("entitlement")
            ?? payload.string("plan")
            ?? payload.string("tier")
            ?? (isActive ? "premium" : "free")

        let expiresAt = parseDate(
            payload.string("expires_at")
                ?? payload.string("current_period_end")
                ?? payload.string("renewal_at")
        )

        let source = payload.string("source") ?? "stripe"

        return AuthSubscription(
            entitlement: entitlement,
            isActive: isActive,
            expiresAt: expiresAt,
            source: source
        )
    }

    static func mapUser(from payload: [String: JSONValue]) throws -> AuthUser {
        let source: [String: JSONValue]
        if case .object(let nested)? = payload["user"] {
            source = nested
        } else {
            source = payload
        }

        guard
            let id = source.int("id"),
            let email = source.string("email"),
            let createdAt = parseDate(source.string("created_at"))
        else {
            throw APIError.decoding(AuthPayloadParseError(message: "Could not parse account payload from /auth/me."))
        }

        return AuthUser(
            id: id,
            email: email,
            displayName: source.string("full_name") ?? source.string("display_name") ?? source.string("name"),
            createdAt: createdAt
        )
    }

    static func mapApplications(from payload: [String: JSONValue]) -> [AccountApplicationSnapshot] {
        let keys = ["applications", "tracker", "application_history"]
        guard let values = keys.compactMap({ payload[$0] }).first else { return [] }
        guard case .array(let rawItems) = values else { return [] }

        return rawItems.compactMap { item in
            guard case .object(let object) = item else { return nil }

            let id = object.string("id").flatMap(UUID.init(uuidString:)) ?? UUID()
            guard
                let company = object.string("company"),
                let role = object.string("role") ?? object.string("job_title") ?? object.string("title"),
                let status = object.string("status")
            else {
                return nil
            }

            let appliedAt =
                parseDate(object.string("applied_at"))
                ?? parseDate(object.string("created_at"))
                ?? Date()

            return AccountApplicationSnapshot(
                id: id,
                company: company,
                role: role,
                status: status,
                source: object.string("source"),
                appliedAt: appliedAt
            )
        }
    }

    static func mapUsageLimits(from payload: [String: JSONValue], subscription: AuthSubscription) -> AuthUsageLimits {
        let plan = payload.string("plan") ?? payload.string("tier") ?? (subscription.isActive ? "premium" : "free")
        let limit = payload.int("scans_daily_limit") ?? payload.int("daily_limit")
        let used = payload.int("scans_used_today") ?? payload.int("used_today") ?? 0
        let remaining = payload.int("scans_remaining_today") ?? payload.int("remaining_today")

        return AuthUsageLimits(
            plan: plan,
            scansDailyLimit: limit,
            scansUsedToday: used,
            scansRemainingToday: remaining
        )
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = iso8601WithFractional.date(from: value) ?? iso8601.date(from: value) {
            return date
        }
        return nil
    }
}
