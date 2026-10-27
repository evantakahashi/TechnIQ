import XCTest
@testable import JuggleCore

final class BallGapFillerTests: XCTestCase {
    private let dt = 1.0 / 30

    private func ball(_ x: Double, _ y: Double, confidence: Double = 0.8) -> BallSighting {
        BallSighting(center: DrillPoint(x: x, y: y), radius: 0.02, confidence: confidence)
    }

    func testADetectionPassesThroughAndSeedsTheTracker() {
        let filler = BallGapFiller()
        var seeds: [BallSighting] = []
        let picked = filler.ball(detected: ball(0.3, 0.4), at: 0, seed: { seeds.append($0) }, track: { XCTFail("tracked"); return nil })

        XCTAssertEqual(picked, ball(0.3, 0.4))
        XCTAssertEqual(seeds, [ball(0.3, 0.4)])
    }

    func testAShortGapIsFilledByTheTracker() {
        let filler = BallGapFiller()
        _ = filler.ball(detected: ball(0.3, 0.4), at: 0, seed: { _ in }, track: { nil })
        let filled = filler.ball(detected: nil, at: dt, seed: { _ in XCTFail("seeded") }, track: { self.ball(0.3, 0.37, confidence: 0.9) })

        XCTAssertEqual(filled?.center, DrillPoint(x: 0.3, y: 0.37))
        XCTAssertEqual(filled?.radius, 0.02)
    }

    func testNothingIsTrackedBeforeTheFirstDetection() {
        let filler = BallGapFiller()
        XCTAssertNil(filler.ball(detected: nil, at: 0, seed: { _ in }, track: { XCTFail("tracked"); return self.ball(0.3, 0.4) }))
    }

    func testAGapLongerThanMaxGapIsLeftEmpty() {
        let filler = BallGapFiller()
        _ = filler.ball(detected: ball(0.3, 0.4), at: 0, seed: { _ in }, track: { nil })
        var tracked = 0
        var last: BallSighting?
        for i in 1...30 {
            last = filler.ball(detected: nil, at: Double(i) * dt, seed: { _ in }, track: { tracked += 1; return self.ball(0.3, 0.4) })
        }

        XCTAssertNil(last)
        XCTAssertLessThan(Double(tracked) * dt, filler.config.maxGap + dt)
    }

    func testAnUnsureTrackerEndsTheFillUntilTheNextDetection() {
        let filler = BallGapFiller()
        _ = filler.ball(detected: ball(0.3, 0.4), at: 0, seed: { _ in }, track: { nil })
        XCTAssertNil(filler.ball(detected: nil, at: dt, seed: { _ in }, track: { self.ball(0.3, 0.38, confidence: 0.2) }))
        XCTAssertNil(filler.ball(detected: nil, at: 2 * dt, seed: { _ in }, track: { XCTFail("tracked after losing it"); return nil }))

        XCTAssertNotNil(filler.ball(detected: ball(0.3, 0.2), at: 3 * dt, seed: { _ in }, track: { nil }))
    }

    func testATrackerThatJumpsAwayIsRejected() {
        // The tracker latched onto something else (a leg, the background).
        let filler = BallGapFiller()
        _ = filler.ball(detected: ball(0.3, 0.4), at: 0, seed: { _ in }, track: { nil })

        XCTAssertNil(filler.ball(detected: nil, at: dt, seed: { _ in }, track: { self.ball(0.6, 0.4, confidence: 0.9) }))
    }

    func testFilledFramesChainOffEachOther() {
        // A ball falling fast: each tracked step is small, the total move is large.
        let filler = BallGapFiller()
        _ = filler.ball(detected: ball(0.3, 0.5), at: 0, seed: { _ in }, track: { nil })
        var y = 0.5
        for i in 1...6 {
            y -= 0.04
            let step = y
            XCTAssertNotNil(filler.ball(detected: nil, at: Double(i) * dt, seed: { _ in }, track: { self.ball(0.3, step) }), "frame \(i)")
        }
    }
}
