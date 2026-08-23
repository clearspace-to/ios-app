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
                if lastSpaceID != nil || launchArgumentsChooseSpace {
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

    /// Tooling hook (screenshots / UI tests): `-app=<id>` names the space and
    /// `-preview` drives the shell directly, so automation never lands on the
    /// first-run selector. Nothing is persisted — a real first launch still
    /// gets the selector. See AppShell.applyLaunchArguments.
    private var launchArgumentsChooseSpace: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-preview") || args.contains { $0.hasPrefix("-app=") }
    }
}
