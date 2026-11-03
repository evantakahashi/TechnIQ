import XCTest

/// Match day + builder prefill on the demo seed (next match in two days, weak spots Weak Foot and
/// Shooting): Home's week strip and Next match row, the Training profile, both plan builders and
/// the plan grid. Screenshots land in the runner's tmp `touchlineshots/M*.png`.
final class MatchDayUITests: XCTestCase {
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
        attachment.name = String(format: "M%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("touchlineshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "M%02d-%@.png", shotIndex, name)))
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

    private func dismissSheet(_ titles: [String] = ["Cancel", "Close", "Done"]) {
        for title in titles {
            let b = app.buttons[title]
            if b.waitForExistence(timeout: 1.5), b.isHittable {
                b.tap()
                settle(1.0)
                return
            }
        }
        app.swipeDown(velocity: .fast)
        settle(1.0)
    }

    func test_home_marksTheMatchAndOffersNextMatch() throws {
        launch(["-TQTab", "0"])
        XCTAssertTrue(text(containing: "This week").waitForExistence(timeout: 40), "home")
        dismissCoachMarkIfPresent()
        settle(1.0)
        shot("home-top")
        app.swipeUp(velocity: .slow)
        settle(0.8)
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'match'")).firstMatch
        XCTAssertTrue(match.exists, "a cell or row mentions the match")
        XCTAssertTrue(app.buttons["home.nextMatch"].waitForExistence(timeout: 5), "next match row")
        shot("home-rows")
        if tapWhenHittable(app.buttons["home.nextMatch"], timeout: 4) {
            settle(1.2)
            XCTAssertTrue(app.buttons["nextMatch.save"].waitForExistence(timeout: 5), "next match sheet")
            shot("home-next-match-sheet")
            dismissSheet(["Cancel"])
        }
    }

    func test_trainingProfile_showsNextMatch() throws {
        launch(["-TQTab", "4"])
        XCTAssertTrue(row("Training profile").waitForExistence(timeout: 40), "you tab")
        dismissCoachMarkIfPresent()
        tapWhenHittable(row("Training profile"))
        settle(1.5)
        XCTAssertTrue(app.buttons["trainingProfile.save"].waitForExistence(timeout: 5), "training profile sheet")
        XCTAssertTrue(text(containing: "Next match").exists, "next match group")
        shot("training-profile")
    }

    func test_planBuilders_prefillFromTheProfile_andPlanGridMarksTheMatch() throws {
        launch(["-TQTab", "2"])
        XCTAssertTrue(text(containing: "Striker Development").waitForExistence(timeout: 40), "plan tab")
        dismissCoachMarkIfPresent()
        settle(1.0)
        shot("plan-detail-top")
        app.swipeUp(velocity: .slow)
        settle(0.8)
        XCTAssertTrue(text(containing: "Match day").waitForExistence(timeout: 4) || button(containing: "Match day").exists, "plan lists the match day")
        shot("plan-detail-matches")
        app.swipeDown(velocity: .fast)
        settle(0.6)

        XCTAssertTrue(tapWhenHittable(app.buttons["plan.allPlans"]), "All plans")
        XCTAssertTrue(button(containing: "New plan").waitForExistence(timeout: 8), "plans library")
        tapWhenHittable(button(containing: "New plan"))
        settle(1.2)
        if tapWhenHittable(row("Build it with the coach"), timeout: 3) {
            settle(1.5)
            XCTAssertTrue(app.buttons["planGenerator.build"].waitForExistence(timeout: 6), "generator form")
            shot("ai-builder-top")
            app.swipeUp(velocity: .slow)
            settle(0.6)
            shot("ai-builder-mid")
            app.swipeUp(velocity: .slow)
            settle(0.6)
            XCTAssertTrue(app.descendants(matching: .any)["planGenerator.nextMatch"].exists, "next match field")
            shot("ai-builder-bottom")
            dismissSheet()
        }
        tapWhenHittable(button(containing: "New plan"))
        settle(1.0)
        if tapWhenHittable(row("Build it yourself"), timeout: 3) {
            settle(1.2)
            XCTAssertTrue(app.buttons["customPlan.create"].waitForExistence(timeout: 6), "custom builder form")
            shot("custom-builder-top")
            app.swipeUp(velocity: .slow)
            settle(0.6)
            shot("custom-builder-mid")
            app.swipeUp(velocity: .slow)
            settle(0.6)
            shot("custom-builder-bottom")
            dismissSheet()
        }
    }
}
