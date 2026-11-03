import XCTest
@testable import TechnIQ

@MainActor
final class XPServiceTests: XCTestCase {
    var sut: XPService!
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        sut = XPService()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - XP formula

    func test_formula_underAMinute_earnsNothing() {
        XCTAssertEqual(XPFormula.session(verifiedTouches: 500, activeSeconds: 59), .zero)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 0).total, 0)
    }

    func test_formula_onePerFullMinute_cappedAt20() {
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 60).timeXP, 1)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 179).timeXP, 2)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 20 * 60).timeXP, 20)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 90 * 60).timeXP, 20)
    }

    func test_formula_onePerTenVerifiedTouches_cappedAt10() {
        XCTAssertEqual(XPFormula.session(verifiedTouches: 9, activeSeconds: 60).touchXP, 0)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 35, activeSeconds: 60).touchXP, 3)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 5_000, activeSeconds: 60).touchXP, 10)
        XCTAssertEqual(XPFormula.session(verifiedTouches: -40, activeSeconds: 60).touchXP, 0)
    }

    func test_formula_neverPasses30() {
        for seconds in stride(from: 0.0, through: 7_200, by: 37) {
            for touches in stride(from: 0, through: 3_000, by: 41) {
                let xp = XPFormula.session(verifiedTouches: touches, activeSeconds: seconds)
                XCTAssertLessThanOrEqual(xp.total, Int32(XPFormula.maxPerSession))
                XCTAssertGreaterThanOrEqual(xp.total, 0)
            }
        }
        XCTAssertEqual(XPFormula.session(verifiedTouches: 1_000, activeSeconds: 3_600).total, 30)
    }

    func test_formula_badDurations_earnNothing() {
        XCTAssertEqual(XPFormula.session(verifiedTouches: 100, activeSeconds: .nan), .zero)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 100, activeSeconds: .infinity), .zero)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 100, activeSeconds: -300), .zero)
    }

    // MARK: - Level curve

    func test_xpRequiredForLevel_level1_returnsZero() {
        XCTAssertEqual(sut.xpRequiredForLevel(1), 0)
        XCTAssertEqual(sut.xpRequiredForLevel(0), 0)
    }

    func test_levelCurve_knownPoints() {
        XCTAssertEqual(sut.xpRequiredForLevel(2), 50)
        XCTAssertEqual(sut.xpRequiredForLevel(3), 108)
        XCTAssertEqual(sut.xpRequiredForLevel(10), 738)
        XCTAssertEqual(sut.xpRequiredForLevel(50), 11_858)
        XCTAssertEqual(sut.xpRequiredForLevel(60), 11_858, "capped at level 50")
    }

    func test_levelCurve_costPerLevelGrows() {
        var previousCost: Int64 = 0
        for level in 1..<50 {
            let cost = sut.xpRequiredForLevel(level + 1) - sut.xpRequiredForLevel(level)
            XCTAssertGreaterThan(cost, previousCost, "level \(level) → \(level + 1)")
            previousCost = cost
        }
    }

    /// The pacing the curve is tuned for, at 20–30 XP a session.
    func test_levelCurve_pacing() {
        let sessionsToLevel2 = (20...30).map { Double(sut.xpRequiredForLevel(2)) / Double($0) }
        XCTAssertTrue(sessionsToLevel2.allSatisfy { (1.6...2.6).contains($0) }, "level 2 in 2–3 sessions")

        // Level 10 at 3–4 sessions a week of ~22 XP: about two months.
        let weeksToLevel10 = Double(sut.xpRequiredForLevel(10)) / (3.5 * 22)
        XCTAssertTrue((7...11).contains(weeksToLevel10), "level 10 in ~2 months, got \(weeksToLevel10) weeks")

        // Level 50: multi-year even at 4 sessions a week of 25 XP.
        let yearsToLevel50 = Double(sut.xpRequiredForLevel(50)) / (4 * 25 * 52)
        XCTAssertGreaterThan(yearsToLevel50, 2)
        XCTAssertEqual(XPService.levelTiers.count, 10)
    }

    func test_levelForXP_zeroXP_returnsLevel1() {
        XCTAssertEqual(sut.levelForXP(0), 1)
    }

    func test_levelForXP_exactThreshold_advancesLevel() {
        let xpForLevel5 = sut.xpRequiredForLevel(5)
        XCTAssertEqual(sut.levelForXP(xpForLevel5), 5)
    }

    func test_levelForXP_justBelow_staysAtPreviousLevel() {
        let xpForLevel5 = sut.xpRequiredForLevel(5)
        XCTAssertEqual(sut.levelForXP(xpForLevel5 - 1), 4)
    }

    func test_levelForXP_maxLevel_cappedAt50() {
        XCTAssertEqual(sut.levelForXP(999_999_999_999), 50)
    }

    func test_progressToNextLevel_midway_returnsHalf() {
        let xpLevel2 = sut.xpRequiredForLevel(2)
        let xpLevel3 = sut.xpRequiredForLevel(3)
        let midpoint = xpLevel2 + (xpLevel3 - xpLevel2) / 2
        let progress = sut.progressToNextLevel(totalXP: midpoint, currentLevel: 2)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    func test_progressToNextLevel_atMaxLevel_returns1() {
        XCTAssertEqual(sut.progressToNextLevel(totalXP: 999_999, currentLevel: 50), 1.0)
    }

    // MARK: - Tier System

    func test_tierForLevel_returnsCorrectTier() {
        XCTAssertEqual(sut.tierForLevel(1)?.title, "Grassroots")
        XCTAssertEqual(sut.tierForLevel(10)?.title, "Rising Star")
        XCTAssertEqual(sut.tierForLevel(50)?.title, "Living Legend")
    }

    // MARK: - Award XP & Level Up

    func test_awardXP_noLevelUp_returnsNil() {
        let player = stack.makePlayer(level: 1, xp: 0)
        let levelUp = sut.awardXP(to: player, amount: 10)
        XCTAssertNil(levelUp)
        XCTAssertEqual(player.totalXP, 10)
    }

    func test_awardXP_triggersLevelUp_returnsNewLevel() {
        let player = stack.makePlayer(level: 1, xp: 40)
        let levelUp = sut.awardXP(to: player, amount: 20)
        XCTAssertEqual(levelUp, 2)
        XCTAssertEqual(player.currentLevel, 2)
    }

    // MARK: - Session completion

    func test_processSessionCompletion_paysTheFormulaFromActiveSecondsAndTouches() {
        let player = stack.makePlayer(xp: 0)
        let session = stack.makeSession(player: player, duration: 25, activeSeconds: 25 * 60)
        session.verifiedTouches = 47

        let result = sut.processSessionCompletion(session: session, player: player, context: stack.context)

        XCTAssertEqual(result.xp, SessionXPBreakdown(timeXP: 20, touchXP: 4))
        XCTAssertEqual(session.xpEarned, 24)
        XCTAssertEqual(player.totalXP, 24)
    }

    func test_processSessionCompletion_ignoresRatingNotesAndStreakMilestones() {
        let player = stack.makePlayer(xp: 0, streak: 6)
        player.lastTrainingDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let session = stack.makeSession(player: player, duration: 10, rating: 5, notes: "great", activeSeconds: 600)

        let result = sut.processSessionCompletion(session: session, player: player, context: stack.context)

        XCTAssertEqual(player.currentStreak, 7, "7-day milestone reached")
        XCTAssertEqual(result.xp.total, 10, "no rating, notes or streak bonus")
        XCTAssertEqual(player.totalXP, 10)
    }

    func test_processSessionCompletion_shortSession_earnsXPButNotStreak() {
        let player = stack.makePlayer(xp: 0, streak: 3)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        player.lastTrainingDate = yesterday
        let session = stack.makeSession(player: player, duration: 4, activeSeconds: 299)

        let result = sut.processSessionCompletion(session: session, player: player, context: stack.context)

        XCTAssertEqual(result.xp.total, 4)
        XCTAssertEqual(player.currentStreak, 3)
        XCTAssertEqual(player.lastTrainingDate, yesterday)
    }

    func test_processSessionCompletion_fiveMinutes_extendsStreak() {
        let player = stack.makePlayer(streak: 3)
        player.lastTrainingDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let session = stack.makeSession(player: player, duration: 5, activeSeconds: 300)

        _ = sut.processSessionCompletion(session: session, player: player, context: stack.context)

        XCTAssertEqual(player.currentStreak, 4)
    }

    func test_processSessionCompletion_underAMinute_paysNothing_andKeepsLevel() {
        let player = stack.makePlayer(level: 1, xp: 45)
        let session = stack.makeSession(player: player, duration: 1, activeSeconds: 40)

        let result = sut.processSessionCompletion(session: session, player: player, context: stack.context)

        XCTAssertEqual(result.xp, .zero)
        XCTAssertNil(result.levelUp)
        XCTAssertEqual(player.totalXP, 45)
    }

    // MARK: - Streak rule

    func test_streakRule_fiveActiveMinutes() {
        XCTAssertFalse(StreakRule.counts(activeSeconds: 299, durationMinutes: 30))
        XCTAssertTrue(StreakRule.counts(activeSeconds: 300, durationMinutes: 0))
    }

    func test_streakRule_legacyRowsFallBackToDuration() {
        XCTAssertTrue(StreakRule.counts(activeSeconds: 0, durationMinutes: 5))
        XCTAssertFalse(StreakRule.counts(activeSeconds: 0, durationMinutes: 4))
        let player = stack.makePlayer()
        XCTAssertTrue(stack.makeSession(player: player, duration: 30).countsTowardStreak)
        XCTAssertFalse(stack.makeSession(player: player, duration: 2).countsTowardStreak)
    }

    func test_calculateStreakFromHistory_skipsShortSessions() {
        let player = stack.makePlayer()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        stack.makeSession(player: player, date: today, duration: 20, activeSeconds: 1_200)
        stack.makeSession(player: player, date: yesterday, duration: 3, activeSeconds: 180)   // too short
        stack.makeSession(player: player, date: twoDaysAgo, duration: 20, activeSeconds: 1_200)

        XCTAssertEqual(sut.calculateStreakFromHistory(for: player, in: stack.context), 1)
    }

    // MARK: - Streak

    func test_updateStreak_firstEver_setsTo1() {
        let player = stack.makePlayer()
        player.lastTrainingDate = nil
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 1)
    }

    func test_updateStreak_consecutiveDay_increments() {
        let player = stack.makePlayer(streak: 5)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        player.lastTrainingDate = yesterday
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 6)
    }

    func test_updateStreak_sameDay_noChange() {
        let player = stack.makePlayer(streak: 5)
        player.lastTrainingDate = Date()
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 5)
    }

    func test_updateStreak_missedDay_resetsTo1() {
        let player = stack.makePlayer(streak: 10)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        player.lastTrainingDate = threeDaysAgo
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 1)
    }

    func test_updateStreak_missedOneDayWithFreeze_continues() {
        let player = stack.makePlayer(streak: 10, streakFreezes: 1)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        player.lastTrainingDate = twoDaysAgo
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 11)
        XCTAssertEqual(player.streakFreezes, 0)
    }

    func test_updateStreak_updatesLongestStreak() {
        let player = stack.makePlayer(streak: 9, longestStreak: 9)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        player.lastTrainingDate = yesterday
        sut.updateStreak(for: player)
        XCTAssertEqual(player.longestStreak, 10)
    }
}
