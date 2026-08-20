import SwiftUI

/// Generic list for any record kind — one screen serves accounts, contacts,
/// buildings and revisions. Searching happens through the command bar.
struct RecordListView: View {
    let service: SalesSpaceService
    let kind: SalesRecordKind
    @State private var state: LoadState<[RecordItem]> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let items):
                List {
                    Section {
                        ForEach(items) { item in
                            RecordRow(
                                avatarText: kind == .accounts || kind == .contacts ? item.title : nil,
                                avatarColor: kind == .contacts ? Theme.navy : Theme.blue,
                                title: item.title,
                                subtitle: item.subtitle,
                                trailingValue: kind == .revisions ? nil : item.trail,
                                badge: kind == .revisions ? item.trail : nil
                            )
                        }
                    } header: {
                        if !items.isEmpty {
                            Text("\(items.count) \(kind.title.lowercased())")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if items.isEmpty {
                        LoadStateView(message: "No \(kind.title.lowercased()) yet.")
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.records(kind: kind, query: ""))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
