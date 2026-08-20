import Foundation

/// Plain-REST client for Supabase GoTrue (no SDK dependency).
/// Mirrors what sales_space's server-side auth.py does, but on-device.
struct SupabaseAuthClient {
    let baseURL: URL
    let anonKey: String

    /// URL to open in the system browser for Microsoft SSO (PKCE).
    func authorizeURL(redirectURI: String, codeChallenge: String) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "/auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "azure"),
            URLQueryItem(name: "redirect_to", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
            URLQueryItem(name: "scopes", value: "email"),
        ]
        return components.url!
    }

    /// Exchange the PKCE auth code for a session.
    func exchangeCode(_ code: String, verifier: String) async throws -> SupabaseSession {
        try await tokenRequest(grantType: "pkce", body: [
            "auth_code": code,
            "code_verifier": verifier,
        ])
    }

    /// Refresh an expired session.
    func refresh(refreshToken: String) async throws -> SupabaseSession {
        try await tokenRequest(grantType: "refresh_token", body: [
            "refresh_token": refreshToken,
        ])
    }

    /// Fetch the signed-in user's profile.
    func user(accessToken: String) async throws -> SupabaseUser {
        var request = URLRequest(url: baseURL.appending(path: "/auth/v1/user"))
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.ensureOK(response, data: data)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    private func tokenRequest(grantType: String, body: [String: String]) async throws -> SupabaseSession {
        var components = URLComponents(url: baseURL.appending(path: "/auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.ensureOK(response, data: data)
        var session = try JSONDecoder().decode(SupabaseSession.self, from: data)
        if session.expiresAt == nil, let expiresIn = session.expiresIn {
            session.expiresAt = Date().timeIntervalSince1970 + TimeInterval(expiresIn)
        }
        return session
    }

    private static func ensureOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.server(status: http.statusCode, message: message)
        }
    }
}

enum AuthError: LocalizedError {
    case network
    case server(status: Int, message: String)
    case cancelled
    case missingCode
    /// Asked for a token while there is no session at all.
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .network: return "Network error — check your connection."
        case .server(let status, _): return "Sign-in failed (\(status)). Try again."
        case .cancelled: return nil // user closed the sheet; not an error worth showing
        case .missingCode: return "Sign-in didn't complete. Try again."
        case .notSignedIn: return "You're not signed in. Sign in to see live data."
        }
    }
}
