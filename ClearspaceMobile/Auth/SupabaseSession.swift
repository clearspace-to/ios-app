import Foundation

/// Token payload returned by GoTrue's /auth/v1/token endpoints.
struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
    /// Unix timestamp we compute at save-time so we can refresh proactively.
    var expiresAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
    }

    var isExpiringSoon: Bool {
        guard let expiresAt else { return true }
        // Refresh two minutes before actual expiry.
        return Date().timeIntervalSince1970 > expiresAt - 120
    }
}

/// Subset of GoTrue's /auth/v1/user response we care about.
struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let userMetadata: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }

    var displayName: String {
        if let meta = userMetadata,
           case .string(let name)? = meta["full_name"] ?? meta["name"] {
            return name
        }
        return email ?? "Signed in"
    }

    var initials: String {
        let source = displayName
        let parts = source.split(separator: " ").prefix(2)
        if parts.count >= 2 {
            return parts.map { String($0.prefix(1)).uppercased() }.joined()
        }
        return String(source.prefix(2)).uppercased()
    }
}

/// Minimal JSON value wrapper so we can decode arbitrary user_metadata.
enum AnyCodableValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let n = try? container.decode(Double.self) { self = .number(n); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}
