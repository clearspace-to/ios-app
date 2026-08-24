import XCTest
@testable import ClearspaceMobile

/// The command bar's cached index of the four searchable lists.
///
/// It used to load all four with a single `try await`, so one dead endpoint —
/// or the cancellation SwiftUI fires on every keystroke — wiped out the whole
/// result set, including the projects people are actually looking for.
final class SafetySearchIndexTests: XCTestCase {

    /// Loads whatever it's given; any list handed `nil` throws instead.
    private struct StubLists: SafetySearchLists {
        var projects: [SafetyProject]? = []
        var talks: [ToolboxTalk]? = []
        var submissions: [FormSubmission]? = []
        var reports: [DailyReport]? = []
        /// Held after each list resolves, to keep a load in flight.
        var delay: Duration = .zero

        struct Down: Error {}

        private func resolve<T>(_ value: [T]?) async throws -> [T] {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard let value else { throw Down() }
            return value
        }

        func projects() async throws -> [SafetyProject] { try await resolve(projects) }
        func talks() async throws -> [ToolboxTalk] { try await resolve(talks) }
        func submissions() async throws -> [FormSubmission] { try await resolve(submissions) }
        func reports() async throws -> [DailyReport] { try await resolve(reports) }
    }

    private func project(_ number: String, _ name: String) -> SafetyProject {
        SafetyProject(projectNumber: number, projectName: name, status: "C - Construction",
                      pmName: nil, siteSuperName: nil)
    }

    func testADeadListDoesNotBlankTheOthers() async {
        let index = SafetySearchIndex()
        let service = StubLists(
            projects: [project("24-118", "Riverside Tower")],
            talks: nil,        // /api/talks is down
            submissions: nil,
            reports: nil
        )

        let snapshot = await index.snapshot(loadedBy: service)

        XCTAssertEqual(snapshot.projects.map(\.projectNumber), ["24-118"],
                       "Projects loaded fine — a broken talks endpoint must not hide them")
        XCTAssertTrue(snapshot.talks.isEmpty)
    }

    func testAFailedListKeepsTheLastGoodOne() async {
        let index = SafetySearchIndex()
        let healthy = StubLists(projects: [project("24-118", "Riverside Tower")])
        _ = await index.snapshot(loadedBy: healthy)

        // Force the cache to expire, then reload with projects unreachable.
        await index.expireForTesting()
        let broken = StubLists(projects: nil)
        let snapshot = await index.snapshot(loadedBy: broken)

        XCTAssertEqual(snapshot.projects.map(\.projectNumber), ["24-118"],
                       "A blip on /api/projects/list should serve the previous list, not nothing")
    }

    func testKeystrokeCancellationDoesNotRestartTheLoad() async {
        let index = SafetySearchIndex()
        let service = StubLists(projects: [project("24-118", "Riverside Tower")],
                                delay: .milliseconds(200))

        // First keystroke starts the load, then gets cancelled — as SwiftUI's
        // .task(id:) does when the query changes.
        let first = Task { await index.snapshot(loadedBy: service) }
        try? await Task.sleep(for: .milliseconds(30))
        first.cancel()

        // The next keystroke must land on the in-flight load and get results.
        let snapshot = await index.snapshot(loadedBy: service)
        XCTAssertEqual(snapshot.projects.map(\.projectNumber), ["24-118"],
                       "The shared load must survive the cancelled keystroke that started it")
    }
}
