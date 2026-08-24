import PhotosUI
import SwiftUI

/// Log one project's weekly FPU: a ±5% stepper per trade division, notes and
/// photos. Built for a site super on a phone on Friday — every division
/// prefills from last week, so the common case is a few taps and Submit.
struct FpuEntryFormView: View {
    let service: SafeSpaceService
    /// Locked when launched from a project or dashboard row; pickable from the
    /// global create sheet.
    let fixedProjectNumber: String?

    @Environment(\.dismiss) private var dismiss

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject: String
    @State private var weekEnding: String
    @State private var form: FpuEntryForm?
    @State private var formError: String?
    @State private var values: [String: Int] = [:]
    @State private var comment = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [PickedPhoto] = []
    @State private var submitting = false
    @State private var progressText: String?
    @State private var errorMessage: String?
    /// Set when a typed percent came in under last week's — see FpuStep.
    @State private var backwardsMessage: String?
    /// Which division's percent field has the keyboard, so the form can offer
    /// one "Done" above the number pad (which has no return key of its own).
    @FocusState private var focusedKey: String?

    init(service: SafeSpaceService, fixedProjectNumber: String? = nil, initialWeekEnding: String? = nil) {
        self.service = service
        self.fixedProjectNumber = fixedProjectNumber
        _selectedProject = State(initialValue: fixedProjectNumber ?? "")
        _weekEnding = State(initialValue: initialWeekEnding ?? FpuWeeks.currentFriday())
    }

    private var canSubmit: Bool { form != nil && !submitting && !isPastWeek }
    private var loadKey: String { "\(selectedProject)|\(weekEnding)" }
    /// Weeks before the current Mon–Sun week are locked: filed or not, they're
    /// read-only once the following Monday starts.
    private var isPastWeek: Bool { weekEnding < FpuWeeks.currentFriday() }

    var body: some View {
        NavigationStack {
            Form {
                contextSection

                if let form {
                    if isPastWeek {
                        Section {
                            Label("This week is locked — past FPUs can't be edited.",
                                  systemImage: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    progressSection(form).disabled(isPastWeek)
                    notesSection.disabled(isPastWeek)
                    photosSection(form).disabled(isPastWeek)
                } else if let formError {
                    Section {
                        Text(formError).foregroundStyle(.secondary).font(.footnote)
                        Button("Try Again") { Task { await loadForm() } }
                    }
                } else if !selectedProject.isEmpty {
                    Section { ProgressView() }
                }
            }
            .navigationTitle("Log FPU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting {
                        ProgressView()
                    } else if !isPastWeek {
                        Button("Submit") { Task { await submit() } }
                            .bold()
                            .disabled(!canSubmit)
                    }
                }
                // The number pad has no return key, so this is the way out of it.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedKey = nil }
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
            .alert("Lower than last week", isPresented: Binding(
                get: { backwardsMessage != nil },
                set: { if !$0 { backwardsMessage = nil } }
            )) {
                Button("OK") { backwardsMessage = nil }
            } message: {
                Text(backwardsMessage ?? "")
            }
            .task { await loadProjects() }
            .task(id: loadKey) { await loadForm() }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                Task { await importPhotos(items) }
            }
            .disabled(submitting)
            .interactiveDismissDisabled(submitting)
        }
    }

    // MARK: - Sections

    private var contextSection: some View {
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
                FieldRow(label: "Project", value: form?.projectName ?? selectedProject)
            }

            HStack {
                Text("Week ending")
                Spacer()
                Button {
                    weekEnding = FpuWeeks.shifted(weekEnding, byWeeks: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text(FpuWeeks.label(weekEnding))
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                Button {
                    weekEnding = FpuWeeks.shifted(weekEnding, byWeeks: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(weekEnding >= FpuWeeks.currentFriday())
            }
        } footer: {
            if selectedProject.isEmpty {
                Text("Choose a project to load this week's FPU.")
            } else if form?.entrySource == "procore" {
                Text("This week is currently filed from Procore — submitting takes it over.")
            }
        }
    }

    @ViewBuilder
    private func progressSection(_ form: FpuEntryForm) -> some View {
        Section {
            ForEach(form.columns) { column in
                FpuDivisionRow(
                    column: column,
                    previous: form.previous[column.key],
                    value: binding(for: column.key),
                    focus: $focusedKey,
                    onRefused: { backwardsMessage = $0 }
                )
            }
        } header: {
            Text("Progress by division")
        } footer: {
            Text(overallLine)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Progress notes, holdups, anything the numbers don't say",
                      text: $comment, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    @ViewBuilder
    private func photosSection(_ form: FpuEntryForm) -> some View {
        Section {
            if !form.existingAttachments.isEmpty {
                FieldRow(label: "Already attached", value: "\(form.existingAttachments.count)")
            }
            ForEach(photos) { photo in
                HStack(spacing: 12) {
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photo.name).font(.subheadline).lineLimit(1)
                        Text(photo.sizeLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { photos.remove(atOffsets: $0) }

            PhotosPicker(selection: $photoItems, maxSelectionCount: 12, matching: .images) {
                Label("Add Photos", systemImage: "photo.badge.plus")
            }
        } header: {
            Text("Photos")
        } footer: {
            if let progressText {
                Text(progressText)
            }
        }
    }

    // MARK: - Behaviour

    /// Removing the key rather than storing nil matters: `submit` sends every
    /// column, so an absent key files as null ("no answer") instead of a number.
    private func binding(for key: String) -> Binding<Int?> {
        Binding(
            get: { values[key] },
            set: { newValue in
                if let newValue {
                    values[key] = newValue
                } else {
                    values.removeValue(forKey: key)
                }
            }
        )
    }

    private var overallLine: String {
        let set = values.values
        guard !set.isEmpty else { return "No divisions logged yet." }
        let mean = Int((Double(set.reduce(0, +)) / Double(set.count)).rounded())
        return "Overall \(mean)% across \(set.count) division\(set.count == 1 ? "" : "s")."
    }

    private var selectedProjectName: String {
        projects.first { $0.projectNumber == selectedProject }?.projectName
            ?? (selectedProject.isEmpty ? "Select a project" : selectedProject)
    }

    private func loadProjects() async {
        guard fixedProjectNumber == nil else { return }
        projects = (try? await service.projects()) ?? []
        if selectedProject.isEmpty, let last = SafeSpaceModule.lastViewedProjectNumber,
           projects.contains(where: { $0.projectNumber == last }) {
            selectedProject = last
        }
    }

    private func loadForm() async {
        guard !selectedProject.isEmpty else { return }
        form = nil
        formError = nil
        do {
            let loaded = try await service.fpuForm(projectNumber: selectedProject, weekEnding: weekEnding)
            form = loaded
            values = loaded.prefill
            comment = loaded.comment
        } catch {
            formError = error.localizedDescription
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  // Re-encode as JPEG: HEIC won't render in the web viewer.
                  let jpeg = image.jpegData(compressionQuality: 0.8) else { continue }
            let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 132, height: 132)) ?? image
            photos.append(PickedPhoto(name: "fpu-photo-\(photos.count + 1).jpg",
                                      data: jpeg, thumbnail: thumbnail))
        }
    }

    private func submit() async {
        guard let form, !isPastWeek else { return }
        submitting = true
        defer {
            submitting = false
            progressText = nil
        }
        do {
            var attachments = form.existingAttachments
            for (index, photo) in photos.enumerated() {
                progressText = "Uploading photo \(index + 1) of \(photos.count)…"
                attachments.append(try await service.uploadFpuPhoto(
                    projectNumber: form.projectNumber,
                    filename: photo.name,
                    contentType: "image/jpeg",
                    data: photo.data))
            }
            progressText = photos.isEmpty ? nil : "Saving…"

            // Send every column so an explicitly cleared value files as null.
            var payload: [String: Int?] = [:]
            for column in form.columns {
                payload.updateValue(values[column.key], forKey: column.key)
            }
            try await service.submitFpu(projectNumber: form.projectNumber, body: SubmitFpuBody(
                weekEnding: weekEnding,
                values: payload,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                attachments: attachments,
                status: "complete"))
            NotificationCenter.default.post(name: .safeSpaceRecordCreated, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One division: last week's figure for reference, a typed percent, and ±5%.
///
/// The field is free to type into and is only read when the keyboard leaves it.
/// Nothing is clamped as they type — a number below last week is refused with a
/// message and the field snaps back, so the super is told rather than quietly
/// corrected. Because `value` only changes on a successful commit, it is never
/// below the floor, even if Submit is tapped mid-edit.
private struct FpuDivisionRow: View {
    let column: FpuColumn
    let previous: Int?
    @Binding var value: Int?
    var focus: FocusState<String?>.Binding
    /// Reports a refused entry to the form, which owns the alert.
    let onRefused: (String) -> Void

    @State private var text = ""

    private var step: FpuStep { FpuStep(previous: previous, value: value) }
    private var isEditing: Bool { focus.wrappedValue == column.key }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(column.label)
                    .font(.subheadline)
                Text(previous.map { "Last week \($0)%" } ?? "No previous entry")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 1) {
                TextField("—", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .font(.body.weight(.semibold))
                    .frame(width: 38)
                    .focused(focus, equals: column.key)
                    .accessibilityLabel("\(column.label) percent complete")
                Text("%")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(value == nil ? .secondary : .primary)
            }

            // Two buttons rather than a Stepper: only the minus side is
            // disabled at the floor, and a Stepper can't disable one half.
            Button {
                focus.wrappedValue = nil
                value = step.stepped(by: -5)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .disabled(step.atFloor)
            .accessibilityLabel("\(column.label) minus 5 percent")

            Button {
                focus.wrappedValue = nil
                value = step.stepped(by: 5)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("\(column.label) plus 5 percent")
        }
        .onAppear { syncText() }
        // Steppers, the week switcher and the initial prefill write `value`.
        .onChange(of: value) { _, _ in
            if !isEditing { syncText() }
        }
        // Read the field only when they're done with it.
        .onChange(of: focus.wrappedValue) { old, _ in
            if old == column.key { commit() }
        }
    }

    private func commit() {
        switch step.typed(text) {
        case .cleared:
            value = nil
        case .accepted(let percent):
            value = percent
        case .refused(let percent):
            onRefused("""
                \(column.label) was \(step.floor)% last week, so \(percent)% \
                can't be filed — progress doesn't go backwards. Enter \
                \(step.floor)% or more, or clear the field to leave this \
                division unanswered. Past weeks can still be corrected in \
                safe_space on the web.
                """)
        }
        // Either way the field goes back to showing what is actually recorded.
        syncText()
    }

    private func syncText() {
        text = value.map(String.init) ?? ""
    }
}

private struct PickedPhoto: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let thumbnail: UIImage

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
