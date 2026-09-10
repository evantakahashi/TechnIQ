import XCTest
@testable import TechnIQ

final class DrillContentTests: XCTestCase {
    func testParsesAIGeneratedBlock() {
        let raw = """
        **Setup:**
        Place two cones 8 m from a wall.

        **Instructions:**
        1. Stand between the cones.
        2. Pass with the left foot.
        3. Every 20 reps, switch cone.

        **Variations:**
        • One-touch only

        **Coaching Points:**
        • Lock the ankle.
        • Strike through the middle of the ball.

        **Progressions:**
        • Move to 10 m

        **Safety Notes:**
        Warm up first.

        **Generated:** 9/9/26
        **Original Request:** weak foot passing
        """
        let content = DrillContent.parse(raw)

        XCTAssertEqual(content.setup, "Place two cones 8 m from a wall.")
        XCTAssertEqual(content.steps, ["Stand between the cones.", "Pass with the left foot.", "Every 20 reps, switch cone."])
        XCTAssertEqual(content.coachingPoints, ["Lock the ankle.", "Strike through the middle of the ball."])
        XCTAssertEqual(content.variations, ["One-touch only"])
        XCTAssertEqual(content.progressions, ["Move to 10 m"])
        XCTAssertEqual(content.safetyNotes, "Warm up first.")
        XCTAssertEqual(content.extras.count, 5)
        XCTAssertEqual(content.coachCue(forStep: 0), "Lock the ankle.")
        XCTAssertEqual(content.coachCue(forStep: 1), "Strike through the middle of the ball.")
        XCTAssertEqual(content.coachCue(forStep: 2), "Lock the ankle.")
    }

    func testParsesPlainNumberedSteps() {
        let content = DrillContent.parse("1. Juggle 20 times\n2. Alternate feet\n3) Catch and repeat")
        XCTAssertEqual(content.steps, ["Juggle 20 times", "Alternate feet", "Catch and repeat"])
        XCTAssertTrue(content.coachingPoints.isEmpty)
        XCTAssertEqual(content.coachCue(forStep: 5), "Catch and repeat")
    }

    func testEmptyInstructions() {
        XCTAssertEqual(DrillContent.parse(nil), .empty)
        XCTAssertEqual(DrillContent.parse("  \n"), .empty)
        XCTAssertNil(DrillContent.empty.coachCue(forStep: 0))
    }
}
