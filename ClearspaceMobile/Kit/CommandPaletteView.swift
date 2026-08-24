import SwiftUI

struct PaletteResult: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
    let icon: String
    let action: () -> Void
}

struct PaletteGroup: Identifiable {
    var id: String { label }
    let label: String
    let items: [PaletteResult]
}

/// Full-screen search & command overlay (mockup: Command Palette).
struct CommandPaletteView: View {
    @Binding var query: String
    let groups: [PaletteGroup]
    var isSearching: Bool = false
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Search or run a command", text: $query)
                        .accessibilityIdentifier("palette.query")
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))

                Button("Cancel", action: onCancel)
                    .foregroundStyle(Theme.blue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)

            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            Button {
                                item.action()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.blue)
                                        .frame(width: 28, height: 28)
                                        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if let subtitle = item.subtitle {
                                            Text(subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(group.label)
                            .accessibilityIdentifier("palette.group.\(group.label)")
                    }
                }
            }
            .clearspaceList()
            .overlay {
                if isSearching && groups.allSatisfy({ $0.items.isEmpty }) {
                    ProgressView("Searching\u{2026}")
                        .foregroundStyle(.secondary)
                } else if !isSearching && !query.trimmingCharacters(in: .whitespaces).isEmpty
                            && groups.allSatisfy({ $0.items.isEmpty }) {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { focused = true }
    }
}
