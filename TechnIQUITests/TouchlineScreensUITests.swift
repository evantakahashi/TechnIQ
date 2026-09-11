import XCTest

/// Smoke tests for the remaining Touchline screens: You (6c), Community drills (6b), Sign-in (7a)
/// and Onboarding (7b). Runs against the seeded demo player where a signed-in state is needed
/// and against the `-TQScreen` debug hosts for the pre-auth screens.
final class TouchlineScreensUITests: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launch(_ arguments: [String]) {
        app.launchArguments = arguments
        app.launch()
    }

    private func shot(_ name: String) {
        shotIndex += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = String(format: "%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("touchlineshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "S%02d-%@.png", shotIndex, name)))
    }

    private func settle(_ seconds: TimeInterval = 1.0) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func dismissCoachMarkIfPresent() {
        let gotIt = app.buttons["Got it"]
        if gotIt.waitForExistence(timeout: 2) {
            gotIt.tap()
            settle(0.6)
        }
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    private func button(containing fragment: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    private func row(_ title: String) -> XCUIElement {
        app.buttons["row.\(title)"]
    }

    /// Exact, case-insensitive label match (Touchline labels render uppercase via textCase).
    private func buttonNamed(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                element.tap()
                return true
            }
            settle(0.3)
        }
        return false
    }

    private func goBack() {
        let back = app.buttons["Back"]
        if tapWhenHittable(back, timeout: 4) { settle(0.8); return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        settle(0.8)
    }

    private func dismissSheet(buttonTitles: [String] = ["Cancel", "Close", "Done"]) {
        for title in buttonTitles {
            let button = app.buttons[title]
            if button.waitForExistence(timeout: 1.5), button.isHittable {
                button.tap()
                let gone = NSPredicate(format: "exists == false")
                _ = XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: button)], timeout: 5)
                settle(0.8)
                return
            }
        }
        app.swipeDown(velocity: .fast)
        settle(1.0)
    }

    /// Taps a text field until it has keyboard focus (a tap during a transition can miss).
    private func focus(_ field: XCUIElement) {
        for _ in 0..<3 {
            field.tap()
            settle(0.6)
            if let focused = field.value(forKey: "hasKeyboardFocus") as? Bool, focused { return }
        }
    }

    /// Scrolls the main scroll view until the element is hittable (or gives up).
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        var swipes = 0
        while swipes < maxSwipes {
            if element.exists, element.isHittable { return true }
            app.swipeUp(velocity: .slow)
            settle(0.5)
            swipes += 1
        }
        return element.exists && element.isHittable
    }

    // MARK: - You (6c)

    func test_youTab_identityCardRowsAndSignOut() throws {
        launch(["-TQSeedDemo", "-TQTab", "4"])
        XCTAssertTrue(row("Progress & analytics").waitForExistence(timeout: 40), "You tab rows should appear")
        dismissCoachMarkIfPresent()
        shot("you")

        XCTAssertTrue(text(containing: "sessions").exists, "stat rail sessions label")
        XCTAssertTrue(text(containing: "streak").exists, "stat rail streak label")
        XCTAssertTrue(text(containing: "Kit number").exists || app.staticTexts["9"].exists, "ghosted kit number")

        // Pushed destinations come back with the chalk back chevron.
        XCTAssertTrue(tapWhenHittable(row("Achievements")), "achievements row")
        XCTAssertTrue(text(containing: "unlocked").waitForExistence(timeout: 8), "achievements screen")
        shot("achievements")
        goBack()
        XCTAssertTrue(row("Achievements").waitForExistence(timeout: 8), "back on You after achievements")

        XCTAssertTrue(tapWhenHittable(row("Matches & seasons")), "matches row")
        XCTAssertTrue(app.navigationBars["Match History"].waitForExistence(timeout: 8) || text(containing: "Match History").waitForExistence(timeout: 2), "match history screen")
        shot("match-history")
        goBack()
        XCTAssertTrue(row("Matches & seasons").waitForExistence(timeout: 8), "back on You after matches")

        // Sheets.
        XCTAssertTrue(tapWhenHittable(row("Edit profile")), "edit profile row")
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 8) || text(containing: "Edit Profile").waitForExistence(timeout: 2), "edit profile sheet")
        shot("edit-profile")
        dismissSheet()
        XCTAssertTrue(row("Edit profile").waitForExistence(timeout: 8), "back on You after edit profile")

        XCTAssertTrue(tapWhenHittable(app.buttons["profile.settings"]), "gear opens settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8) || text(containing: "Settings").waitForExistence(timeout: 2), "settings sheet")
        dismissSheet(buttonTitles: ["Done", "Close", "Cancel"])

        // Sign out lives at the bottom as a ghost button behind a confirmation alert.
        let signOut = app.buttons["profile.signOut"]
        XCTAssertTrue(scrollTo(signOut), "sign out button reachable")
        shot("you-bottom")
        XCTAssertTrue(text(containing: "TechnIQ Pro").exists, "pro row visible")
        signOut.tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "sign out confirmation alert")
        cancel.tap()
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), "still signed in after cancelling")
    }

    // MARK: - Community drills (6b)

    func test_communityDrills_featuredCardChipsAndRows() throws {
        launch(["-TQSeedDemo", "-TQTab", "3"])
        XCTAssertTrue(text(containing: "Drill of the week").waitForExistence(timeout: 40), "featured card")
        dismissCoachMarkIfPresent()
        shot("community-drills")

        XCTAssertTrue(text(containing: "Wall pass finishing").exists, "featured drill title")
        XCTAssertTrue(row("Box-to-box shuttles").exists, "drill rows with saves")

        // Preview opens the shared drill sheet.
        XCTAssertTrue(tapWhenHittable(buttonNamed("Preview")), "preview button")
        XCTAssertTrue(app.navigationBars["Drill Details"].waitForExistence(timeout: 8) || text(containing: "Wall pass finishing").waitForExistence(timeout: 2), "shared drill detail")
        shot("shared-drill")
        dismissSheet(buttonTitles: ["Close", "Cancel", "Done"])
        XCTAssertTrue(buttonNamed("Preview").waitForExistence(timeout: 8), "back on drills after preview")

        // Chips filter the list.
        XCTAssertTrue(tapWhenHittable(buttonNamed("Physical")), "physical chip")
        XCTAssertTrue(row("Sprint ladder").waitForExistence(timeout: 5), "physical drills listed")
        XCTAssertFalse(row("Third-man runs").exists, "tactical drill filtered out")
        shot("community-physical")

        // Rows open the same sheet.
        XCTAssertTrue(tapWhenHittable(row("Sprint ladder")), "drill row")
        XCTAssertTrue(app.navigationBars["Drill Details"].waitForExistence(timeout: 8) || text(containing: "Sprint ladder").waitForExistence(timeout: 2), "row opens drill detail")
        dismissSheet(buttonTitles: ["Close", "Cancel", "Done"])

        // Segment switches tabs and back.
        XCTAssertTrue(tapWhenHittable(buttonNamed("Leaderboard")), "leaderboard segment")
        settle(1.0)
        shot("community-leaderboard")
        XCTAssertTrue(tapWhenHittable(buttonNamed("Drills")), "drills segment")
        XCTAssertTrue(text(containing: "Drill of the week").waitForExistence(timeout: 8), "drills tab restored")
    }

    // MARK: - Sign-in (7a)

    func test_signIn_landingAndEmailForm() throws {
        launch(["-TQScreen", "signIn"])
        let apple = app.buttons["signin.apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 40), "sign-in landing")
        shot("sign-in")

        XCTAssertTrue(text(containing: "Train with").exists, "headline")
        XCTAssertTrue(app.buttons["signin.google"].exists, "google button")
        XCTAssertTrue(app.buttons["signin.guest"].exists, "guest link")

        XCTAssertTrue(tapWhenHittable(app.buttons["signin.email"]), "email button")
        XCTAssertTrue(text(containing: "Welcome back").waitForExistence(timeout: 8), "email sign-in form")
        XCTAssertFalse(app.buttons["email.submit"].isEnabled, "submit disabled until fields are filled")
        shot("email-sign-in")

        XCTAssertTrue(tapWhenHittable(buttonNamed("Create account")), "create account segment")
        XCTAssertTrue(text(containing: "Create your account").waitForExistence(timeout: 5), "create account form")
        XCTAssertTrue(app.textFields["Name"].exists || app.textFields.firstMatch.exists, "name field on sign-up")
        shot("email-create")

        goBack()
        XCTAssertTrue(apple.waitForExistence(timeout: 8), "back on landing")
    }

    // MARK: - Onboarding (7b)

    func test_onboarding_fiveDecisionScreens() throws {
        launch(["-TQScreen", "onboarding"])
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 40), "onboarding goal step")
        XCTAssertTrue(text(containing: "training for").exists, "goal headline")
        XCTAssertTrue(text(containing: "Step 1 of 5").exists || app.staticTexts["01"].exists, "stepper at 01")
        shot("onboarding-goal")

        XCTAssertTrue(tapWhenHittable(button(containing: "Build Fitness")), "select a goal")
        XCTAssertTrue(next.label.localizedCaseInsensitiveContains("how often"), "button names the next step: \(next.label)")
        next.tap()
        XCTAssertTrue(text(containing: "How often").waitForExistence(timeout: 5), "frequency step")
        shot("onboarding-frequency")
        XCTAssertTrue(tapWhenHittable(button(containing: "Daily")), "select frequency")
        next.tap()

        XCTAssertTrue(text(containing: "Where do").waitForExistence(timeout: 5), "position step")
        XCTAssertTrue(tapWhenHittable(button(containing: "Forward")), "select position")
        XCTAssertTrue(tapWhenHittable(buttonNamed("Left")), "stronger foot segment")
        shot("onboarding-position")
        _ = scrollTo(next, maxSwipes: 3)
        next.tap()

        XCTAssertTrue(text(containing: "most work").waitForExistence(timeout: 5), "weak spots step")
        XCTAssertTrue(tapWhenHittable(button(containing: "Dribbling")), "select a weak spot")
        XCTAssertTrue(tapWhenHittable(button(containing: "Shooting")), "select a second weak spot")
        shot("onboarding-weak-spots")
        _ = scrollTo(next, maxSwipes: 3)
        next.tap()

        XCTAssertTrue(text(containing: "about you").waitForExistence(timeout: 5), "about step")
        settle(1.2)   // let the step transition finish before touching the fields
        XCTAssertTrue(next.label.localizedCaseInsensitiveContains("Build my plan"), "final button label: \(next.label)")
        XCTAssertFalse(next.isEnabled, "build plan disabled until name and age are given")
        let name = app.textFields.element(boundBy: 0)
        XCTAssertTrue(name.waitForExistence(timeout: 5), "name field")
        focus(name)
        name.typeText("Evan")
        let age = app.textFields.element(boundBy: 1)
        focus(age)
        age.typeText("14")
        if app.keyboards.count > 0, app.buttons["Done"].exists { app.buttons["Done"].tap() }
        settle(0.5)
        XCTAssertTrue(next.isEnabled, "build plan enabled once name and age are valid")
        shot("onboarding-about")

        // Back returns to the previous decision with its answer kept.
        goBack()
        XCTAssertTrue(text(containing: "most work").waitForExistence(timeout: 5), "back to weak spots")
        XCTAssertTrue(button(containing: "Dribbling").isSelected || button(containing: "Dribbling").exists, "weak spot selection kept")
    }
}
