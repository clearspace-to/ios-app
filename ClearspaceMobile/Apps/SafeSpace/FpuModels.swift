import Foundation

// MARK: - safe_space FPU (Field Progress Update) domain models
// Mirrors frontend/src/pages/fpus in the safe_space repo. The trade percentages
// live in the shared fpu_project_executions table (also fed by Procore); the
// comment, photos and draft state live in safe_space's own fpu_reports table.

/// Where a (project, week) stands. Derivation order mirrors the web app:
/// a filed row wins, then a draft, then the done/expected flags.
enum FpuState: Equatable {
    case filedSafeSpace
    case filedProcore
    case draft
    case outstanding
    case done
    case notStarted

    static func derive(entrySource: String?, reportStatus: String?, done: Bool, expected: Bool) -> FpuState {
        if let entrySource { return entrySource == "safe_space" ? .filedSafeSpace : .filedProcore }
        if reportStatus == "draft" { return .draft }
        if done { return .done }
        if expected { return .outstanding }
        return .notStarted
    }

    /// Badge text; nil renders no badge.
    var badge: String? {
        switch self {
        case .filedSafeSpace: return "Filed"
        case .filedProcore: return "Procore"
        case .draft: return "Draft"
        case .outstanding: return "Outstanding"
        case .done: return "Done"
        case .notStarted: return nil
        }
    }

    /// Dashboard sort: what needs attention first.
    var rank: Int {
        switch self {
        case .outstanding: return 0
        case .draft: return 1
        case .filedSafeSpace, .filedProcore: return 2
        case .notStarted: return 3
        case .done: return 4
        }
    }

    /// Status-filter bucket for the FpusView filter chips. Rows not expected
    /// this week (`notStarted`) have no bucket and drop out of any status filter.
    var filterCategory: String? {
        switch self {
        case .outstanding: return "Outstanding"
        case .draft: return "Draft"
        case .filedSafeSpace, .filedProcore, .done: return "Complete"
        case .notStarted: return nil
        }
    }
}

/// One project's row on the weekly FPU dashboard.
struct FpuProjectWeek: Identifiable {
    var id: String { projectNumber }
    let projectNumber: String
    let projectName: String
    let siteSuperName: String?
    /// The signed-in user is this project's site super.
    let mine: Bool
    let state: FpuState
    /// Mean of the answered trade percentages, 0–100.
    let overall: Int?
    let updatedAt: String?
}

struct FpuWeekOverview {
    let weekEnding: String
    let rows: [FpuProjectWeek]
}

/// One trade division on the FPU form. Keys are the shared table's column
/// names; the list comes from the API so the app never hardcodes it.
struct FpuColumn: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
}

/// The ±5% stepping rule for one division.
///
/// Progress doesn't run backwards, so last week's figure is the floor the
/// steppers work above: a step down stops ON it rather than skipping past it,
/// and once the value is sitting on the floor there is nowhere left to go and
/// the minus is greyed out. Mirrors the web form's `TradeRow`, including the
/// off-grid case that its first version got wrong — a division nudged to 82
/// with last week at 80 can still come back to 80.
///
/// The floor binds TYPING here too, which is a deliberate divergence from the
/// web form: on the web a typed value is free, as the escape hatch for a week
/// filed wrong. On a phone the only way to correct a bad prior week is to go
/// under last week, and per Mark (2026-08-24) the phone must not be able to do
/// that at all — a super in the field can only move progress forward, and
/// corrections happen on the web. A typed value below the floor is REFUSED
/// with a message rather than quietly pulled up, so the super sees why the
/// number they entered didn't stick. Clearing a division to blank is still
/// allowed: that files no answer, not a lower number.
struct FpuStep {
    /// Last week's percentage. nil = no history, which floors the division at 0.
    let previous: Int?
    /// What's in the field now; nil when unset.
    let value: Int?

    var floor: Int { previous ?? 0 }

    /// An unset field steps from last week's number — the figure the super is
    /// mentally adjusting from.
    private var base: Int { value ?? previous ?? 0 }

    /// Nothing left to step down to, so the minus button is disabled.
    var atFloor: Bool { base <= floor }

    func stepped(by delta: Int) -> Int {
        let snapped = Int((Double(base + delta) / 5).rounded()) * 5
        return min(100, max(floor, snapped))
    }

    /// What committing a typed field should do.
    enum Typed: Equatable {
        /// Blank (or nothing numeric): this division files no answer.
        case cleared
        /// Taken as-is — a typed value is NOT snapped to the 5% grid, so a
        /// super typing 63 gets 63.
        case accepted(Int)
        /// Below last week. Carries the number they typed, for the message.
        case refused(Int)
    }

    func typed(_ raw: String) -> Typed {
        // Three digits is enough for 0–100, and keeps a long paste from
        // overflowing Int on the way to being capped anyway.
        let digits = raw.filter(\.isNumber).prefix(3)
        guard let number = Int(digits) else { return .cleared }
        let capped = min(100, number)
        return capped < floor ? .refused(capped) : .accepted(capped)
    }
}

/// One stored photo/file descriptor, kept verbatim in fpu_reports.attachments.
struct FpuAttachment: Codable, Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    let size: Int
    let type: String
    let kind: String
}

/// Everything the entry form needs for one (project, week).
struct FpuEntryForm {
    let weekEnding: String
    let projectNumber: String
    let projectName: String
    let columns: [FpuColumn]
    /// Starting values: an open draft's own numbers, else this week's filed
    /// entry, else last week's — the same prefill order as the web form.
    let prefill: [String: Int]
    /// Last week's numbers, shown per row as the reference point.
    let previous: [String: Int]
    let comment: String
    let existingAttachments: [FpuAttachment]
    /// "procore" when this week is currently Procore's row — saving takes it over.
    let entrySource: String?
}

/// One week in a project's FPU history (project detail tab).
struct FpuWeekRow: Identifiable {
    var id: String { weekEnding }
    let weekEnding: String
    let filed: Bool
    let state: FpuState
    let overall: Int?
    let hasComment: Bool
    let attachmentCount: Int
    let submittedBy: String?

    var weekLabel: String { FpuWeeks.label(weekEnding) }
}

/// Sheet target for the FPU entry form.
struct FpuLogTarget: Identifiable {
    let projectNumber: String
    let weekEnding: String
    var id: String { projectNumber + "|" + weekEnding }
}

/// Friday math. An FPU week is identified by its Friday ("week ending"), and
/// the current week's Friday can be in the past (on Sat/Sun) — mirrors the API.
enum FpuWeeks {
    private static let utc = TimeZone(identifier: "UTC")!

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.timeZone = zone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    /// Friday of the Mon–Sun week containing `reference`, as "yyyy-MM-dd".
    static func currentFriday(reference: Date = Date(), calendar: Calendar = .current) -> String {
        // Monday-based weekday index: Mon=0 … Sun=6, so Sat/Sun step back to
        // the Friday just past instead of forward to next week's.
        let monBased = (calendar.component(.weekday, from: reference) + 5) % 7
        let friday = calendar.date(byAdding: .day, value: 4 - monBased, to: reference) ?? reference
        return formatter("yyyy-MM-dd", calendar.timeZone).string(from: friday)
    }

    /// "2026-08-21" shifted by whole weeks (stays on a Friday).
    static func shifted(_ iso: String, byWeeks weeks: Int) -> String {
        guard let date = formatter("yyyy-MM-dd", utc).date(from: iso) else { return iso }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let moved = calendar.date(byAdding: .day, value: weeks * 7, to: date) ?? date
        return formatter("yyyy-MM-dd", utc).string(from: moved)
    }

    /// "2026-08-21" -> "Fri, Aug 21". A calendar date carries no time zone, so
    /// it is parsed AND rendered in UTC (see SafetyDates.day).
    static func label(_ iso: String) -> String {
        guard let date = formatter("yyyy-MM-dd", utc).date(from: iso) else { return iso }
        return formatter("EEE, MMM d", utc).string(from: date)
    }
}
