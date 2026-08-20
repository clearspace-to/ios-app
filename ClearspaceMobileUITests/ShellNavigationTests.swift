import XCTest

/// Drives the real app in the simulator to prove the shell's controls work.
final class ShellNavigationTests: XCTestCase {

    private func launchApp(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-preview"] + extraArgs
        app.launch()
        return app
    }

    // MARK: - Bottom bar

    func testMenuButtonOpensDrawer() {
        let app = launchApp()

        let menu = app.buttons["bottomBar.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "Bottom bar menu button never appeared")
        XCTAssertTrue(menu.isHittable, "Menu button exists but is not hittable — something is covering it")

        menu.tap()

        XCTAssertTrue(app.staticTexts["SALES_SPACE"].waitForExistence(timeout: 5),
                      "Tapping the menu button did not open the drawer")
    }

    func testDrawerNavigatesToPipeline() {
        let app = launchApp()

        app.buttons["bottomBar.menu"].tap()
        let pipeline = app.buttons["Pipeline"]
        XCTAssertTrue(pipeline.waitForExistence(timeout: 5))
        pipeline.tap()

        XCTAssertTrue(app.navigationBars["Pipeline"].waitForExistence(timeout: 5),
                      "Drawer selection did not navigate to Pipeline")
    }

    func testSearchButtonOpensCommandPalette() {
        let app = launchApp()

        let search = app.buttons["bottomBar.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5), "Command palette did not open")
    }

    func testCreateButtonOpensActionSheet() {
        let app = launchApp()

        let create = app.buttons["bottomBar.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()

        XCTAssertTrue(app.buttons["New Opportunity"].waitForExistence(timeout: 5),
                      "Create action sheet did not open")
    }

    // MARK: - Drawer covers the full screen height

    func testDrawerFillsFullScreenHeight() {
        let app = launchApp(["-drawer"])
        XCTAssertTrue(app.staticTexts["SALES_SPACE"].waitForExistence(timeout: 10))

        // The drawer's own scroll view should span essentially the whole window.
        let window = app.windows.element(boundBy: 0).frame
        let drawer = app.scrollViews.firstMatch.frame

        XCTAssertLessThanOrEqual(drawer.minY, window.minY + 60,
                                 "Drawer does not reach the top of the screen")
        XCTAssertGreaterThanOrEqual(drawer.maxY, window.maxY - 60,
                                    "Drawer does not reach the bottom of the screen")
    }

    // MARK: - Content is never trapped under the floating bar

    func testLastRowStaysReachableAboveBottomBar() {
        let app = launchApp(["-screen=opportunities"])

        let lastRow = app.staticTexts["Bayview Corporate Centre"]
        for _ in 0..<6 where !lastRow.exists || !lastRow.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(lastRow.exists, "Never reached the last opportunity by scrolling")
        XCTAssertTrue(lastRow.isHittable,
                      "The last row is covered by the floating bottom bar and cannot be tapped")
    }

    // MARK: - Command bar search scoping

    func testCommandBarSearchesCurrentRecordTypeFirst() {
        let app = launchApp(["-screen=accounts"])

        app.buttons["bottomBar.search"].tap()
        let field = app.textFields["palette.query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Meridian")

        let accountsHeader = app.staticTexts["palette.group.Accounts"].firstMatch
        let opportunitiesHeader = app.staticTexts["palette.group.Opportunities"].firstMatch
        XCTAssertTrue(accountsHeader.waitForExistence(timeout: 5), "No Accounts results group")
        XCTAssertTrue(opportunitiesHeader.waitForExistence(timeout: 5), "No Opportunities results group")

        XCTAssertLessThan(accountsHeader.frame.minY, opportunitiesHeader.frame.minY,
                          "On the Accounts screen, account results should be listed before other record types")
    }
}
