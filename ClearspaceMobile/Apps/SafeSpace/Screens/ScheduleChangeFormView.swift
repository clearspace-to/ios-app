import SwiftUI

/// Request a schedule change: pick the Procore task, say what should move and
/// why. Files straight into Procore's Schedule tool, where it can only be
/// accepted or denied — not edited or withdrawn — so submitting confirms first.
struct ScheduleChangeFormView: View {
    let service: SafeSpaceService
    /// Locked when launched from a project page; pickable from the global
    /// create sheet (falling back to the last viewed project).
    let fixedProjectNumber: String?

    @Environment(\.dismiss) private var dismiss

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject: String
    @State private var tasks: [ScheduleTask]?
    @State private var tasksError: String?
    /// Which project the loaded tasks belong to. `.task(id:)` re-fires when the
    /// form reappears after the picker pops — without this guard that reload
    /// would wipe the task the user just picked.
    @State private var tasksProject = ""
    @State private var taskID: Int?
    @State private var changeStart = false
    @State private var newStart = Date()
    @State private var changeFinish = false
    @State private var newFinish = Date()
    @State private var newPercentage = ""
    @State private var otherChange = ""
    @State private var reason = ""
    @State private var notes = ""
    @State private var confirming = false
    @State private var submitting = false
    @State private var errorMessage: String?

    init(service: SafeSpaceService, fixedProjectNumber: String? = nil) {
        self.service = service
        self.fixedProjectNumber = fixedProjectNumber
        _selectedProject = State(initialValue: fixedProjectNumber ?? "")
    }

    private var selectedTask: ScheduleTask? { tasks?.first { $0.id == taskID } }

    /// The server's rule, enforced client-side too: a task plus at least one
    /// actual change (reason and notes alone don't count).
    private var hasAChange: Bool {
        changeStart || changeFinish
            || !newPercentage.trimmingCharacters(in: .whitespaces).isEmpty
            || !otherChange.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var canSubmit: Bool { taskID != nil && hasAChange && !submitting }

    var body: some View {
        NavigationStack {
            Form {
                projectSection

                if let tasks {
                    taskSection(tasks)
                    if taskID != nil {
                        changesSection
                        contextSection
                    }
                } else if let tasksError {
                    Section {
                        Text(tasksError).foregroundStyle(.secondary).font(.footnote)
                        Button("Try Again") { Task { await loadTasks() } }
                    }
                } else if !selectedProject.isEmpty {
                    Section { ProgressView() }
                }
            }
            .navigationTitle("Schedule Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting {
                        ProgressView()
                    } else {
                        Button("File") { confirming = true }
                            .bold()
                            .disabled(!canSubmit)
                    }
                }
            }
            .confirmationDialog("File this change request?", isPresented: $confirming, titleVisibility: .visible) {
                Button("File into Procore") { Task { await submit() } }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("It files straight into Procore's Schedule tool, where it can only be accepted or denied — it can't be edited or withdrawn.")
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
            .task(id: selectedProject) { await loadTasks() }
            .disabled(submitting)
            .interactiveDismissDisabled(submitting)
        }
    }

    // MARK: - Sections

    private var projectSection: some View {
        Section {
            if fixedProjectNumber == nil {
                NavigationLink {
                    ProjectPickerList(projects: projects, selection: $selectedProject)
                } label: {
                    HStack {
                        Text("Project")
                        Spacer()
                        Text(selectedProjectName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                FieldRow(label: "Project", value: selectedProjectName)
            }
        } footer: {
            if selectedProject.isEmpty {
                Text("Choose a project to load its Procore schedule.")
            }
        }
    }

    @ViewBuilder
    private func taskSection(_ tasks: [ScheduleTask]) -> some View {
        Section {
            NavigationLink {
                ScheduleTaskPickerList(tasks: tasks, selection: $taskID)
            } label: {
                HStack {
                    Text("Schedule task")
                    Spacer()
                    Text(selectedTask?.name ?? "Pick a task")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } footer: {
            if let selectedTask {
                Text("Currently \(selectedTask.currentLine)")
            } else {
                Text("The Procore schedule task the change is for.")
            }
        }
    }

    private var changesSection: some View {
        Section {
            Toggle("New start", isOn: $changeStart.animation())
            if changeStart {
                DatePicker("Starts", selection: $newStart, displayedComponents: .date)
            }
            Toggle("New finish", isOn: $changeFinish.animation())
            if changeFinish {
                DatePicker("Finishes", selection: $newFinish, displayedComponents: .date)
            }
            HStack {
                Text("New % complete")
                Spacer()
                TextField("—", text: $newPercentage)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            TextField("Other change — anything dates and % don't cover",
                      text: $otherChange, axis: .vertical)
        } header: {
            Text("Requested change")
        } footer: {
            if !hasAChange {
                Text("Request at least one change — a new date, percent complete, or a described change.")
            }
        }
    }

    private var contextSection: some View {
        Section {
            TextField("Reason — e.g. Permit delay", text: $reason)
            TextField("Notes for the reviewer", text: $notes, axis: .vertical)
                .lineLimit(2...6)
        } footer: {
            Text("Reviewers see the reason in Procore. Files straight into Procore — it can only be accepted or denied there, not withdrawn.")
        }
    }

    // MARK: - Behaviour

    private var selectedProjectName: String {
        projects.first { $0.projectNumber == selectedProject }?.projectName
            ?? (selectedProject.isEmpty ? "Select a project" : selectedProject)
    }

    private func loadProjects() async {
        projects = (try? await service.projects()) ?? []
        if fixedProjectNumber == nil, selectedProject.isEmpty,
           let last = SafeSpaceModule.lastViewedProjectNumber,
           projects.contains(where: { $0.projectNumber == last }) {
            selectedProject = last
        }
    }

    private func loadTasks() async {
        guard !selectedProject.isEmpty, selectedProject != tasksProject else { return }
        tasksProject = selectedProject
        tasks = nil
        tasksError = nil
        taskID = nil
        do {
            tasks = try await service.scheduleTasks(projectNumber: selectedProject)
        } catch {
            tasksError = error.localizedDescription
            tasksProject = ""   // so Try Again actually retries
        }
    }

    private func submit() async {
        guard let taskID, hasAChange else { return }
        submitting = true
        defer { submitting = false }

        let percentText = newPercentage.trimmingCharacters(in: .whitespaces)
        let percent = percentText.isEmpty ? nil : Double(percentText)
        if !percentText.isEmpty {
            guard let percent, (0...100).contains(percent) else {
                errorMessage = "New % complete must be a number between 0 and 100."
                return
            }
        }

        do {
            try await service.createScheduleChange(projectNumber: selectedProject, body: CreateScheduleChangeBody(
                taskId: taskID,
                newStart: changeStart ? Self.isoDay.string(from: newStart) : nil,
                newFinish: changeFinish ? Self.isoDay.string(from: newFinish) : nil,
                newPercentage: percent,
                otherChange: otherChange.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)))
            NotificationCenter.default.post(name: .safeSpaceRecordCreated, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

private struct ScheduleTaskPickerList: View {
    let tasks: [ScheduleTask]
    @Binding var selection: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [ScheduleTask] {
        if search.isEmpty { return tasks }
        return tasks.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered) { task in
            Button {
                selection = task.id
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(task.name).lineLimit(2)
                        Text(task.currentLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if task.id == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .searchable(text: $search, prompt: "Search tasks")
        .navigationTitle("Schedule Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}
