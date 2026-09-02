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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
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
            shot("auth-no-guest-button")
            return
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

            if tapFirst(advanceLabels, timeout: 2) { continue }
            // Paywall / terminal step candidates
            if tapFirst(["Maybe Later", "Not Now", "Skip for now", "Continue Free", "Close", "Dismiss", "xmark", "Skip"], timeout: 2) {
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
