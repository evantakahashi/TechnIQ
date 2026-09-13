import XCTest
@testable import TechnIQ

/// The free-tier contract in one place: what opens for free, what needs Pro, and the label a row
/// shows before the tap.
final class ProGatesTests: XCTestCase {
    func test_plans_firstOneIsFree() {
        XCTAssertTrue(ProGates.canGeneratePlan(isPro: false, existingAIPlans: 0))
        XCTAssertFalse(ProGates.canGeneratePlan(isPro: false, existingAIPlans: 1))
        XCTAssertTrue(ProGates.canGeneratePlan(isPro: true, existingAIPlans: 5))
        XCTAssertEqual(ProGates.planGateLabel(isPro: false, existingAIPlans: 0), "First one free")
        XCTAssertEqual(ProGates.planGateLabel(isPro: false, existingAIPlans: 2), "Pro")
        XCTAssertNil(ProGates.planGateLabel(isPro: true, existingAIPlans: 2))
    }

    func test_drills_threeForLifeThenPro() {
        XCTAssertTrue(ProGates.canGenerateDrill(isPro: false, freeDrillsRemaining: 1))
        XCTAssertFalse(ProGates.canGenerateDrill(isPro: false, freeDrillsRemaining: 0))
        XCTAssertTrue(ProGates.canGenerateDrill(isPro: true, freeDrillsRemaining: 0))
        XCTAssertEqual(ProGates.drillGateLabel(isPro: false, freeDrillsRemaining: 3), "3 free left")
        XCTAssertEqual(ProGates.drillGateLabel(isPro: false, freeDrillsRemaining: 1), "1 free left")
        XCTAssertEqual(ProGates.drillGateLabel(isPro: false, freeDrillsRemaining: 0), "Pro")
        XCTAssertNil(ProGates.drillGateLabel(isPro: true, freeDrillsRemaining: 0))
    }

    func test_everyPaywallContextMapsToAGate() {
        let contexts: [PaywallFeature] = [.trainingPlan, .customDrill, .dailyCoaching, .weeklyAdaptation, .youtubeRecs]
        XCTAssertEqual(Set(contexts.map(\.gate)).count, 4, "five contexts, four gates (video picks ride on the drill budget)")
        for context in contexts {
            XCTAssertFalse(context.title.isEmpty)
            XCTAssertFalse(context.gate.detail.isEmpty)
        }
    }
}
