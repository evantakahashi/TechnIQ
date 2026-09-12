import XCTest

/// Screenshot tour of the screens and sheets the smoke suites don't visit: Plans segments and
/// sheets, the plan-detail day sheet, the new-drill sheet, avatar / shop / settings / progress /
/// session history from You, the in-session drill sheet, the Community feed and post composer.
/// Assertions are deliberately loose — the value is the screenshots (tmp/touchlineshots/T*.png).
final class TouchlineTourUITests: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    private func launch(_ arguments: [String]) {
        app.launchArguments = ["-TQSeedDemo", "-TQLocalUser"] + arguments
        app.launch()
    }

    private func shot(_ name: String) {
        shotIndex += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = String(format: "T%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("touchlineshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "T%02d-%@.png", shotIndex, name)))
    }

    private func settle(_ seconds: TimeInterval = 1.0) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func dismissCoachMarkIfPresent() {
        let gotIt = app.buttons["Got it"]
        if gotIt.waitForExistence(timeout: 2) { gotIt.tap(); settle(0.6) }
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    private func button(containing fragment: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    private func buttonNamed(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    private func row(_ title: String) -> XCUIElement { app.buttons["row.\(title)"] }

    @discardableResult
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { element.tap(); return true }
            settle(0.3)
        }
        return false
    }

    private func goBack() {
        if tapWhenHittable(app.buttons["Back"], timeout: 4) { settle(0.8); return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        settle(0.8)
    }

    /// Drags a detented bottom sheet (no Cancel button) down from its top edge.
    private func dismissBottomSheet() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
        start.press(forDuration: 0.1, thenDragTo: end)
        settle(1.0)
    }

    private func dismissSheet(_ titles: [String] = ["Cancel", "Close", "Done"]) {
        for title in titles {
            let b = app.buttons[title]
            if b.waitForExistence(timeout: 1.5), b.isHittable {
                b.tap()
                _ = XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: b)], timeout: 5)
                settle(0.8)
                return
            }
        }
        app.swipeDown(velocity: .fast)
        settle(1.0)
    }

    // MARK: - Plans

    func test_tour_plans() throws {
        launch(["-TQTab", "2"])
        XCTAssertTrue(button(containing: "New plan").waitForExistence(timeout: 40), "plans tab")
        dismissCoachMarkIfPresent()
        shot("plans-prebuilt")

        tapWhenHittable(button(containing: "My plans"))
        settle(0.8)
        shot("plans-mine")

        tapWhenHittable(button(containing: "New plan"))
        settle(1.2)
        shot("plans-new-sheet")
        // "Build it with the coach" → AI plan generator sheet
        if tapWhenHittable(row("Build it with the coach"), timeout: 3) {
            settle(1.5)
            shot("plan-generator")
            dismissSheet()
            settle(0.8)
        } else {
            dismissBottomSheet()
        }

        // Active plan card → plan detail → day sheet
        tapWhenHittable(button(containing: "Active plan"))
        XCTAssertTrue(text(containing: "Striker Development").waitForExistence(timeout: 8), "plan detail")
        settle(0.8)
        shot("plan-detail-top")
        app.swipeUp(velocity: .slow)
        settle(0.6)
        shot("plan-detail-scrolled")
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'WK 3'")).firstMatch
        if tapWhenHittable(cell, timeout: 4) {
            settle(1.0)
            shot("plan-day-sheet")
            dismissSheet(["Done", "Close", "Cancel"])
        }
        goBack()
    }

    // MARK: - Train

    func test_tour_train() throws {
        launch(["-TQTab", "1"])
        XCTAssertTrue(button(containing: "New drill").waitForExistence(timeout: 40), "train tab")
        dismissCoachMarkIfPresent()
        tapWhenHittable(button(containing: "New drill"))
        settle(1.2)
        shot("train-new-drill-sheet")
        // Pick the AI route to see the generator form, then cancel.
        if tapWhenHittable(row("Generate with the coach"), timeout: 3) {
            settle(1.2)
            shot("train-ai-generator")
            dismissSheet()
        } else {
            dismissBottomSheet()
        }
        shot("train-sections")
        app.swipeUp(velocity: .slow)
        settle(0.6)
        shot("train-sections-scrolled")
        if tapWhenHittable(button(containing: "See all My drills"), timeout: 3) {
            settle(1.0)
            shot("train-my-drills")
            goBack()
        }
    }

    // MARK: - You

    func test_tour_you() throws {
        launch(["-TQTab", "4"])
        XCTAssertTrue(row("Progress & analytics").waitForExistence(timeout: 40), "you tab")
        dismissCoachMarkIfPresent()

        tapWhenHittable(row("Progress & analytics"))
        settle(1.5)
        shot("progress")
        goBack()

        tapWhenHittable(row("Session history"))
        settle(1.5)
        shot("session-history")
        goBack()

        tapWhenHittable(row("Edit profile"))
        settle(1.2)
        shot("edit-profile")
        dismissSheet()

        tapWhenHittable(row("Kit & avatar"))
        settle(1.5)
        shot("avatar")
        dismissSheet(["Done", "Close", "Cancel"])

        tapWhenHittable(row("Shop"))
        settle(1.5)
        shot("shop")
        dismissSheet(["Done", "Close", "Cancel"])

        tapWhenHittable(app.buttons["profile.settings"])
        settle(1.5)
        shot("settings")
        dismissSheet(["Done", "Close", "Cancel"])
    }

    // MARK: - Session drill sheet + Community feed

    func test_tour_sessionSheetAndFeed() throws {
        launch([])
        let start = app.buttons["Start session"]
        XCTAssertTrue(start.waitForExistence(timeout: 40), "home")
        dismissCoachMarkIfPresent()
        tapWhenHittable(start)
        XCTAssertTrue(app.buttons["Drill steps"].waitForExistence(timeout: 10), "active session")
        settle(1.0)
        tapWhenHittable(app.buttons["Drill steps"])
        settle(1.2)
        shot("session-drill-sheet")
        dismissSheet(["Done", "Close", "Cancel"])
        tapWhenHittable(app.buttons["End session"])
        settle(0.6)
        shot("session-end-alert")
        if app.alerts.buttons["End Session"].waitForExistence(timeout: 3) { app.alerts.buttons["End Session"].tap() }
        settle(1.5)
        shot("session-complete-early")
        if tapWhenHittable(app.buttons["Done"], timeout: 5) { settle(1.0) }

        tapWhenHittable(app.buttons["Community"])
        settle(1.0)
        tapWhenHittable(buttonNamed("Leaderboard"))
        settle(1.5)
        shot("community-leaderboard")
        tapWhenHittable(buttonNamed("Feed"))
        settle(1.5)
        shot("community-feed")
        tapWhenHittable(button(containing: "Post"))
        settle(1.2)
        shot("community-create-post")
        dismissSheet()
    }
}
