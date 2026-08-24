import Foundation

/// The four lists the command bar searches. Split out so the search index —
/// and its tests — depend only on these, not on the whole service.
protocol SafetySearchLists {
    func projects() async throws -> [SafetyProject]
    func talks() async throws -> [ToolboxTalk]
    func submissions() async throws -> [FormSubmission]
    func reports() async throws -> [DailyReport]
}

/// Data source for the safe_space module.
protocol SafeSpaceService: SafetySearchLists {
    func projectSummary(projectNumber: String) async throws -> ProjectSafetySummary
    func projectOverview(projectNumber: String) async throws -> ProjectOverview
    func talkDetail(id: String) async throws -> ToolboxTalkDetail
    func submissionDetail(id: String) async throws -> FormSubmissionDetail
    func reportDetail(id: String) async throws -> DailyReport
    func createReport(_ body: CreateDailyReportBody) async throws
    func createTalk(_ body: CreateToolboxTalkBody) async throws
    func fpuOverview(weekEnding: String) async throws -> FpuWeekOverview
    func fpuForm(projectNumber: String, weekEnding: String) async throws -> FpuEntryForm
    func submitFpu(projectNumber: String, body: SubmitFpuBody) async throws
    func fpuWeeks(projectNumber: String) async throws -> [FpuWeekRow]
    func uploadFpuPhoto(projectNumber: String, filename: String, contentType: String, data: Data) async throws -> FpuAttachment
    func uploadPhoto(scope: String, filename: String, contentType: String, data: Data) async throws -> FpuAttachment
    func scheduleChanges(projectNumber: String) async throws -> ScheduleChanges
    func scheduleMilestones(projectNumber: String) async throws -> [ScheduleMilestone]
    func createScheduleChange(projectNumber: String, body: CreateScheduleChangeBody) async throws
    func search(query: String) async throws -> [SafetySearchHit]
}

struct SafetySearchHit: Identifiable {
    let id: String
    let scope: SafetySearchScope
    let title: String
    var subtitle: String?
    /// Record id used to build the detail route.
    let recordID: String
}

/// Live implementation against https://safe.clearspace.to.
///
/// safe_space already authenticates with `Authorization: Bearer <token>` from the
/// shared Clearspace auth project and gates on `auth_app_access`, so this needed
/// no backend change.
struct LiveSafeSpaceService: SafeSpaceService {
    let api: APIClient

    init(auth: AuthManager = .shared) {
        self.api = APIClient(baseURL: Endpoints.safeSpace, auth: auth)
    }

    // MARK: - Projects

    func projects() async throws -> [SafetyProject] {
        let response: ProjectsListResponse = try await api.get("/api/projects/list")
        return response.projects.map { $0.toModel() }
    }

    func projectSummary(projectNumber: String) async throws -> ProjectSafetySummary {
        let response: ProjectDetailResponse = try await api.get("/api/projects/\(projectNumber)")
        let project = response.project.toModel()
        // This route omits project_name on the nested records — supply the parent's.
        return ProjectSafetySummary(
            project: project,
            talks: response.talks.map { $0.toModel(projectName: project.projectName) },
            forms: response.submissions.map { $0.toModel(projectName: project.projectName) },
            reports: response.dailyReports.map { $0.toModel(projectName: project.projectName) }
        )
    }

    /// Its own request, not folded into projectSummary: this route calls Wrike
    /// and Procore, which are slow and can be down. The record tabs must never
    /// wait on or fail with either.
    func projectOverview(projectNumber: String) async throws -> ProjectOverview {
        let response: ProjectOverviewResponse =
            try await api.get("/api/projects/\(projectNumber)/overview")
        return response.toModel()
    }

    // MARK: - Toolbox talks

    func talks() async throws -> [ToolboxTalk] {
        let response: TalksResponse = try await api.get("/api/talks")
        return response.talks.map { $0.toModel() }
    }

    func talkDetail(id: String) async throws -> ToolboxTalkDetail {
        let response: TalkDetailResponse = try await api.get("/api/talks/\(id)")
        return ToolboxTalkDetail(
            talk: response.talk.toModel(),
            topicBody: response.talk.topic?.body ?? "",
            corElements: response.talk.topic?.corElements ?? [],
            attendees: response.attendance.map { $0.toModel() }
        )
    }

    // MARK: - Forms

    func submissions() async throws -> [FormSubmission] {
        // The submissions list carries project_number but not project_name.
        async let response: SubmissionsResponse = api.get("/api/submissions")
        async let names = projectNames()
        let (list, lookup) = try await (response, names)
        return list.submissions.map { $0.toModel(projectName: lookup[$0.projectNumber]) }
    }

    func submissionDetail(id: String) async throws -> FormSubmissionDetail {
        // No snake_case conversion: `data` is keyed by the form's own field keys.
        async let response: SubmissionDetailResponse =
            api.get("/api/submissions/\(id)", convertSnakeCase: false)
        async let names = projectNames()
        let (detail, lookup) = try await (response, names)
        return detail.submission.toModel(projectName: lookup[detail.submission.projectNumber])
    }

    // MARK: - Daily reports

    func reports() async throws -> [DailyReport] {
        let response: DailyReportsResponse = try await api.get("/api/daily-reports")
        return response.reports.map { $0.toModel() }
    }

    func reportDetail(id: String) async throws -> DailyReport {
        let response: DailyReportResponse = try await api.get("/api/daily-reports/\(id)")
        return response.report.toModel()
    }

    // MARK: - Create

    func createReport(_ body: CreateDailyReportBody) async throws {
        let _: CreateRecordResponse = try await api.post("/api/daily-reports", body: body)
    }

    func createTalk(_ body: CreateToolboxTalkBody) async throws {
        let envelope: CreateTopicEnvelope = try await api.post("/api/topics", body: body.topic)
        let talkBody = CreateTalkRequestBody(
            topicId: envelope.topic.id,
            projectNumber: body.projectNumber,
            talkDate: body.talkDate,
            deliveredBy: body.deliveredBy
        )
        let _: CreateRecordResponse = try await api.post("/api/talks", body: talkBody)
    }

    // MARK: - FPUs
    //
    // FPU routes are decoded WITHOUT snake_case conversion: entry/previous/values
    // are keyed by the shared table's column names, which must stay verbatim to
    // match the `columns` keys.

    func fpuOverview(weekEnding: String) async throws -> FpuWeekOverview {
        let response: FpuOverviewResponse =
            try await api.get("/api/fpus", query: ["week_ending": weekEnding], convertSnakeCase: false)
        return response.toModel()
    }

    func fpuForm(projectNumber: String, weekEnding: String) async throws -> FpuEntryForm {
        let response: FpuFormResponse =
            try await api.get("/api/fpus/\(projectNumber)", query: ["week_ending": weekEnding],
                              convertSnakeCase: false)
        return response.toModel()
    }

    func submitFpu(projectNumber: String, body: SubmitFpuBody) async throws {
        let _: FpuSubmitResponse =
            try await api.put("/api/fpus/\(projectNumber)", body: body, convertSnakeCase: false)
    }

    func fpuWeeks(projectNumber: String) async throws -> [FpuWeekRow] {
        let response: FpuWeeksResponse =
            try await api.get("/api/fpus/\(projectNumber)/weeks", convertSnakeCase: false)
        return response.toModel()
    }

    /// Two-step upload shared with the web app: the API signs a Storage URL,
    /// the client PUTs the bytes straight to it (Vercel caps request bodies,
    /// so files never pass through the API).
    func uploadPhoto(scope: String, filename: String, contentType: String, data: Data) async throws -> FpuAttachment {
        let sign: SignUploadResponse = try await api.post(
            "/api/uploads/sign",
            body: SignUploadBody(name: filename, type: contentType, size: data.count,
                                 scope: scope))
        guard let url = URL(string: sign.signedUrl) else { throw APIError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return FpuAttachment(path: sign.path, name: filename, size: data.count,
                             type: contentType, kind: "photo")
    }

    func uploadFpuPhoto(projectNumber: String, filename: String, contentType: String, data: Data) async throws -> FpuAttachment {
        try await uploadPhoto(scope: "fpus/\(projectNumber)", filename: filename,
                              contentType: contentType, data: data)
    }

    // MARK: - Schedule change requests
    //
    // Fixed snake_case keys, so these use the default conversion. Status lives
    // in Procore and is merged on read; there is no edit/withdraw API.
    // Requests target one of the three movable milestones, not any task.

    func scheduleChanges(projectNumber: String) async throws -> ScheduleChanges {
        let response: ScheduleChangesResponse =
            try await api.get("/api/projects/\(projectNumber)/schedule-changes")
        return response.toModel()
    }

    func scheduleMilestones(projectNumber: String) async throws -> [ScheduleMilestone] {
        let response: ScheduleMilestonesResponse =
            try await api.get("/api/projects/\(projectNumber)/schedule-milestones")
        guard response.linked else { throw APIError.server(status: 400, message: "This project isn't linked to Procore.") }
        return response.milestones.map { $0.toModel() }
    }

    func createScheduleChange(projectNumber: String, body: CreateScheduleChangeBody) async throws {
        let _: CreateScheduleChangeResponse =
            try await api.post("/api/projects/\(projectNumber)/schedule-changes", body: body)
    }

    // MARK: - Search
    //
    // safe_space has no search endpoint, so the command bar filters a cached
    // snapshot of the four lists rather than re-fetching on every keystroke.

    func search(query: String) async throws -> [SafetySearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let snapshot = await Self.index.snapshot(loadedBy: self)

        func matches(_ values: String?...) -> Bool {
            values.compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(q) }
        }

        var hits: [SafetySearchHit] = []
        hits += snapshot.projects
            .filter { matches($0.projectName, $0.projectNumber, $0.pmName, $0.siteSuperName) }
            .map { SafetySearchHit(id: "project-\($0.projectNumber)", scope: .projects,
                                   title: $0.projectName,
                                   subtitle: "\($0.projectNumber) · \($0.siteSuperName ?? "Unassigned")",
                                   recordID: $0.projectNumber) }
        hits += snapshot.talks
            .filter { matches($0.topicName, $0.projectName, $0.deliveredBy) }
            .map { SafetySearchHit(id: "talk-\($0.id)", scope: .talks, title: $0.topicName,
                                   subtitle: "\($0.projectName) · \($0.talkDate)", recordID: $0.id) }
        hits += snapshot.forms
            .filter { matches($0.templateName, $0.projectName, $0.submittedBy) }
            .map { SafetySearchHit(id: "form-\($0.id)", scope: .forms, title: $0.templateName,
                                   subtitle: "\($0.projectName) · \($0.submittedAt)", recordID: $0.id) }
        hits += snapshot.reports
            .filter { matches($0.projectName, $0.reportDate, $0.workPerformed, $0.submittedBy) }
            .map { SafetySearchHit(id: "report-\($0.id)", scope: .reports,
                                   title: "\($0.projectName) — \($0.reportDate)",
                                   subtitle: "\($0.submittedBy) · \($0.crewSummary)", recordID: $0.id) }
        return hits
    }

    // MARK: - Caches

    static let index = SafetySearchIndex()
    private static let names = ProjectNameCache()

    private func projectNames() async throws -> [String: String] {
        try await Self.names.lookup(loadedBy: self)
    }
}

/// Project number -> name, so records that only carry a number can show one.
actor ProjectNameCache {
    private var cached: [String: String]?
    private var fetchedAt: Date?
    private let ttl: TimeInterval = 300

    func lookup(loadedBy service: LiveSafeSpaceService) async throws -> [String: String] {
        if let cached, let fetchedAt, Date().timeIntervalSince(fetchedAt) < ttl {
            return cached
        }
        let projects = try await service.projects()
        let lookup = Dictionary(projects.map { ($0.projectNumber, $0.projectName) },
                                uniquingKeysWith: { first, _ in first })
        cached = lookup
        fetchedAt = Date()
        return lookup
    }
}

/// One snapshot of every searchable list, refreshed at most once a minute.
///
/// Two things this has to survive, because the command bar re-searches on every
/// keystroke:
///
/// 1. **Cancellation.** SwiftUI cancels the previous search task when the query
///    changes, which cancels the URLSession calls underneath it. So the load runs
///    in one shared `Task` that outlives whichever keystroke started it — later
///    keystrokes await the same task instead of restarting four requests from
///    scratch and never finishing.
/// 2. **A partial outage.** Each list is loaded independently: `/api/talks` being
///    down must not make a project search come back empty.
actor SafetySearchIndex {
    struct Snapshot {
        var projects: [SafetyProject] = []
        var talks: [ToolboxTalk] = []
        var forms: [FormSubmission] = []
        var reports: [DailyReport] = []
    }

    private var cached: Snapshot?
    private var expiresAt: Date?
    private var inFlight: Task<Snapshot, Never>?

    private let ttl: TimeInterval = 60
    /// A load that lost a list is retried soon rather than serving the hole for
    /// a full minute.
    private let partialTTL: TimeInterval = 10

    func snapshot(loadedBy service: SafetySearchLists) async -> Snapshot {
        if let cached, let expiresAt, Date() < expiresAt { return cached }
        return await (inFlight ?? load(from: service)).value
    }

    private func load(from service: SafetySearchLists) -> Task<Snapshot, Never> {
        let previous = cached
        let task = Task { () -> Snapshot in
            async let projects = try? await service.projects()
            async let talks = try? await service.talks()
            async let forms = try? await service.submissions()
            async let reports = try? await service.reports()

            let loadedProjects = await projects
            let loadedTalks = await talks
            let loadedForms = await forms
            let loadedReports = await reports

            let snapshot = Snapshot(
                projects: loadedProjects ?? previous?.projects ?? [],
                talks: loadedTalks ?? previous?.talks ?? [],
                forms: loadedForms ?? previous?.forms ?? [],
                reports: loadedReports ?? previous?.reports ?? []
            )
            let complete = loadedProjects != nil && loadedTalks != nil
                && loadedForms != nil && loadedReports != nil
            self.store(snapshot, complete: complete)
            return snapshot
        }
        inFlight = task
        return task
    }

    private func store(_ snapshot: Snapshot, complete: Bool) {
        cached = snapshot
        expiresAt = Date().addingTimeInterval(complete ? ttl : partialTTL)
        inFlight = nil
    }

    /// Kick off a load if the cache is cold, so results are ready by the time
    /// the user finishes typing.
    func warm(using service: SafetySearchLists) {
        guard cached == nil || (expiresAt.map { Date() >= $0 } ?? true) else { return }
        guard inFlight == nil else { return }
        _ = load(from: service)
    }

    /// Age the cache out so a test can force the next reload.
    func expireForTesting() {
        expiresAt = .distantPast
    }
}
