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

    // MARK: - GET /api/projects/<project>/schedule-tasks

    func testDecodesScheduleTasks() throws {
        let response = try decode(ScheduleTasksResponse.self, """
        {"linked": true,
         "tasks": [{"id": 987, "name": "Drywall — L3",
                    "start": "2026-09-01", "finish": "2026-09-15", "percentage": 40},
                   {"id": 988, "name": "Millwork", "start": null, "finish": null, "percentage": null}]}
        """)
        XCTAssertTrue(response.linked)
        XCTAssertEqual(response.tasks.count, 2)
        let first = response.tasks[0].toModel()
        XCTAssertEqual(first.id, 987)
        XCTAssertEqual(first.start, "2026-09-01")
        XCTAssertEqual(first.currentLine, "2026-09-01 → 2026-09-15 · 40% complete")
        let second = response.tasks[1].toModel()
        XCTAssertNil(second.percentage)
        XCTAssertEqual(second.currentLine, "— → —")
    }

    func testDecodesUnlinkedTasksResponse() throws {
        let response = try decode(ScheduleTasksResponse.self, """
        {"linked": false, "tasks": []}
        """)
        XCTAssertFalse(response.linked)
        XCTAssertTrue(response.tasks.isEmpty)
    }

    // MARK: - GET /api/projects/<project>/schedule-changes

    func testDecodesScheduleChanges() throws {
        let response = try decode(ScheduleChangesResponse.self, """
        {"linked": true, "available": true,
         "changes": [{"procore_rc_id": 12345, "status": "pending",
                      "task_name": "Drywall — L3",
                      "summary": "Start → 2026-09-01 · Finish → 2026-09-15",
                      "reason": "Permit delay", "notes": "",
                      "filed_by": "mark@clearspace.to", "requested_by": "",
                      "created_at": "2026-08-23T21:35:13.123456+00:00"},
                     {"procore_rc_id": 12000, "status": "accepted",
                      "task_name": "", "summary": "Finish → 2026-10-01",
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

    func testEncodesCreateBodyInSnakeCase() throws {
        let body = CreateScheduleChangeBody(
            taskId: 987, newStart: "2026-09-01", newFinish: nil,
            newPercentage: 40, otherChange: "", reason: "Permit delay",
            notes: "Crane back Thursday")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(body)) as? [String: Any])

        XCTAssertEqual(json["task_id"] as? Int, 987)
        XCTAssertEqual(json["new_start"] as? String, "2026-09-01")
        XCTAssertNil(json["new_finish"] as Any?)
        XCTAssertEqual(json["new_percentage"] as? Double, 40)
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
