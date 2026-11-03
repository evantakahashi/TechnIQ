import XCTest
@testable import JuggleCore

/// Weak-foot and alternating juggling: the same counter with a foot rule.
final class JuggleVariantTests: XCTestCase {
    private typealias S = SyntheticScene

    /// Drop from the hands, then one foot touch per entry ("L" / "R"), then the floor.
    private func feet(_ sides: String) -> [DrillFrame] {
        var b = S.Builder()
        let first = sides.first == "L"
        b.pose = first ? S.leftFootPose : S.pose
        let start = first ? S.leftFootContact : S.footContact
        b.hold(DrillPoint(x: start.x, y: S.at(0, 0.35).y), seconds: 0.5)
        b.fall(from: DrillPoint(x: start.x, y: S.at(0, 0.35).y), to: start)
        let list = Array(sides)
        for i in list.indices {
            let last = i == list.count - 1
            let next = last ? S.groundContact : (list[i + 1] == "L" ? S.leftFootContact : S.footContact)
            b.pose = list[i] == "L" ? S.leftFootPose : S.pose
            let from = list[i] == "L" ? S.leftFootContact : S.footContact
            b.pop(from: from, height: 0.20 * S.scale, to: next)
            if !last { b.pose = list[i + 1] == "L" ? S.leftFootPose : S.pose }
        }
        b.hold(S.groundContact, seconds: 0.5)
        return b.frames
    }

    private func counter(_ rule: JuggleCounter.FootRule) -> JuggleCounter {
        var config = JuggleCounter.Config()
        config.footRule = rule
        return JuggleCounter(config: config)
    }

    func testFootTouchesKnowWhichFoot() {
        let events = S.run(feet("RLR"))

        XCTAssertEqual(events.touches.map(\.part), [.foot, .foot, .foot])
        XCTAssertEqual(events.footSides, [.right, .left, .right])
    }

    func testWeakFootCountsOnlyThatFoot() {
        let events = S.run(feet("LLL"), counter: counter(.only(.left)))

        XCTAssertEqual(events.touches.map(\.count), [1, 2, 3])
        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
    }

    func testAStrongFootTouchEndsAWeakFootRun() {
        let events = S.run(feet("LLR"), counter: counter(.only(.left)))

        XCTAssertEqual(events.touches.map(\.count), [1, 2])
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.wrongFoot])
    }

    func testStrongFootTouchesBeforeTheRunDoNotStartIt() {
        let events = S.run(feet("RRLL"), counter: counter(.only(.left)))

        XCTAssertEqual(events.touches.map(\.count), [1, 2])
        XCTAssertEqual(events.runEnds.map(\.count), [2])
    }

    func testAlternatingCountsLeftRightLeft() {
        let events = S.run(feet("LRLR"), counter: counter(.alternate))

        XCTAssertEqual(events.touches.map(\.count), [1, 2, 3, 4])
        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
    }

    func testTheSameFootTwiceEndsAnAlternatingRun() {
        let events = S.run(feet("LRR"), counter: counter(.alternate))

        XCTAssertEqual(events.touches.map(\.count), [1, 2])
        XCTAssertEqual(events.runEnds.map(\.count), [2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.wrongFoot])
    }

    func testThighTouchesNeitherCountNorEndAFootRule() {
        var b = S.Builder()
        b.pose = S.leftFootPose
        b.fall(from: S.at(0.23, 0.35), to: S.leftFootContact)
        b.pop(from: S.leftFootContact, height: 0.30 * S.scale, to: S.thighContact)
        b.pose = S.pose
        b.pop(from: S.thighContact, height: 0.20 * S.scale, to: S.footContact)
        b.pop(from: S.footContact, height: 0.20 * S.scale, to: S.groundContact)
        b.hold(S.groundContact, seconds: 0.5)

        let events = S.run(b.frames, counter: counter(.alternate))

        XCTAssertEqual(events.touches.map(\.count), [1, 2])
        XCTAssertEqual(events.runEnds.map(\.reason), [.ground])
    }
}

extension Array where Element == DrillEvent {
    var footSides: [BodySide?] {
        compactMap { if case let .touch(_, part, _, side) = $0, part == .foot { return side } else { return nil } }
    }
}
