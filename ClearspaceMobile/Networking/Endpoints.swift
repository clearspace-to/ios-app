import Foundation

/// Production origins for each Clearspace app's API.
/// Every app authenticates with the same Supabase token (see AuthConfig).
enum Endpoints {
    static let salesSpace = URL(string: "https://sales.clearspace.to")!
    /// Live and bearer-authed today — `GET /api/projects/list` etc.
    static let safeSpace = URL(string: "https://safe.clearspace.to")!
}
