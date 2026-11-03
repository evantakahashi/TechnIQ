import XCTest
@testable import JuggleCore

/// Per-run stats and insight lines, worked out from the same frames + counter events the session sees.
final class RunStatsTests: XCTestCase {
    private typealias S = SyntheticScene

    /// Frames through a fresh counter and recorder; the finished runs' stats.
    private func stats(_ frames: [DrillFrame], counter: JuggleCounter = JuggleCounter()) -> [RunStats] {
        let recorder = RunRecorder()
        var out: [RunStats] = []
        for frame in frames { out += recorder.record(frame, events: counter.process(frame)) }
        if let last = frames.last { out += recorder.record(last, events: counter.finish(at: last.time)) }
        return out
    }

    /// Drop, one touch per side ("L" / "R") popping to `height` metres above the contact, then the floor.
    private func run(_ sides: String, height: (Character) -> Double = { _ in 0.6 }) -> [DrillFrame] {
        var b = S.Builder()
        let list = Array(sides)
        let contact = { (c: Character) in c == "L" ? S.leftFootContact : S.footContact }
        b.pose = list[0] == "L" ? S.leftFootPose : S.pose
        b.hold(DrillPoint(x: contact(list[0]).x, y: S.at(0, 0.35).y), seconds: 0.4)
        b.fall(from: DrillPoint(x: contact(list[0]).x, y: S.at(0, 0.35).y), to: contact(list[0]))
        for i in list.indices {
            b.pose = list[i] == "L" ? S.leftFootPose : S.pose
            let next = i == list.count - 1 ? S.groundContact : contact(list[i + 1])
            b.pop(from: contact(list[i]), height: height(list[i]) * S.unitsPerMetre, to: next)
        }
        b.hold(S.groundContact, seconds: 0.6)
        return b.frames
    }

    func testTouchesAreSplitByFootAndTheEndIsKept() throws {
        let result = try XCTUnwrap(stats(run("RLRRL")).first)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result.rightFoot, 3)
        XCTAssertEqual(result.leftFoot, 2)
        XCTAssertEqual(result.endReason, .ground)
        XCTAssertEqual(result.ambiguous, 0)
    }

    func testBallHeightAfterEachTouchIsInMetresAboveTheFloor() throws {
        let result = try XCTUnwrap(stats(run("RRRR", height: { _ in 0.6 })).first)
        // Contact ~0.2 m up (ball centre at the raised foot) + a 0.6 m pop.
        let contactHeight = (S.footContact.y - (0.10 - 0.08 * S.unitsPerMetre)) / S.unitsPerMetre

        XCTAssertEqual(try XCTUnwrap(result.apexRight), contactHeight + 0.6, accuracy: 0.05)
    }

    func testTouchesPerMinute() throws {
        let result = try XCTUnwrap(stats(run("RRRRRRRR")).first)
        let expected = Double(result.count - 1) / result.duration * 60

        XCTAssertEqual(try XCTUnwrap(result.touchesPerMinute), expected, accuracy: 0.01)
        XCTAssertGreaterThan(result.duration, 0)
    }

    func testOneFootSendingItHigherIsCalledOut() throws {
        let result = try XCTUnwrap(stats(run("RLRLRL", height: { $0 == "R" ? 0.8 : 0.4 })).first)

        let lines = result.insights
        XCTAssertTrue(lines.contains { $0.hasPrefix("Right foot sends it") && $0.contains("higher than your left") }, "\(lines)")
    }

    func testEvenFeetGetNoHeightLine() throws {
        let result = try XCTUnwrap(stats(run("RLRLRL")).first)

        XCTAssertFalse(result.insights.contains { $0.contains("sends it") }, "\(result.insights)")
    }

    func testTheEndOfEveryRunIsSaidPlainly() throws {
        let result = try XCTUnwrap(stats(run("RRR")).first)

        XCTAssertEqual(result.endLine, "Ended: the ball hit the ground")
    }

    func testHowRunsUsuallyEndIsSurfacedAcrossASession() {
        let ground = RunStats(count: 4, endReason: .ground, touches: [])
        let hands = RunStats(count: 2, endReason: .handball, touches: [])

        XCTAssertEqual(RunStats.sessionLine([ground, ground, hands, ground]), "3 of 4 runs ended with the ball hitting the ground")
        XCTAssertNil(RunStats.sessionLine([ground]))
    }
}
