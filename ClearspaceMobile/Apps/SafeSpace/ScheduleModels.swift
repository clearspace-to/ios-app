import Foundation

// MARK: - safe_space schedule change requests domain models
// Mirrors frontend/src/pages/schedule in the safe_space repo. Requests file
// straight into Procore's Schedule tool — the one Procore write in safe_space.
// Status lives in Procore and is merged live on read; there is no edit,
// withdraw or review API, so filing is deliberately confirm-y in the UI.

/// One of the three date-movable Procore milestones — the target of a change
/// request. safe_space deliberately exposes only these three (rough
/// inspections, construction completion, takeover) rather than the whole
/// 180-row task list. Milestones are single-day, so there is one date, not a
/// start/finish range and no percent complete.
struct ScheduleMilestone: Identifiable, Hashable {
    var id: Int { taskId }
    /// Stable key from the API ("construction_completion").
    let key: String
    /// safe_space's own label, not Procore's raw task name.
    let label: String
    /// The Procore schedule task id the change request is filed against.
    let taskId: Int
    let taskName: String
    let date: String?

    /// "currently Sep 15, 2026" — the picker's reference line.
    var currentLine: String {
        guard let date, !date.isEmpty else { return "no date on the schedule" }
        return "currently \(SafetyDates.day(date))"
    }
}

/// One row of a project's change-request history: Procore's live status merged
/// with our snapshot of what was asked (Procore's own list is nearly empty).
struct ScheduleChange: Identifiable {
    var id: Int { procoreRcId }
    let procoreRcId: Int
    /// An open string, not a closed enum — Procore owns the vocabulary.
    let status: String
    let taskName: String
    let summary: String
    let reason: String
    let notes: String
    /// Who filed it from this app; empty for requests made directly in Procore.
    let filedBy: String
    /// Procore's attribution line — the fallback when filedBy is empty.
    let requestedBy: String
    let createdAt: String?

    var statusBadge: String { status.isEmpty ? "Unknown" : status.capitalized }
    var byLine: String {
        if !filedBy.isEmpty { return filedBy }
        if !requestedBy.isEmpty { return requestedBy }
        return "—"
    }
}

/// A project's schedule-change history plus the two Procore health flags.
struct ScheduleChanges {
    /// The project has a Procore id at all.
    let linked: Bool
    /// Procore answered just now — false shows a "temporarily unavailable" note.
    let available: Bool
    let changes: [ScheduleChange]
}
