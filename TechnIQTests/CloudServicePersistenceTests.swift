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
}
