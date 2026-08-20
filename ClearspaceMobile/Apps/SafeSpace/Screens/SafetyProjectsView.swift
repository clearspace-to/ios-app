import SwiftUI

/// Projects are the spine of safe_space: every talk, form and report hangs off one.
/// This is a coverage check, not a directory — zero counts are called out.
struct SafetyProjectsView: View {
    let service: SafeSpaceService
    @State private var state: LoadState<[SafetyProject]> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let projects):
                List {
                    Section {
                        ForEach(projects) { project in
                            NavigationLink(value: SafeSpaceModule.projectRoute(project.projectNumber)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                                        Text(project.projectNumber)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.tertiary)
                                        Text(project.projectName)
                                            .font(.body)
                                            .lineLimit(1)
                                    }
                                    Text("Super: \(project.siteSuperName ?? "Unassigned") · PM: \(project.pmName ?? "—")")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if project.hasNothingOnFile {
                                        Text("Nothing on file")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Theme.red)
                                    } else {
                                        Text(project.activityLine)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        if !projects.isEmpty {
                            Text("\(projects.count) active projects")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if projects.isEmpty {
                        LoadStateView(message: "No active projects.")
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.projects())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
