import XCTest
import CoreData
import FirebaseFirestore
@testable import TechnIQ

@MainActor
final class CloudServicePersistenceTests: XCTestCase {
    var stack: TestCoreDataStack!
    var sut: CloudService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = CloudService.shared
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - PlayerStats round-trip

    func test_playerStats_encodeDecode_preservesAllFields() throws {
        let player = stack.makePlayer()
        let ratings: [String: Double] = ["passing": 4.2, "shooting": 3.8, "dribbling": 4.0]
        let original = stack.makePlayerStats(
            player: player,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            skillRatings: ratings,
            totalHours: 42.5,
            totalSessions: 17
        )

        let doc = sut.createPlayerStatsDocument(stats: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restorePlayerStats(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.stats?.allObjects as? [PlayerStats])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.date?.timeIntervalSince1970, original.date?.timeIntervalSince1970)
        XCTAssertEqual(restored?.totalTrainingHours, 42.5)
        XCTAssertEqual(restored?.totalSessions, 17)
        XCTAssertEqual(restored?.skillRatings?["passing"], 4.2)
        XCTAssertEqual(restored?.skillRatings?["shooting"], 3.8)
        XCTAssertEqual(restored?.skillRatings?["dribbling"], 4.0)
    }

    // MARK: - Season round-trip

    func test_season_encodeDecode_preservesAllFields() throws {
        let player = stack.makePlayer()
        let original = stack.makeSeason(player: player, name: "2025-26", isActive: true)
        original.team = "FC Test"
        original.endDate = Date(timeIntervalSince1970: 1_800_000_000)
        try stack.context.save()

        let doc = sut.createSeasonDocument(season: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreSeason(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.seasons?.allObjects as? [Season])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.name, "2025-26")
        XCTAssertEqual(restored?.team, "FC Test")
        XCTAssertEqual(restored?.isActive, true)
        XCTAssertEqual(restored?.endDate?.timeIntervalSince1970, 1_800_000_000)
    }

    // MARK: - Match round-trip with Season link

    func test_match_encodeDecode_preservesSeasonRelationship() throws {
        let player = stack.makePlayer()
        let season = stack.makeSeason(player: player, name: "2025-26")
        let original = stack.makeMatch(
            player: player, date: Date(timeIntervalSince1970: 1_700_000_000),
            goals: 2, assists: 1, minutesPlayed: 88, result: "W", season: season
        )
        original.opponent = "Rival FC"
        original.competition = "League"
        original.rating = 4
        original.xpEarned = 150
        try stack.context.save()

        let seasonDoc = sut.createSeasonDocument(season: season)
        let matchDoc = sut.createMatchDocument(match: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreSeason(from: seasonDoc, for: restoredPlayer, in: restoredContext)
        try sut.restoreMatch(from: matchDoc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.matches?.allObjects as? [Match])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.opponent, "Rival FC")
        XCTAssertEqual(restored?.competition, "League")
        XCTAssertEqual(restored?.goals, 2)
        XCTAssertEqual(restored?.assists, 1)
        XCTAssertEqual(restored?.minutesPlayed, 88)
        XCTAssertEqual(restored?.result, "W")
        XCTAssertEqual(restored?.rating, 4)
        XCTAssertEqual(restored?.xpEarned, 150)
        XCTAssertNotNil(restored?.season, "Season relationship must be rewired by UUID")
        XCTAssertEqual(restored?.season?.id, season.id)
    }

    func test_match_withoutSeason_restoresWithNilSeason() throws {
        let player = stack.makePlayer()
        let original = stack.makeMatch(player: player, goals: 1, result: "D", season: nil)
        let matchDoc = sut.createMatchDocument(match: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreMatch(from: matchDoc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.matches?.allObjects as? [Match])?.first
        XCTAssertNotNil(restored)
        XCTAssertNil(restored?.season)
    }

    // MARK: - PlanSession.exercises restore

    func test_trainingPlan_restoresPlanSessionExerciseRelationship() throws {
        let player = stack.makePlayer()
        let e1 = stack.makeExercise(player: player, name: "Passing Drill")
        let e2 = stack.makeExercise(player: player, name: "Shooting Drill")
        let plan = stack.makeTrainingPlan(player: player)
        let week = stack.makePlanWeek(plan: plan, weekNumber: 1)
        let day = stack.makePlanDay(week: week, dayNumber: 1)
        _ = stack.makePlanSession(day: day, exercises: [e1, e2])

        let customExerciseDocs: [[String: Any]] = [e1, e2].map { sut.createCustomExerciseDocument(exercise: $0) }
        let planDoc = sut.createTrainingPlanDocument(plan: plan)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        // Mirror production order: exercises first, then plan.
        for exerciseDoc in customExerciseDocs {
            try sut.restoreCustomExercise(from: exerciseDoc, for: restoredPlayer, in: restoredContext)
        }
        try sut.restoreTrainingPlan(from: planDoc, for: restoredPlayer, in: restoredContext)

        let restoredPlan = (restoredPlayer.trainingPlans?.allObjects as? [TrainingPlan])?.first
        let restoredWeek = (restoredPlan?.weeks?.allObjects as? [PlanWeek])?.first
        let restoredDay = (restoredWeek?.days?.allObjects as? [PlanDay])?.first
        let restoredSession = (restoredDay?.sessions?.allObjects as? [PlanSession])?.first
        let restoredExercises = (restoredSession?.exercises as? Set<Exercise>) ?? []

        XCTAssertEqual(restoredExercises.count, 2)
        XCTAssertEqual(Set(restoredExercises.compactMap { $0.id }), Set([e1.id!, e2.id!]))
    }

    func test_trainingPlan_restoresWithNoExercises_whenSessionHasEmptyExerciseIDs() throws {
        let player = stack.makePlayer()
        let plan = stack.makeTrainingPlan(player: player)
        let week = stack.makePlanWeek(plan: plan, weekNumber: 1)
        let day = stack.makePlanDay(week: week, dayNumber: 1)
        _ = stack.makePlanSession(day: day, exercises: [])

        let planDoc = sut.createTrainingPlanDocument(plan: plan)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreTrainingPlan(from: planDoc, for: restoredPlayer, in: restoredContext)

        let restoredDays = ((restoredPlayer.trainingPlans?.allObjects as? [TrainingPlan])?.first?
            .weeks?.allObjects as? [PlanWeek])?.first?.days?.allObjects as? [PlanDay]
        XCTAssertEqual(restoredDays?.first?.sessions?.count, 1)
    }
}
