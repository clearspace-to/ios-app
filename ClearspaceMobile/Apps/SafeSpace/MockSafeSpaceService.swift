import Foundation

/// Sample safety data so every screen is navigable before the API is wired up.
struct MockSafeSpaceService: SafeSpaceService {

    static let projects: [SafetyProject] = [
        SafetyProject(projectNumber: "24-118", projectName: "Riverside Tower — Floors 8-12", status: "Active",
                      pmName: "Dana Whitfield", siteSuperName: "Marco Ruiz",
                      talkCount: 12, formCount: 8, reportCount: 34),
        SafetyProject(projectNumber: "24-092", projectName: "Lakeshore Campus Phase 2", status: "Active",
                      pmName: "Priya Raman", siteSuperName: "Tom Beaudry",
                      talkCount: 9, formCount: 5, reportCount: 41),
        SafetyProject(projectNumber: "25-004", projectName: "Midtown Medical Suites", status: "Active",
                      pmName: "Alex Nguyen", siteSuperName: "Unassigned",
                      talkCount: 4, formCount: 3, reportCount: 11),
        SafetyProject(projectNumber: "24-077", projectName: "Gateway Logistics Hub", status: "Active",
                      pmName: "Dana Whitfield", siteSuperName: "Ken Osei",
                      talkCount: 15, formCount: 11, reportCount: 52),
        SafetyProject(projectNumber: "25-011", projectName: "Union Station Retail Pods", status: "Active",
                      pmName: "Priya Raman", siteSuperName: "Marco Ruiz",
                      talkCount: 2, formCount: 1, reportCount: 6),
    ]

    static let talks: [ToolboxTalk] = [
        ToolboxTalk(id: "t1", topicName: "Ladder Safety & Three-Point Contact", projectNumber: "24-118",
                    projectName: "Riverside Tower — Floors 8-12", talkDate: "Aug 10, 2026",
                    deliveredBy: "Marco Ruiz", status: .open, attendanceCount: 14),
        ToolboxTalk(id: "t2", topicName: "Silica Dust Control", projectNumber: "24-077",
                    projectName: "Gateway Logistics Hub", talkDate: "Aug 10, 2026",
                    deliveredBy: "Ken Osei", status: .closed, attendanceCount: 22),
        ToolboxTalk(id: "t3", topicName: "Working at Heights — Tie-Off Points", projectNumber: "24-092",
                    projectName: "Lakeshore Campus Phase 2", talkDate: "Aug 11, 2026",
                    deliveredBy: "Tom Beaudry", status: .scheduled, attendanceCount: 0),
        ToolboxTalk(id: "t4", topicName: "Heat Stress & Hydration", projectNumber: "24-118",
                    projectName: "Riverside Tower — Floors 8-12", talkDate: "Aug 7, 2026",
                    deliveredBy: "Marco Ruiz", status: .closed, attendanceCount: 16),
        ToolboxTalk(id: "t5", topicName: "Housekeeping & Slip/Trip Hazards", projectNumber: "25-004",
                    projectName: "Midtown Medical Suites", talkDate: "Aug 6, 2026",
                    deliveredBy: "Alex Nguyen", status: .closed, attendanceCount: 8),
    ]

    static let submissions: [FormSubmission] = [
        FormSubmission(id: "f1", templateName: "Site Safety Inspection", category: "Inspection",
                       projectNumber: "24-118", projectName: "Riverside Tower — Floors 8-12",
                       submittedBy: "marco.ruiz@clearspace.to", source: .sso, status: .submitted,
                       submittedAt: "Aug 10, 2026 · 3:42 PM"),
        FormSubmission(id: "f2", templateName: "Hot Work Permit", category: "Permit",
                       projectNumber: "24-077", projectName: "Gateway Logistics Hub",
                       submittedBy: "Field link", source: .field, status: .reviewed,
                       submittedAt: "Aug 10, 2026 · 11:08 AM"),
        FormSubmission(id: "f3", templateName: "Equipment Pre-Use Checklist", category: "Equipment",
                       projectNumber: "24-092", projectName: "Lakeshore Campus Phase 2",
                       submittedBy: "tom.beaudry@clearspace.to", source: .sso, status: .submitted,
                       submittedAt: "Aug 9, 2026 · 7:15 AM"),
        FormSubmission(id: "f4", templateName: "Near Miss Report", category: "Incident",
                       projectNumber: "24-118", projectName: "Riverside Tower — Floors 8-12",
                       submittedBy: "Field link", source: .field, status: .reviewed,
                       submittedAt: "Aug 8, 2026 · 2:30 PM"),
    ]

    static let reports: [DailyReport] = [
        DailyReport(id: "d1", projectNumber: "24-118", projectName: "Riverside Tower — Floors 8-12",
                    reportDate: "Aug 10, 2026", weather: "Sunny · 24°C",
                    crew: [CrewLine(tradeName: "Drywall", headcount: 8),
                           CrewLine(tradeName: "Electrical", headcount: 4),
                           CrewLine(tradeName: "Mechanical", headcount: 3)],
                    workPerformed: "Boarding complete on floor 10 north. Began taping floor 9. Electrical rough-in continued in the east core.",
                    hazardsObserved: "Housekeeping in the west stair — debris cleared by end of shift.",
                    toolboxTalkDelivered: true, visitors: "City inspector (11:00)", deliveries: "2 skids drywall, 1 pallet fixtures",
                    incidents: false, notes: "Crane down for scheduled maintenance tomorrow.",
                    attachmentCount: 6, submittedBy: "Marco Ruiz"),
        DailyReport(id: "d2", projectNumber: "24-077", projectName: "Gateway Logistics Hub",
                    reportDate: "Aug 10, 2026", weather: "Overcast · 19°C",
                    crew: [CrewLine(tradeName: "Concrete", headcount: 12),
                           CrewLine(tradeName: "Steel", headcount: 6)],
                    workPerformed: "Slab pour in bay 3 completed. Steel erection continued on the north elevation.",
                    hazardsObserved: "Wet slab barricaded and signed.",
                    toolboxTalkDelivered: true, visitors: "None", deliveries: "6 concrete trucks",
                    incidents: false, notes: "", attachmentCount: 11, submittedBy: "Ken Osei"),
        DailyReport(id: "d3", projectNumber: "24-092", projectName: "Lakeshore Campus Phase 2",
                    reportDate: "Aug 9, 2026", weather: "Rain · 16°C",
                    crew: [CrewLine(tradeName: "Sitework", headcount: 5)],
                    workPerformed: "Excavation paused for weather. Pumps run on the south pit.",
                    hazardsObserved: "Standing water near the trench — pumped and re-shored.",
                    toolboxTalkDelivered: false, visitors: "None", deliveries: "None",
                    incidents: true, notes: "Minor first-aid: cut hand, treated on site, no lost time.",
                    attachmentCount: 3, submittedBy: "Tom Beaudry"),
    ]

    /// The real division list, verbatim from the API's FPU_COLUMNS.
    static let fpuColumns: [FpuColumn] = [
        FpuColumn(key: "a1_demolition", label: "A1 — Demolition"),
        FpuColumn(key: "a2_partitions", label: "A2 — Partitions"),
        FpuColumn(key: "a3_ceiling", label: "A3 — Ceiling"),
        FpuColumn(key: "a4_electrical", label: "A4 — Electrical"),
        FpuColumn(key: "a5_plumbing", label: "A5 — Plumbing"),
        FpuColumn(key: "a6_hvac", label: "A6 — HVAC"),
        FpuColumn(key: "a7_flooring", label: "A7 — Flooring"),
        FpuColumn(key: "a8_glazing", label: "A8 — Glazing"),
        FpuColumn(key: "a9_life_safety", label: "A9 — Life Safety"),
        FpuColumn(key: "a10_wall_finishes", label: "A10 — Wall Finishes"),
        FpuColumn(key: "a11_doors_security", label: "A11 — Doors & Security"),
        FpuColumn(key: "a12_millwork_kitchen", label: "A12 — Millwork & Kitchen"),
        FpuColumn(key: "c2_networking", label: "C2 — Networking"),
        FpuColumn(key: "c3_structured_cabling", label: "C3 — Structured Cabling"),
    ]

    static let fpuPreviousValues: [String: Int] = [
        "a1_demolition": 100, "a2_partitions": 85, "a3_ceiling": 60,
        "a4_electrical": 55, "a5_plumbing": 50, "a6_hvac": 45,
        "a7_flooring": 20, "a8_glazing": 10, "a9_life_safety": 30,
        "a10_wall_finishes": 5, "a11_doors_security": 0,
        "a12_millwork_kitchen": 0, "c2_networking": 15, "c3_structured_cabling": 15,
    ]

    // MARK: - SafeSpaceService

    func projects() async throws -> [SafetyProject] { Self.projects }

    func projectSummary(projectNumber: String) async throws -> ProjectSafetySummary {
        let project = Self.projects.first { $0.projectNumber == projectNumber } ?? Self.projects[0]
        return ProjectSafetySummary(
            project: project,
            talks: Self.talks.filter { $0.projectNumber == project.projectNumber },
            forms: Self.submissions.filter { $0.projectNumber == project.projectNumber },
            reports: Self.reports.filter { $0.projectNumber == project.projectNumber }
        )
    }

    func projectOverview(projectNumber: String) async throws -> ProjectOverview {
        // 25-004 deliberately has no Procore link, so the "unavailable" state is
        // reachable in previews without turning the network off.
        let linked = projectNumber != "25-004"
        return ProjectOverview(
            keyDates: [
                ProjectKeyDate(label: "Construction start", date: "Jun 9, 2026"),
                ProjectKeyDate(label: "Rough inspection pass", date: "Jul 14, 2026", passed: true),
                ProjectKeyDate(label: "Construction completion", date: "Sep 25, 2026"),
                ProjectKeyDate(label: "Takeover", date: "Oct 23, 2026"),
            ],
            pmName: "Dana Whitfield",
            designerName: "Lucila Mckinlay",
            siteSuperName: "Marco Ruiz",
            procoreURL: linked ? URL(string: "https://us02.procore.com/1/project/home") : nil,
            trades: linked ? [
                ProjectTrade(vendor: "Vertex Drywall", scopes: ["Drywall, Ceiling and Acoustic Walls"],
                             poNumbers: ["PO-24118-013"]),
                ProjectTrade(vendor: "Nova Electric", scopes: ["Electrical Work"],
                             poNumbers: ["PO-24118-012"]),
                ProjectTrade(vendor: "Peak Mechanical", scopes: ["HVAC & Plumbing Works"],
                             poNumbers: ["PO-24118-005"]),
                ProjectTrade(vendor: "Arcamm Fire Protection", scopes: ["Fire Protection Works"],
                             poNumbers: ["PO-24118-008"]),
            ] : nil
        )
    }

    func talks() async throws -> [ToolboxTalk] { Self.talks }

    func talkDetail(id: String) async throws -> ToolboxTalkDetail {
        let talk = Self.talks.first { $0.id == id } ?? Self.talks[0]
        let names = ["Luis Ferreira", "Dan Okoro", "Sam Whitfield", "Priya Raman", "Jake Molnar",
                     "Chris Vaillancourt", "Ahmed Rahim", "Nina Kovacs"]
        let employers = ["Vertex Drywall", "Nova Electric", "Vertex Drywall", "Clearspace",
                         "Peak Mechanical", "Nova Electric", "Peak Mechanical", "Vertex Drywall"]
        let attendees = (0..<min(talk.attendanceCount, names.count)).map { i in
            TalkAttendee(id: "a\(i)", name: names[i], employerLabel: employers[i],
                         signedAt: "\(talk.talkDate) · 7:0\(i) AM")
        }
        return ToolboxTalkDetail(
            talk: talk,
            topicBody: "Review the three-point contact rule before every climb. Inspect the ladder for damage, set it at a 4:1 angle, tie off the top where possible, and never stand above the second-from-top rung. Report damaged ladders to the site super immediately.",
            corElements: [3, 7],
            attendees: attendees
        )
    }

    func submissions() async throws -> [FormSubmission] { Self.submissions }

    func submissionDetail(id: String) async throws -> FormSubmissionDetail {
        let submission = Self.submissions.first { $0.id == id } ?? Self.submissions[0]
        return FormSubmissionDetail(
            submission: submission,
            answers: [
                FormAnswer(key: "area", label: "Area inspected", value: "Floors 8–12, north core"),
                FormAnswer(key: "ppe", label: "PPE compliance", value: "Compliant"),
                FormAnswer(key: "housekeeping", label: "Housekeeping", value: "Needs attention"),
                FormAnswer(key: "guardrails", label: "Guardrails in place", value: "Yes"),
                FormAnswer(key: "corrective", label: "Corrective actions",
                           value: "Debris cleared from west stair; reminder issued to drywall crew."),
                FormAnswer(key: "photos", label: "Photos", value: "3 attached"),
            ],
            hasSignature: true
        )
    }

    func createReport(_ body: CreateDailyReportBody) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    // MARK: - FPUs

    func fpuOverview(weekEnding: String) async throws -> FpuWeekOverview {
        FpuWeekOverview(weekEnding: weekEnding, rows: [
            FpuProjectWeek(projectNumber: "24-118", projectName: "Riverside Tower — Floors 8-12",
                           siteSuperName: "Marco Ruiz", mine: true, state: .outstanding,
                           overall: nil, updatedAt: nil),
            FpuProjectWeek(projectNumber: "24-092", projectName: "Lakeshore Campus Phase 2",
                           siteSuperName: "Tom Beaudry", mine: false, state: .draft,
                           overall: 46, updatedAt: "Aug 21, 2026 · 7:40 AM"),
            FpuProjectWeek(projectNumber: "25-004", projectName: "Midtown Medical Suites",
                           siteSuperName: nil, mine: false, state: .filedSafeSpace,
                           overall: 62, updatedAt: "Aug 21, 2026 · 4:05 PM"),
            FpuProjectWeek(projectNumber: "24-077", projectName: "Gateway Logistics Hub",
                           siteSuperName: "Ken Osei", mine: false, state: .filedProcore,
                           overall: 78, updatedAt: "Aug 21, 2026 · 2:12 PM"),
            FpuProjectWeek(projectNumber: "25-011", projectName: "Union Station Retail Pods",
                           siteSuperName: "Marco Ruiz", mine: true, state: .done,
                           overall: 100, updatedAt: nil),
        ])
    }

    func fpuForm(projectNumber: String, weekEnding: String) async throws -> FpuEntryForm {
        let project = Self.projects.first { $0.projectNumber == projectNumber } ?? Self.projects[0]
        return FpuEntryForm(
            weekEnding: weekEnding,
            projectNumber: project.projectNumber,
            projectName: project.projectName,
            columns: Self.fpuColumns,
            prefill: Self.fpuPreviousValues,
            previous: Self.fpuPreviousValues,
            comment: "",
            existingAttachments: [],
            entrySource: nil
        )
    }

    func submitFpu(projectNumber: String, body: SubmitFpuBody) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    func fpuWeeks(projectNumber: String) async throws -> [FpuWeekRow] {
        [
            FpuWeekRow(weekEnding: FpuWeeks.currentFriday(), filed: false, state: .outstanding,
                       overall: nil, hasComment: false, attachmentCount: 0, submittedBy: nil),
            FpuWeekRow(weekEnding: FpuWeeks.shifted(FpuWeeks.currentFriday(), byWeeks: -1),
                       filed: true, state: .filedSafeSpace, overall: 58, hasComment: true,
                       attachmentCount: 4, submittedBy: "marco.ruiz@clearspace.to"),
            FpuWeekRow(weekEnding: FpuWeeks.shifted(FpuWeeks.currentFriday(), byWeeks: -2),
                       filed: true, state: .filedProcore, overall: 52, hasComment: false,
                       attachmentCount: 0, submittedBy: nil),
            FpuWeekRow(weekEnding: FpuWeeks.shifted(FpuWeeks.currentFriday(), byWeeks: -3),
                       filed: true, state: .filedProcore, overall: 45, hasComment: false,
                       attachmentCount: 0, submittedBy: nil),
        ]
    }

    func uploadFpuPhoto(projectNumber: String, filename: String, contentType: String, data: Data) async throws -> FpuAttachment {
        try await Task.sleep(for: .milliseconds(300))
        return FpuAttachment(path: "fpus/\(projectNumber)/mock-\(filename)", name: filename,
                             size: data.count, type: contentType, kind: "photo")
    }

    func createTalk(_ body: CreateToolboxTalkBody) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    func reports() async throws -> [DailyReport] { Self.reports }

    func reportDetail(id: String) async throws -> DailyReport {
        Self.reports.first { $0.id == id } ?? Self.reports[0]
    }

    func search(query: String) async throws -> [SafetySearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        func matches(_ values: String...) -> Bool {
            values.contains { $0.localizedCaseInsensitiveContains(q) }
        }

        var hits: [SafetySearchHit] = []
        hits += Self.projects.filter { matches($0.projectName, $0.projectNumber, $0.pmName ?? "", $0.siteSuperName ?? "") }
            .map { SafetySearchHit(id: "project-\($0.projectNumber)", scope: .projects, title: $0.projectName,
                                   subtitle: "\($0.projectNumber) · \($0.siteSuperName ?? "Unassigned")",
                                   recordID: $0.projectNumber) }
        hits += Self.talks.filter { matches($0.topicName, $0.projectName, $0.deliveredBy) }
            .map { SafetySearchHit(id: "talk-\($0.id)", scope: .talks, title: $0.topicName,
                                   subtitle: "\($0.projectName) · \($0.talkDate)", recordID: $0.id) }
        hits += Self.submissions.filter { matches($0.templateName, $0.projectName, $0.category ?? "", $0.submittedBy) }
            .map { SafetySearchHit(id: "form-\($0.id)", scope: .forms, title: $0.templateName,
                                   subtitle: "\($0.projectName) · \($0.submittedAt)", recordID: $0.id) }
        hits += Self.reports.filter { matches($0.projectName, $0.reportDate, $0.workPerformed, $0.submittedBy) }
            .map { SafetySearchHit(id: "report-\($0.id)", scope: .reports, title: "\($0.projectName) — \($0.reportDate)",
                                   subtitle: "\($0.submittedBy) · \($0.crewSummary)", recordID: $0.id) }
        return hits
    }
}
