import Foundation

// Wire types for safe_space's Flask API. Field names mirror the JSON exactly
// (decoded with .convertFromSnakeCase unless noted).

// MARK: - Responses

struct ProjectsListResponse: Decodable { let projects: [ProjectDTO] }
struct TalksResponse: Decodable { let talks: [TalkDTO] }
struct TalkDetailResponse: Decodable {
    let talk: TalkDTO
    let attendance: [AttendanceDTO]
}
struct SubmissionsResponse: Decodable { let submissions: [SubmissionDTO] }
struct DailyReportsResponse: Decodable { let reports: [DailyReportDTO] }
struct DailyReportResponse: Decodable { let report: DailyReportDTO }

struct ProjectDetailResponse: Decodable {
    let project: ProjectDTO
    let talks: [TalkDTO]
    let submissions: [SubmissionDTO]
    let dailyReports: [DailyReportDTO]
}

// MARK: - Records

struct ProjectDTO: Decodable {
    let projectNumber: String
    let projectName: String?
    let status: String?
    let pmName: String?
    let siteSuperName: String?
    let talkCount: Int?
    let submissionCount: Int?
    let dailyReportCount: Int?
    let lastReportDate: String?
}

struct TopicDTO: Decodable {
    let name: String?
    let body: String?
    let corElements: [Int]?
}

struct TalkDTO: Decodable {
    let id: String
    let projectNumber: String
    let talkDate: String?
    let deliveredBy: String?
    let status: String?
    let topic: TopicDTO?
    let topicName: String?
    let projectName: String?
    let attendanceCount: Int?
}

struct AttendanceDTO: Decodable {
    let id: String
    let name: String?
    let employerLabel: String?
    let signedAt: String?
}

struct SubmissionDTO: Decodable {
    let id: String
    let projectNumber: String
    let submittedBy: String?
    let source: String?
    let status: String?
    let submittedAt: String?
    let templateName: String?
}

/// Submission detail is decoded WITHOUT snake_case conversion, because `data`
/// is keyed by the form's own field keys.
struct SubmissionDetailResponse: Decodable {
    let submission: SubmissionDetailDTO
}

struct SubmissionDetailDTO: Decodable {
    let id: String
    let projectNumber: String
    let submittedBy: String?
    let source: String?
    let status: String?
    let submittedAt: String?
    let templateName: String?
    let signature: String?
    /// field key -> {label, type, value}
    let data: [String: FormValueDTO]
    /// Display order of the field keys.
    let fieldOrder: [String]?

    enum CodingKeys: String, CodingKey {
        case id, source, status, signature, data
        case projectNumber = "project_number"
        case submittedBy = "submitted_by"
        case submittedAt = "submitted_at"
        case templateName = "template_name"
        case fieldOrder = "field_order"
    }
}

struct FormValueDTO: Decodable {
    let label: String?
    let type: String?
    let value: JSONValue?
}

struct CrewLineDTO: Decodable {
    let tradeName: String?
    let headcount: Int?
}

struct DailyReportDTO: Decodable {
    let id: String
    let projectNumber: String
    let projectName: String?
    let reportDate: String?
    let weather: String?
    let crew: [CrewLineDTO]?
    let workPerformed: String?
    let hazardsObserved: String?
    let toolboxTalkDelivered: Bool?
    let visitors: String?
    let deliveries: String?
    let incidents: Bool?
    let notes: String?
    let attachments: [JSONValue]?
    let submittedBy: String?
}

// MARK: - Polymorphic JSON

/// A form answer's value can be a string, number, list of choices, table rows or
/// a list of attachments, depending on the field type.
indirect enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        self = .null
    }

    /// Human-readable rendering for a detail row.
    var displayText: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b ? "Yes" : "No"
        case .number(let n):
            return n == n.rounded() ? String(Int(n)) : String(n)
        case .array(let items):
            // Photos and table rows render as a count; choice lists join.
            let scalars = items.compactMap { item -> String? in
                if case .object = item { return nil }
                return item.displayText
            }
            if scalars.count == items.count {
                return scalars.isEmpty ? "—" : scalars.joined(separator: ", ")
            }
            return "\(items.count) item\(items.count == 1 ? "" : "s")"
        case .object:
            return "—"
        case .null:
            return "—"
        }
    }
}

// MARK: - Request bodies

struct CreateDailyReportBody: Encodable {
    let projectNumber: String
    let reportDate: String
    let weather: String
    let crew: [CrewLineBody]
    let workPerformed: String
    let hazardsObserved: String
    let toolboxTalkDelivered: Bool
    let visitors: String
    let deliveries: String
    let incidents: Bool
    let notes: String

    struct CrewLineBody: Encodable {
        let tradeName: String
        let headcount: Int
    }
}

struct CreateToolboxTalkBody: Encodable {
    let projectNumber: String
    let topic: TopicBody
    let talkDate: String
    let deliveredBy: String

    struct TopicBody: Encodable {
        let name: String
        let body: String
    }
}

struct CreateRecordResponse: Decodable {
    let id: String?
}

struct CreateTopicEnvelope: Decodable {
    let topic: TopicCreatedDTO
    struct TopicCreatedDTO: Decodable { let id: String }
}

struct CreateTalkRequestBody: Encodable {
    let topicId: String
    let projectNumber: String
    let talkDate: String
    let deliveredBy: String
}

// MARK: - Dates

enum SafetyDates {
    private static let utc = TimeZone(identifier: "UTC")!

    /// Time zone used to display timestamps. Overridable so tests don't depend
    /// on the machine's zone.
    static var displayTimeZone: TimeZone = .current

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.timeZone = zone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    /// "2026-08-10" -> "Aug 10, 2026". Falls back to the raw value.
    ///
    /// A calendar date carries no time zone, so it is parsed AND rendered in UTC.
    /// Rendering it in local time would shift it a day back for anyone west of UTC.
    static func day(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        guard let date = formatter("yyyy-MM-dd", utc).date(from: raw) else { return raw }
        return formatter("MMM d, yyyy", utc).string(from: date)
    }

    /// ISO timestamp -> "Aug 10, 2026 · 3:42 PM" in the viewer's time zone.
    static func stamp(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let stampOut = formatter("MMM d, yyyy · h:mm a", displayTimeZone)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return stampOut.string(from: date) }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return stampOut.string(from: date) }
        // PostgREST emits microseconds ("...:11.123456+00:00"), which ISO8601
        // won't parse — drop the whole fractional part and retry.
        if let dot = raw.firstIndex(of: "."),
           let end = raw[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let stripped = raw.replacingCharacters(in: dot..<end, with: "")
            if let date = iso.date(from: stripped) { return stampOut.string(from: date) }
        }
        return day(String(raw.prefix(10)))
    }
}

// MARK: - DTO -> domain

extension ProjectDTO {
    func toModel() -> SafetyProject {
        SafetyProject(
            projectNumber: projectNumber,
            projectName: projectName ?? projectNumber,
            status: status ?? "",
            pmName: pmName,
            siteSuperName: siteSuperName,
            talkCount: talkCount ?? 0,
            formCount: submissionCount ?? 0,
            reportCount: dailyReportCount ?? 0,
            lastReportDate: lastReportDate.map { SafetyDates.day($0) }
        )
    }
}

extension TalkDTO {
    /// `projectName` is absent on the project-detail route, so it can be supplied.
    func toModel(projectName fallbackName: String? = nil) -> ToolboxTalk {
        ToolboxTalk(
            id: id,
            topicName: topic?.name ?? topicName ?? "Untitled topic",
            projectNumber: projectNumber,
            projectName: projectName ?? fallbackName ?? projectNumber,
            talkDate: SafetyDates.day(talkDate),
            deliveredBy: deliveredBy ?? "—",
            status: TalkStatus(rawValue: status ?? "") ?? .open,
            attendanceCount: attendanceCount ?? 0
        )
    }
}

extension AttendanceDTO {
    func toModel() -> TalkAttendee {
        TalkAttendee(
            id: id,
            name: name ?? "—",
            employerLabel: employerLabel ?? "—",
            signedAt: SafetyDates.stamp(signedAt)
        )
    }
}

extension SubmissionDTO {
    func toModel(projectName: String?) -> FormSubmission {
        FormSubmission(
            id: id,
            templateName: templateName ?? "(deleted template)",
            category: nil,
            projectNumber: projectNumber,
            projectName: projectName ?? projectNumber,
            submittedBy: submittedBy ?? "—",
            source: FormSubmissionSource(rawValue: source ?? "") ?? .sso,
            status: FormSubmissionStatus(rawValue: status ?? "") ?? .submitted,
            submittedAt: SafetyDates.stamp(submittedAt)
        )
    }
}

extension SubmissionDetailDTO {
    func toModel(projectName: String?) -> FormSubmissionDetail {
        let submission = FormSubmission(
            id: id,
            templateName: templateName ?? "(deleted template)",
            category: nil,
            projectNumber: projectNumber,
            projectName: projectName ?? projectNumber,
            submittedBy: submittedBy ?? "—",
            source: FormSubmissionSource(rawValue: source ?? "") ?? .sso,
            status: FormSubmissionStatus(rawValue: status ?? "") ?? .submitted,
            submittedAt: SafetyDates.stamp(submittedAt)
        )
        // Render from the labels snapshotted at submit time, in the API's order.
        let keys = fieldOrder ?? Array(data.keys).sorted()
        let answers = keys.compactMap { key -> FormAnswer? in
            guard let field = data[key] else { return nil }
            return FormAnswer(
                key: key,
                label: field.label ?? key,
                value: field.value?.displayText ?? "—"
            )
        }
        return FormSubmissionDetail(
            submission: submission,
            answers: answers,
            hasSignature: !(signature ?? "").isEmpty
        )
    }
}

extension DailyReportDTO {
    func toModel(projectName fallbackName: String? = nil) -> DailyReport {
        DailyReport(
            id: id,
            projectNumber: projectNumber,
            projectName: (projectName?.isEmpty == false ? projectName : nil) ?? fallbackName ?? projectNumber,
            reportDate: SafetyDates.day(reportDate),
            weather: weather ?? "—",
            crew: (crew ?? []).map { CrewLine(tradeName: $0.tradeName ?? "—", headcount: $0.headcount ?? 0) },
            workPerformed: workPerformed ?? "",
            hazardsObserved: hazardsObserved ?? "",
            toolboxTalkDelivered: toolboxTalkDelivered ?? false,
            visitors: visitors ?? "",
            deliveries: deliveries ?? "",
            incidents: incidents ?? false,
            notes: notes ?? "",
            attachmentCount: attachments?.count ?? 0,
            submittedBy: submittedBy ?? "—"
        )
    }
}
