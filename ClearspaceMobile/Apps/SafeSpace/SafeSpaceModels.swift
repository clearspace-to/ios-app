import Foundation

// MARK: - safe_space domain models
// Mirrors frontend/src/lib/types.ts in the safe_space repo.

struct SafetyProject: Identifiable, Hashable {
    var id: String { projectNumber }
    let projectNumber: String
    let projectName: String
    let status: String
    let pmName: String?
    let siteSuperName: String?
    var talkCount: Int = 0
    var formCount: Int = 0
    var reportCount: Int = 0
    /// nil when no daily report has ever been filed for this project.
    var lastReportDate: String?

    /// master_project_data ships statuses as "C - Construction"; the apps show the word only.
    var statusLabel: String {
        guard let range = status.range(of: " - ") else { return status }
        return String(status[range.upperBound...])
    }

    var activityLine: String {
        "\(talkCount) talks · \(formCount) forms · \(reportCount) reports"
    }

    var hasNothingOnFile: Bool {
        talkCount == 0 && formCount == 0 && reportCount == 0
    }
}

enum TalkStatus: String {
    case scheduled, open, closed

    var label: String { rawValue.capitalized }
}

struct ToolboxTalk: Identifiable, Hashable {
    let id: String
    let topicName: String
    let projectNumber: String
    let projectName: String
    let talkDate: String
    let deliveredBy: String
    let status: TalkStatus
    let attendanceCount: Int
}

struct TalkAttendee: Identifiable, Hashable {
    let id: String
    let name: String
    /// Snapshot of the trade name when they signed — never re-resolved.
    let employerLabel: String
    let signedAt: String
}

struct ToolboxTalkDetail {
    let talk: ToolboxTalk
    let topicBody: String
    let corElements: [Int]
    let attendees: [TalkAttendee]
}

enum FormSubmissionStatus: String {
    case submitted, reviewed

    var label: String { rawValue.capitalized }
}

enum FormSubmissionSource: String {
    case sso, field

    var label: String { self == .sso ? "Office" : "Field" }
}

struct FormSubmission: Identifiable, Hashable {
    let id: String
    let templateName: String
    /// Lives on the template, not the submission — absent from the list API.
    let category: String?
    let projectNumber: String
    let projectName: String
    let submittedBy: String
    let source: FormSubmissionSource
    let status: FormSubmissionStatus
    let submittedAt: String
}

/// One answered field. `label` and `type` are snapshotted at submit time.
struct FormAnswer: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let value: String
}

struct FormSubmissionDetail {
    let submission: FormSubmission
    let answers: [FormAnswer]
    let hasSignature: Bool
}

struct CrewLine: Identifiable, Hashable {
    var id: String { tradeName }
    /// Snapshot of the trade name when the report was filed.
    let tradeName: String
    let headcount: Int
}

struct DailyReport: Identifiable, Hashable {
    let id: String
    let projectNumber: String
    let projectName: String
    let reportDate: String
    let weather: String
    let crew: [CrewLine]
    let workPerformed: String
    let hazardsObserved: String
    let toolboxTalkDelivered: Bool
    let visitors: String
    let deliveries: String
    let incidents: Bool
    let notes: String
    let attachmentCount: Int
    let submittedBy: String

    var headcount: Int { crew.reduce(0) { $0 + $1.headcount } }
    var crewSummary: String {
        crew.isEmpty ? "No crew logged" : crew.map { "\($0.tradeName) ×\($0.headcount)" }.joined(separator: ", ")
    }
}

/// Rollup shown on a project's detail screen.
struct ProjectSafetySummary {
    let project: SafetyProject
    let talks: [ToolboxTalk]
    let forms: [FormSubmission]
    let reports: [DailyReport]
}

/// One committed subcontractor on a project, grouped across its Procore POs.
struct ProjectTrade: Identifiable, Hashable {
    var id: String { vendor.isEmpty ? poNumbers.joined(separator: ",") : vendor }
    let vendor: String
    let scopes: [String]
    let poNumbers: [String]

    var scopeLine: String { scopes.joined(separator: " · ") }
}

/// A construction key date. `passed` only ever comes from Wrike's milestone
/// completion — the other three dates are plans, not events.
struct ProjectKeyDate: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let date: String?
    var passed: Bool = false

    var displayValue: String { date ?? "—" }
}

/// GET /api/projects/<n>/overview. Loaded separately from the record sets
/// because it calls Wrike and Procore, which are slow and can be down.
struct ProjectOverview {
    let keyDates: [ProjectKeyDate]
    let pmName: String?
    let designerName: String?
    let siteSuperName: String?
    let procoreURL: URL?
    /// nil = Procore unreachable or unlinked; [] = no committed subs yet.
    let trades: [ProjectTrade]?
}

extension Notification.Name {
    static let safeSpaceRecordCreated = Notification.Name("safeSpaceRecordCreated")
}

/// The record types safe_space's command bar can search.
enum SafetySearchScope: String, CaseIterable {
    case projects, talks, forms, reports

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .talks: return "Toolbox Talks"
        case .forms: return "Form Submissions"
        case .reports: return "Daily Reports"
        }
    }

    var icon: String {
        switch self {
        case .projects: return "folder"
        case .talks: return "person.2.wave.2"
        case .forms: return "list.bullet.clipboard"
        case .reports: return "sun.max"
        }
    }
}
