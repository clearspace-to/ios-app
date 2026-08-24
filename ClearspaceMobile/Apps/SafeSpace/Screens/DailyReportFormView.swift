import PhotosUI
import SwiftUI

struct DailyReportFormView: View {
    let service: SafeSpaceService
    /// Set when launched from a project's own "New Daily Report" action, so the
    /// project field arrives pre-filled instead of relying on the module-wide
    /// `lastViewedProjectNumber` fallback in `loadProjects()`.
    let preselectedProjectNumber: String?
    @Environment(\.dismiss) private var dismiss

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject: String
    @State private var reportDate = Date()
    @State private var crewLines: [CrewEntry] = []
    @State private var committedTrades: [ProjectTrade]?
    @State private var tradesLoading = false
    @State private var showTradePicker = false
    @State private var workPerformed = ""
    @State private var hazardsObserved = ""
    @State private var notes = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [PickedPhoto] = []
    @State private var showCamera = false
    @State private var submitting = false
    @State private var progressText: String?
    @State private var errorMessage: String?

    init(service: SafeSpaceService, preselectedProjectNumber: String? = nil) {
        self.service = service
        self.preselectedProjectNumber = preselectedProjectNumber
        _selectedProject = State(initialValue: preselectedProjectNumber ?? "")
    }

    private var canSubmit: Bool {
        !selectedProject.isEmpty
            && crewLines.contains { !$0.tradeName.trimmingCharacters(in: .whitespaces).isEmpty }
            && !workPerformed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    DatePicker("Date", selection: $reportDate, displayedComponents: .date)
                }

                Section("Crew") {
                    ForEach($crewLines) { $entry in
                        HStack {
                            Text(entry.tradeName)
                            Spacer()
                            Stepper("\(entry.headcount)", value: $entry.headcount, in: 1...200)
                                .fixedSize()
                        }
                    }
                    .onDelete { crewLines.remove(atOffsets: $0) }

                    if tradesLoading {
                        HStack {
                            ProgressView()
                            Text("Loading trades…").foregroundStyle(.secondary)
                        }
                    } else if let trades = committedTrades {
                        let available = trades.filter { trade in
                            !crewLines.contains { $0.tradeName == trade.vendor }
                        }
                        if available.isEmpty && !trades.isEmpty {
                            Text("All committed trades added")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        } else {
                            Button {
                                showTradePicker = true
                            } label: {
                                Label("Add Trade", systemImage: "plus.circle")
                            }
                            .disabled(available.isEmpty)
                        }
                    } else if selectedProject.isEmpty {
                        Text("Select a project to see trades")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        Text("Trade list unavailable — Procore may be offline")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }

                Section("Work Performed") {
                    TextField("Describe work completed today", text: $workPerformed, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Hazards Observed") {
                    TextField("Describe any hazards (or leave blank)", text: $hazardsObserved, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
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
                        Label("Choose from Library", systemImage: "photo.badge.plus")
                    }

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    if let progressText {
                        Text(progressText)
                    }
                }
            }
            .navigationTitle("New Daily Report")
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
            .onChange(of: photoItems) { _, items in
                Task { await importPhotos(items) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    Task {
                        if let photo = await pickedPhoto(from: image, index: photos.count + 1,
                                                         prefix: "report-photo") {
                            photos.append(photo)
                        }
                    }
                }
            }
            .task { await loadProjects() }
            .task(id: selectedProject) { await loadTrades() }
            .sheet(isPresented: $showTradePicker) {
                NavigationStack {
                    TradePickerList(trades: availableTrades) { vendor in
                        crewLines.append(CrewEntry(tradeName: vendor))
                    }
                }
            }
            .disabled(submitting)
            .interactiveDismissDisabled(submitting)
        }
    }

    private var availableTrades: [ProjectTrade] {
        guard let trades = committedTrades else { return [] }
        return trades.filter { trade in
            !crewLines.contains { $0.tradeName == trade.vendor }
        }
    }

    private var selectedProjectName: String {
        projects.first { $0.projectNumber == selectedProject }?.projectName
            ?? (selectedProject.isEmpty ? "Select a project" : selectedProject)
    }

    private func loadProjects() async {
        projects = (try? await service.projects()) ?? []
        if preselectedProjectNumber == nil, selectedProject.isEmpty,
           let last = SafeSpaceModule.lastViewedProjectNumber,
           projects.contains(where: { $0.projectNumber == last }) {
            selectedProject = last
        }
    }

    private func loadTrades() async {
        committedTrades = nil
        crewLines = []
        guard !selectedProject.isEmpty else { return }
        tradesLoading = true
        defer { tradesLoading = false }
        let overview = try? await service.projectOverview(projectNumber: selectedProject)
        committedTrades = overview?.trades
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.8) else { continue }
            let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 132, height: 132)) ?? image
            photos.append(PickedPhoto(name: "report-photo-\(photos.count + 1).jpg",
                                      data: jpeg, thumbnail: thumbnail))
        }
    }

    private func submit() async {
        submitting = true
        defer {
            submitting = false
            progressText = nil
        }

        do {
            var attachments: [FpuAttachment] = []
            for (index, photo) in photos.enumerated() {
                progressText = "Uploading photo \(index + 1) of \(photos.count)…"
                attachments.append(try await service.uploadPhoto(
                    scope: "daily-reports/\(selectedProject)",
                    filename: photo.name,
                    contentType: "image/jpeg",
                    data: photo.data))
            }
            progressText = photos.isEmpty ? nil : "Saving…"

            let validCrew = crewLines.filter { !$0.tradeName.trimmingCharacters(in: .whitespaces).isEmpty }
            let body = CreateDailyReportBody(
                projectNumber: selectedProject,
                reportDate: Self.dateString(reportDate),
                weather: "",
                crew: validCrew.map { .init(tradeName: $0.tradeName.trimmingCharacters(in: .whitespaces),
                                            headcount: $0.headcount) },
                workPerformed: workPerformed.trimmingCharacters(in: .whitespaces),
                hazardsObserved: hazardsObserved.trimmingCharacters(in: .whitespaces),
                toolboxTalkDelivered: false,
                visitors: "",
                deliveries: "",
                incidents: false,
                notes: notes.trimmingCharacters(in: .whitespaces),
                attachments: attachments
            )

            try await service.createReport(body)
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

struct CrewEntry: Identifiable {
    let id = UUID()
    var tradeName: String
    var headcount: Int = 1

    init(tradeName: String = "", headcount: Int = 1) {
        self.tradeName = tradeName
        self.headcount = headcount
    }
}

struct TradePickerList: View {
    let trades: [ProjectTrade]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [ProjectTrade] {
        if search.isEmpty { return trades }
        return trades.filter {
            $0.vendor.localizedCaseInsensitiveContains(search)
                || $0.scopes.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        List(filtered) { trade in
            Button {
                onSelect(trade.vendor)
                dismiss()
            } label: {
                VStack(alignment: .leading) {
                    Text(trade.vendor).lineLimit(1)
                    if !trade.scopeLine.isEmpty {
                        Text(trade.scopeLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .searchable(text: $search, prompt: "Search trades")
        .navigationTitle("Select Trade")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProjectPickerList: View {
    let projects: [SafetyProject]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [SafetyProject] {
        if search.isEmpty { return projects }
        return projects.filter {
            $0.projectName.localizedCaseInsensitiveContains(search)
                || $0.projectNumber.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(filtered) { project in
            Button {
                selection = project.projectNumber
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.projectName).lineLimit(1)
                        Text(project.projectNumber)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if project.projectNumber == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .searchable(text: $search, prompt: "Search projects")
        .navigationTitle("Select Project")
        .navigationBarTitleDisplayMode(.inline)
    }
}
