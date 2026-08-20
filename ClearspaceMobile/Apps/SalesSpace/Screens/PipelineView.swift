import SwiftUI

struct PipelineView: View {
    let service: SalesSpaceService
    @State private var state: LoadState<[PipelineGroup]> = .loading
    @State private var scope = "Sales"
    private let scopes = ["Sales", "Service"]

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let groups):
                List {
                    Picker("Scope", selection: $scope) {
                        ForEach(scopes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.rows) { opp in
                                NavigationLink(value: SalesSpaceModule.route(for: opp)) {
                                    RecordRow(
                                        title: opp.name,
                                        subtitle: opp.accountName,
                                        trailingValue: opp.feesFormatted
                                    )
                                }
                            }
                            LabeledContent("Subtotal") {
                                Text(group.subtotal.currencyCompact)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .font(.subheadline)
                        } header: {
                            HStack {
                                Text(group.label)
                                Spacer()
                                Text("\(group.rows.count)")
                            }
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if groups.isEmpty {
                        LoadStateView(message: "No open opportunities in this pipeline.")
                    }
                }
            }
        }
        .navigationTitle("Pipeline")
        .task(id: scope) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.pipeline(scope: scope.lowercased()))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
