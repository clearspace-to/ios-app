import SwiftUI

struct OpportunitiesView: View {
    let service: SalesSpaceService
    @State private var state: LoadState<[Opportunity]> = .loading
    @State private var selectedStages: Set<String> = []

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let opportunities):
                List {
                    FilterChipsRow(options: SalesStages.filterOptions, selected: $selectedStages)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    Section {
                        ForEach(opportunities) { opp in
                            NavigationLink(value: SalesSpaceModule.route(for: opp)) {
                                RecordRow(
                                    monogramPrefix: opp.number,
                                    title: opp.name,
                                    subtitle: [opp.accountName, opp.city].compactMap { $0 }.joined(separator: " · "),
                                    trailingValue: opp.feesFormatted,
                                    badge: opp.stage
                                )
                            }
                        }
                    } header: {
                        if !opportunities.isEmpty {
                            Text("\(opportunities.count) opportunities")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if opportunities.isEmpty {
                        LoadStateView(message: "No opportunities match these filters.")
                    }
                }
            }
        }
        .navigationTitle("Opportunities")
        .task(id: selectedStages) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.opportunities(query: "", stages: selectedStages))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
