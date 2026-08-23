import Foundation

// MARK: - safe_space schedule change requests domain models
// Mirrors frontend/src/pages/schedule in the safe_space repo. Requests file
// straight into Procore's Schedule tool — the one Procore write in safe_space.
// Status lives in Procore and is merged live on read; there is no edit,
// withdraw or review API, so filing is deliberately confirm-y in the UI.

/// One schedule task from Procore — the target of a change request.
struct ScheduleTask: Identifiable, Hashable {
    let id: Int
    let name: String
    let start: String?
    let finish: String?
    let percentage: Double?

    /// "2026-09-01 → 2026-09-15 · 40% complete" — the picker's reference line.
    var currentLine: String {
        var line = "\(start ?? "—") → \(finish ?? "—")"
        if let percentage { line += " · \(Int(percentage.rounded()))% complete" }
        return line
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
