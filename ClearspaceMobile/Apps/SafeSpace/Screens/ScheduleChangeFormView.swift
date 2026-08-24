import SwiftUI

/// Request a milestone date change: pick one of the three movable milestones,
/// pick the new date, say why. Deliberately tiny — supers move rough
/// inspections, construction completion and takeover, and the old whole-schedule
/// task list buried those. Files straight into Procore's Schedule tool, where it
/// can only be accepted or denied — not edited or withdrawn — so submitting
/// confirms first.
struct ScheduleChangeFormView: View {
    let service: SafeSpaceService
    /// Locked when launched from a project page; pickable from the global
    /// create sheet (falling back to the last viewed project).
    let fixedProjectNumber: String?

    @Environment(\.dismiss) private var dismiss

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject: String
    @State private var milestones: [ScheduleMilestone]?
    @State private var milestonesError: String?
    /// Which project the loaded milestones belong to. `.task(id:)` re-fires when
    /// the form reappears after the project picker pops — without this guard
    /// that reload would wipe the milestone the user just picked.
    @State private var milestonesProject = ""
    @State private var taskID: Int?
    @State private var newDate = Date()
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

    private var selectedMilestone: ScheduleMilestone? {
        milestones?.first { $0.taskId == taskID }
    }

    /// Filing is one-way in Procore, so don't let a no-op through: the new date
    /// has to actually differ from what the schedule says today.
    private var dateMoves: Bool {
        guard let current = selectedMilestone?.date else { return true }
        return Self.isoDay.string(from: newDate) != current
    }
    private var canSubmit: Bool { taskID != nil && dateMoves && !submitting }

    var body: some View {
        NavigationStack {
            Form {
                projectSection

                if let milestones {
                    if milestones.isEmpty {
                        Section {
                            Text("This project's Procore schedule has none of the movable milestones (rough inspections, construction completion, takeover).")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    } else {
                        milestoneSection(milestones)
                        if taskID != nil {
                            dateSection
                            contextSection
                        }
                    }
                } else if let milestonesError {
                    Section {
                        Text(milestonesError).foregroundStyle(.secondary).font(.footnote)
                        Button("Try Again") { Task { await loadMilestones() } }
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
            .task(id: selectedProject) { await loadMilestones() }
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
                Text("Choose a project to load its Procore milestones.")
            }
        }
    }

    /// Only ever three rows, so they list inline — no separate picker screen.
    private func milestoneSection(_ milestones: [ScheduleMilestone]) -> some View {
        Section {
            ForEach(milestones) { milestone in
                Button {
                    taskID = milestone.taskId
                    // Seed the picker from the milestone's own date so the super
                    // nudges from where the schedule actually is.
                    if let date = milestone.date,
                       let parsed = Self.isoDay.date(from: date) {
                        newDate = parsed
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.label)
                            Text(milestone.currentLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if milestone.taskId == taskID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Milestone")
        } footer: {
            if taskID == nil {
                Text("Which milestone needs to move.")
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("New date", selection: $newDate, displayedComponents: .date)
        } footer: {
            if let current = selectedMilestone?.date, !dateMoves {
                Text("Pick a date other than \(SafetyDates.day(current)) — that's where the schedule already sits.")
            } else if let current = selectedMilestone?.date {
                Text("Moving from \(SafetyDates.day(current)).")
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

    private func loadMilestones() async {
        guard !selectedProject.isEmpty, selectedProject != milestonesProject else { return }
        milestonesProject = selectedProject
        milestones = nil
        milestonesError = nil
        taskID = nil
        do {
            milestones = try await service.scheduleMilestones(projectNumber: selectedProject)
        } catch {
            milestonesError = error.localizedDescription
            milestonesProject = ""   // so Try Again actually retries
        }
    }

    private func submit() async {
        guard let taskID, dateMoves else { return }
        submitting = true
        defer { submitting = false }

        do {
            try await service.createScheduleChange(projectNumber: selectedProject, body: CreateScheduleChangeBody(
                taskId: taskID,
                newDate: Self.isoDay.string(from: newDate),
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)))
            NotificationCenter.default.post(name: .safeSpaceRecordCreated, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Local time zone on purpose, in both directions: DatePicker hands back a
    /// local midnight, so parsing and formatting locally round-trips the day the
    /// super actually tapped. (SafetyDates.day renders UTC because it only ever
    /// reads dates off the wire.)
    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
