import Foundation

// Wire types for safe_space's schedule change routes. All keys are fixed
// snake_case (no dynamic keys), so these use the client's default snake_case
// conversion — unlike the FPU routes.

// MARK: - GET /api/projects/<project>/schedule-milestones

struct ScheduleMilestonesResponse: Decodable {
    let linked: Bool
    let milestones: [ScheduleMilestoneDTO]
}

struct ScheduleMilestoneDTO: Decodable {
    let key: String
    let label: String
    let taskId: Int
    let taskName: String
    let date: String?

    func toModel() -> ScheduleMilestone {
        ScheduleMilestone(key: key, label: label, taskId: taskId,
                          taskName: taskName, date: date)
    }
}

// MARK: - GET /api/projects/<project>/schedule-changes

struct ScheduleChangesResponse: Decodable {
    let linked: Bool
    let available: Bool
    let changes: [ScheduleChangeDTO]

    func toModel() -> ScheduleChanges {
        ScheduleChanges(linked: linked, available: available,
                        changes: changes.map { $0.toModel() })
    }
}

struct ScheduleChangeDTO: Decodable {
    let procoreRcId: Int
    let status: String?
    let taskName: String?
    let summary: String?
    let reason: String?
    let notes: String?
    let filedBy: String?
    let requestedBy: String?
    let createdAt: String?

    func toModel() -> ScheduleChange {
        ScheduleChange(
            procoreRcId: procoreRcId,
            status: status ?? "",
            taskName: taskName ?? "",
            summary: summary ?? "",
            reason: reason ?? "",
            notes: notes ?? "",
            filedBy: filedBy ?? "",
            requestedBy: requestedBy ?? "",
            createdAt: createdAt.map { SafetyDates.stamp($0) }
        )
    }
}

// MARK: - POST /api/projects/<project>/schedule-changes

/// Just "which milestone, what new date" — the API expands the single date into
/// Procore's start and finish itself, since milestones are single-day.
struct CreateScheduleChangeBody: Encodable {
    let taskId: Int
    let newDate: String
    let reason: String
    let notes: String
}

/// POST response — decoded only to confirm the request landed. (The key is
/// "report", not "request" — the API reuses the daily-report response shape.)
struct CreateScheduleChangeResponse: Decodable {
    let created: Bool
}
