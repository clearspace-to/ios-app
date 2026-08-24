import XCTest
@testable import ClearspaceMobile

/// Locks the schedule change request wire format. Unlike the FPU routes these
/// have fixed snake_case keys, so they decode with the client's DEFAULT
/// convertFromSnakeCase strategy — mirrored here.
final class ScheduleDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: Data(json.utf8))
    }

    // MARK: - GET /api/projects/<project>/schedule-milestones

    func testDecodesScheduleMilestones() throws {
        let response = try decode(ScheduleMilestonesResponse.self, """
        {"linked": true,
         "milestones": [{"key": "construction_completion",
                         "label": "Construction completion",
                         "task_id": 987,
                         "task_name": "Phase 3 : Construction Completion",
                         "date": "2026-09-15"},
                        {"key": "takeover", "label": "Takeover",
                         "task_id": 988,
                         "task_name": "Phase 3 : Ready For Takeover",
                         "date": null}]}
        """)
        XCTAssertTrue(response.linked)
        XCTAssertEqual(response.milestones.count, 2)

        let first = response.milestones[0].toModel()
        XCTAssertEqual(first.id, 987)
        XCTAssertEqual(first.taskId, 987)
        XCTAssertEqual(first.label, "Construction completion")
        XCTAssertEqual(first.date, "2026-09-15")
        XCTAssertEqual(first.currentLine, "currently Sep 15, 2026")

        // A milestone can be on the schedule with no date set.
        let second = response.milestones[1].toModel()
        XCTAssertNil(second.date)
        XCTAssertEqual(second.currentLine, "no date on the schedule")
    }

    func testDecodesUnlinkedMilestonesResponse() throws {
        let response = try decode(ScheduleMilestonesResponse.self, """
        {"linked": false, "milestones": []}
        """)
        XCTAssertFalse(response.linked)
        XCTAssertTrue(response.milestones.isEmpty)
    }

    /// A linked project whose Procore schedule has none of the three.
    func testDecodesLinkedButEmptyMilestones() throws {
        let response = try decode(ScheduleMilestonesResponse.self, """
        {"linked": true, "milestones": []}
        """)
        XCTAssertTrue(response.linked)
        XCTAssertTrue(response.milestones.isEmpty)
    }

    // MARK: - GET /api/projects/<project>/schedule-changes

    func testDecodesScheduleChanges() throws {
        let response = try decode(ScheduleChangesResponse.self, """
        {"linked": true, "available": true,
         "changes": [{"procore_rc_id": 12345, "status": "pending",
                      "task_name": "Drywall — L3",
                      "summary": "Move to 2026-09-01",
                      "reason": "Permit delay", "notes": "",
                      "filed_by": "mark@clearspace.to", "requested_by": "",
                      "created_at": "2026-08-23T21:35:13.123456+00:00"},
                     {"procore_rc_id": 12000, "status": "accepted",
                      "task_name": "", "summary": "Move to 2026-10-01",
                      "reason": "", "notes": "", "filed_by": "",
                      "requested_by": "Jane Doe on Mon Aug 3", "created_at": null}]}
        """)
        let model = response.toModel()
        XCTAssertTrue(model.linked)
        XCTAssertTrue(model.available)
        XCTAssertEqual(model.changes.count, 2)

        let filed = model.changes[0]
        XCTAssertEqual(filed.id, 12345)
        XCTAssertEqual(filed.statusBadge, "Pending")
        XCTAssertEqual(filed.byLine, "mark@clearspace.to")
        XCTAssertNotNil(filed.createdAt)

        // Filed directly in Procore: no local snapshot, attribution falls back.
        let remote = model.changes[1]
        XCTAssertEqual(remote.byLine, "Jane Doe on Mon Aug 3")
        XCTAssertNil(remote.createdAt)
        XCTAssertEqual(remote.statusBadge, "Accepted")
    }

    /// linked:false / available:false — project has no Procore id, or Procore
    /// is down. Both arrive with an empty list, never an error payload.
    func testDecodesUnlinkedAndUnavailableStates() throws {
        let unlinked = try decode(ScheduleChangesResponse.self, """
        {"linked": false, "available": false, "changes": []}
        """).toModel()
        XCTAssertFalse(unlinked.linked)

        let down = try decode(ScheduleChangesResponse.self, """
        {"linked": true, "available": false, "changes": []}
        """).toModel()
        XCTAssertTrue(down.linked)
        XCTAssertFalse(down.available)
    }

    // MARK: - POST /api/projects/<project>/schedule-changes

    /// One date, not a start/finish/percent — the API expands it into Procore's
    /// start and finish, since milestones are single-day.
    func testEncodesCreateBodyInSnakeCase() throws {
        let body = CreateScheduleChangeBody(
            taskId: 987, newDate: "2026-09-01", reason: "Permit delay",
            notes: "Crane back Thursday")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(body)) as? [String: Any])

        XCTAssertEqual(json.count, 4)
        XCTAssertEqual(json["task_id"] as? Int, 987)
        XCTAssertEqual(json["new_date"] as? String, "2026-09-01")
        XCTAssertEqual(json["reason"] as? String, "Permit delay")
        XCTAssertEqual(json["notes"] as? String, "Crane back Thursday")
    }

    /// The success response's key is "report" (the API reuses the daily-report
    /// shape) — we only decode `created`.
    func testDecodesCreateResponse() throws {
        let response = try decode(CreateScheduleChangeResponse.self, """
        {"created": true, "report": {"id": "abc", "project_number": "1626"}}
        """)
        XCTAssertTrue(response.created)
    }
}
