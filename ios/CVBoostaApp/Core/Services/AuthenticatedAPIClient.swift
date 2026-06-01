import Foundation

final class AuthenticatedAPIClient {
    static let shared = AuthenticatedAPIClient()

    private let apiClient: APIClient
    private let authService: AuthService

    init(apiClient: APIClient = .shared, authService: AuthService = .shared) {
        self.apiClient = apiClient
        self.authService = authService
    }

    func getJSON<T: Decodable>(path: String) async throws -> T {
        try await performAuthorized { accessToken in
            try await self.apiClient.getJSON(
                path: path,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
        }
    }

    func postJSON<T: Decodable, U: Encodable>(path: String, body: U) async throws -> T {
        try await performAuthorized { accessToken in
            try await self.apiClient.postJSON(
                path: path,
                body: body,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
        }
    }

    func patchJSON<T: Decodable, U: Encodable>(path: String, body: U) async throws -> T {
        try await performAuthorized { accessToken in
            try await self.apiClient.patchJSON(
                path: path,
                body: body,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
        }
    }

    func delete(path: String) async throws {
        _ = try await performAuthorized { accessToken in
            try await self.apiClient.deleteNoBody(
                path: path,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
            return true
        }
    }

    func uploadMultipart<T: Decodable>(
        path: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) async throws -> T {
        try await performAuthorized { accessToken in
            try await self.apiClient.uploadMultipart(
                path: path,
                fields: fields,
                fileFieldName: fileFieldName,
                fileName: fileName,
                mimeType: mimeType,
                fileData: fileData,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
        }
    }

    private func performAuthorized<T>(
        _ operation: @escaping (String) async throws -> T
    ) async throws -> T {
        let accessToken = try await authService.currentAccessToken()

        do {
            return try await operation(accessToken)
        } catch let APIError.server(statusCode, _) where statusCode == 401 {
            do {
                let refreshedToken = try await authService.refreshAccessToken()
                return try await operation(refreshedToken)
            } catch {
                await authService.clearSession()
                throw APIError.server(statusCode: 401, message: "Session expired. Please log in again.")
            }
        }
    }
}
