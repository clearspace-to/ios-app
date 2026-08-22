import Foundation

/// Standard envelope returned by Clearspace app APIs: { ok, data, meta }.
struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T
}

enum APIError: LocalizedError {
    case badResponse
    case unauthorized
    case forbidden(message: String)
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Unexpected server response."
        case .unauthorized: return "Your session expired. Sign in again."
        // The API says exactly which app you lack access to — show that.
        case .forbidden(let message): return message
        case .server(let status, let message):
            return message.isEmpty ? "Server error (\(status))." : message
        }
    }
}

/// Clearspace APIs return `{"error": "..."}` on failure.
private struct APIErrorBody: Decodable { let error: String }

/// Bearer-authenticated JSON client for the Clearspace app APIs.
/// Retries once on 401 after forcing a token refresh.
struct APIClient {
    let baseURL: URL
    let auth: AuthManager

    /// `convertSnakeCase: false` for payloads containing caller-defined keys
    /// (a form submission's answers are keyed by field key — converting those
    /// would rename the data).
    func get<T: Decodable>(_ path: String, query: [String: String] = [:], convertSnakeCase: Bool = true) async throws -> T {
        try await send(path: path, method: "GET", query: query, body: Optional<Int>.none, convertSnakeCase: convertSnakeCase)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path: path, method: "PATCH", query: [:], body: body)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path: path, method: "POST", query: [:], body: body)
    }

    private func send<T: Decodable, B: Encodable>(path: String, method: String, query: [String: String], body: B?, convertSnakeCase: Bool = true) async throws -> T {
        var token = try await auth.validAccessToken()
        var attempt = 0
        while true {
            attempt += 1
            var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
            if !query.isEmpty {
                components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            var request = URLRequest(url: components.url!)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let encoder = JSONEncoder()
                if convertSnakeCase { encoder.keyEncodingStrategy = .convertToSnakeCase }
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
            if http.statusCode == 401, attempt == 1 {
                token = try await auth.forceRefresh()
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error ?? ""
                if http.statusCode == 401 { throw APIError.unauthorized }
                if http.statusCode == 403 {
                    throw APIError.forbidden(message: message.isEmpty ? "You don't have access to this app." : message)
                }
                throw APIError.server(status: http.statusCode, message: message)
            }
            let decoder = JSONDecoder()
            if convertSnakeCase { decoder.keyDecodingStrategy = .convertFromSnakeCase }
            // Clearspace APIs wrap responses in {ok, data}; fall back to bare payloads.
            if let envelope = try? decoder.decode(Envelope<T>.self, from: data) {
                return envelope.data
            }
            return try decoder.decode(T.self, from: data)
        }
    }
}
