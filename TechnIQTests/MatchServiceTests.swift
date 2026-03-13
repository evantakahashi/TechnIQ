import XCTest
import CoreData
@testable import TechnIQ

final class MatchServiceTests: XCTestCase {
    var sut: MatchService!
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = MatchService(context: stack.context)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Stats Calculation

    func test_calculateStats_emptyMatches_returnsEmpty() {
        let stats = sut.calculateStats(for: [])
        XCTAssertEqual(stats.matchesPlayed, 0)
        XCTAssertEqual(stats.totalGoals, 0)
    }

    func test_calculateStats_singleMatch_correctTotals() {
        let player = stack.makePlayer()
        let match = stack.makeMatch(player: player, goals: 2, assists: 1, minutesPlayed: 90, result: "W")
        let stats = sut.calculateStats(for: [match])

        XCTAssertEqual(stats.matchesPlayed, 1)
        XCTAssertEqual(stats.totalGoals, 2)
        XCTAssertEqual(stats.totalAssists, 1)
        XCTAssertEqual(stats.totalMinutes, 90)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.draws, 0)
        XCTAssertEqual(stats.losses, 0)
    }

    func test_calculateStats_multipleMatches_correctAverages() {
        let player = stack.makePlayer()
        let m1 = stack.makeMatch(player: player, goals: 2, assists: 0, minutesPlayed: 90, result: "W")
        let m2 = stack.makeMatch(player: player, goals: 0, assists: 2, minutesPlayed: 60, result: "L")
        let stats = sut.calculateStats(for: [m1, m2])

        XCTAssertEqual(stats.matchesPlayed, 2)
        XCTAssertEqual(stats.goalsPerGame, 1.0, accuracy: 0.01)
        XCTAssertEqual(stats.assistsPerGame, 1.0, accuracy: 0.01)
        XCTAssertEqual(stats.minutesPerGame, 75.0, accuracy: 0.01)
    }

    func test_calculateStats_winRate_computed() {
        let player = stack.makePlayer()
        let m1 = stack.makeMatch(player: player, result: "W")
        let m2 = stack.makeMatch(player: player, result: "W")
        let m3 = stack.makeMatch(player: player, result: "L")
        let m4 = stack.makeMatch(player: player, result: "D")
        let stats = sut.calculateStats(for: [m1, m2, m3, m4])

        XCTAssertEqual(stats.winRate, 50.0, accuracy: 0.01)
    }

    func test_calculateStats_goalContributions() {
        let player = stack.makePlayer()
        let m1 = stack.makeMatch(player: player, goals: 3, assists: 2)
        let stats = sut.calculateStats(for: [m1])

        XCTAssertEqual(stats.goalContributions, 5)
    }

    // MARK: - Match CRUD

    func test_createMatch_clampsValues() {
        let player = stack.makePlayer()
        let match = sut.createMatch(
            for: player, date: Date(), opponent: "Test",
            competition: nil, minutesPlayed: 200,
            goals: -5, assists: 0, positionPlayed: nil,
            isHomeGame: true, result: "W", notes: nil, rating: 10
        )
        XCTAssertEqual(match.minutesPlayed, 150)
        XCTAssertEqual(match.goals, 0)
        XCTAssertEqual(match.rating, 5)
    }

    func test_createMatch_calculatesXP() {
        let player = stack.makePlayer()
        let match = sut.createMatch(
            for: player, date: Date(), opponent: nil,
            competition: nil, minutesPlayed: 90,
            goals: 2, assists: 1, positionPlayed: nil,
            isHomeGame: true, result: "W", notes: nil, rating: 3
        )
        // base(50) + goals(40) + assists(15) + fullMatch(25) + win(30) = 160
        XCTAssertEqual(match.xpEarned, 160)
    }

    // MARK: - Season Comparison

    func test_compareSeasons_calculatesDeltas() {
        let player = stack.makePlayer()
        let s1 = stack.makeSeason(player: player, name: "S1")
        let s2 = stack.makeSeason(player: player, name: "S2")

        stack.makeMatch(player: player, goals: 1, assists: 0, minutesPlayed: 90, season: s1)
        stack.makeMatch(player: player, goals: 3, assists: 2, minutesPlayed: 90, season: s2)

        let comparison = sut.compareSeasons(s1, s2)
        XCTAssertEqual(comparison.goalsPerGameDelta, 2.0, accuracy: 0.01)
        XCTAssertEqual(comparison.assistsPerGameDelta, 2.0, accuracy: 0.01)
    }

    // MARK: - Fetch

    func test_fetchMatches_filtersByPlayer() {
        let player1 = stack.makePlayer(name: "P1")
        let player2 = stack.makePlayer(name: "P2")
        stack.makeMatch(player: player1, goals: 1)
        stack.makeMatch(player: player1, goals: 2)
        stack.makeMatch(player: player2, goals: 3)

        let matches = sut.fetchMatches(for: player1)
        XCTAssertEqual(matches.count, 2)
    }

    func test_deleteMatch_removesFromStore() {
        let player = stack.makePlayer()
        let match = sut.createMatch(
            for: player, date: Date(), opponent: nil,
            competition: nil, minutesPlayed: 90,
            goals: 0, assists: 0, positionPlayed: nil,
            isHomeGame: true, result: nil, notes: nil, rating: 3
        )
        sut.deleteMatch(match)
        let remaining = sut.fetchMatches(for: player)
        XCTAssertEqual(remaining.count, 0)
    }
}
