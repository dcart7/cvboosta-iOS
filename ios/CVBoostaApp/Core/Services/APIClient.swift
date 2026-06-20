import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case transport(Error)
    case invalidResponse
    case server(statusCode: Int, message: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .transport(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid server response."
        case .server(_, let message):
            return message
        case .decoding:
            return "Unable to parse server response."
        }
    }
}

struct APIErrorBody: Decodable {
    let detail: String?
}

final class APIClient {
    static let shared = APIClient(baseURL: AppEnvironment.apiBaseURL)

    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.session = session ?? Self.makeSession()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.iso8601WithFractional.date(from: value) ?? Self.iso8601.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func postJSON<T: Decodable, U: Encodable>(
        path: String,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        request.httpBody = try encoder.encode(body)

        let data = try await perform(request: request)
        return try decode(T.self, from: data)
    }

    func uploadMultipart<T: Decodable>(
        path: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = try makeURL(path: path)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fields: fields,
            fileFieldName: fileFieldName,
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData
        )

        let data = try await perform(request: request)
        return try decode(T.self, from: data)
    }

    func getJSON<T: Decodable>(path: String, headers: [String: String] = [:]) async throws -> T {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        let data = try await perform(request: request, retryCount: 1)
        return try decode(T.self, from: data)
    }

    func postNoBody<T: Decodable>(path: String, headers: [String: String] = [:]) async throws -> T {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        let data = try await perform(request: request)
        return try decode(T.self, from: data)
    }

    func patchJSON<T: Decodable, U: Encodable>(
        path: String,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        request.httpBody = try encoder.encode(body)

        let data = try await perform(request: request)
        return try decode(T.self, from: data)
    }

    func deleteNoBody(path: String, headers: [String: String] = [:]) async throws {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)
        _ = try await perform(request: request)
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 60 * 1024 * 1024,
            diskPath: "cvboosta-api-cache"
        )
        return URLSession(configuration: configuration)
    }

    private func makeURL(path: String) throws -> URL {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalized, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        let isHTTPS = url.scheme?.lowercased() == "https"
        let host = url.host?.lowercased()
        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard isHTTPS || isLocalhost else {
            throw APIError.invalidURL
        }
        return url
    }

    private func perform(request: URLRequest, retryCount: Int = 0) async throws -> Data {
        let response = try await performRequest(request: request, retryCount: retryCount)
        return response.data
    }

    private func performRequest(
        request: URLRequest,
        retryCount: Int = 0
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if retryCount > 0, shouldRetryTransport(error, for: request) {
                try? await Task.sleep(for: .milliseconds(350))
                return try await performRequest(request: request, retryCount: retryCount - 1)
            }
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if retryCount > 0,
           shouldRetryStatusCode(httpResponse.statusCode, for: request) {
            try? await Task.sleep(for: .milliseconds(350))
            return try await performRequest(request: request, retryCount: retryCount - 1)
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let parsed = try? decoder.decode(APIErrorBody.self, from: data)
            let rawMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = parsed?.detail
                ?? humanReadableServerMessage(
                    statusCode: httpResponse.statusCode,
                    body: rawMessage
                )
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }

        return (data, httpResponse)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func apply(headers: [String: String], to request: inout URLRequest) {
        applyProductionFallbackHeaders(to: &request)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func applyProductionFallbackHeaders(to request: inout URLRequest) {
        guard let url = request.url else { return }
        guard url.host?.lowercased() == AppEnvironment.apiBaseURL.host?.lowercased() else { return }

        if request.value(forHTTPHeaderField: "Origin") == nil {
            request.setValue(AppEnvironment.webBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forHTTPHeaderField: "Origin")
        }

        if request.value(forHTTPHeaderField: "Referer") == nil {
            request.setValue(AppEnvironment.webBaseURL.absoluteString + "/", forHTTPHeaderField: "Referer")
        }
    }

    private func humanReadableServerMessage(statusCode: Int, body: String?) -> String {
        if let body {
            if body.localizedCaseInsensitiveContains("csrf protection") {
                return "Request reached the website instead of the production API. Check API_BASE_URL."
            }

            if !body.isEmpty {
                return body
            }
        }

        return "Server error \(statusCode)."
    }

    private func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }

        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.append(lineBreak)
        body.append("--\(boundary)--\(lineBreak)")

        return body
    }
}

private extension APIClient {
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

    func shouldRetryTransport(_ error: Error, for request: URLRequest) -> Bool {
        guard request.httpMethod?.uppercased() == "GET" else { return false }
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    func shouldRetryStatusCode(_ statusCode: Int, for request: URLRequest) -> Bool {
        guard request.httpMethod?.uppercased() == "GET" else { return false }
        return [408, 429, 500, 502, 503, 504].contains(statusCode)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
