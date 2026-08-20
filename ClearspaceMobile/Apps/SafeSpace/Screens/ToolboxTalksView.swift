import SwiftUI

struct ToolboxTalksView: View {
    let service: SafeSpaceService
    @State private var state: LoadState<[ToolboxTalk]> = .loading
    @State private var statusFilter: Set<String> = []

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .failed(let message):
                LoadStateView(message: message, isError: true) { await load() }
            case .loaded(let talks):
                let visible = statusFilter.isEmpty
                    ? talks
                    : talks.filter { statusFilter.contains($0.status.label) }
                List {
                    FilterChipsRow(options: ["Scheduled", "Open", "Closed"], selected: $statusFilter)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    Section {
                        ForEach(visible) { talk in
                            NavigationLink(value: SafeSpaceModule.talkRoute(talk.id)) {
                                RecordRow(
                                    title: talk.topicName,
                                    subtitle: "\(talk.projectName) · \(talk.talkDate)",
                                    trailingValue: talk.attendanceCount > 0 ? "\(talk.attendanceCount) signed" : nil,
                                    badge: talk.status.label
                                )
                            }
                        }
                    } header: {
                        if !visible.isEmpty {
                            Text("\(visible.count) talks")
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
                .overlay {
                    if visible.isEmpty {
                        LoadStateView(message: "No talks match this filter.")
                    }
                }
            }
        }
        .navigationTitle("Toolbox Talks")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.talks())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct ToolboxTalkDetailView: View {
    let service: SafeSpaceService
    let talkID: String
    @State private var state: LoadState<ToolboxTalkDetail> = .loading

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
                            Text(detail.talk.topicName)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                StageBadge(text: detail.talk.status.label)
                                Text(detail.talk.projectName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                    }

                    Section("Details") {
                        FieldRow(label: "Date", value: detail.talk.talkDate)
                        FieldRow(label: "Delivered by", value: detail.talk.deliveredBy)
                        FieldRow(label: "Project", value: detail.talk.projectNumber)
                        FieldRow(label: "Signed in", value: "\(detail.attendees.count)")
                        if !detail.corElements.isEmpty {
                            FieldRow(label: "COR elements",
                                     value: detail.corElements.map(String.init).joined(separator: ", "))
                        }
                    }

                    Section("Topic") {
                        Text(detail.topicBody).font(.body)
                    }

                    Section("Attendance") {
                        if detail.attendees.isEmpty {
                            Text("No one has signed in yet").foregroundStyle(.secondary)
                        }
                        ForEach(detail.attendees) { attendee in
                            RecordRow(
                                avatarText: attendee.name,
                                title: attendee.name,
                                subtitle: attendee.employerLabel
                            )
                        }
                    }
                }
                .clearspaceList()
                .bottomBarInset()
            }
        }
        .navigationTitle("Toolbox Talk")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await service.talkDetail(id: talkID))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
