import XCTest
@testable import TechnIQ

// MARK: - Feature Highlight Data Tests

final class FeatureHighlightTests: XCTestCase {

    func test_onboardingHighlights_hasThreeItems() {
        XCTAssertEqual(FeatureHighlight.onboardingHighlights.count, 3)
    }

    func test_onboardingHighlights_firstIsAITraining() {
        let highlight = FeatureHighlight.onboardingHighlights[0]
        XCTAssertEqual(highlight.headline, "Smart Drills, Built for You")
        XCTAssertFalse(highlight.body.isEmpty)
    }

    func test_onboardingHighlights_secondIsProgressXP() {
        let highlight = FeatureHighlight.onboardingHighlights[1]
        XCTAssertEqual(highlight.headline, "Level Up Your Game")
    }

    func test_onboardingHighlights_thirdIsAvatar() {
        let highlight = FeatureHighlight.onboardingHighlights[2]
        XCTAssertEqual(highlight.headline, "Make It Yours")
    }

    func test_onboardingHighlights_allHaveUniqueIDs() {
        let highlights = FeatureHighlight.onboardingHighlights
        let ids = Set(highlights.map { $0.id })
        XCTAssertEqual(ids.count, highlights.count)
    }

    func test_featureIconContent_sfSymbol() {
        let highlight = FeatureHighlight.onboardingHighlights[0]
        if case .sfSymbol(let name, _) = highlight.iconContent {
            XCTAssertEqual(name, "brain.head.profile")
        } else {
            XCTFail("Expected sfSymbol icon content for AI Training highlight")
        }
    }

    func test_featureIconContent_multiIcon() {
        let highlight = FeatureHighlight.onboardingHighlights[1]
        if case .multiIcon(let icons) = highlight.iconContent {
            XCTAssertEqual(icons.count, 3)
            XCTAssertEqual(icons[0].name, "star.fill")
            XCTAssertEqual(icons[1].name, "flame.fill")
            XCTAssertEqual(icons[2].name, "trophy.fill")
        } else {
            XCTFail("Expected multiIcon content for Progress highlight")
        }
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
