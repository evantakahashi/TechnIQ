import XCTest
@testable import JuggleCore

/// Wall passes: the player faces the phone with a wall to one side; the ball goes from their feet out of
/// frame to the wall and back. A pass that comes back to the feet counts; a miss doesn't.
final class WallPassCounterTests: XCTestCase {
    private typealias S = SyntheticScene

    private static let atFeet = DrillPoint(x: S.at(0.40, 0).x, y: S.groundContact.y)
    private static let edge = DrillPoint(x: 0.56, y: S.groundContact.y)

    private struct Clip {
        var frames: [DrillFrame] = []
        var t = 0.0

        mutating func ball(_ p: DrillPoint?, seconds: Double) {
            for _ in 0..<Int(seconds * S.fps) {
                frames.append(DrillFrame(time: t, ball: p.map { BallSighting(center: $0, radius: S.ballRadius) }, pose: S.pose))
                t += 1 / S.fps
            }
        }

        mutating func roll(from a: DrillPoint, to b: DrillPoint, seconds: Double) {
            let n = Int(seconds * S.fps)
            for i in 1...n {
                let f = Double(i) / Double(n)
                frames.append(DrillFrame(time: t, ball: BallSighting(center: DrillPoint(x: a.x + (b.x - a.x) * f, y: a.y),
                                                                     radius: S.ballRadius), pose: S.pose))
                t += 1 / S.fps
            }
        }

        /// Out to the wall (off frame) and back to the feet.
        mutating func pass(awaySeconds: Double = 0.6) {
            roll(from: WallPassCounterTests.atFeet, to: WallPassCounterTests.edge, seconds: 0.3)
            ball(nil, seconds: awaySeconds)
            roll(from: WallPassCounterTests.edge, to: WallPassCounterTests.atFeet, seconds: 0.3)
            ball(WallPassCounterTests.atFeet, seconds: 0.3)
        }
    }

    private func run(_ frames: [DrillFrame]) -> [DrillEvent] {
        let counter = WallPassCounter()
        return frames.flatMap { counter.process($0) } + counter.finish(at: frames.last?.time ?? 0)
    }

    func testEachReturnedPassCounts() {
        var clip = Clip()
        clip.ball(Self.atFeet, seconds: 0.5)
        clip.pass(); clip.pass(); clip.pass()

        let events = run(clip.frames)

        XCTAssertEqual(events.touches.map(\.count), [1, 2, 3])
        XCTAssertEqual(events.runEnds.map(\.reason), [.stopped])
    }

    func testABallThatNeverLeavesCountsNothing() {
        var clip = Clip()
        clip.ball(Self.atFeet, seconds: 3)

        XCTAssertTrue(run(clip.frames).isEmpty)
    }

    func testAMissThatHasToBeFetchedDoesNotCount() {
        var clip = Clip()
        clip.ball(Self.atFeet, seconds: 0.5)
        clip.pass()
        clip.pass(awaySeconds: 6)   // missed the return, went to fetch it
        clip.pass()

        XCTAssertEqual(run(clip.frames).touches.map(\.count), [1, 2])
    }

    func testDribblingAroundTheFeetIsNotAPass() {
        var clip = Clip()
        clip.ball(Self.atFeet, seconds: 0.5)
        let nudge = DrillPoint(x: Self.atFeet.x + 0.04, y: Self.atFeet.y)
        for _ in 0..<4 {
            clip.roll(from: Self.atFeet, to: nudge, seconds: 0.2)
            clip.roll(from: nudge, to: Self.atFeet, seconds: 0.2)
        }

        XCTAssertTrue(run(clip.frames).touches.isEmpty)
    }
}
