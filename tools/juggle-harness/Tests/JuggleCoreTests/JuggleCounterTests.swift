import XCTest
@testable import JuggleCore

final class JuggleCounterTests: XCTestCase {
    private typealias S = SyntheticScene

    /// Drop from the hands, `touches` foot juggles, then the ball falls to the floor.
    private func footRun(touches: Int, noise: @escaping (Int) -> Double = { _ in 0 }) -> [DrillFrame] {
        var b = S.Builder()
        b.noise = noise
        b.hold(S.at(0.37, 0.35), seconds: 0.5)
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        for i in 0..<touches {
            let last = i == touches - 1
            b.pop(from: S.footContact, height: 0.20 * S.scale, to: last ? S.groundContact : S.footContact)
        }
        b.hold(S.groundContact, seconds: 0.5)
        return b.frames
    }

    func testCountsEveryFootTouchAndEndsOnTheGround() {
        let events = S.run(footRun(touches: 5))

        XCTAssertEqual(events.touches.map(\.count), [1, 2, 3, 4, 5])
        XCTAssertEqual(events.touches.map(\.part), Array(repeating: .foot, count: 5))
        XCTAssertEqual(events.runEnds.map(\.count), [5])
        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
    }

    func testBallBouncingOnTheGroundBeforeARunCountsNothing() {
        var b = S.Builder()
        b.hold(S.at(0.42, 0.30), seconds: 0.3)
        b.fall(from: S.at(0.42, 0.30), to: S.groundContact)
        b.pop(from: S.groundContact, height: 0.08 * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.5)

        let events = S.run(b.frames)

        XCTAssertTrue(events.isEmpty, "\(events)")
    }

    func testThighAndHeadTouchesAreClassified() {
        var b = S.Builder()
        b.fall(from: S.at(0.36, 0.50), to: S.thighContact)
        b.pop(from: S.thighContact, height: 0.35 * S.scale, to: S.headContact)
        b.pop(from: S.headContact, height: 0.10 * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.3)

        let events = S.run(b.frames)

        XCTAssertEqual(events.touches.map(\.part), [.thigh, .head])
        XCTAssertEqual(events.runEnds.map(\.count), [2])
    }

    func testArmTouchEndsTheRunAsHandballWithoutCounting() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.25 * S.scale, to: S.wristContact)
        b.hold(S.wristContact, seconds: 0.5)

        let events = S.run(b.frames)

        XCTAssertEqual(events.touches.count, 2)
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.handball])
    }

    func testLosingTheBallMidRunEndsItAfterTheTimeout() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.gap(seconds: 1.5)

        let events = S.run(b.frames)

        // The last contact never rebounds or stalls on camera, so it can't be confirmed.
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.lostBall])
    }

    func testDetectorJitterDoesNotAddTouches() {
        // ±0.006 units (~2 cm) alternating every frame.
        let events = S.run(footRun(touches: 8, noise: { $0 % 2 == 0 ? 0.006 : -0.006 }))

        XCTAssertEqual(events.runEnds.map(\.count), [8])
    }

    func testShortDetectorGapAroundTheContactStillCounts() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        var frames = b.frames
        var tail = S.Builder()
        tail.time = b.time
        tail.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        tail.pop(from: S.footContact, height: 0.20 * S.scale, to: S.groundContact)
        tail.hold(S.groundContact, seconds: 0.3)
        frames += tail.frames
        // Blank the 2 frames either side of every contact.
        let contacts = frames.indices.filter { frames[$0].ball?.center == S.footContact.self }
        for i in contacts { for j in max(0, i - 2)...min(frames.count - 1, i + 2) where j != i { frames[j].ball = nil } }
        for i in contacts { frames[i].ball = nil }

        let events = S.run(frames)

        XCTAssertEqual(events.runEnds.map(\.count), [2])
    }

    func testTouchWithoutAPoseCountsAsUnknown() {
        var b = S.Builder()
        b.pose = nil
        b.fall(from: S.at(0.37, 0.45), to: S.thighContact)
        b.pop(from: S.thighContact, height: 0.20 * S.scale, to: S.thighContact)
        b.pop(from: S.thighContact, height: 0.20 * S.scale, to: S.at(0.36, 0.40))
        b.gap(seconds: 1.5)

        let events = S.run(b.frames)

        XCTAssertEqual(events.touches.map(\.part), [.unknown, .unknown])
    }

    func testTwoRunsBackToBack() {
        let events = S.run(footRun(touches: 3) + footRun(touches: 4).retimed(after: 10))

        XCTAssertEqual(events.runEnds.map(\.count), [3, 4])
    }

    func testFinishEndsAnOpenRunAsStopped() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.10 * S.scale, to: S.at(0.37, 0.25))

        let events = S.run(b.frames)

        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.stopped])
    }
}

private extension Array where Element == DrillFrame {
    func retimed(after offset: Double) -> [DrillFrame] {
        map { var f = $0; f.time += offset; return f }
    }
}
