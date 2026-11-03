import XCTest

/// Smoke test for the Touchline Home screen: every tappable element on Home leads somewhere and
/// comes back. Runs against the seeded demo player (`-TQSeedDemo`) so the populated state exists.
/// Screenshots are attached at each step and mirrored to the runner's tmp dir.
final class TouchlineHomeUITests: XCTestCase {
    var app: XCUIApplication!
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launch(_ arguments: [String]) {
        app.launchArguments = ["-TQSeedDemo", "-TQLocalUser"] + arguments
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
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(String(format: "%02d-%@.png", shotIndex, name)))
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

    private func row(_ title: String) -> XCUIElement {
        app.buttons["row.\(title)"]
    }

    /// Any element by accessibility identifier (rows without an action aren't buttons).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func goBack() {
        let back = app.buttons["Back"]
        if back.exists, back.isHittable {
            back.tap()
        } else if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        }
        settle(0.8)
    }

    /// A multi-drill session shows a preview sheet first; start from it when it appears.
    private func passPreviewIfShown() {
        let start = app.buttons["preview.start"]
        if start.waitForExistence(timeout: 3) { start.tap() }
    }

    private func dismissSheet() {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 2), cancel.isHittable {
            cancel.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        // Wait for the sheet to finish animating away before touching Home again.
        let gone = NSPredicate(format: "exists == false")
        _ = XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: cancel)], timeout: 5)
        settle(0.8)
    }

    /// Taps once the element is on screen and hittable (sheet/animation settled).
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

    // MARK: - Populated Home (4a)

    func test_populatedHome_everyRowAndButtonWorks() throws {
        launch([])
        let start = app.buttons["Start session"]
        XCTAssertTrue(start.waitForExistence(timeout: 40), "Home hero with Start session should appear")
        dismissCoachMarkIfPresent()
        shot("home-populated")

        XCTAssertTrue(text(containing: "Today's session").exists, "hero eyebrow")
        XCTAssertTrue(text(containing: "This week").exists, "week section header")
        XCTAssertTrue(app.buttons["Community"].exists == false, "four tabs without -TQCommunity")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "day streak")).firstMatch.exists
                      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "XP")).firstMatch.exists, "footer line")

        // Plan row → plan detail → back
        let planRow = row("Striker Development")
        XCTAssertTrue(planRow.waitForExistence(timeout: 5), "plan row")
        XCTAssertTrue(tapWhenHittable(planRow), "plan row hittable")
        XCTAssertTrue(text(containing: "Striker Development").waitForExistence(timeout: 8), "plan detail opened")
        shot("plan-detail")
        app.swipeUp()
        settle(0.8)
        XCTAssertTrue(text(containing: "RETEST").waitForExistence(timeout: 5), "the plan ends with a retest week")
        shot("plan-detail-retest")
        goBack()
        XCTAssertTrue(start.waitForExistence(timeout: 8), "back on Home after plan detail")

        // Last match row → match history → back
        let matchRow = row("Last match")
        XCTAssertTrue(matchRow.waitForExistence(timeout: 5), "last match row")
        XCTAssertTrue(tapWhenHittable(matchRow), "match row hittable")
        XCTAssertTrue(
            text(containing: "Match History").waitForExistence(timeout: 8) || text(containing: "Northside").waitForExistence(timeout: 2),
            "match history opened"
        )
        shot("match-history")
        goBack()
        XCTAssertTrue(start.waitForExistence(timeout: 8), "back on Home after match history")

        // Coach drills row → pushed screen → back
        let coachRow = row("Drills from Coach")
        XCTAssertTrue(coachRow.waitForExistence(timeout: 5), "coach row")
        XCTAssertTrue(tapWhenHittable(coachRow), "coach row hittable")
        XCTAssertTrue(text(containing: "Pick what to fix").waitForExistence(timeout: 8), "coach drills opened")
        shot("coach-drills")
        goBack()
        XCTAssertTrue(start.waitForExistence(timeout: 8), "back on Home after coach drills")

        // Next session row → plan detail → back
        let nextRow = app.buttons["home.nextSession"]
        XCTAssertTrue(nextRow.waitForExistence(timeout: 5), "next session row")
        XCTAssertTrue(tapWhenHittable(nextRow), "next session row hittable")
        XCTAssertTrue(text(containing: "Striker Development").waitForExistence(timeout: 8), "plan opened from next session")
        goBack()
        XCTAssertTrue(start.waitForExistence(timeout: 8), "back on Home after next session")

        // Benchmarks: last vs best per test (seeded assessment + retest)
        app.swipeUp()
        settle(0.8)
        XCTAssertTrue(text(containing: "Benchmarks").waitForExistence(timeout: 5), "benchmarks section")
        XCTAssertTrue(element("home.benchmark.juggling").exists, "one row per benchmark")
        XCTAssertTrue(element("home.benchmark.toeTaps30").exists, "one row per benchmark")
        shot("home-benchmarks")
        app.swipeDown()
        settle(0.8)

        // Tab bar round trip
        let trainTab = app.buttons["Train"]
        XCTAssertTrue(trainTab.waitForExistence(timeout: 5), "Train tab")
        trainTab.tap()
        settle(1.5)
        shot("train-tab")
        app.buttons["Home"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 8), "back on Home via tab bar")

        // Start session → active training → end early → Home
        XCTAssertTrue(tapWhenHittable(start), "start button hittable")
        passPreviewIfShown()
        let endSession = app.buttons["End session"]
        XCTAssertTrue(endSession.waitForExistence(timeout: 10), "active training opened")
        shot("active-training")
        endSession.tap()
        let confirm = app.alerts.buttons["End Session"]
        if confirm.waitForExistence(timeout: 4) { confirm.tap() }
        // Ending before any drill is completed keeps nothing: a "Nothing saved" card with Done.
        let nothingSaved = text(containing: "Nothing saved")
        XCTAssertTrue(nothingSaved.waitForExistence(timeout: 15), "nothing-saved state shown after ending early with no drill done")
        XCTAssertFalse(text(containing: "Session Complete").exists, "no XP screen for an empty session")
        shot("session-nothing-saved")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Done on the nothing-saved card")
        done.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 15), "back on Home after the session")
        XCTAssertFalse(nothingSaved.waitForExistence(timeout: 2), "nothing-saved card dismissed")
        shot("home-after-session")
    }

    // MARK: - Active session → Session complete (5c, 6a)

    func test_activeSession_repsPauseFinishAndFeel() throws {
        launch([])
        let start = app.buttons["Start session"]
        XCTAssertTrue(start.waitForExistence(timeout: 40), "Home hero")
        dismissCoachMarkIfPresent()
        XCTAssertTrue(tapWhenHittable(start), "start hittable")
        passPreviewIfShown()

        let plusReps = app.buttons["+ 10 reps"]
        XCTAssertTrue(plusReps.waitForExistence(timeout: 15), "active session opened with the reps button")
        XCTAssertTrue(text(containing: "Drill 1 of").exists, "drill counter")
        XCTAssertTrue(text(containing: "reps").exists, "reps label")
        XCTAssertFalse(text(containing: "effort").exists, "no effort zone until a heart-rate source exists")
        shot("session-running")

        plusReps.tap()
        plusReps.tap()
        XCTAssertTrue(app.staticTexts["20"].waitForExistence(timeout: 3), "reps counted to 20")

        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.exists, "pause button")
        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 3), "clock paused")
        app.buttons["Resume"].tap()
        shot("session-reps")

        let finish = app.buttons["Finish session"].exists ? app.buttons["Finish session"] : app.buttons["Next drill"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3), "next/finish control")
        finish.tap()
        // Any further drills: keep finishing
        var guardCount = 0
        while app.buttons["Next drill"].waitForExistence(timeout: 2), guardCount < 5 {
            app.buttons["Next drill"].tap(); guardCount += 1
        }
        if app.buttons["Finish session"].waitForExistence(timeout: 2) { app.buttons["Finish session"].tap() }

        XCTAssertTrue(text(containing: "Full time").waitForExistence(timeout: 15), "session complete header")
        XCTAssertTrue(text(containing: "Session").exists, "headline")
        XCTAssertTrue(text(containing: "How did it feel").exists, "feel question")
        XCTAssertFalse(text(containing: "coins").exists, "no coins")
        XCTAssertFalse(app.buttons["Close"].exists, "no close button that skips the feel question")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Done button")
        for option in ["Too easy", "Right", "Too hard"] {
            XCTAssertTrue(app.buttons[option].exists, "feel option \(option)")
            XCTAssertFalse(app.buttons[option].isSelected, "no default feel")
        }
        XCTAssertFalse(done.isEnabled, "Done waits for a feel")
        shot("session-complete")

        let tooHard = app.buttons["Too hard"]
        tooHard.tap()
        XCTAssertTrue(tooHard.isSelected, "picked feel is selected")
        XCTAssertTrue(done.isEnabled, "Done enabled once a feel is picked")
        shot("session-complete-feel")
        done.tap()
        // The day is done now: Home offers the next session, or a rest-day hero with "Train anyway".
        let backHome = start.waitForExistence(timeout: 15) || app.buttons["Train anyway"].waitForExistence(timeout: 5)
        XCTAssertTrue(backHome, "back on Home")
        shot("home-after-full-session")
    }

    // MARK: - Interrupted session → Home "Session in progress" → continue (6a)

    func test_interruptedSession_resumesFromHomeAfterRelaunch() throws {
        launch([])
        let start = app.buttons["Start session"]
        XCTAssertTrue(start.waitForExistence(timeout: 40), "Home hero")
        dismissCoachMarkIfPresent()
        XCTAssertTrue(tapWhenHittable(start), "start hittable")
        passPreviewIfShown()

        let plusReps = app.buttons["+ 10 reps"]
        XCTAssertTrue(plusReps.waitForExistence(timeout: 15), "active session opened")
        plusReps.tap()
        XCTAssertTrue(app.staticTexts["10"].waitForExistence(timeout: 3), "reps counted")
        let pause = app.buttons["Pause"]
        if pause.waitForExistence(timeout: 3) { pause.tap() }
        settle(1)

        // A phone call: the app dies mid-session.
        app.terminate()
        launch([])
        let resume = app.buttons["home.resumeSession"]
        XCTAssertTrue(resume.waitForExistence(timeout: 40), "Home offers the interrupted session")
        XCTAssertTrue(text(containing: "Session in progress").exists, "resume strip eyebrow")
        dismissCoachMarkIfPresent()
        shot("home-resume-strip")

        XCTAssertTrue(tapWhenHittable(resume), "resume strip hittable")
        XCTAssertTrue(app.buttons["End session"].waitForExistence(timeout: 15), "back on the pitch")
        XCTAssertTrue(app.staticTexts["10"].waitForExistence(timeout: 5), "reps survived the relaunch")
        XCTAssertTrue(text(containing: "Drill 1 of").exists, "same drill")
        shot("session-resumed")

        // Ending it clears the snapshot: Home no longer offers it.
        app.buttons["End session"].tap()
        let confirm = app.alerts.buttons["End Session"]
        if confirm.waitForExistence(timeout: 4) { confirm.tap() }
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "nothing-saved card")
        done.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 15), "back on Home")
        XCTAssertFalse(resume.waitForExistence(timeout: 2), "resume strip gone after ending")
    }

    // MARK: - First-run Home (9b)

    func test_emptyHome_rowsOfferCreationRoutes() throws {
        launch(["-TQHomeState", "empty"])
        let quick = app.buttons["Start assessment"]
        XCTAssertTrue(quick.waitForExistence(timeout: 40), "first-run hero is the assessment")
        dismissCoachMarkIfPresent()
        shot("home-empty")

        XCTAssertTrue(text(containing: "Your first session").exists, "first-run eyebrow")
        XCTAssertTrue(text(containing: "10-minute assessment").exists, "first-run title")
        XCTAssertTrue(app.buttons["home.takeAssessment"].exists, "benchmarks row offers the assessment")
        XCTAssertTrue(text(containing: "after your first session").exists, "disabled coach row note")

        // Build a training plan → generator sheet → cancel
        let buildRow = row("Build a training plan")
        XCTAssertTrue(buildRow.waitForExistence(timeout: 5), "build plan row")
        XCTAssertTrue(tapWhenHittable(buildRow), "build plan row hittable")
        XCTAssertTrue(
            app.buttons["planGenerator.build"].waitForExistence(timeout: 8) || text(containing: "New plan · AI").waitForExistence(timeout: 2),
            "plan generator opened"
        )
        shot("plan-generator")
        dismissSheet()
        XCTAssertTrue(quick.waitForExistence(timeout: 8), "back on Home after plan generator")

        // Log a match → match log sheet → cancel
        let logRow = row("Log a match")
        XCTAssertTrue(logRow.waitForExistence(timeout: 5), "log match row")
        XCTAssertTrue(tapWhenHittable(logRow), "log match row hittable")
        XCTAssertTrue(
            app.navigationBars["Log Match"].waitForExistence(timeout: 8) || text(containing: "Log Match").waitForExistence(timeout: 2),
            "match log opened"
        )
        shot("match-log")
        dismissSheet()
        XCTAssertTrue(quick.waitForExistence(timeout: 8), "back on Home after match log")

        // Assessment opens full screen and closes from its intro.
        XCTAssertTrue(tapWhenHittable(quick), "assessment button hittable")
        XCTAssertTrue(text(containing: "Three numbers").waitForExistence(timeout: 8), "assessment intro")
        XCTAssertTrue(tapWhenHittable(app.buttons["assessment.close"]), "close")
        XCTAssertTrue(quick.waitForExistence(timeout: 8), "back on Home after the assessment intro")
    }

    // MARK: - First-session assessment

    func test_firstAssessment_walksEveryStep() throws {
        launch(["-TQHomeState", "empty"])
        let startAssessment = app.buttons["Start assessment"]
        XCTAssertTrue(startAssessment.waitForExistence(timeout: 40), "assessment hero")
        dismissCoachMarkIfPresent()
        XCTAssertTrue(tapWhenHittable(startAssessment))

        let primary = app.buttons["assessment.primary"]
        XCTAssertTrue(text(containing: "Three numbers").waitForExistence(timeout: 8), "intro")
        shot("assessment-intro")
        XCTAssertTrue(tapWhenHittable(primary), "start warm-up")
        XCTAssertTrue(text(containing: "Warm-up").waitForExistence(timeout: 5), "warm-up")
        settle(1.5)
        shot("assessment-warmup")
        XCTAssertTrue(tapWhenHittable(app.buttons["assessment.skipWarmup"]), "skip warm-up")

        // Juggling: two typed attempts.
        XCTAssertTrue(text(containing: "Keep it up").waitForExistence(timeout: 5), "juggling")
        shot("assessment-juggling")
        for count in ["12", "17"] {
            let field = app.textFields.firstMatch
            XCTAssertTrue(tapWhenHittable(field), "count field")
            field.typeText(count)
            XCTAssertTrue(tapWhenHittable(app.buttons["assessment.addAttempt"]), "add attempt")
            settle(0.5)
        }
        XCTAssertTrue(element("row.Attempt 2").waitForExistence(timeout: 5), "attempts listed")
        shot("assessment-juggling-attempts")
        XCTAssertTrue(tapWhenHittable(primary), "next: wall passes")

        // Wall passes and toe taps: start the clock, stop early, type the count.
        for (title, count) in [("Wall passes", "19"), ("Toe taps", "42")] {
            XCTAssertTrue(text(containing: title).waitForExistence(timeout: 5), title)
            XCTAssertTrue(tapWhenHittable(primary), "start clock")
            settle(1.5)
            shot("assessment-\(title == "Toe taps" ? "toetaps" : "wallpasses")-running")
            XCTAssertTrue(tapWhenHittable(app.buttons["assessment.stopClock"]), "stop early")
            let field = app.textFields.firstMatch
            XCTAssertTrue(tapWhenHittable(field), "count field")
            field.typeText(count)
            XCTAssertTrue(tapWhenHittable(primary), "save count")
        }

        XCTAssertTrue(text(containing: "Your numbers").waitForExistence(timeout: 8), "results")
        XCTAssertTrue(element("row.Toe taps").exists, "toe taps result")
        shot("assessment-results")
        XCTAssertTrue(tapWhenHittable(app.buttons["assessment.done"]), "done")
        XCTAssertTrue(text(containing: "This week").waitForExistence(timeout: 10), "back on Home")
    }

    // MARK: - Offline and loading slots (9c, 9d)

    func test_offlineAndLoadingStatesKeepLayout() throws {
        launch(["-TQHomeState", "offline"])
        XCTAssertTrue(app.buttons["Start session"].waitForExistence(timeout: 40), "offline hero still offers Start")
        dismissCoachMarkIfPresent()
        XCTAssertTrue(text(containing: "You're offline").exists, "offline banner")
        // The coach line is the drill's own cue (local), so it shows offline too: today's demo
        // drill is Passing Accuracy.
        XCTAssertTrue(text(containing: "Ankle locked").exists, "drill cue as the coach line, offline")
        XCTAssertTrue(text(containing: "needs connection").exists, "coach row disabled note")
        shot("home-offline")

        app.terminate()
        launch(["-TQHomeState", "loading"])
        XCTAssertTrue(text(containing: "Coach is picking your drill").waitForExistence(timeout: 40), "loading hero")
        dismissCoachMarkIfPresent()
        XCTAssertTrue(text(containing: "This week").exists, "local data renders while coach loads")
        XCTAssertTrue(row("Striker Development").exists, "plan row renders while coach loads")
        shot("home-loading")
    }
}
