import XCTest
@testable import ClearspaceMobile

/// Locks the FPU wire format. These routes are decoded WITHOUT snake_case
/// conversion because entry/previous/values are keyed by the shared table's
/// column names — a converted key would never match the `columns` list.
final class FpuDecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        // Mirrors APIClient with convertSnakeCase: false, as the FPU routes use.
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - GET /api/fpus (weekly overview)

    func testOverviewRowDerivesStateAndOverall() throws {
        let response = try decode(FpuOverviewResponse.self, """
        {
          "week_ending": "2026-08-21",
          "projects": [
            {"project_number": "1626", "project_name": "Riverside", "site_super_name": "Jane Doe",
             "mine": true, "done": false, "expected": true,
             "entry": {"source": "safe_space", "status": "Open", "overall": 62.4,
                       "updated_at": "2026-08-21T19:05:11+00:00"},
             "report": {"status": "complete", "overall": 62, "has_comment": true,
                        "attachment_count": 3, "submitted_by": "a@b.c",
                        "updated_at": "2026-08-21T19:05:11+00:00"}},
            {"project_number": "1701", "project_name": "", "site_super_name": null,
             "mine": false, "done": false, "expected": true, "entry": null, "report": null},
            {"project_number": "1702", "project_name": "Done project",
             "mine": false, "done": true, "expected": false, "entry": null, "report": null}
          ]
        }
        """)
        XCTAssertEqual(response.weekEnding, "2026-08-21")

        let rows = response.toModel().rows
        XCTAssertEqual(rows[0].state, .filedSafeSpace, "A safe_space entry wins over every other flag")
        XCTAssertEqual(rows[0].overall, 62, "overall rounds to a whole percent")
        XCTAssertTrue(rows[0].mine)

        XCTAssertEqual(rows[1].state, .outstanding, "expected with nothing filed is Outstanding")
        XCTAssertEqual(rows[1].projectName, "1701", "blank project_name falls back to the number")
        XCTAssertNil(rows[1].overall)

        XCTAssertEqual(rows[2].state, .done, "done wins once nothing is filed")
    }

    func testOverviewProcoreAndDraftStates() throws {
        let row = try decode(FpuOverviewRowDTO.self, """
        {"project_number": "1626", "mine": false, "done": false, "expected": true,
         "entry": {"source": "procore", "status": "Closed", "overall": 80, "updated_at": null},
         "report": null}
        """)
        XCTAssertEqual(row.toModel().state, .filedProcore)

        let draft = try decode(FpuOverviewRowDTO.self, """
        {"project_number": "1626", "mine": false, "done": false, "expected": true,
         "entry": null,
         "report": {"status": "draft", "overall": 31, "has_comment": false,
                    "attachment_count": 0, "submitted_by": "a@b.c", "updated_at": null}}
        """)
        XCTAssertEqual(draft.toModel().state, .draft)
        XCTAssertEqual(draft.toModel().overall, 31, "a draft's overall comes from the report")
    }

    // MARK: - GET /api/fpus/<project> (entry form)

    /// The wide row's trade keys must survive decoding verbatim — this is the
    /// reason the FPU routes skip snake_case conversion.
    func testFormResponseKeepsTradeKeysVerbatimAndPrefillsFromDraft() throws {
        let response = try decode(FpuFormResponse.self, """
        {
          "week_ending": "2026-08-21",
          "project": {"project_number": "1626", "project_name": "Riverside", "site_super_name": "Jane"},
          "columns": [{"key": "a1_demolition", "label": "A1 — Demolition"},
                      {"key": "c3_structured_cabling", "label": "C3 — Structured Cabling"}],
          "entry": {"id": "x", "project_number": "1626", "project_name": "Riverside",
                    "week_ending": "2026-08-21", "status": "Open", "source": "procore",
                    "updated_at": "2026-08-21T10:00:00+00:00",
                    "a1_demolition": 75, "c3_structured_cabling": null},
          "previous": {"project_number": "1626", "week_ending": "2026-08-14",
                       "status": "Open", "source": "procore",
                       "a1_demolition": 70, "c3_structured_cabling": 10},
          "report": {"status": "draft", "comment": "wip",
                     "values": {"a1_demolition": 80.0},
                     "attachments": [{"path": "fpus/1626/ab-photo.jpg", "name": "photo.jpg",
                                      "size": 123, "type": "image/jpeg", "kind": "photo"}],
                     "submitted_by": "a@b.c", "updated_at": null},
          "done": false
        }
        """)
        let form = response.toModel()

        XCTAssertEqual(form.columns.map(\.key), ["a1_demolition", "c3_structured_cabling"],
                       "column keys must match the wide row's keys exactly")
        XCTAssertEqual(form.prefill, ["a1_demolition": 80],
                       "an open draft's own values beat the filed entry and last week")
        XCTAssertEqual(form.previous, ["a1_demolition": 70, "c3_structured_cabling": 10],
                       "null trade values are unanswered, not zero")
        XCTAssertEqual(form.comment, "wip")
        XCTAssertEqual(form.entrySource, "procore", "the form warns before taking over a Procore week")
        XCTAssertEqual(form.existingAttachments.first?.path, "fpus/1626/ab-photo.jpg")
    }

    func testFormPrefillFallsBackEntryThenPrevious() throws {
        let base = """
        {
          "week_ending": "2026-08-21",
          "project": {"project_number": "1626", "project_name": "Riverside"},
          "columns": [{"key": "a1_demolition", "label": "A1 — Demolition"}],
          "entry": %ENTRY%,
          "previous": {"project_number": "1626", "a1_demolition": 40},
          "report": null,
          "done": false
        }
        """
        let withEntry = try decode(FpuFormResponse.self, base.replacingOccurrences(
            of: "%ENTRY%",
            with: #"{"project_number": "1626", "source": "safe_space", "a1_demolition": 55}"#))
        XCTAssertEqual(withEntry.toModel().prefill, ["a1_demolition": 55],
                       "this week's filed entry beats last week")

        let withoutEntry = try decode(FpuFormResponse.self,
                                      base.replacingOccurrences(of: "%ENTRY%", with: "null"))
        XCTAssertEqual(withoutEntry.toModel().prefill, ["a1_demolition": 40],
                       "a fresh week starts from last week's numbers")
    }

    // MARK: - GET /api/fpus/<project>/weeks (history)

    func testWeeksHistoryTreatsGapsAsOutstandingAndComputesOverall() throws {
        let response = try decode(FpuWeeksResponse.self, """
        {
          "project_number": "1626", "done": false,
          "weeks": [
            {"week_ending": "2026-08-21", "filed": false, "entry": null, "report": null},
            {"week_ending": "2026-08-14", "filed": true,
             "entry": {"id": "x", "project_number": "1626", "project_name": "Riverside",
                       "week_ending": "2026-08-14", "status": "Open", "source": "safe_space",
                       "updated_at": "2026-08-14T20:00:00+00:00",
                       "a1_demolition": 100, "a2_partitions": 50, "a3_ceiling": null},
             "report": {"status": "complete", "comment": "good week",
                        "values": {}, "attachments": [{"path": "p", "name": "n",
                        "size": 1, "type": "image/jpeg", "kind": "photo"}],
                        "submitted_by": "a@b.c", "updated_at": null}}
          ]
        }
        """)
        let rows = response.toModel()

        XCTAssertEqual(rows[0].state, .outstanding, "an unfiled listed week reads as Outstanding")
        XCTAssertEqual(rows[1].state, .filedSafeSpace)
        XCTAssertEqual(rows[1].overall, 75,
                       "overall averages only the answered trades and ignores meta columns")
        XCTAssertTrue(rows[1].hasComment)
        XCTAssertEqual(rows[1].attachmentCount, 1)
    }

    // MARK: - PUT /api/fpus/<project> (request body)

    func testSubmitBodyEncodesSnakeKeysAndNullsForUnanswered() throws {
        let body = SubmitFpuBody(
            weekEnding: "2026-08-21",
            values: ["a1_demolition": 75, "a2_partitions": nil],
            comment: "steady",
            attachments: [FpuAttachment(path: "fpus/1626/x.jpg", name: "x.jpg",
                                        size: 10, type: "image/jpeg", kind: "photo")],
            status: "complete")
        // Encoded WITHOUT snake conversion, matching api.put(convertSnakeCase: false).
        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["week_ending"] as? String, "2026-08-21")
        XCTAssertEqual(json["status"] as? String, "complete")
        let values = try XCTUnwrap(json["values"] as? [String: Any])
        XCTAssertEqual(values["a1_demolition"] as? Int, 75)
        XCTAssertTrue(values["a2_partitions"] is NSNull,
                      "an unanswered division files as null, never 0")
        let attachment = try XCTUnwrap((json["attachments"] as? [[String: Any]])?.first)
        XCTAssertEqual(attachment["kind"] as? String, "photo")
        XCTAssertEqual(attachment["path"] as? String, "fpus/1626/x.jpg")
    }

    // MARK: - Friday math

    private func utcDate(_ y: Int, _ m: Int, _ d: Int) -> (Date, Calendar) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        return (date, calendar)
    }

    func testCurrentFridayLandsOnThisWeeksFriday() {
        // Wed Aug 19 2026 -> Fri Aug 21 (later the same week).
        let (wednesday, calendar) = utcDate(2026, 8, 19)
        XCTAssertEqual(FpuWeeks.currentFriday(reference: wednesday, calendar: calendar), "2026-08-21")

        // Sat Aug 22 2026 -> Fri Aug 21 (the day before, NOT next week's Friday).
        let (saturday, _) = utcDate(2026, 8, 22)
        XCTAssertEqual(FpuWeeks.currentFriday(reference: saturday, calendar: calendar), "2026-08-21")

        // Sun Aug 23 2026 -> still Fri Aug 21.
        let (sunday, _) = utcDate(2026, 8, 23)
        XCTAssertEqual(FpuWeeks.currentFriday(reference: sunday, calendar: calendar), "2026-08-21")

        // A Friday is its own week ending.
        let (friday, _) = utcDate(2026, 8, 21)
        XCTAssertEqual(FpuWeeks.currentFriday(reference: friday, calendar: calendar), "2026-08-21")
    }

    func testWeekShiftingStaysOnFridaysAcrossMonthEnds() {
        XCTAssertEqual(FpuWeeks.shifted("2026-08-21", byWeeks: -1), "2026-08-14")
        XCTAssertEqual(FpuWeeks.shifted("2026-09-04", byWeeks: -1), "2026-08-28")
        XCTAssertEqual(FpuWeeks.shifted("2026-08-28", byWeeks: 1), "2026-09-04")
    }

    func testWeekLabelRendersInUTC() {
        // Parsed AND rendered in UTC so the date never shifts a day west of UTC.
        XCTAssertEqual(FpuWeeks.label("2026-08-21"), "Fri, Aug 21")
    }
}
