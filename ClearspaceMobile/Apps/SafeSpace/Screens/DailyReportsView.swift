import SwiftUI

/// The scan view: incidents are the thing you're looking for, so they're loud.
struct DailyReportsView: View {
    let service: SafeSpaceService
    @State private var state: LoadState<[DailyReport]> = .loading
    @State private var incidentsOnly = false

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let reports):
                let visible = incidentsOnly ? reports.filter(\.incidents) : reports
                List {
                    Toggle("Incidents only", isOn: $incidentsOnly)
                        .font(.subheadline)

                    Section {
                        ForEach(visible) { report in
                            NavigationLink(value: SafeSpaceModule.reportRoute(report.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(report.reportDate).font(.body)
                                        if report.incidents {
                                            StageBadge(text: "Incident")
                                        }
                                        Spacer()
                                        Text("\(report.headcount) on site")
                                            .font(.subheadline.weight(.medium))
                                            .monospacedDigit()
                                    }
                                    Text(report.projectName)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text("\(report.weather) · \(report.crewSummary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(report.incidents ? Theme.red.opacity(0.06) : nil)
                        }
                    } header: {
                        if !visible.isEmpty {
                            Text("\(visible.count) reports")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if visible.isEmpty {
                        LoadStateView(message: "No reports match this filter.")
                    }
                }
            }
        }
        .navigationTitle("Daily Reports")
        .task { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .safeSpaceRecordCreated)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        do {
            state = .loaded(try await service.reports())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct DailyReportDetailView: View {
    let service: SafeSpaceService
    let reportID: String
    @State private var state: LoadState<DailyReport> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let report):
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(report.reportDate)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                if report.incidents {
                                    StageBadge(text: "Incident")
                                }
                                Text(report.projectName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                    }

                    Section("Site") {
                        FieldRow(label: "Weather", value: report.weather)
                        FieldRow(label: "On site", value: "\(report.headcount)")
                        FieldRow(label: "Toolbox talk", value: report.toolboxTalkDelivered ? "Delivered" : "Not delivered")
                        FieldRow(label: "Visitors", value: report.visitors.isEmpty ? "None" : report.visitors)
                        FieldRow(label: "Deliveries", value: report.deliveries.isEmpty ? "None" : report.deliveries)
                        FieldRow(label: "Attachments", value: "\(report.attachmentCount)")
                        FieldRow(label: "Submitted by", value: report.submittedBy)
                    }

                    // trade_name is the snapshot taken when the report was filed.
                    Section("Crew") {
                        if report.crew.isEmpty {
                            Text("No crew logged").foregroundStyle(.secondary)
                        }
                        ForEach(report.crew) { line in
                            LabeledContent(line.tradeName) {
                                Text("\(line.headcount)").monospacedDigit()
                            }
                        }
                    }

                    Section("Work performed") {
                        Text(report.workPerformed).font(.body)
                    }

                    Section("Hazards observed") {
                        Text(report.hazardsObserved.isEmpty ? "None reported" : report.hazardsObserved)
                            .font(.body)
                            .foregroundStyle(report.hazardsObserved.isEmpty ? .secondary : .primary)
                    }

                    if !report.notes.isEmpty {
                        Section("Notes") {
                            Text(report.notes).font(.body)
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
            }
        }
        .navigationTitle("Daily Report")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.reportDetail(id: reportID))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
