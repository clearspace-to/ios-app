import Foundation

/// Data source for the safe_space module.
protocol SafeSpaceService {
    func projects() async throws -> [SafetyProject]
    func projectSummary(projectNumber: String) async throws -> ProjectSafetySummary
    func talks() async throws -> [ToolboxTalk]
    func talkDetail(id: String) async throws -> ToolboxTalkDetail
    func submissions() async throws -> [FormSubmission]
    func submissionDetail(id: String) async throws -> FormSubmissionDetail
    func reports() async throws -> [DailyReport]
    func reportDetail(id: String) async throws -> DailyReport
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

    // MARK: - Search
    //
    // safe_space has no search endpoint, so the command bar filters a cached
    // snapshot of the four lists rather than re-fetching on every keystroke.

    func search(query: String) async throws -> [SafetySearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let snapshot = try await Self.index.snapshot(loadedBy: self)

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

    private static let index = SafetySearchIndex()
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
actor SafetySearchIndex {
    struct Snapshot {
        var projects: [SafetyProject] = []
        var talks: [ToolboxTalk] = []
        var forms: [FormSubmission] = []
        var reports: [DailyReport] = []
    }

    private var cached: Snapshot?
    private var fetchedAt: Date?
    private let ttl: TimeInterval = 60

    func snapshot(loadedBy service: LiveSafeSpaceService) async throws -> Snapshot {
        if let cached, let fetchedAt, Date().timeIntervalSince(fetchedAt) < ttl {
            return cached
        }
        async let projects = service.projects()
        async let talks = service.talks()
        async let forms = service.submissions()
        async let reports = service.reports()
        let snapshot = Snapshot(
            projects: try await projects,
            talks: try await talks,
            forms: try await forms,
            reports: try await reports
        )
        cached = snapshot
        fetchedAt = Date()
        return snapshot
    }
}
