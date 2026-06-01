import AuthenticationServices
import Foundation

final class AuthService: NSObject {
    static let shared = AuthService()

    private override init() {}

    func makeAppleRequest() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        return request
    }
}
