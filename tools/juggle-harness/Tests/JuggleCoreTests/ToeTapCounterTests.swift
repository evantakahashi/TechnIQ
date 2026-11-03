import XCTest
@testable import JuggleCore

/// Toe taps: the ball rests on the ground in front of the player; soles alternate on top of it.
final class ToeTapCounterTests: XCTestCase {
    private typealias S = SyntheticScene

    /// Ball resting on the floor in front of the player.
    private static let ball = DrillPoint(x: S.at(0.32, 0).x, y: S.groundContact.y)
    private static var ballTop: DrillPoint { DrillPoint(x: ball.x, y: ball.y + S.ballRadius) }

    /// Standing pose with both feet down, either side of the ball.
    private static let standing: BodyPose = {
        var p = S.pose
        p.joints[.leftAnkle] = S.at(0.26, 0.10)
        p.joints[.rightAnkle] = S.at(0.38, 0.10)
        p.joints[.leftKnee] = S.at(0.27, 0.22)
        p.joints[.rightKnee] = S.at(0.37, 0.22)
        return p
    }()

    /// `side`'s sole on top of the ball.
    private static func tapping(_ side: BodySide) -> BodyPose {
        var p = standing
        let onTop = DrillPoint(x: ballTop.x, y: ballTop.y + 0.06 * S.unitsPerMetre)
        p.joints[side == .left ? .leftAnkle : .rightAnkle] = onTop
        return p
    }

    /// Frames for a sequence of taps ("L" / "R"), each ~0.25 s on the ball then ~0.25 s back down.
    private func frames(_ taps: String, ballMissing: Bool = false) -> [DrillFrame] {
        var out: [DrillFrame] = []
        var t = 0.0
        func add(_ pose: BodyPose, seconds: Double) {
            for _ in 0..<Int(seconds * S.fps) {
                let ball = ballMissing ? nil : BallSighting(center: Self.ball, radius: S.ballRadius)
                out.append(DrillFrame(time: t, ball: ball, pose: pose))
                t += 1 / S.fps
            }
        }
        add(Self.standing, seconds: 0.5)
        for c in taps {
            add(Self.tapping(c == "L" ? .left : .right), seconds: 0.25)
            add(Self.standing, seconds: 0.25)
        }
        return out
    }

    private func run(_ frames: [DrillFrame]) -> [DrillEvent] {
        let counter = ToeTapCounter()
        return frames.flatMap { counter.process($0) } + counter.finish(at: frames.last?.time ?? 0)
    }

    func testAlternatingTapsAllCount() {
        let events = run(frames("LRLRLR"))

        XCTAssertEqual(events.touches.map(\.count), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(events.runEnds.map(\.count), [6])
        XCTAssertEqual(events.runEnds.map(\.reason), [.stopped])
    }

    func testTheSameFootTwiceCountsOnce() {
        let events = run(frames("LLR"))

        XCTAssertEqual(events.touches.map(\.count), [1, 2])
    }

    func testStandingStillCountsNothing() {
        XCTAssertTrue(run(frames("")).isEmpty)
    }

    func testNoBallNoTaps() {
        XCTAssertTrue(run(frames("LRLR", ballMissing: true)).touches.isEmpty)
    }
}
