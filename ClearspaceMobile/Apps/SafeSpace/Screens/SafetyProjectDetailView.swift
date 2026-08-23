import SwiftUI

/// One project's safety record. Talks, forms and reports stay three separate
/// sets — deliberately not merged into one timeline.
///
/// Overview leads: the key dates, the team and the Procore link answer "what is
/// this site?" before the record tabs answer "what happened on it?". Overview
/// and Trades share one request that is loaded SEPARATELY from the record sets,
/// because it calls Wrike and Procore — slow, and occasionally down. A failure
/// there must leave the record tabs fully usable.
struct SafetyProjectDetailView: View {
    let service: SafeSpaceService
    let projectNumber: String

    @State private var state: LoadState<ProjectSafetySummary> = .loading
    @State private var overview: ProjectOverview?
    @State private var overviewError: String?
    @State private var fpuWeeks: [FpuWeekRow]?
    @State private var fpuError: String?
    @State private var loggingFpu: FpuLogTarget?
    @State private var tab = "Overview"
    @State private var showNewReport = false
    private let tabs = ["Overview", "Trades", "FPUs", "Talks", "Forms", "Reports"]

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let summary):
                List {
                    Section {
                        FieldRow(label: "Number", value: summary.project.projectNumber)
                        FieldRow(label: "Status", value: summary.project.statusLabel)
                        FieldRow(label: "Last daily report", value: summary.project.lastReportDate ?? "Never filed")
                    }

                    Picker("Section", selection: $tab) {
                        ForEach(tabs, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    switch tab {
                    case "Trades":
                        tradesSection
                    case "FPUs":
                        fpusSection
                    case "Talks":
                        talksSection(summary.talks)
                    case "Forms":
                        formsSection(summary.forms)
                    case "Reports":
                        reportsSection(summary.reports)
                    default:
                        overviewSection(fallback: summary.project)
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .navigationTitle(summary.project.projectName)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { SafeSpaceModule.lastViewedProjectNumber = projectNumber }
        .task { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .safeSpaceRecordCreated)) { _ in
            Task { await load() }
        }
        .sheet(item: $loggingFpu) { target in
            FpuEntryFormView(service: service,
                             fixedProjectNumber: target.projectNumber,
                             initialWeekEnding: target.weekEnding)
        }
        .sheet(isPresented: $showNewReport) {
            DailyReportFormView(service: service, preselectedProjectNumber: projectNumber)
        }
    }

    // MARK: - Overview

    /// `fallback` supplies the PM and site super from the project row so the
    /// team still reads when Wrike/Procore are unreachable.
    @ViewBuilder
    private func overviewSection(fallback: SafetyProject) -> some View {
        Section("Construction key dates") {
            if let overview {
                ForEach(overview.keyDates) { entry in
                    LabeledContent(entry.label) {
                        HStack(spacing: 6) {
                            Text(entry.displayValue)
                                .foregroundStyle(entry.date == nil ? .tertiary : .secondary)
                            if entry.passed { StageBadge(text: "Passed") }
                        }
                    }
                }
            } else if let overviewError {
                Text(overviewError).foregroundStyle(.secondary).font(.footnote)
            } else {
                ProgressView()
            }
        }

        Section("Team") {
            FieldRow(label: "Project manager", value: overview?.pmName ?? fallback.pmName ?? "—")
            FieldRow(label: "Design lead", value: overview?.designerName ?? "—")
            FieldRow(label: "Site super",
                     value: overview?.siteSuperName ?? fallback.siteSuperName ?? "Unassigned")
        }

        if let url = overview?.procoreURL {
            Section {
                Button {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
                        if !opened { UIApplication.shared.open(url) }
                    }
                } label: {
                    Label("Open in Procore", systemImage: "arrow.up.forward.square")
                }
            }
        }
    }

    // MARK: - Trades

    @ViewBuilder
    private var tradesSection: some View {
        Section("Trades") {
            if let trades = overview?.trades {
                if trades.isEmpty {
                    Text("No committed subs yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trades) { trade in
                        RecordRow(title: trade.vendor.isEmpty ? "(no vendor named)" : trade.vendor,
                                  subtitle: trade.scopeLine)
                    }
                }
            } else if overview != nil || overviewError != nil {
                // Loaded (or failed) with no trade list: Procore is unlinked or down.
                Text("Procore data unavailable — this project isn't linked to Procore, or Procore couldn't be reached.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - FPUs

    /// Every listed week is expected, so gaps read as Outstanding. Any row —
    /// filed or not — opens the log sheet for that week.
    @ViewBuilder
    private var fpusSection: some View {
        Section {
            if let weeks = fpuWeeks {
                if weeks.isEmpty {
                    Text("No FPUs on record").foregroundStyle(.secondary)
                } else {
                    ForEach(weeks) { week in
                        Button {
                            loggingFpu = FpuLogTarget(projectNumber: projectNumber,
                                                      weekEnding: week.weekEnding)
                        } label: {
                            RecordRow(title: week.weekLabel,
                                      subtitle: fpuSubtitle(week),
                                      trailingValue: week.overall.map { "\($0)%" },
                                      badge: week.state.badge)
                        }
                        .foregroundStyle(.primary)
                        .listRowBackground(week.state == .outstanding ? Color.orange.opacity(0.08) : nil)
                    }
                }
            } else if let fpuError {
                Text(fpuError).foregroundStyle(.secondary).font(.footnote)
            } else {
                ProgressView()
            }
        } header: {
            if let weeks = fpuWeeks, !weeks.isEmpty {
                Text("Weekly FPUs — \(weeks.filter(\.filed).count) of \(weeks.count) weeks filed")
            } else {
                Text("Weekly FPUs")
            }
        }
    }

    private func fpuSubtitle(_ week: FpuWeekRow) -> String {
        var parts: [String] = []
        if week.hasComment { parts.append("Notes") }
        if week.attachmentCount > 0 {
            parts.append("\(week.attachmentCount) photo\(week.attachmentCount == 1 ? "" : "s")")
        }
        if let by = week.submittedBy, !by.isEmpty { parts.append(by) }
        return parts.isEmpty ? "Tap to log" : parts.joined(separator: " · ")
    }

    // MARK: - Records

    @ViewBuilder
    private func talksSection(_ talks: [ToolboxTalk]) -> some View {
        Section("Toolbox Talks") {
            if talks.isEmpty {
                Text("No talks on file").foregroundStyle(.secondary)
            }
            ForEach(talks) { talk in
                NavigationLink(value: SafeSpaceModule.talkRoute(talk.id)) {
                    RecordRow(title: talk.topicName,
                              subtitle: "\(talk.talkDate) · \(talk.deliveredBy)",
                              trailingValue: talk.attendanceCount > 0 ? "\(talk.attendanceCount) signed" : nil,
                              badge: talk.status.label)
                }
            }
        }
    }

    @ViewBuilder
    private func formsSection(_ forms: [FormSubmission]) -> some View {
        Section("Form Submissions") {
            if forms.isEmpty {
                Text("No submissions on file").foregroundStyle(.secondary)
            }
            ForEach(forms) { form in
                NavigationLink(value: SafeSpaceModule.formRoute(form.id)) {
                    RecordRow(title: form.templateName,
                              subtitle: "\(form.submittedAt) · \(form.source.label)",
                              badge: form.status.label)
                }
            }
        }
    }

    @ViewBuilder
    private func reportsSection(_ reports: [DailyReport]) -> some View {
        Section("Daily Reports") {
            Button {
                showNewReport = true
            } label: {
                Label("New Daily Report", systemImage: "plus.circle")
            }
            if reports.isEmpty {
                Text("No reports on file").foregroundStyle(.secondary)
            }
            ForEach(reports) { report in
                NavigationLink(value: SafeSpaceModule.reportRoute(report.id)) {
                    RecordRow(title: report.reportDate,
                              subtitle: "\(report.weather) · \(report.headcount) on site",
                              badge: report.incidents ? "Incident" : nil)
                }
            }
        }
    }

    private func load() async {
        // Three independent requests: a dead Wrike, Procore or shared FPU table
        // must not empty the record tabs, and a slow one must not delay them.
        async let summary = service.projectSummary(projectNumber: projectNumber)
        async let detail = service.projectOverview(projectNumber: projectNumber)
        async let weeks = service.fpuWeeks(projectNumber: projectNumber)

        do {
            state = .loaded(try await summary)
        } catch {
            state = .failed(error.localizedDescription)
        }
        do {
            overview = try await detail
            overviewError = nil
        } catch {
            overview = nil
            overviewError = error.localizedDescription
        }
        do {
            fpuWeeks = try await weeks
            fpuError = nil
        } catch {
            fpuWeeks = nil
            fpuError = error.localizedDescription
        }
    }
}
