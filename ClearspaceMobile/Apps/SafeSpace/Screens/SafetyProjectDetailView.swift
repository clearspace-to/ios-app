import SwiftUI

/// One project's safety record. Talks, forms and reports stay three separate
/// sets — deliberately not merged into one timeline.
struct SafetyProjectDetailView: View {
    let service: SafeSpaceService
    let projectNumber: String

    @State private var state: LoadState<ProjectSafetySummary> = .loading
    @State private var tab = "Talks"
    private let tabs = ["Talks", "Forms", "Reports"]

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
                        FieldRow(label: "Site super", value: summary.project.siteSuperName ?? "Unassigned")
                        FieldRow(label: "Project manager", value: summary.project.pmName ?? "—")
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
                    case "Forms":
                        formsSection(summary.forms)
                    case "Reports":
                        reportsSection(summary.reports)
                    default:
                        talksSection(summary.talks)
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .navigationTitle(summary.project.projectName)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

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
        do {
            state = .loaded(try await service.projectSummary(projectNumber: projectNumber))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
