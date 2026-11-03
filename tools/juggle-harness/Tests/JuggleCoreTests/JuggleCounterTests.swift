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

    func testARaisedHandTouchEndsTheRunAsHandballWithoutCounting() {
        var raised = S.pose
        raised.joints[.rightElbow] = S.at(0.39, 0.42)
        raised.joints[.rightWrist] = S.at(0.40, 0.46)
        let hand = S.at(0.41, 0.46)
        var b = S.Builder()
        b.pose = raised
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.40 * S.scale, to: hand)
        b.hold(hand, seconds: 0.5)

        let events = S.run(b.frames)

        XCTAssertEqual(events.touches.count, 2)
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.handball])
    }

    func testATouchBesideAHangingHandIsNotAHandball() {
        // Seen on device: front-on, a thigh touch lands right where the hanging hand is.
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.25 * S.scale, to: S.wristContact)
        b.pop(from: S.wristContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.6)

        let events = S.run(b.frames)

        XCTAssertFalse(events.runEnds.map(\.reason).contains(.handball), "\(events.runEnds)")
        XCTAssertEqual(events.runEnds.map(\.count), [3])
    }

    func testLowTouchesRightAtTheFootAreNotTheGround() {
        // Seen on device with the phone on the floor: a ball touched just above the floor in front of the feet
        // sits as low in the frame as the floor itself.
        let lowFoot = DrillPoint(x: S.at(0.37, 0).x, y: S.groundContact.y + 0.03 * S.unitsPerMetre)
        let awayOnTheFloor = DrillPoint(x: S.at(0.60, 0).x, y: S.groundContact.y)
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: lowFoot)
        for _ in 0..<3 { b.pop(from: lowFoot, height: 0.20 * S.scale, to: lowFoot) }
        b.pop(from: lowFoot, height: 0.20 * S.scale, to: awayOnTheFloor)
        b.hold(awayOnTheFloor, seconds: 0.5)

        let events = S.run(b.frames)

        XCTAssertEqual(events.runEnds.map(\.count), [4], "\(events.touches) \(events.runEnds)")
        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
    }

    func testLosingTheBallAndThePlayerEndsTheRunAfterTheTimeout() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pose = nil
        b.gap(seconds: 1.5)

        let events = S.run(b.frames)

        // The last contact never rebounds or stalls on camera, so it can't be confirmed.
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.lostBall])
    }

    func testTheBallHiddenWhileThePlayerIsStillThereDoesNotEndTheRun() {
        // Seen on device: white ball against white trousers, the detector loses it for 1–2 s mid-run.
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.gap(seconds: 1.5)
        b.hold(S.at(0.37, 0.40), seconds: 0.1)
        b.fall(from: S.at(0.37, 0.40), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.5)

        let events = S.run(b.frames)

        XCTAssertEqual(events.runEnds.count, 1, "\(events.runEnds)")
        XCTAssertEqual(events.runEnds.first?.reason, .ground)
        XCTAssertGreaterThanOrEqual(events.runEnds.first?.count ?? 0, 4)
    }

    func testTheBallGoneForLongEvenWithThePlayerThereEndsTheRun() {
        var b = S.Builder()
        b.fall(from: S.at(0.37, 0.35), to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.footContact)
        b.gap(seconds: 3)

        XCTAssertEqual(S.run(b.frames).runEnds.map(\.reason), [.lostBall])
    }

    func testTouchesHiddenAtTheBottomStillCount() {
        // Seen on device: the detector finds the ball high up but loses it below the knees, where every
        // touch happens. A falling ball can't come back higher without being touched.
        // Only the top few centimetres of each arc stay visible: never enough fall to confirm a low point.
        var frames = footRun(touches: 6)
        let apex = frames.compactMap { $0.ball?.center.y }.max() ?? 1
        let visibleBelowApex = 0.04 * S.unitsPerMetre
        let firstFall = frames.firstIndex { ($0.ball?.center.y ?? 1) < S.footContact.y + 0.01 } ?? 0
        for i in frames.indices where i > firstFall && (frames[i].ball?.center.y ?? 1) < apex - visibleBelowApex {
            frames[i].ball = nil
        }

        let events = S.run(frames)

        XCTAssertEqual(events.touches.map(\.count).last, 6, "\(events.touches)")
    }

    func testATouchHiddenBelowTheKneesIsStillCreditedToTheFoot() {
        // Seen on device: the ball vanishes below the knees, so the lowest sighting is at thigh height and
        // foot touches were judged thigh / chest. The contact is where the fall and the rise meet.
        let kneeHeight = S.at(0, 0.24).y
        var frames = footRun(touches: 6)
        let firstFall = frames.firstIndex { ($0.ball?.center.y ?? 1) < S.footContact.y + 0.01 } ?? 0
        for i in frames.indices where i > firstFall && (frames[i].ball?.center.y ?? 1) < kneeHeight {
            frames[i].ball = nil
        }

        let events = S.run(frames)

        XCTAssertGreaterThanOrEqual(events.touches.count, 5, "\(events.touches)")
        XCTAssertEqual(Set(events.touches.dropFirst().map(\.part)), [.foot], "\(events.touches)")
    }

    func testABallThatJustFallsBehindAGapIsNotATouch() {
        var b = S.Builder()
        b.hold(S.at(0.37, 0.50), seconds: 0.3)
        b.fall(from: S.at(0.37, 0.50), to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.5)
        var frames = b.frames
        let mid = frames.count / 2
        for i in (mid - 4)...(mid + 2) { frames[i].ball = nil }

        XCTAssertTrue(S.run(frames).touches.isEmpty)
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
