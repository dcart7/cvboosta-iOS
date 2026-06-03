import Foundation

/// User state facade (me/profile, shared snapshots).
/// Auth/session lifecycle stays in `AuthService`.
actor UserService {
    static let shared = UserService()

    private let authService: AuthService

    init(authService: AuthService = .shared) {
        self.authService = authService
    }

    func me() async throws -> AuthMePayload {
        try await authService.fetchCurrentUserState()
    }
}

