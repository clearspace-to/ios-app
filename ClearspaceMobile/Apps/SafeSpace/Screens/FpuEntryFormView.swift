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

    init(service: SafeSpaceService, fixedProjectNumber: String? = nil, initialWeekEnding: String? = nil) {
        self.service = service
        self.fixedProjectNumber = fixedProjectNumber
        _selectedProject = State(initialValue: fixedProjectNumber ?? "")
        _weekEnding = State(initialValue: initialWeekEnding ?? FpuWeeks.currentFriday())
    }

    private var canSubmit: Bool { form != nil && !submitting }
    private var loadKey: String { "\(selectedProject)|\(weekEnding)" }

    var body: some View {
        NavigationStack {
            Form {
                contextSection

                if let form {
                    progressSection(form)
                    notesSection
                    photosSection(form)
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
                Stepper {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(column.label)
                                .font(.subheadline)
                            Text(form.previous[column.key].map { "Last week \($0)%" } ?? "No previous entry")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(values[column.key].map { "\($0)%" } ?? "—")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(values[column.key] == nil ? Color.secondary : Color.primary)
                    }
                } onIncrement: {
                    step(column.key, by: 5, previous: form.previous[column.key])
                } onDecrement: {
                    step(column.key, by: -5, previous: form.previous[column.key])
                }
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

    /// Steps on the 5% grid, starting from last week's number when the field
    /// is unset — the same snap rule as the web form.
    private func step(_ key: String, by delta: Int, previous: Int?) {
        let base = values[key] ?? previous ?? 0
        let snapped = Int((Double(base + delta) / 5).rounded()) * 5
        values[key] = min(100, max(0, snapped))
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
        guard let form else { return }
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

private struct PickedPhoto: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let thumbnail: UIImage

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
