import XCTest
@testable import ClearspaceMobile

/// Decodes fixtures shaped like safe_space's real responses, so a change in the
/// API contract (or a mistake in our models) fails here rather than on a phone.
final class SafeSpaceDecodingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Pin the display zone so timestamp assertions don't depend on the machine.
        SafetyDates.displayTimeZone = TimeZone(identifier: "UTC")!
    }

    override func tearDown() {
        SafetyDates.displayTimeZone = .current
        super.tearDown()
    }

    /// Matches APIClient's decoder for normal endpoints.
    private func decode<T: Decodable>(_ type: T.Type, _ json: String, convertSnakeCase: Bool = true) throws -> T {
        let decoder = JSONDecoder()
        if convertSnakeCase { decoder.keyDecodingStrategy = .convertFromSnakeCase }
        return try decoder.decode(type, from: Data(json.utf8))
    }

    func testProjectsListDecodes() throws {
        // Includes wrike_ss_id, which we deliberately don't model.
        let json = """
        {"projects":[
          {"project_number":"24-118","project_name":"Riverside Tower","status":"C - Construction",
           "pm_name":"Dana Whitfield","site_super_name":"Marco Ruiz","wrike_ss_id":"KUAQ",
           "talk_count":12,"submission_count":8,"daily_report_count":34,"last_report_date":"2026-08-10"},
          {"project_number":"25-011","project_name":"Union Station","status":"D - Completion",
           "pm_name":null,"site_super_name":null,"wrike_ss_id":null,
           "talk_count":0,"submission_count":0,"daily_report_count":0,"last_report_date":null}
        ]}
        """
        let response = try decode(ProjectsListResponse.self, json)
        let projects = response.projects.map { $0.toModel() }

        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects[0].projectName, "Riverside Tower")
        XCTAssertEqual(projects[0].talkCount, 12)
        XCTAssertEqual(projects[0].formCount, 8)
        XCTAssertEqual(projects[0].reportCount, 34)
        XCTAssertEqual(projects[0].statusLabel, "Construction", "The 'C - ' prefix should be stripped for display")
        XCTAssertEqual(projects[0].lastReportDate, "Aug 10, 2026")

        XCTAssertTrue(projects[1].hasNothingOnFile, "A project with no records should be flagged")
        XCTAssertNil(projects[1].lastReportDate, "Never-filed projects have no last report date")
        XCTAssertEqual(projects[1].siteSuperName, nil)
    }

    func testTalksListDecodes() throws {
        let json = """
        {"talks":[
          {"id":"9f1","topic_id":"t1","project_number":"24-118","talk_date":"2026-08-10",
           "delivered_by":"Marco Ruiz","status":"open","created_at":"2026-08-10T12:00:00+00:00",
           "topic":{"id":"t1","name":"Ladder Safety","body":"Three points of contact."},
           "topic_name":"Ladder Safety","project_name":"Riverside Tower","attendance_count":14}
        ]}
        """
        let talks = try decode(TalksResponse.self, json).talks.map { $0.toModel() }

        XCTAssertEqual(talks.count, 1)
        XCTAssertEqual(talks[0].topicName, "Ladder Safety")
        XCTAssertEqual(talks[0].status, .open)
        XCTAssertEqual(talks[0].talkDate, "Aug 10, 2026")
        XCTAssertEqual(talks[0].attendanceCount, 14)
    }

    func testTalkWithoutProjectNameUsesTheSuppliedOne() throws {
        // The project-detail route omits project_name on nested talks.
        let json = """
        {"talks":[{"id":"9f1","topic_id":"t1","project_number":"24-118","talk_date":"2026-08-11",
          "delivered_by":"Marco","status":"scheduled","topic_name":"Heat Stress","attendance_count":0}]}
        """
        let talks = try decode(TalksResponse.self, json).talks.map { $0.toModel(projectName: "Riverside Tower") }

        XCTAssertEqual(talks[0].projectName, "Riverside Tower")
        XCTAssertEqual(talks[0].topicName, "Heat Stress", "Falls back to topic_name when topic is absent")
        XCTAssertEqual(talks[0].status, .scheduled)
    }

    func testSubmissionDetailPreservesFieldKeysAndOrder() throws {
        // Decoded WITHOUT snake_case conversion — the keys inside `data` are the
        // form's own field keys and must survive verbatim.
        let json = """
        {"submission":{
          "id":"s1","template_id":"tpl1","project_number":"24-118","submitted_by":"marco@clearspace.to",
          "source":"field","status":"reviewed","submitted_at":"2026-08-10T15:42:11.123456+00:00",
          "template_name":"Site Safety Inspection","signature":"data:image/png;base64,AAA",
          "attachments":[],
          "data":{
            "work_performed":{"label":"Work performed","type":"textarea","value":"Boarding floor 10"},
            "ppe_ok":{"label":"PPE compliance","type":"select","value":"Compliant"},
            "hazards":{"label":"Hazards","type":"multicheck","value":["Dust","Noise"]},
            "site_photos":{"label":"Photos","type":"photo","value":[{"path":"a","name":"a.jpg","size":10,"type":"image/jpeg","kind":"photo"}]},
            "headcount":{"label":"Headcount","type":"number","value":15}
          },
          "field_order":["work_performed","ppe_ok","hazards","site_photos","headcount"],
          "column_order":{}
        }}
        """
        let detail = try decode(SubmissionDetailResponse.self, json, convertSnakeCase: false)
            .submission.toModel(projectName: "Riverside Tower")

        XCTAssertEqual(detail.answers.map(\.key),
                       ["work_performed", "ppe_ok", "hazards", "site_photos", "headcount"],
                       "Answers must keep their original field keys and the API's display order")
        XCTAssertEqual(detail.answers[0].label, "Work performed")
        XCTAssertEqual(detail.answers[0].value, "Boarding floor 10")
        XCTAssertEqual(detail.answers[2].value, "Dust, Noise", "Multi-choice answers join")
        XCTAssertEqual(detail.answers[3].value, "1 item", "Photo answers show a count")
        XCTAssertEqual(detail.answers[4].value, "15", "Whole numbers render without a decimal point")
        XCTAssertTrue(detail.hasSignature)
        XCTAssertEqual(detail.submission.status, .reviewed)
        XCTAssertEqual(detail.submission.source, .field)
        XCTAssertEqual(detail.submission.submittedAt, "Aug 10, 2026 · 3:42 PM",
                       "Microsecond timestamps must still format")
        XCTAssertEqual(detail.submission.projectName, "Riverside Tower")
    }

    func testDailyReportDecodes() throws {
        let json = """
        {"reports":[
          {"id":"d1","project_number":"24-092","project_name":"Lakeshore Campus","report_date":"2026-08-09",
           "weather":"Rain · 16C","crew":[{"trade_id":4,"trade_name":"Sitework","headcount":5},
                                          {"trade_id":null,"trade_name":"Clearspace","headcount":2}],
           "work_performed":"Excavation paused.","hazards_observed":"Standing water.",
           "toolbox_talk_delivered":false,"visitors":"","deliveries":"","incidents":true,
           "notes":"First aid, no lost time.",
           "attachments":[{"path":"a","name":"a.jpg","size":1,"type":"image/jpeg","kind":"photo"},
                          {"path":"b","name":"b.mp4","size":2,"type":"video/mp4","kind":"video"}],
           "submitted_by":"Tom Beaudry","signature":"data:image/png;base64,AAA",
           "created_at":"2026-08-09T22:00:00+00:00","updated_at":"2026-08-09T22:00:00+00:00"}
        ]}
        """
        let reports = try decode(DailyReportsResponse.self, json).reports.map { $0.toModel() }

        XCTAssertEqual(reports.count, 1)
        let report = reports[0]
        XCTAssertEqual(report.reportDate, "Aug 9, 2026")
        XCTAssertTrue(report.incidents, "Incidents drive the red badge on the list")
        XCTAssertEqual(report.headcount, 7, "Headcount sums every crew line")
        XCTAssertEqual(report.crewSummary, "Sitework ×5, Clearspace ×2")
        XCTAssertEqual(report.attachmentCount, 2)
        XCTAssertFalse(report.toolboxTalkDelivered)
    }

    func testDailyReportFallsBackWhenProjectNameIsBlank() throws {
        // The API sends "" when a project has aged out of the active list.
        let json = """
        {"report":{"id":"d2","project_number":"24-001","project_name":"","report_date":"2026-01-05",
          "weather":"","crew":[],"work_performed":"","hazards_observed":"",
          "toolbox_talk_delivered":false,"visitors":"","deliveries":"","incidents":false,
          "notes":"","attachments":[],"submitted_by":"","signature":null}}
        """
        let report = try decode(DailyReportResponse.self, json).report.toModel()

        XCTAssertEqual(report.projectName, "24-001", "Blank names fall back to the project number")
        XCTAssertEqual(report.crewSummary, "No crew logged")
        XCTAssertEqual(report.headcount, 0)
    }

    func testProjectDetailDecodesAllThreeRecordSets() throws {
        let json = """
        {"project":{"project_number":"24-118","project_name":"Riverside Tower","status":"C - Construction",
                    "pm_name":"Dana","site_super_name":"Marco",
                    "talk_count":1,"submission_count":1,"daily_report_count":1},
         "talks":[{"id":"t9","topic_id":"x","project_number":"24-118","talk_date":"2026-08-10",
                   "delivered_by":"Marco","status":"closed","topic_name":"Silica Dust","attendance_count":22}],
         "submissions":[{"id":"s9","template_id":"tpl","project_number":"24-118","submitted_by":"a@b.c",
                         "source":"sso","status":"submitted","submitted_at":"2026-08-10T11:08:00+00:00",
                         "template_name":"Hot Work Permit"}],
         "daily_reports":[{"id":"d9","project_number":"24-118","report_date":"2026-08-10","weather":"Sunny",
                           "crew":[],"work_performed":"","hazards_observed":"","toolbox_talk_delivered":true,
                           "visitors":"","deliveries":"","incidents":false,"notes":"","attachments":[],
                           "submitted_by":"Marco"}]}
        """
        let response = try decode(ProjectDetailResponse.self, json)
        let project = response.project.toModel()

        XCTAssertEqual(project.projectName, "Riverside Tower")
        XCTAssertEqual(response.talks.count, 1)
        XCTAssertEqual(response.submissions.count, 1)
        XCTAssertEqual(response.dailyReports.count, 1)

        // Nested records inherit the parent project's name.
        let talk = response.talks[0].toModel(projectName: project.projectName)
        let report = response.dailyReports[0].toModel(projectName: project.projectName)
        XCTAssertEqual(talk.projectName, "Riverside Tower")
        XCTAssertEqual(report.projectName, "Riverside Tower")
        XCTAssertEqual(talk.status, .closed)
    }

    func testUnknownEnumValuesFallBackInsteadOfFailing() throws {
        let json = """
        {"talks":[{"id":"x","topic_id":"t","project_number":"1","talk_date":"2026-08-10",
          "delivered_by":"A","status":"something_new","topic_name":"T","attendance_count":0}]}
        """
        let talks = try decode(TalksResponse.self, json).talks.map { $0.toModel() }
        XCTAssertEqual(talks[0].status, .open, "An unrecognised status should not break the screen")
    }
}
