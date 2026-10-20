import XCTest
@testable import JuggleCore

final class HandsFreeFlowTests: XCTestCase {
    private let aspect = 0.5625
    private let standing = SyntheticScene.pose

    private var armsUp: BodyPose {
        var pose = SyntheticScene.pose
        pose.joints[.leftWrist] = DrillPoint(x: 0.24, y: 0.62)
        pose.joints[.rightWrist] = DrillPoint(x: 0.36, y: 0.62)
        return pose
    }

    /// Feeds `pose` at 30 fps from `from` for `seconds`; returns all cues.
    @discardableResult
    private func feed(_ flow: HandsFreeFlow, _ pose: BodyPose?, from: Double, seconds: Double) -> [HandsFreeFlow.Cue] {
        var cues: [HandsFreeFlow.Cue] = []
        var t = from
        while t < from + seconds - 1e-9 {
            cues += flow.update(pose: pose, time: t)
            t += 1 / 30
        }
        return cues
    }

    func testStandingInTheOutlineCountsDownThenGoesLive() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)
        XCTAssertEqual(flow.state, .positioning)

        let cues = feed(flow, standing, from: 0, seconds: 4.2)

        XCTAssertEqual(cues, [.ready, .countdown(3), .countdown(2), .countdown(1), .go])
        XCTAssertTrue(flow.isLive)
    }

    func testNoPoseNeverStarts() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)

        feed(flow, nil, from: 0, seconds: 5)

        XCTAssertEqual(flow.state, .positioning)
    }

    func testPlayerTooFarAwayIsNotInPosition() {
        var tiny = BodyPose(joints: [:])
        for (joint, p) in standing.joints {
            tiny.joints[joint] = DrillPoint(x: 0.28 + (p.x - 0.30) * 0.5, y: 0.10 + (p.y - 0.10) * 0.5)
        }

        XCTAssertTrue(HandsFreeFlow.isInPosition(standing, aspect: aspect))
        XCTAssertFalse(HandsFreeFlow.isInPosition(tiny, aspect: aspect))
    }

    func testSteppingOutDuringTheCountdownCancelsIt() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)
        feed(flow, standing, from: 0, seconds: 1.6)

        let cues = feed(flow, nil, from: 1.6, seconds: 1)

        XCTAssertEqual(cues, [.stepIn])
        XCTAssertEqual(flow.state, .positioning)
    }

    func testStreakRunEndShowsTheResultThenStayingInPositionGoesAgain() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)
        feed(flow, standing, from: 0, seconds: 4.2)

        flow.runEnded(at: 10)
        XCTAssertEqual(flow.state, .result(since: 10))
        let early = feed(flow, standing, from: 10, seconds: 3)
        XCTAssertTrue(early.isEmpty, "result stays up at least 4 s: \(early)")

        let later = feed(flow, standing, from: 13, seconds: 5)

        XCTAssertEqual(later.first, .ready)
        XCTAssertTrue(flow.isLive)
    }

    func testTimedDrillEndsWhenTheClockRunsOut() {
        let flow = HandsFreeFlow(mode: .timed(seconds: 30), aspect: aspect)
        feed(flow, standing, from: 0, seconds: 4.2)
        XCTAssertTrue(flow.isLive)

        let cues = feed(flow, standing, from: 4.2, seconds: 31)

        XCTAssertTrue(cues.contains(.timeUp))
        if case .result = flow.state {} else { XCTFail("expected result, got \(flow.state)") }
    }

    func testTimedDrillReportsTimeLeft() {
        let flow = HandsFreeFlow(mode: .timed(seconds: 30), aspect: aspect)
        feed(flow, standing, from: 0, seconds: 4.2)  // live from ~4.0 s

        feed(flow, standing, from: 4.2, seconds: 10)

        XCTAssertEqual(flow.timeLeft ?? 0, 20, accuracy: 0.3)
    }

    func testHoldingBothArmsUpFinishesTheSession() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)

        let cues = feed(flow, armsUp, from: 0, seconds: 1.2)

        XCTAssertEqual(cues, [.finished])
        XCTAssertEqual(flow.state, .finished)
    }

    func testArmsUpMidRunDoesNotEndIt() {
        let flow = HandsFreeFlow(mode: .streak, aspect: aspect)
        feed(flow, standing, from: 0, seconds: 4.2)

        feed(flow, armsUp, from: 4.2, seconds: 2)

        XCTAssertTrue(flow.isLive)
    }
}
