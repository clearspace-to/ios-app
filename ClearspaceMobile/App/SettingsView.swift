import SwiftUI

struct SettingsView: View {
    /// Where the current app's data comes from — live API or sample data.
    var dataSource: String = "—"
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    InitialsAvatar(text: auth.user?.initials ?? "?", size: 52, background: Theme.navy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.user?.displayName ?? "Signed in")
                            .font(.headline)
                        if let email = auth.user?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersionDisplay)
                LabeledContent("Data", value: AppEnvironment.isPreview ? "Sample data" : dataSource)
            }

            Section {
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Text("Log Out")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .clearspaceList()
        .bottomBarInset()
        .navigationTitle("Settings")
    }
}

extension Bundle {
    var appVersionDisplay: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
