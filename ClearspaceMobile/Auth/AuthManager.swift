import Foundation
import SwiftUI

/// App-wide auth state: Microsoft SSO via the shared Clearspace Supabase project,
/// session persisted in the Keychain, automatic refresh.
@MainActor
final class AuthManager: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn
    }

    /// Single instance so the networking layer can get a token without the view tree.
    static let shared = AuthManager()

    @Published var state: State = .loading
    @Published var user: SupabaseUser?
    @Published var lastError: String?

    private let client = SupabaseAuthClient(baseURL: AuthConfig.supabaseURL, anonKey: AuthConfig.anonKey)
    private let presenter = WebAuthPresenter()
    private var session: SupabaseSession?
    private static let keychainKey = "supabase_session"

    // MARK: - Session lifecycle

    func restoreSession() async {
        guard state == .loading else { return }
        // Launch argument used by tooling/screenshots to skip login (mock data only).
        if ProcessInfo.processInfo.arguments.contains("-preview") {
            state = .signedIn
            return
        }
        guard let data = KeychainStore.load(for: Self.keychainKey),
              let saved = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            state = .signedOut
            return
        }
        session = saved
        do {
            _ = try await validAccessToken()
            user = try await client.user(accessToken: session!.accessToken)
            state = .signedIn
        } catch {
            // Refresh failed (revoked / long-expired) — require a fresh login.
            clearSession()
        }
    }

    func signInWithMicrosoft() async {
        lastError = nil
        let verifier = PKCE.generateVerifier()
        let challenge = PKCE.challenge(for: verifier)
        let url = client.authorizeURL(redirectURI: AuthConfig.redirectURI, codeChallenge: challenge)
        do {
            let callback = try await presenter.start(url: url, callbackScheme: AuthConfig.callbackScheme)
            guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else {
                throw AuthError.missingCode
            }
            let newSession = try await client.exchangeCode(code, verifier: verifier)
            persist(newSession)
            user = try await client.user(accessToken: newSession.accessToken)
            state = .signedIn
        } catch AuthError.cancelled {
            // User dismissed the sheet — stay signed out silently.
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed. Try again."
        }
    }

    func signOut() {
        clearSession()
    }

    /// Browse the app with sample data, no login (pre-release only).
    /// Modules must be switched to mock data *before* any screen is built.
    func enterPreviewMode() {
        AppEnvironment.enableSampleData()
        state = .signedIn
    }

    /// Returns a fresh access token, refreshing first if it's about to expire.
    func validAccessToken() async throws -> String {
        guard var current = session else { throw AuthError.notSignedIn }
        if current.isExpiringSoon {
            current = try await client.refresh(refreshToken: current.refreshToken)
            persist(current)
        }
        return current.accessToken
    }

    /// Force a refresh (e.g. after an API 401) and return the new token.
    func forceRefresh() async throws -> String {
        guard let current = session else { throw AuthError.notSignedIn }
        let refreshed = try await client.refresh(refreshToken: current.refreshToken)
        persist(refreshed)
        return refreshed.accessToken
    }

    // MARK: - Private

    private func persist(_ newSession: SupabaseSession) {
        session = newSession
        if let data = try? JSONEncoder().encode(newSession) {
            KeychainStore.save(data, for: Self.keychainKey)
        }
    }

    private func clearSession() {
        session = nil
        user = nil
        KeychainStore.delete(for: Self.keychainKey)
        state = .signedOut
    }
}
