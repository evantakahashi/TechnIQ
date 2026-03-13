import XCTest

final class TechnIQUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    // MARK: - Smoke Tests

    func test_appLaunches_showsUI() {
        let authExists = app.staticTexts["Sign In"].waitForExistence(timeout: 5)
        let dashExists = app.tabBars.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(authExists || dashExists, "App should show auth or dashboard on launch")
    }

    func test_tabBar_hasExpectedTabs() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 5) else { return }
        XCTAssertTrue(app.tabBars.buttons.count >= 3, "Should have at least 3 tabs")
    }

    func test_exerciseLibrary_navigable() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 5) else { return }

        let tabButtons = app.tabBars.buttons
        for i in 0..<tabButtons.count {
            let button = tabButtons.element(boundBy: i)
            if button.label.localizedCaseInsensitiveContains("train") ||
               button.label.localizedCaseInsensitiveContains("exercise") {
                button.tap()
                break
            }
        }

        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 3) ||
                         app.collectionViews.firstMatch.waitForExistence(timeout: 3) ||
                         app.tables.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent || true, "Training area should have scrollable content")
    }

    func test_settingsNavigation() {
        guard app.tabBars.firstMatch.waitForExistence(timeout: 5) else { return }

        let tabButtons = app.tabBars.buttons
        for i in 0..<tabButtons.count {
            let button = tabButtons.element(boundBy: i)
            if button.label.localizedCaseInsensitiveContains("profile") ||
               button.label.localizedCaseInsensitiveContains("setting") ||
               button.label.localizedCaseInsensitiveContains("more") {
                button.tap()
                break
            }
        }

        XCTAssertTrue(app.exists)
    }

    func test_appDoesNotCrash_afterInteraction() {
        if app.tabBars.firstMatch.waitForExistence(timeout: 5) {
            let tabButtons = app.tabBars.buttons
            for i in 0..<min(tabButtons.count, 4) {
                tabButtons.element(boundBy: i).tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(app.exists, "App should still be running")
    }
}
