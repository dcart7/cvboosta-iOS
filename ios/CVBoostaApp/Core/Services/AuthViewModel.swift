import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loggedOut
        case loggedIn
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var me: AuthMePayload?
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let authService: AuthService
    private let subscriptionService: SubscriptionService
    private let pushNotificationService: PushNotificationService
    private let widgetSyncService: WidgetSyncService

    init(
        authService: AuthService? = nil,
        subscriptionService: SubscriptionService? = nil,
        pushNotificationService: PushNotificationService? = nil,
        widgetSyncService: WidgetSyncService? = nil
    ) {
        self.authService = authService ?? .shared
        self.subscriptionService = subscriptionService ?? .shared
        self.pushNotificationService = pushNotificationService ?? .shared
        self.widgetSyncService = widgetSyncService ?? .shared
    }

    func bootstrap() async {
        state = .loading
        errorMessage = nil
        do {
            if let snapshot = try await authService.restoreSession() {
                applyAuthenticatedState(snapshot)
            } else {
                applyLoggedOutState()
            }
        } catch {
            applyLoggedOutState()
        }
    }

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        await submit { [self] in
            let snapshot = try await self.authService.login(email: email, password: password)
            self.applyAuthenticatedState(snapshot)
        }
    }

    func register(displayName: String, email: String, password: String, confirmPassword: String) async {
        guard !email.isEmpty else {
            errorMessage = "Email is required."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        await submit { [self] in
            let snapshot = try await self.authService.register(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            self.applyAuthenticatedState(snapshot)
        }
    }

    func sendPasswordReset(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Email is required."
            return
        }
        await submit { [self] in
            let message = try await self.authService.forgotPassword(email: email)
            self.infoMessage = message
            self.errorMessage = nil
        }
    }

    func refreshSharedState() async {
        guard state == .loggedIn else { return }
        await submit { [self] in
            let snapshot = try await self.authService.fetchCurrentUserState()
            self.applyAuthenticatedState(snapshot)
        }
    }

    func logout() async {
        await authService.logout()
        applyLoggedOutState()
    }

    private func submit(_ work: @escaping @MainActor () async throws -> Void) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await work()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyAuthenticatedState(_ snapshot: AuthMePayload) {
        me = snapshot
        subscriptionService.applyBackendSubscription(snapshot.subscription)
        subscriptionService.applyBackendUsageLimits(snapshot.usageLimits)
        widgetSyncService.applyAuthenticatedSnapshot(snapshot)
        errorMessage = nil
        infoMessage = nil
        state = .loggedIn

        Task {
            await pushNotificationService.requestAuthorizationIfNeeded()
            await pushNotificationService.syncIfPossible()
        }
    }

    private func applyLoggedOutState() {
        me = nil
        subscriptionService.reset()
        widgetSyncService.clear()
        errorMessage = nil
        infoMessage = nil
        state = .loggedOut
    }
}
