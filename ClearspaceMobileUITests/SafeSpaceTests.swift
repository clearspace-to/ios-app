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

        // A fresh install shows the space selector first; pick safe_space.
        // (Skipped when a previous run already stored a space.)
        if app.staticTexts["Choose a space to get started"].waitForExistence(timeout: 3) {
            app.staticTexts["safe_space"].firstMatch.tap()
        }

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
        // Start pinned to sales_space to prove the switcher crosses apps.
        let app = launchApp(["-app=sales_space"])

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

        // The record sets live behind the segmented control.
        let talksTab = app.buttons["Talks"]
        XCTAssertTrue(talksTab.waitForExistence(timeout: 5), "Project detail tabs did not render")
        talksTab.tap()
        XCTAssertTrue(app.staticTexts["Toolbox Talks"].waitForExistence(timeout: 5),
                      "Project detail did not show its toolbox talks")
        XCTAssertTrue(app.staticTexts["Ladder Safety & Three-Point Contact"].waitForExistence(timeout: 5),
                      "Project detail did not list the project's talks")
    }

    func testProjectDetailFpusTabListsWeeks() {
        let app = launchApp(["-app=safe_space"])

        let project = app.staticTexts["Riverside Tower — Floors 8-12"]
        XCTAssertTrue(project.waitForExistence(timeout: 10))
        project.tap()

        let fpusTab = app.buttons["FPUs"]
        XCTAssertTrue(fpusTab.waitForExistence(timeout: 5), "FPUs tab missing from project detail")
        fpusTab.tap()

        XCTAssertTrue(app.staticTexts["Outstanding"].waitForExistence(timeout: 5),
                      "FPU history did not flag the unfiled week")
        XCTAssertTrue(app.staticTexts["58%"].exists, "FPU history did not show a filed week's overall")
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

    func testFpusDashboardListsProjectsAndOpensLogSheet() {
        let app = launchApp(["-app=safe_space", "-screen=fpus"])
        XCTAssertTrue(app.navigationBars["FPUs"].waitForExistence(timeout: 10))

        // Attention-first sort: the outstanding project leads the list.
        let row = app.staticTexts["Riverside Tower — Floors 8-12"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "FPU dashboard did not list projects")
        XCTAssertTrue(app.staticTexts["Outstanding"].exists, "Outstanding badge missing")

        // Any row opens the log sheet with the API-served divisions prefilled.
        row.tap()
        XCTAssertTrue(app.navigationBars["Log FPU"].waitForExistence(timeout: 5),
                      "Tapping a dashboard row did not open the log sheet")
        XCTAssertTrue(app.staticTexts["A1 — Demolition"].waitForExistence(timeout: 5),
                      "Trade divisions did not load in the log sheet")
    }

    func testCreateSheetOffersLogFpu() {
        let app = launchApp(["-app=safe_space"])
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 10))

        app.buttons["bottomBar.create"].tap()
        let logFpu = app.buttons["Log FPU"]
        XCTAssertTrue(logFpu.waitForExistence(timeout: 5), "Log FPU missing from the create sheet")
        logFpu.tap()

        XCTAssertTrue(app.navigationBars["Log FPU"].waitForExistence(timeout: 5),
                      "Log FPU did not present the entry sheet")
    }

    func testPastWeekFpuIsLockedReadOnly() {
        let app = launchApp(["-app=safe_space", "-screen=fpus"])
        XCTAssertTrue(app.navigationBars["FPUs"].waitForExistence(timeout: 10))

        app.buttons["fpus.weekBack"].tap()

        let row = app.staticTexts["Riverside Tower — Floors 8-12"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.navigationBars["Log FPU"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This week is locked — past FPUs can't be edited."]
            .waitForExistence(timeout: 5), "Past week did not show the lock message")
        XCTAssertFalse(app.buttons["Submit"].exists, "Submit should not be offered on a locked past week")

        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        XCTAssertFalse(stepper.isEnabled, "Progress steppers should be disabled on a locked past week")
    }

    func testCurrentWeekFpuIsStillEditable() {
        let app = launchApp(["-app=safe_space", "-screen=fpus"])
        XCTAssertTrue(app.navigationBars["FPUs"].waitForExistence(timeout: 10))

        let row = app.staticTexts["Riverside Tower — Floors 8-12"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.navigationBars["Log FPU"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Submit"].waitForExistence(timeout: 5),
                      "Current week should still offer Submit")
        XCTAssertFalse(app.staticTexts["This week is locked — past FPUs can't be edited."].exists)
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
