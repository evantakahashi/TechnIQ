import XCTest
@testable import JuggleCore

/// Trends from saved runs: zero-effort logging turned into a chart and a headline.
final class CameraTrendsTests: XCTestCase {
    private let day = 86_400.0
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func run(_ drill: CameraDrill, _ count: Int, dayOffset: Double, end: RunEndReason = .ground,
                     left: Int = 0, right: Int = 0, seconds: Double = 10) -> TrendRun {
        var touches: [TouchRecord] = []
        for i in 0..<count {
            let side: BodySide? = i < left ? .left : (i < left + right ? .right : nil)
            touches.append(TouchRecord(time: seconds * Double(i) / Double(max(1, count - 1)),
                                       part: side == nil ? .thigh : .foot, side: side))
        }
        return TrendRun(drill: drill, count: count, date: start.addingTimeInterval(dayOffset * day + 3600),
                        endReason: end, stats: RunStats(count: count, endReason: end, touches: touches))
    }

    func testBestPerDayIsTheChartLine() {
        let runs = [run(.juggling, 5, dayOffset: 0), run(.juggling, 9, dayOffset: 0), run(.juggling, 7, dayOffset: 2),
                    run(.weakFootJuggling, 30, dayOffset: 2)]

        let points = CameraTrends.dailyBests(runs, drill: .juggling)

        XCTAssertEqual(points.map(\.best), [9, 7])
        XCTAssertEqual(points.count, 2)
    }

    func testTheHeadlineShowsRealProgress() {
        let runs = [run(.weakFootJuggling, 8, dayOffset: 0), run(.weakFootJuggling, 6, dayOffset: 1),
                    run(.weakFootJuggling, 15, dayOffset: 10), run(.weakFootJuggling, 23, dayOffset: 21)]

        XCTAssertEqual(CameraTrends.headline(runs, drill: .weakFootJuggling), "Weak-foot juggling: 8 → 23 in 3 weeks")
    }

    func testNoHeadlineWithoutAWeekOfHistoryOrWithoutProgress() {
        let tooSoon = [run(.juggling, 8, dayOffset: 0), run(.juggling, 20, dayOffset: 3)]
        let flat = [run(.juggling, 20, dayOffset: 0), run(.juggling, 21, dayOffset: 14)]

        XCTAssertNil(CameraTrends.headline(tooSoon, drill: .juggling))
        XCTAssertNil(CameraTrends.headline(flat, drill: .juggling))
    }

    func testHowRunsEndIsTheFailureBreakdown() {
        let runs = [run(.feetOnlyJuggling, 5, dayOffset: 0, end: .thighTouch),
                    run(.feetOnlyJuggling, 7, dayOffset: 0, end: .ground),
                    run(.feetOnlyJuggling, 3, dayOffset: 1, end: .thighTouch)]

        let ends = CameraTrends.endings(runs, drill: .feetOnlyJuggling)

        XCTAssertEqual(ends.map(\.reason), [.thighTouch, .ground])
        XCTAssertEqual(ends.map(\.count), [2, 1])
    }

    func testLeftFootShareByDay() {
        let runs = [run(.juggling, 10, dayOffset: 0, left: 2, right: 8), run(.juggling, 10, dayOffset: 5, left: 5, right: 5)]

        let shares = CameraTrends.leftFootShare(runs, drill: .juggling)

        XCTAssertEqual(shares.map(\.share), [0.2, 0.5])
    }

    func testTempoByDay() {
        let runs = [run(.juggling, 11, dayOffset: 0, seconds: 10)]

        XCTAssertEqual(CameraTrends.tempo(runs, drill: .juggling).first?.touchesPerMinute ?? 0, 60, accuracy: 0.01)
    }
}
