import XCTest

/// Covers the second app module and the app switcher that reaches it.
final class SafeSpaceTests: XCTestCase {

    private func launchApp(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-preview"] + extraArgs
        app.launch()
        return app
    }

    /// "Explore with sample data" skips login, so the modules must switch to mock
    /// data too — otherwise they call live APIs with no token and every screen errors.
    func testExploreWithSampleDataShowsRecordsNotAnAuthError() {
        let app = XCUIApplication()   // deliberately no -preview: this is the real path
        app.launch()

        let explore = app.buttons["Explore with sample data"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10), "Login screen never appeared")
        explore.tap()

        // Land in safe_space and confirm real rows render.
        app.buttons["bottomBar.menu"].tap()
        app.buttons["drawer.brand"].tap()
        app.buttons["drawer.app.safe_space"].tap()

        XCTAssertTrue(app.staticTexts["Riverside Tower — Floors 8-12"].waitForExistence(timeout: 10),
                      "Sample data did not load — the module is probably still calling the live API")
        XCTAssertFalse(app.staticTexts["You're not signed in. Sign in to see live data."].exists,
                       "Sample-data mode should never hit the network")
    }

    func testAppSwitcherOpensSafeSpace() {
        let app = launchApp()

        app.buttons["bottomBar.menu"].tap()
        XCTAssertTrue(app.staticTexts["SALES_SPACE"].waitForExistence(timeout: 10))

        // The brand card expands the app switcher.
        app.buttons["drawer.brand"].tap()
        let safeSpace = app.buttons["drawer.app.safe_space"]
        XCTAssertTrue(safeSpace.waitForExistence(timeout: 5), "safe_space is not listed in the app switcher")
        safeSpace.tap()

        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5),
                      "Switching to safe_space did not land on its Projects screen")
    }

    func testSafeSpaceSectionsAreReachable() {
        let app = launchApp(["-app=safe_space"])
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 10))

        for (item, title) in [("Toolbox Talks", "Toolbox Talks"),
                              ("Forms", "Forms"),
                              ("Daily Reports", "Daily Reports")] {
            app.buttons["bottomBar.menu"].tap()
            let navItem = app.buttons[item]
            XCTAssertTrue(navItem.waitForExistence(timeout: 5), "\(item) missing from safe_space nav")
            navItem.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
                          "Could not navigate to \(title)")
        }
    }

    func testProjectDetailShowsItsSafetyRecords() {
        let app = launchApp(["-app=safe_space"])

        let project = app.staticTexts["Riverside Tower — Floors 8-12"]
        XCTAssertTrue(project.waitForExistence(timeout: 10))
        project.tap()

        // Lands on the project rollup with its talks listed first.
        XCTAssertTrue(app.staticTexts["Toolbox Talks"].waitForExistence(timeout: 5),
                      "Project detail did not show its toolbox talks")
        XCTAssertTrue(app.staticTexts["Ladder Safety & Three-Point Contact"].waitForExistence(timeout: 5),
                      "Project detail did not list the project's talks")
    }

    func testTalkDetailShowsAttendance() {
        let app = launchApp(["-app=safe_space", "-screen=talks"])

        let talk = app.staticTexts["Ladder Safety & Three-Point Contact"]
        XCTAssertTrue(talk.waitForExistence(timeout: 10))
        talk.tap()

        XCTAssertTrue(app.staticTexts["Attendance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Luis Ferreira"].waitForExistence(timeout: 5),
                      "Attendance sheet did not render signed-in workers")
    }

    func testCommandBarSearchesSafeSpaceRecordsScopedToScreen() {
        let app = launchApp(["-app=safe_space", "-screen=daily"])

        app.buttons["bottomBar.search"].tap()
        let field = app.textFields["palette.query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Riverside")

        let reports = app.staticTexts["palette.group.Daily Reports"].firstMatch
        let projects = app.staticTexts["palette.group.Projects"].firstMatch
        XCTAssertTrue(reports.waitForExistence(timeout: 5), "No Daily Reports results group")
        XCTAssertTrue(projects.waitForExistence(timeout: 5), "No Projects results group")
        XCTAssertLessThan(reports.frame.minY, projects.frame.minY,
                          "On Daily Reports, report results should come first")
    }
}
