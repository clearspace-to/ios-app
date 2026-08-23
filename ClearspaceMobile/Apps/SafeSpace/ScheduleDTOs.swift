import Foundation

// Wire types for safe_space's schedule change routes. All keys are fixed
// snake_case (no dynamic keys), so these use the client's default snake_case
// conversion — unlike the FPU routes.

// MARK: - GET /api/projects/<project>/schedule-tasks

struct ScheduleTasksResponse: Decodable {
    let linked: Bool
    let tasks: [ScheduleTaskDTO]
}

struct ScheduleTaskDTO: Decodable {
    let id: Int
    let name: String
    let start: String?
    let finish: String?
    let percentage: Double?

    func toModel() -> ScheduleTask {
        ScheduleTask(id: id, name: name, start: start, finish: finish, percentage: percentage)
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

struct CreateScheduleChangeBody: Encodable {
    let taskId: Int
    let newStart: String?
    let newFinish: String?
    let newPercentage: Double?
    let otherChange: String
    let reason: String
    let notes: String
}

/// POST response — decoded only to confirm the request landed. (The key is
/// "report", not "request" — the API reuses the daily-report response shape.)
struct CreateScheduleChangeResponse: Decodable {
    let created: Bool
}
