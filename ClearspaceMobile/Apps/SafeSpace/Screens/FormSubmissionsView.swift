import SwiftUI

struct FormSubmissionsView: View {
    let service: SafeSpaceService
    @State private var state: LoadState<[FormSubmission]> = .loading
    @State private var statusFilter: Set<String> = []

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let submissions):
                let visible = statusFilter.isEmpty
                    ? submissions
                    : submissions.filter { statusFilter.contains($0.status.label) }
                List {
                    FilterChipsRow(options: ["Submitted", "Reviewed"], selected: $statusFilter)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    Section {
                        ForEach(visible) { submission in
                            NavigationLink(value: SafeSpaceModule.formRoute(submission.id)) {
                                RecordRow(
                                    title: submission.templateName,
                                    subtitle: "\(submission.projectName) · \(submission.submittedAt)",
                                    trailingValue: submission.source.label,
                                    badge: submission.status.label
                                )
                            }
                        }
                    } header: {
                        if !visible.isEmpty {
                            Text("\(visible.count) submissions")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if visible.isEmpty {
                        LoadStateView(message: "No submissions match this filter.")
                    }
                }
            }
        }
        .navigationTitle("Forms")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.submissions())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct FormSubmissionDetailView: View {
    let service: SafeSpaceService
    let submissionID: String
    @State private var state: LoadState<FormSubmissionDetail> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let detail):
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detail.submission.templateName)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                StageBadge(text: detail.submission.status.label)
                                if let category = detail.submission.category {
                                    Text(category)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                    }

                    Section("Submission") {
                        FieldRow(label: "Project", value: detail.submission.projectName)
                        FieldRow(label: "Submitted", value: detail.submission.submittedAt)
                        FieldRow(label: "Submitted by", value: detail.submission.submittedBy)
                        FieldRow(label: "Source", value: detail.submission.source.label)
                        FieldRow(label: "Signature", value: detail.hasSignature ? "On file" : "None")
                    }

                    // Rendered from the labels snapshotted at submit time, never
                    // from the template's current definition.
                    Section("Answers") {
                        ForEach(detail.answers) { answer in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(answer.label)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(answer.value)
                                    .font(.body)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
            }
        }
        .navigationTitle("Submission")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.submissionDetail(id: submissionID))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
