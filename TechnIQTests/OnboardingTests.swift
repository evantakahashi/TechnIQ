import XCTest
@testable import TechnIQ

// MARK: - Onboarding Step Tests (Touchline 7b)

final class OnboardingStepTests: XCTestCase {
    typealias Step = UnifiedOnboardingView.Step

    func test_fiveDecisionStepsInOrder() {
        let decisions = Step.allCases.filter(\.isDecision)
        XCTAssertEqual(decisions, [.goal, .frequency, .position, .weakSpots, .about])
    }

    func test_generationAndPaywallFollowTheDecisions() {
        XCTAssertFalse(Step.generating.isDecision)
        XCTAssertFalse(Step.paywall.isDecision)
        XCTAssertEqual(Step.about.rawValue + 1, Step.generating.rawValue)
        XCTAssertEqual(Step.generating.rawValue + 1, Step.paywall.rawValue)
    }

    func test_shortNamesAreLowercaseAndUnique() {
        let names = Step.allCases.map(\.shortName)
        XCTAssertEqual(Set(names).count, names.count)
        for name in names {
            XCTAssertEqual(name, name.lowercased())
            XCTAssertFalse(name.isEmpty)
        }
    }

    func test_noWelcomeOrPlayingStyleSteps() {
        let names = Step.allCases.map(\.shortName)
        XCTAssertFalse(names.contains { $0.contains("welcome") || $0.contains("style") })
    }
}

// MARK: - Coach Mark Manager Tests

final class CoachMarkManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachMarkManager.shared.resetAll()
    }

    override func tearDown() {
        CoachMarkManager.shared.resetAll()
        super.tearDown()
    }

    func test_hasSeen_returnsFalseByDefault() {
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("dashboard"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("train"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("plans"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("progress"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("avatar"))
    }

    func test_markSeen_setsFlag() {
        CoachMarkManager.shared.markSeen("dashboard")
        XCTAssertTrue(CoachMarkManager.shared.hasSeen("dashboard"))
    }

    func test_markSeen_doesNotAffectOtherIDs() {
        CoachMarkManager.shared.markSeen("dashboard")
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("train"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("plans"))
    }

    func test_markSeen_isIdempotent() {
        CoachMarkManager.shared.markSeen("train")
        CoachMarkManager.shared.markSeen("train")
        XCTAssertTrue(CoachMarkManager.shared.hasSeen("train"))
    }

    func test_resetAll_clearsAllFlags() {
        CoachMarkManager.shared.markSeen("dashboard")
        CoachMarkManager.shared.markSeen("train")
        CoachMarkManager.shared.markSeen("plans")
        CoachMarkManager.shared.markSeen("progress")
        CoachMarkManager.shared.markSeen("avatar")

        CoachMarkManager.shared.resetAll()

        XCTAssertFalse(CoachMarkManager.shared.hasSeen("dashboard"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("train"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("plans"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("progress"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("avatar"))
    }

    func test_markSeen_multipleIDs() {
        CoachMarkManager.shared.markSeen("dashboard")
        CoachMarkManager.shared.markSeen("progress")

        XCTAssertTrue(CoachMarkManager.shared.hasSeen("dashboard"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("train"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("plans"))
        XCTAssertTrue(CoachMarkManager.shared.hasSeen("progress"))
        XCTAssertFalse(CoachMarkManager.shared.hasSeen("avatar"))
    }
}

// MARK: - Coach Mark Info Tests

final class CoachMarkInfoTests: XCTestCase {

    func test_predefinedCoachMarks_haveCorrectIDs() {
        XCTAssertEqual(CoachMarkInfo.dashboard.id, "dashboard")
        XCTAssertEqual(CoachMarkInfo.train.id, "train")
        XCTAssertEqual(CoachMarkInfo.plans.id, "plans")
        XCTAssertEqual(CoachMarkInfo.progress.id, "progress")
        XCTAssertEqual(CoachMarkInfo.avatar.id, "avatar")
    }

    func test_predefinedCoachMarks_haveNonEmptyText() {
        XCTAssertFalse(CoachMarkInfo.dashboard.text.isEmpty)
        XCTAssertFalse(CoachMarkInfo.train.text.isEmpty)
        XCTAssertFalse(CoachMarkInfo.plans.text.isEmpty)
        XCTAssertFalse(CoachMarkInfo.progress.text.isEmpty)
        XCTAssertFalse(CoachMarkInfo.avatar.text.isEmpty)
    }
}
