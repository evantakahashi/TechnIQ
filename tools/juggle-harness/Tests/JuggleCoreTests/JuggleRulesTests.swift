import XCTest
@testable import JuggleCore

/// The judge: rules end a run the moment they're clearly broken, and never on ambiguous evidence.
final class JuggleRulesTests: XCTestCase {
    private typealias S = SyntheticScene

    private func counter(parts: JuggleCounter.PartRule = .any, height: JuggleCounter.HeightLimit? = nil) -> JuggleCounter {
        var config = JuggleCounter.Config()
        config.partRule = parts
        config.heightLimit = height
        return JuggleCounter(config: config)
    }

    /// Two foot touches, then the ball comes down onto `contact`, then back onto the foot and the floor.
    private func footFootThen(_ contact: DrillPoint, height: Double = 0.20) -> [DrillFrame] {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: height * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: height * S.scale, to: contact)
        b.pop(from: contact, height: 0.15 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: height * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.6)
        return b.frames
    }

    // MARK: - Feet only

    func testAThighTouchEndsAFeetOnlyRun() {
        let events = S.run(footFootThen(S.thighContact), counter: counter(parts: .feetOnly))

        XCTAssertEqual(events.runEnds.first?.count, 2, "\(events.runEnds)")
        XCTAssertEqual(events.runEnds.first?.reason, .thighTouch)
    }

    func testAHeadTouchEndsAFeetOnlyRun() {
        let events = S.run(footFootThen(S.headContact, height: 0.60), counter: counter(parts: .feetOnly))

        XCTAssertEqual(events.runEnds.first?.reason, .headTouch, "\(events.runEnds)")
    }

    func testFeetOnlyIsFineWithFeet() {
        let events = S.run(footFootThen(S.footContact), counter: counter(parts: .feetOnly))

        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
        XCTAssertEqual(events.runEnds.map(\.count), [4])
    }

    func testATouchHalfwayBetweenFootAndThighIsNotCalled() {
        // Knee height: as close to the shin as to the thigh. Benefit of the doubt.
        let knee = S.at(0.355, 0.255)
        let events = S.run(footFootThen(knee), counter: counter(parts: .feetOnly))

        XCTAssertFalse(events.runEnds.map(\.reason).contains(.thighTouch), "\(events.runEnds)")
    }

    func testAThighTouchHiddenFromTheCameraIsNotCalled() {
        var frames = footFootThen(S.thighContact)
        // Blank the frames around the thigh contact: the judge only has an estimate.
        let i = frames.firstIndex { $0.ball?.center == S.thighContact } ?? 0
        for j in max(0, i - 4)...min(frames.count - 1, i + 2) { frames[j].ball = nil }

        let events = S.run(frames, counter: counter(parts: .feetOnly))

        XCTAssertFalse(events.runEnds.map(\.reason).contains(.thighTouch), "\(events.runEnds)")
    }

    // MARK: - Height limits

    func testABallAboveTheWaistEndsABelowTheWaistRun() {
        let events = S.run(footFootThen(S.footContact, height: 0.30), counter: counter(height: .waist))

        XCTAssertEqual(events.runEnds.first?.reason, .tooHigh, "\(events.runEnds)")
        XCTAssertEqual(events.runEnds.first?.count, 1)
    }

    func testStayingBelowTheWaistIsFine() {
        let events = S.run(footFootThen(S.footContact, height: 0.10), counter: counter(height: .waist))

        XCTAssertEqual(events.runEnds.map(\.reason), [.ground], "\(events.runEnds)")
    }

    func testABallAboveTheKneeEndsABelowTheKneeRun() {
        let events = S.run(footFootThen(S.footContact, height: 0.20), counter: counter(height: .knee))

        XCTAssertEqual(events.runEnds.first?.reason, .tooHigh, "\(events.runEnds)")
    }

    func testOneStrayFrameAboveTheLineIsNotCalled() {
        var frames = footFootThen(S.footContact, height: 0.10)
        // A single bad detection high up.
        let mid = frames.count / 2
        frames[mid].ball?.center.y = S.at(0, 0.50).y

        let events = S.run(frames, counter: counter(height: .waist))

        XCTAssertFalse(events.runEnds.map(\.reason).contains(.tooHigh), "\(events.runEnds)")
    }

    func testATinyFalseDetectionHighUpIsNotCalled() {
        // Seen on device: a detection a quarter of the ball's size near the top of the frame.
        var frames = footFootThen(S.footContact, height: 0.10)
        let mid = frames.count / 2
        for i in mid...(mid + 3) {
            frames[i].ball = BallSighting(center: DrillPoint(x: 0.2, y: 0.85), radius: S.ballRadius / 4)
        }

        let events = S.run(frames, counter: counter(height: .waist))

        XCTAssertFalse(events.runEnds.map(\.reason).contains(.tooHigh), "\(events.runEnds)")
    }

    func testATouchBelowTheHipsIsNeverCalledAChestTouch() {
        let hipHeight = S.at(0.33, 0.33)
        let events = S.run(footFootThen(hipHeight), counter: counter(parts: .feetOnly))

        XCTAssertNotEqual(events.runEnds.first?.reason, .chestTouch, "\(events.runEnds)")
    }

    // MARK: - Words

    func testEveryRuleBreakIsSaidPlainly() {
        XCTAssertEqual(RunStats(count: 3, endReason: .thighTouch, touches: []).endLine, "Ended: thigh touch (feet only)")
        XCTAssertEqual(RunStats(count: 3, endReason: .tooHigh, touches: []).endLine, "Ended: ball went too high")
    }
}
