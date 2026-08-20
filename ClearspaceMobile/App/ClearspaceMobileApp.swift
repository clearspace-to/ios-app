import SwiftUI

@main
struct ClearspaceMobileApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(Theme.blue)
        }
    }
}
