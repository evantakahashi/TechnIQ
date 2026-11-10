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

// MARK: - Coach Mark Info Tests

