import SwiftUI

struct DailyReportFormView: View {
    let service: SafeSpaceService
    @Environment(\.dismiss) private var dismiss

    @State private var projects: [SafetyProject] = []
    @State private var selectedProject = ""
    @State private var reportDate = Date()
    @State private var weather = ""
    @State private var crewLines: [CrewEntry] = [CrewEntry()]
    @State private var workPerformed = ""
    @State private var hazardsObserved = ""
    @State private var toolboxTalkDelivered = false
    @State private var visitors = ""
    @State private var deliveries = ""
    @State private var incidents = false
    @State private var notes = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !selectedProject.isEmpty
            && !weather.trimmingCharacters(in: .whitespaces).isEmpty
            && crewLines.contains { !$0.tradeName.trimmingCharacters(in: .whitespaces).isEmpty }
            && !workPerformed.trimmingCharacters(in: .whitespaces).isEmpty
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
                    DatePicker("Date", selection: $reportDate, displayedComponents: .date)
                    TextField("Weather", text: $weather, prompt: Text("e.g. Sunny · 24°C"))
                }

                Section("Crew") {
                    ForEach($crewLines) { $entry in
                        HStack {
                            TextField("Trade", text: $entry.tradeName)
                            Stepper("\(entry.headcount)", value: $entry.headcount, in: 1...200)
                                .fixedSize()
                        }
                    }
                    .onDelete { crewLines.remove(atOffsets: $0) }

                    Button {
                        crewLines.append(CrewEntry())
                    } label: {
                        Label("Add Trade", systemImage: "plus.circle")
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

                Section("Site Activity") {
                    Toggle("Toolbox talk delivered", isOn: $toolboxTalkDelivered)
                    TextField("Visitors", text: $visitors, prompt: Text("e.g. City inspector (11:00)"))
                    TextField("Deliveries", text: $deliveries, prompt: Text("e.g. 2 skids drywall"))
                    Toggle("Incidents", isOn: $incidents)
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
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
            .task { await loadProjects() }
            .disabled(submitting)
            .interactiveDismissDisabled(submitting)
        }
    }

    private func loadProjects() async {
        projects = (try? await service.projects()) ?? []
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }

        let validCrew = crewLines.filter { !$0.tradeName.trimmingCharacters(in: .whitespaces).isEmpty }
        let body = CreateDailyReportBody(
            projectNumber: selectedProject,
            reportDate: Self.dateString(reportDate),
            weather: weather.trimmingCharacters(in: .whitespaces),
            crew: validCrew.map { .init(tradeName: $0.tradeName.trimmingCharacters(in: .whitespaces),
                                        headcount: $0.headcount) },
            workPerformed: workPerformed.trimmingCharacters(in: .whitespaces),
            hazardsObserved: hazardsObserved.trimmingCharacters(in: .whitespaces),
            toolboxTalkDelivered: toolboxTalkDelivered,
            visitors: visitors.trimmingCharacters(in: .whitespaces),
            deliveries: deliveries.trimmingCharacters(in: .whitespaces),
            incidents: incidents,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )

        do {
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
    var tradeName: String = ""
    var headcount: Int = 1
}
