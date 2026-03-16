import XCTest
@testable import TechnIQ

final class DrillDiagramTests: XCTestCase {

    // MARK: - DiagramElementType Parsing

    func testPlayerTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "player"), .player)
    }

    func testDefenderTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "defender"), .defender)
    }

    func testServerTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "server"), .server)
    }

    func testMannequinTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "mannequin"), .mannequin)
    }

    func testWallTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "wall"), .wall)
    }

    func testConeTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "cone"), .cone)
    }

    func testGoalTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "goal"), .goal)
    }

    func testBallTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "ball"), .ball)
    }

    func testTargetTypeParsesCorrectly() {
        XCTAssertEqual(DiagramElementType(rawValue: "target"), .target)
    }

    func testUnknownTypeDefaultsToCone() {
        let element = DiagramElement(type: "unknown_type", x: 5, y: 5, label: "X")
        XCTAssertEqual(element.elementType, .cone)
    }

    // MARK: - Backward Compatibility

    func testExistingDrillElementsParseUnchanged() {
        let elements = [
            DiagramElement(type: "cone", x: 2, y: 2, label: "A"),
            DiagramElement(type: "player", x: 5, y: 5, label: "P1"),
            DiagramElement(type: "goal", x: 10, y: 20, label: "Goal"),
            DiagramElement(type: "ball", x: 3, y: 3, label: "Ball"),
            DiagramElement(type: "target", x: 8, y: 10, label: "T1")
        ]
        XCTAssertEqual(elements[0].elementType, .cone)
        XCTAssertEqual(elements[1].elementType, .player)
        XCTAssertEqual(elements[2].elementType, .goal)
        XCTAssertEqual(elements[3].elementType, .ball)
        XCTAssertEqual(elements[4].elementType, .target)
    }

    func testNewElementTypesGenerateUniqueIds() {
        let wall = DiagramElement(type: "wall", x: 10, y: 0, label: "W1")
        let defender = DiagramElement(type: "defender", x: 8, y: 12, label: "D1")
        XCTAssertNotEqual(wall.id, defender.id)
        XCTAssertTrue(wall.id.contains("wall"))
        XCTAssertTrue(defender.id.contains("defender"))
    }
}
