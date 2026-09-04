import XCTest

/// Drives the app like a first-time guest user and captures a screenshot at every
/// step. Assertion-light by design: the artifact is the screenshot trail, so one
/// missing element must not abort the tour.
final class WalkthroughUITests: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    private func shot(_ name: String) {
        shotIndex += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = String(format: "%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also persist to the runner's tmp dir so shots survive even if the
        // result bundle never finalizes (recoverable from the sim container).
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("walkshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "%02d-%@.png", shotIndex, name)))
    }

    @discardableResult
    private func tapFirst(_ labels: [String], in element: XCUIElement? = nil, timeout: TimeInterval = 3) -> Bool {
        let root: XCUIElement = element ?? app
        for label in labels {
            let button = root.buttons[label]
            if button.waitForExistence(timeout: timeout), button.isHittable {
                button.tap()
                return true
            }
            let text = root.staticTexts[label]
            if text.exists, text.isHittable {
                text.tap()
                return true
            }
            let other = root.otherElements[label]
            if other.exists, other.isHittable {
                other.tap()
                return true
            }
        }
        return false
    }

    private func settle(_ seconds: TimeInterval = 1.5) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func typeInto(placeholder: String, text: String) {
        let plain = app.textFields[placeholder]
        let secure = app.secureTextFields[placeholder]
        let field = plain.exists ? plain : secure
        guard field.waitForExistence(timeout: 2), field.isHittable else { return }
        field.tap()
        field.typeText(text)
    }

    func test_guestTapProbe() throws {
        settle(3)
        shot("probe-before")
        let byLabel = app.buttons["Try without an account"]
        let byText = app.buttons["TRY WITHOUT AN ACCOUNT"]
        print("WALKDBG byLabel exists=\(byLabel.exists) hittable=\(byLabel.exists ? byLabel.isHittable : false) frame=\(byLabel.exists ? byLabel.frame : .zero)")
        print("WALKDBG byText exists=\(byText.exists) hittable=\(byText.exists ? byText.isHittable : false) frame=\(byText.exists ? byText.frame : .zero)")
        if byText.exists, byText.isHittable {
            byText.tap()
        } else if byLabel.exists, byLabel.isHittable {
            byLabel.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.824)).tap()
        }
        for i in 1...10 {
            settle(3)
            shot("probe-after-\(i)")
            if !app.textFields["Enter your email"].exists { break }
        }
    }

    func test_loginAndDrill() throws {
        settle(4)
        // Sign in with the seeded demo account if we're on the auth screen.
        if app.textFields["Enter your email"].waitForExistence(timeout: 6) {
            typeInto(placeholder: "Enter your email", text: "demo.reviewer@techniq-demo.app")
            typeInto(placeholder: "Enter your password", text: "Demo1234!")
            shot("login-filled")
            _ = tapFirst(["LOGIN", "Login"], timeout: 3)
            settle(8)
        }
        shot("after-login")
        for _ in 0..<3 { if !tapFirst(["Got it"], timeout: 1) { break }; settle(0.5) }
        // Wait for the dashboard hero, then generate.
        var heroFound = false
        for _ in 0..<10 {
            if app.staticTexts["Generate AI Drill"].exists || app.buttons["Generate AI Drill"].exists { heroFound = true; break }
            settle(4)
        }
        shot("dashboard-state")
        guard heroFound, tapFirst(["Generate AI Drill"], timeout: 4) else { shot("hero-missing"); return }
        settle(2)
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.waitForExistence(timeout: 3), field.isHittable {
            field.tap()
            field.typeText("get better at shooting with my weak foot")
            if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        }
        _ = tapFirst(["GENERATE DRILL", "Generate Drill", "Generate Custom Drill"], timeout: 4)
        for i in 1...12 {
            settle(10)
            shot("live-wait-\(i)")
            let errored = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'snag' OR label CONTAINS[c] 'failed' OR label CONTAINS[c] 'error'")).firstMatch.exists
            let done = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'start' OR label CONTAINS[c] 'save' OR label CONTAINS[c] 'begin'")).firstMatch.exists
            if errored || done { break }
        }
        shot("live-drill-final")
        app.swipeUp()
        settle(1)
        shot("live-drill-final-2")
    }

    func test_aiDrillLive() throws {
        settle(3)
        for _ in 0..<3 { if !tapFirst(["Got it"], timeout: 1) { break }; settle(0.5) }
        shot("dash")
        guard tapFirst(["Generate AI Drill"], timeout: 5) else { shot("no-hero"); return }
        settle(2)
        shot("generator")
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.waitForExistence(timeout: 3), field.isHittable {
            field.tap()
            field.typeText("get better at shooting with my weak foot")
            if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
            settle(0.5)
        }
        shot("generator-filled")
        _ = tapFirst(["GENERATE DRILL", "Generate Drill", "Generate Custom Drill", "GENERATE CUSTOM DRILL"], timeout: 4)
        // Live backend call — poll up to ~120s for a result or error.
        for i in 1...12 {
            settle(10)
            shot("gen-wait-\(i)")
            let errored = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] 'error' OR label CONTAINS[c] 'try again'")).firstMatch.exists
            // A generated drill shows a Start/Save action or a diagram; the form's Generate button is gone.
            let done = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'start' OR label CONTAINS[c] 'save' OR label CONTAINS[c] 'begin'")).firstMatch.exists
            if errored || done { break }
        }
        shot("drill-result")
        app.swipeUp()
        settle(1)
        shot("drill-result-scrolled")
    }

    func test_firstSession() throws {
        settle(3)
        // Clear any coach marks blocking taps.
        for _ in 0..<3 { if !tapFirst(["Got it"], timeout: 1) { break }; settle(0.5) }
        shot("dash-before-session")

        // Start the fastest session path.
        app.swipeUp()
        settle(1)
        if !tapFirst(["Surprise Me"], timeout: 3) {
            app.swipeUp(); settle(1)
            guard tapFirst(["Surprise Me", "START TRAINING", "Start Training"], timeout: 3) else {
                shot("no-session-entry"); return
            }
        }
        settle(3)
        for _ in 0..<2 { if !tapFirst(["Got it"], timeout: 1) { break }; settle(0.5) }
        shot("active-training")

        // Complete the exercise, rate it, advance to the summary.
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for step in 1...8 {
            _ = tapFirst(["I've completed this drill", "COMPLETE EXERCISE", "Complete Exercise", "MARK COMPLETE", "COMPLETE", "Complete"], timeout: 3)
            settle(1)
            if app.buttons["Rate 4 stars"].waitForExistence(timeout: 3) {
                app.buttons["Rate 4 stars"].tap()
                settle(0.8)
                shot("rated-\(step)")
            }
            _ = tapFirst(["Finish", "Next", "Done", "DONE", "NEXT EXERCISE", "Next Exercise", "FINISH SESSION", "Finish Session", "FINISH"], timeout: 3)
            settle(2)
            // Notification permission alert (springboard) may appear after the celebration.
            if sb.buttons["Allow"].waitForExistence(timeout: 2) {
                shot("notif-permission")
                sb.buttons["Allow"].tap()
                settle(1)
            }
            shot("post-step-\(step)")
            if app.staticTexts["Session Complete!"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'XP'")).count > 2 { break }
        }
        shot("session-complete")
        app.swipeUp()
        settle(1)
        shot("session-complete-scrolled")

        // Dismiss back to the dashboard and capture the changed state.
        _ = tapFirst(["Done", "DONE", "Continue", "CONTINUE", "Back to Home", "Close"], timeout: 4)
        settle(3)
        if sb.buttons["Allow"].waitForExistence(timeout: 2) { shot("notif-permission-2"); sb.buttons["Allow"].tap(); settle(1) }
        shot("dash-after-session")

        // Progress tab: focus numbers should now exist.
        _ = tapFirst(["You"], timeout: 3)
        settle(1.5)
        for _ in 0..<2 { if !tapFirst(["Got it"], timeout: 1) { break }; settle(0.5) }
        _ = tapFirst(["Progress & Analytics"], timeout: 3)
        settle(2.5)
        shot("progress")
        app.swipeUp()
        settle(1)
        shot("progress-scrolled")
    }

    func test_walkthrough() throws {
        settle(3)
        shot("auth")

        // Guest entry (scroll down first in case it sits below the fold)
        var guestTapped = tapFirst(["Try without an account", "Just exploring? Try it without an account"], timeout: 6)
        if !guestTapped {
            app.swipeUp()
            settle(1)
            shot("auth-scrolled")
            guestTapped = tapFirst(["Try without an account", "Just exploring? Try it without an account"], timeout: 4)
        }
        if !guestTapped {
            if app.textFields["Enter your email"].exists {
                shot("auth-no-guest-button")
                return
            }
            // Already signed in from a previous session — continue the tour.
        }
        settle(4)
        shot("after-guest-tap")

        // Guest provider may be disabled in the Firebase console — fall back to a
        // deterministic demo email account (signup, or login if it already exists).
        if app.textFields["Enter your email"].exists {
            let email = "demo.reviewer@techniq-demo.app"
            let password = "Demo1234!"
            if tapFirst(["Create an account", "CREATE AN ACCOUNT"], timeout: 3) {
                settle(1.5)
                shot("signup-form")
                typeInto(placeholder: "Choose username", text: "ballerAlex")
                typeInto(placeholder: "First name", text: "Alex")
                typeInto(placeholder: "Last name", text: "T")
                typeInto(placeholder: "your.email@example.com", text: email)
                typeInto(placeholder: "Create password", text: password)
                typeInto(placeholder: "Confirm password", text: password)
                shot("signup-filled")
                _ = tapFirst(["CREATE ACCOUNT", "Create account"], timeout: 3)
                settle(7)
                shot("after-signup")
                if app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'already exists'")).firstMatch.exists {
                    _ = tapFirst(["Back"], timeout: 2)
                    settle(1)
                    typeInto(placeholder: "Enter your email", text: email)
                    typeInto(placeholder: "Enter your password", text: password)
                    _ = tapFirst(["LOGIN", "Login", "Sign in"], timeout: 3)
                    settle(7)
                    shot("after-login")
                }
            }
        }

        // Onboarding tour: advance up to 12 steps, screenshotting each.
        let advanceLabels = ["Continue", "CONTINUE", "Next", "NEXT", "Get Started", "GET STARTED",
                             "LET'S SET UP YOUR PROFILE", "GENERATE MY PLAN", "Generate My Plan",
                             "Let's Go", "LET'S GO", "Begin", "BEGIN", "Create My Plan", "CREATE MY PLAN",
                             "Start Training", "START TRAINING", "Done", "DONE", "Finish", "FINISH"]
        for step in 1...12 {
            settle(1.5)
            shot("onboarding-\(step)")

            // Fill the name field if present and empty.
            let field = app.textFields.firstMatch
            if field.exists, field.isHittable, (field.value as? String)?.isEmpty != false || (field.value as? String) == field.placeholderValue {
                field.tap()
                field.typeText("Alex")
                app.keyboards.buttons["return"].exists ? app.keyboards.buttons["return"].tap() : ()
                settle(0.5)
            }

            // Neutral age wheel requires an explicit selection before Continue.
            let wheel = app.pickerWheels.firstMatch
            if wheel.exists {
                wheel.adjust(toPickerWheelValue: "13 years")
                settle(0.5)
            }

            if tapFirst(advanceLabels, timeout: 2) { continue }
            // Tall steps park the CTA below the fold — scroll and retry once.
            app.swipeUp()
            settle(0.8)
            if tapFirst(advanceLabels, timeout: 2) { continue }
            // Paywall / terminal step candidates
            if tapFirst(["Continue with Free", "Maybe Later", "Not Now", "Skip for now", "Continue Free", "Close", "Dismiss", "xmark", "Skip"], timeout: 2) {
                settle(2)
                shot("after-paywall-dismiss")
                continue
            }
            break
        }

        // Plan generation can take a while — wait for the tab bar.
        for _ in 0..<12 {
            if app.staticTexts["Home"].exists || app.buttons["Home"].exists { break }
            settle(5)
        }
        shot("dashboard")

        // Tab tour
        for tab in ["Train", "Plans", "Community", "You"] {
            if tapFirst([tab], timeout: 4) {
                settle(2.5)
                shot("tab-\(tab.lowercased())")
            }
        }
        _ = tapFirst(["Home"], timeout: 3)
        settle(1.5)
        shot("home-final")

        // Scroll the dashboard to capture below-the-fold content.
        app.swipeUp()
        settle(1)
        shot("home-scrolled")
        app.swipeUp()
        settle(1)
        shot("home-scrolled-2")
    }
}
