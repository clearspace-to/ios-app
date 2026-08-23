import SwiftUI

/// Weekly FPU dashboard: every active project's percent-complete filing for
/// one Friday. Rows needing attention (outstanding, then drafts) sort and
/// tint first; tapping any row opens the log sheet for that project + week.
struct FpusView: View {
    let service: SafeSpaceService

    @State private var weekEnding = FpuWeeks.currentFriday()
    @State private var state: LoadState<FpuWeekOverview> = .loading
    @State private var logging: FpuLogTarget?
    /// "Mine" plus any of the FpuState.filterCategory buckets. Defaults to
    /// mine-only per product ask; all are independently toggleable.
    @State private var activeFilters: Set<String> = ["Mine"]

    private static let statusOptions = ["Outstanding", "Draft", "Complete"]

    private var isCurrentWeek: Bool { weekEnding >= FpuWeeks.currentFriday() }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let overview):
                let statusFilters = activeFilters.subtracting(["Mine"])
                let rows = overview.rows
                    .filter { row in
                        (!activeFilters.contains("Mine") || row.mine)
                            && (statusFilters.isEmpty || row.state.filterCategory.map(statusFilters.contains) == true)
                    }
                    .sorted {
                        ($0.state.rank, $0.projectNumber) < ($1.state.rank, $1.projectNumber)
                    }
                List {
                    weekPicker

                    FilterChipsRow(options: ["Mine"] + Self.statusOptions, selected: $activeFilters)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Section {
                        ForEach(rows) { row in
                            Button {
                                logging = FpuLogTarget(projectNumber: row.projectNumber,
                                                       weekEnding: overview.weekEnding)
                            } label: {
                                RecordRow(title: row.projectName,
                                          subtitle: subtitle(row),
                                          trailingValue: row.overall.map { "\($0)%" },
                                          badge: row.state.badge)
                            }
                            .foregroundStyle(.primary)
                            .listRowBackground(row.state == .outstanding ? Color.orange.opacity(0.08) : nil)
                        }
                    } header: {
                        if !rows.isEmpty { Text(summary(rows)) }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if rows.isEmpty {
                        LoadStateView(message: activeFilters.isEmpty
                                      ? "No projects on record for this week."
                                      : "No projects match this filter.")
                    }
                }
            }
        }
        .navigationTitle("FPUs")
        .task(id: weekEnding) { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .safeSpaceRecordCreated)) { _ in
            Task { await load() }
        }
        .sheet(item: $logging) { target in
            FpuEntryFormView(service: service,
                             fixedProjectNumber: target.projectNumber,
                             initialWeekEnding: target.weekEnding)
        }
    }

    private var weekPicker: some View {
        HStack {
            Button {
                weekEnding = FpuWeeks.shifted(weekEnding, byWeeks: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            Spacer()
            Text("Week ending \(FpuWeeks.label(weekEnding))")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button {
                weekEnding = FpuWeeks.shifted(weekEnding, byWeeks: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(isCurrentWeek)
        }
    }

    private func subtitle(_ row: FpuProjectWeek) -> String {
        let superName = row.siteSuperName ?? "Unassigned"
        return "\(row.projectNumber) · \(superName)\(row.mine ? " (you)" : "")"
    }

    private func summary(_ rows: [FpuProjectWeek]) -> String {
        let filed = rows.filter { $0.state == .filedSafeSpace || $0.state == .filedProcore }.count
        let drafts = rows.filter { $0.state == .draft }.count
        let outstanding = rows.filter { $0.state == .outstanding }.count
        var parts = ["\(filed) of \(rows.count) filed"]
        if drafts > 0 { parts.append("\(drafts) in draft") }
        if outstanding > 0 { parts.append("\(outstanding) outstanding") }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        do {
            let overview = try await service.fpuOverview(weekEnding: weekEnding)
            state = .loaded(overview)
        } catch is CancellationError {
            // Superseded by a newer load (e.g. week changed mid-request) — the
            // newer task owns `state` now, so leave it alone.
        } catch let error as URLError where error.code == .cancelled {
            // Same as above: URLSession surfaces SwiftUI's task cancellation this way.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
