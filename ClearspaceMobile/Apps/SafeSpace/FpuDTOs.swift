import Foundation

// Wire types for safe_space's FPU routes. These are decoded WITHOUT snake_case
// conversion: `entry`, `previous` and `values` are keyed by the shared table's
// column names (a1_demolition, …), which must survive verbatim to match the
// `columns` keys. Multiword fields therefore carry explicit CodingKeys.

// MARK: - GET /api/fpus?week_ending=

struct FpuOverviewResponse: Decodable {
    let weekEnding: String
    let projects: [FpuOverviewRowDTO]

    enum CodingKeys: String, CodingKey {
        case weekEnding = "week_ending"
        case projects
    }
}

struct FpuOverviewRowDTO: Decodable {
    let projectNumber: String
    let projectName: String?
    let siteSuperName: String?
    let mine: Bool?
    let done: Bool?
    let expected: Bool?
    let entry: FpuEntrySummaryDTO?
    let report: FpuReportSummaryDTO?

    enum CodingKeys: String, CodingKey {
        case projectNumber = "project_number"
        case projectName = "project_name"
        case siteSuperName = "site_super_name"
        case mine, done, expected, entry, report
    }
}

struct FpuEntrySummaryDTO: Decodable {
    let source: String?
    let status: String?
    let overall: Double?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case source, status, overall
        case updatedAt = "updated_at"
    }
}

struct FpuReportSummaryDTO: Decodable {
    let status: String?
    let overall: Double?
    let hasComment: Bool?
    let attachmentCount: Int?
    let submittedBy: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, overall
        case hasComment = "has_comment"
        case attachmentCount = "attachment_count"
        case submittedBy = "submitted_by"
        case updatedAt = "updated_at"
    }
}

// MARK: - GET /api/fpus/<project>?week_ending=

struct FpuFormResponse: Decodable {
    let weekEnding: String
    let project: FpuFormProjectDTO
    let columns: [FpuColumnDTO]
    /// This week's row in the shared table, wide format — trade keys inline.
    let entry: [String: JSONValue]?
    /// The previous week's wide row, the prefill/reference values.
    let previous: [String: JSONValue]?
    let report: FpuReportRowDTO?
    let done: Bool?

    enum CodingKeys: String, CodingKey {
        case weekEnding = "week_ending"
        case project, columns, entry, previous, report, done
    }
}

struct FpuFormProjectDTO: Decodable {
    let projectNumber: String
    let projectName: String?

    enum CodingKeys: String, CodingKey {
        case projectNumber = "project_number"
        case projectName = "project_name"
    }
}

struct FpuColumnDTO: Decodable {
    let key: String
    let label: String
}

struct FpuReportRowDTO: Decodable {
    let status: String?
    let comment: String?
    /// A draft's own numbers, keyed by trade column.
    let values: [String: JSONValue]?
    let attachments: [FpuAttachmentDTO]?
    let submittedBy: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, comment, values, attachments
        case submittedBy = "submitted_by"
        case updatedAt = "updated_at"
    }
}

struct FpuAttachmentDTO: Decodable {
    let path: String
    let name: String?
    let size: Int?
    let type: String?
    let kind: String?
}

// MARK: - GET /api/fpus/<project>/weeks

struct FpuWeeksResponse: Decodable {
    let done: Bool?
    let weeks: [FpuWeekDTO]
}

struct FpuWeekDTO: Decodable {
    let weekEnding: String
    let filed: Bool?
    let entry: [String: JSONValue]?
    let report: FpuReportRowDTO?

    enum CodingKeys: String, CodingKey {
        case weekEnding = "week_ending"
        case filed, entry, report
    }
}

// MARK: - PUT /api/fpus/<project> (file this week's FPU)

struct SubmitFpuBody: Encodable {
    let weekEnding: String
    /// Every column key; nil encodes as null ("no answer").
    let values: [String: Int?]
    let comment: String
    let attachments: [FpuAttachment]
    let status: String

    enum CodingKeys: String, CodingKey {
        case weekEnding = "week_ending"
        case values, comment, attachments, status
    }
}

/// PUT response — decoded only to confirm the request landed.
struct FpuSubmitResponse: Decodable {
    let entry: [String: JSONValue]?
    let report: FpuReportRowDTO?
}

// MARK: - POST /api/uploads/sign
// This route has no dynamic keys, so it uses the default snake_case conversion.

struct SignUploadBody: Encodable {
    let name: String
    let type: String
    let size: Int
    let scope: String
}

struct SignUploadResponse: Decodable {
    let signedUrl: String
    let path: String
}

// MARK: - Wide-row helpers

enum FpuWideRow {
    /// Non-trade columns on fpu_project_executions. Anything else numeric is a
    /// trade percentage — resilient if divisions are ever added.
    private static let metaKeys: Set<String> = [
        "id", "project_number", "project_name", "week_ending",
        "status", "source", "updated_at", "created_at",
    ]

    /// Percent by trade key, from a wide shared-table row or a draft's `values`.
    static func percents(_ row: [String: JSONValue]?) -> [String: Int] {
        guard let row else { return [:] }
        var out: [String: Int] = [:]
        for (key, value) in row where !metaKeys.contains(key) {
            if case .number(let n) = value {
                out[key] = max(0, min(100, Int(n.rounded())))
            }
        }
        return out
    }

    /// Mean of the answered trades, matching the API's `_overall`.
    static func overall(_ row: [String: JSONValue]?) -> Int? {
        let values = percents(row).values
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

private func stringField(_ row: [String: JSONValue]?, _ key: String) -> String? {
    guard let value = row?[key], case .string(let s) = value else { return nil }
    return s
}

// MARK: - DTO -> domain

extension FpuOverviewResponse {
    func toModel() -> FpuWeekOverview {
        FpuWeekOverview(weekEnding: weekEnding, rows: projects.map { $0.toModel() })
    }
}

extension FpuOverviewRowDTO {
    func toModel() -> FpuProjectWeek {
        let overall = entry?.overall ?? report?.overall
        return FpuProjectWeek(
            projectNumber: projectNumber,
            projectName: (projectName?.isEmpty == false ? projectName : nil) ?? projectNumber,
            siteSuperName: siteSuperName,
            mine: mine ?? false,
            state: FpuState.derive(entrySource: entry?.source,
                                   reportStatus: report?.status,
                                   done: done ?? false,
                                   expected: expected ?? false),
            overall: overall.map { Int($0.rounded()) },
            updatedAt: (entry?.updatedAt ?? report?.updatedAt).map { SafetyDates.stamp($0) }
        )
    }
}

extension FpuAttachmentDTO {
    func toModel() -> FpuAttachment {
        FpuAttachment(path: path, name: name ?? "attachment", size: size ?? 0,
                      type: type ?? "application/octet-stream", kind: kind ?? "file")
    }
}

extension FpuFormResponse {
    func toModel() -> FpuEntryForm {
        let entryValues = FpuWideRow.percents(entry)
        let draftValues = report?.status == "draft" ? FpuWideRow.percents(report?.values) : [:]
        let previousValues = FpuWideRow.percents(previous)
        let prefill = !draftValues.isEmpty ? draftValues
            : !entryValues.isEmpty ? entryValues
            : previousValues
        return FpuEntryForm(
            weekEnding: weekEnding,
            projectNumber: project.projectNumber,
            projectName: (project.projectName?.isEmpty == false ? project.projectName : nil)
                ?? project.projectNumber,
            columns: columns.map { FpuColumn(key: $0.key, label: $0.label) },
            prefill: prefill,
            previous: previousValues,
            comment: report?.comment ?? "",
            existingAttachments: (report?.attachments ?? []).map { $0.toModel() },
            entrySource: stringField(entry, "source")
        )
    }
}

extension FpuWeeksResponse {
    func toModel() -> [FpuWeekRow] {
        weeks.map { week in
            // The history treats every listed week as expected, so gaps read
            // as Outstanding — same as the web tab.
            let state = FpuState.derive(entrySource: stringField(week.entry, "source"),
                                        reportStatus: week.report?.status,
                                        done: done ?? false,
                                        expected: true)
            let overall = FpuWideRow.overall(week.entry)
                ?? (week.report?.status == "draft" ? FpuWideRow.overall(week.report?.values) : nil)
            let comment = week.report?.comment ?? ""
            return FpuWeekRow(
                weekEnding: week.weekEnding,
                filed: week.filed ?? false,
                state: state,
                overall: overall,
                hasComment: !comment.isEmpty,
                attachmentCount: week.report?.attachments?.count ?? 0,
                submittedBy: week.report?.submittedBy
            )
        }
    }
}
