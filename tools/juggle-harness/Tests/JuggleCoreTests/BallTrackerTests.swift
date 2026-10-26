import XCTest
@testable import JuggleCore

final class BallTrackerTests: XCTestCase {
    private let dt = 1.0 / 30

    private func ball(_ x: Double, _ y: Double, confidence: Double = 0.6) -> BallSighting {
        BallSighting(center: DrillPoint(x: x, y: y), radius: 0.02, confidence: confidence)
    }

    /// A juggled ball: bounces between y 0.1 and 0.5 about twice a second.
    private func juggledY(_ t: Double) -> Double { 0.1 + 0.4 * abs(sin(.pi * 2 * t)) }

    func testAMovingBallIsTracked() {
        let tracker = BallTracker()
        for i in 0..<60 {
            let t = Double(i) * dt
            XCTAssertEqual(tracker.pick([ball(0.3, juggledY(t))], at: t)?.center.y ?? -1, juggledY(t), accuracy: 1e-9)
        }
    }

    func testSomethingRoundThatNeverMovesIsScenery() {
        // A plant pot the detector calls a sports ball, sitting next to the player.
        let tracker = BallTracker()
        var picks: [BallSighting?] = []
        for i in 0..<60 { picks.append(tracker.pick([ball(0.76, 0.41)], at: Double(i) * dt)) }

        XCTAssertNotNil(picks[10])          // can't tell yet
        XCTAssertNil(picks.last ?? nil)     // after a second it's scenery
    }

    func testSceneryTheDetectorOnlySometimesSeesIsStillScenery() {
        // The detector finds the pot in every other frame and the juggled ball in the rest.
        let tracker = BallTracker()
        var potPicks: [BallSighting?] = []
        for i in 0..<90 {
            let t = Double(i) * dt
            if i.isMultiple(of: 2) {
                potPicks.append(tracker.pick([ball(0.76, 0.41)], at: t))
            } else {
                _ = tracker.pick([ball(0.3, juggledY(t))], at: t)
            }
        }

        XCTAssertNil(potPicks.last ?? nil)
    }

    func testSceneryStaysSceneryAfterTheDetectorLosesItForAWhile() {
        let tracker = BallTracker()
        for i in 0..<45 { _ = tracker.pick([ball(0.76, 0.41)], at: Double(i) * dt) }
        for i in 45..<120 { _ = tracker.pick([ball(0.3, juggledY(Double(i) * dt))], at: Double(i) * dt) }

        XCTAssertNil(tracker.pick([ball(0.76, 0.41)], at: 120 * dt))
    }

    func testTheRealBallWinsOverSceneryEvenAfterTrackingTheScenery() {
        let tracker = BallTracker()
        for i in 0..<45 { _ = tracker.pick([ball(0.76, 0.41, confidence: 0.8)], at: Double(i) * dt) }

        let t = 45 * dt
        let pick = tracker.pick([ball(0.76, 0.41, confidence: 0.8), ball(0.4, 0.7, confidence: 0.4)], at: t)

        XCTAssertEqual(pick?.center.x, 0.4)
    }

    func testABallHeldStillForUnderASecondStillCounts() {
        let tracker = BallTracker()
        for i in 0..<20 { _ = tracker.pick([ball(0.3, 0.5)], at: Double(i) * dt) }

        XCTAssertNotNil(tracker.pick([ball(0.3, 0.5)], at: 20 * dt))
        XCTAssertNotNil(tracker.pick([ball(0.3, 0.45)], at: 21 * dt))
    }

    func testABallThatStartsMovingAgainIsTrackedAgain() {
        // Held in the hands for two seconds, then dropped into a juggle.
        let tracker = BallTracker()
        for i in 0..<60 { _ = tracker.pick([ball(0.3, 0.5)], at: Double(i) * dt) }

        XCTAssertNotNil(tracker.pick([ball(0.3, 0.42)], at: 61 * dt))
    }

    func testPrefersTheCandidateNearestLastFramesBall() {
        let tracker = BallTracker()
        _ = tracker.pick([ball(0.3, 0.5)], at: 0)

        let pick = tracker.pick([ball(0.9, 0.5, confidence: 0.9), ball(0.32, 0.47, confidence: 0.3)], at: dt)

        XCTAssertEqual(pick?.center.x, 0.32)
    }
}
