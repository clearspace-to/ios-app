import SwiftUI

/// Decides between the login screen and the signed-in experience.
struct RootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn:
                AppShell(modules: ClearspaceApps.all)
            }
        }
        .task { await auth.restoreSession() }
    }
}
