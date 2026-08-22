import SwiftUI

struct ToolboxTalkFormView: View {
    let service: SafeSpaceService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject = ""
    @State private var topicName = ""
    @State private var talkDate = Date()
    @State private var deliveredBy = ""
    @State private var topicBody = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !selectedProject.isEmpty
            && !topicName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Project", selection: $selectedProject) {
                        Text("Select a project").tag("")
                        ForEach(projects) { project in
                            Text(project.projectName)
                                .lineLimit(1)
                                .tag(project.projectNumber)
                        }
                    }
                    TextField("Topic", text: $topicName, prompt: Text("e.g. Ladder Safety"))
                    DatePicker("Date", selection: $talkDate, displayedComponents: .date)
                    TextField("Delivered by", text: $deliveredBy, prompt: Text("Name"))
                }

                Section("Topic Content") {
                    TextField("Talk content (optional)", text: $topicBody, axis: .vertical)
                        .lineLimit(4...12)
                }
            }
            .navigationTitle("New Toolbox Talk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting {
                        ProgressView()
                    } else {
                        Button("Submit") { Task { await submit() } }
                            .bold()
                            .disabled(!canSubmit)
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadProjects() }
            .disabled(submitting)
            .interactiveDismissDisabled(submitting)
        }
    }

    private func loadProjects() async {
        projects = (try? await service.projects()) ?? []
        if deliveredBy.isEmpty {
            deliveredBy = auth.user?.displayName ?? ""
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }

        let body = CreateToolboxTalkBody(
            projectNumber: selectedProject,
            topicName: topicName.trimmingCharacters(in: .whitespaces),
            talkDate: Self.dateString(talkDate),
            deliveredBy: deliveredBy.trimmingCharacters(in: .whitespaces),
            topicBody: topicBody.trimmingCharacters(in: .whitespaces)
        )

        do {
            try await service.createTalk(body)
            NotificationCenter.default.post(name: .safeSpaceRecordCreated, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
