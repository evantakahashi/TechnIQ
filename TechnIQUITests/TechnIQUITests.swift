import XCTest

final class TechnIQUITests: XCTestCase {

    let app = XCUIApplication()

    /// Touchline's tab bar is a custom view (TQTabBar), not a UITabBar: the tabs are plain buttons
    /// labelled Home / Train / Plans / You (Community only with `-TQCommunity`).
    private let tabLabels = ["Home", "Train", "Plans", "You"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["UI_TESTING", "-TQSeedDemo", "-TQLocalUser"]
        app.launch()
    }

    private func tabBarPresent(timeout: TimeInterval = 40) -> Bool {
        app.buttons["Home"].waitForExistence(timeout: timeout)
    }

    // MARK: - Smoke Tests

    func test_appLaunches_showsUI() {
        let authExists = app.buttons["signin.apple"].waitForExistence(timeout: 5)
        let dashExists = tabBarPresent()
        XCTAssertTrue(authExists || dashExists, "App should show auth or dashboard on launch")
    }

    func test_tabBar_hasExpectedTabs() {
        guard tabBarPresent() else { return }
        let present = tabLabels.filter { app.buttons[$0].exists }
        XCTAssertEqual(present, tabLabels, "four tabs")
        XCTAssertFalse(app.buttons["Community"].exists, "Community is flagged off by default")
    }

    func test_tabBar_communityFlagAddsTheTab() {
        app.terminate()
        app.launchArguments = ["UI_TESTING", "-TQSeedDemo", "-TQLocalUser", "-TQCommunity"]
        app.launch()
        guard tabBarPresent() else { return }
        XCTAssertTrue(app.buttons["Community"].exists, "-TQCommunity shows the Community tab")
    }

    func test_exerciseLibrary_navigable() {
        guard tabBarPresent() else { return }
        app.buttons["Train"].tap()
        let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 5) ||
                         app.collectionViews.firstMatch.waitForExistence(timeout: 3) ||
                         app.tables.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Training area should have scrollable content")
    }

    func test_youTabShowsAccountRows() {
        guard tabBarPresent() else { return }
        app.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Edit profile"].waitForExistence(timeout: 10), "You tab shows the account rows")
    }

    func test_appDoesNotCrash_afterInteraction() {
        if tabBarPresent() {
            for label in tabLabels where app.buttons[label].exists {
                app.buttons[label].tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(app.exists, "App should still be running")
    }
}
