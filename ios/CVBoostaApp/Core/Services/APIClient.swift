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

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
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
        apply(headers: headers, to: &request)
        let data = try await perform(request: request)
        return try decode(T.self, from: data)
    }

    func postNoBody<T: Decodable>(path: String, headers: [String: String] = [:]) async throws -> T {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        apply(headers: headers, to: &request)
        let data = try await perform(request: request)
        return try decode(T.self, from: data)
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

    private func perform(request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let parsed = try? decoder.decode(APIErrorBody.self, from: data)
            let message = parsed?.detail ?? "Server error \(httpResponse.statusCode)."
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func apply(headers: [String: String], to request: inout URLRequest) {
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
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
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
