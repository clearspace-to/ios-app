import SwiftUI

/// Decides between the login screen, space selector, and the signed-in shell.
struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("lastSpaceID") private var lastSpaceID: String?

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn:
                if lastSpaceID != nil {
                    AppShell(modules: ClearspaceApps.all)
                } else {
                    SpaceSelectorView(modules: ClearspaceApps.all) { spaceID in
                        withAnimation { lastSpaceID = spaceID }
                    }
                }
            }
        }
        .task { await auth.restoreSession() }
    }
}
