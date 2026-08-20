import SwiftUI

struct SalesDashboardView: View {
    let service: SalesSpaceService
    @State private var state: LoadState<DashboardData> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let data):
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Pipeline overview and reporting")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        StatTileGrid(tiles: data.stats.map { StatTile(label: $0.label, value: $0.value) })

                        BarChartCard(
                            title: "Weekly Identified",
                            subtitle: "Last 8 weeks",
                            points: data.weeklyIdentified.map { BarPoint(label: $0.week, value: $0.count) }
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECENT OPPORTUNITIES")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            VStack(spacing: 0) {
                                ForEach(data.recent) { opp in
                                    NavigationLink(value: SalesSpaceModule.route(for: opp)) {
                                        HStack {
                                            RecordRow(title: opp.name, subtitle: opp.accountName, badge: opp.stage)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                    }
                                    .buttonStyle(.plain)
                                    if opp.id != data.recent.last?.id {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
                .bottomBarInset()
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Dashboard")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.dashboard())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
