import XCTest
@testable import JuggleCore

final class ShotAnalyzerTests: XCTestCase {
    private typealias Scene = ShotScene

    private func analyze(_ spot: ShotSpot, _ frames: [DrillFrame]) -> ShotResult? {
        let goal = GoalPose(corners: Scene.corners(spot: spot), camera: Scene.camera)!
        return ShotAnalyzer(camera: Scene.camera, goal: goal, spot: spot).analyze(frames)
    }

    private func assertMatches(
        _ result: ShotResult?, _ truth: ShotScene.Truth, speedTolerance: Double = 0.03,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let result else { return XCTFail("no result", file: file, line: line) }
        XCTAssertEqual(result.averageSpeed, truth.averageSpeed, accuracy: truth.averageSpeed * speedTolerance, file: file, line: line)
        XCTAssertEqual(result.flightTime, truth.flightTime, accuracy: truth.flightTime * speedTolerance, file: file, line: line)
        XCTAssertEqual(result.crossing.x, truth.crossing.x, accuracy: 0.25, file: file, line: line)
        XCTAssertEqual(result.crossing.y, truth.crossing.y, accuracy: 0.2, file: file, line: line)
    }

    // MARK: - Geometry

    func testGoalPoseRecoversTheGoalFromItsCorners() throws {
        let goal = try XCTUnwrap(GoalPose(corners: Scene.corners(spot: .penalty), camera: Scene.camera))
        let basis = Scene.basis(Scene.Rig(), spot: .penalty)
        let topRight = basis.toCamera(Vec3(x: 3.66, y: 2.44, z: 11))

        XCTAssertEqual((goal.point(u: 7.32, v: 2.44) - topRight).length, 0, accuracy: 0.01)
        XCTAssertEqual(goal.distanceInFront(of: basis.toCamera(Vec3(x: 0, y: 0.11, z: 0))), 11, accuracy: 0.01)
    }

    func testFocalLengthIsRecoveredFromTheBallOnItsSpot() throws {
        let basis = Scene.basis(Scene.Rig(), spot: .penalty)
        let resting = Scene.ballSighting(Vec3(x: 0, y: 0.11, z: 0), basis)
        let focal = try XCTUnwrap(ShotGeometry.estimateFocal(
            corners: Scene.corners(spot: .penalty), aspect: Scene.aspect, restingBall: resting, spot: .penalty
        ))

        XCTAssertEqual(focal, Scene.camera.focal, accuracy: Scene.camera.focal * 0.02)
    }

    // MARK: - Shots

    func testAPenaltyIntoTheTopRightCorner() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 7.2, y: 7.0, z: 26))
        let result = analyze(.penalty, frames)

        assertMatches(result, truth)
        XCTAssertEqual(result?.placement, .onTarget(column: 2, row: 2))
    }

    func testALowShotFromTheEdgeOfTheBox() {
        let (frames, truth) = Scene.shot(spot: .edgeOfBox, velocity: Vec3(x: -3.4, y: 4.9, z: 22))
        let result = analyze(.edgeOfBox, frames)

        assertMatches(result, truth)
        XCTAssertEqual(result?.placement, .onTarget(column: 0, row: 0))
    }

    func testASlowShotDownTheMiddle() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 0, y: 4.6, z: 15))
        let result = analyze(.penalty, frames)

        assertMatches(result, truth)
        XCTAssertEqual(result?.placement, .onTarget(column: 1, row: 0))
    }

    func testAShotWideOfTheRightPost() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 11, y: 5, z: 25))
        let result = analyze(.penalty, frames)

        assertMatches(result, truth)
        XCTAssertEqual(result?.placement, .wideRight)
    }

    func testAShotOverTheBar() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 1, y: 9.5, z: 24))
        let result = analyze(.penalty, frames)

        assertMatches(result, truth)
        XCTAssertEqual(result?.placement, .over)
    }

    func testOneHundredTwentyFramesASecondStillWorks() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 7.2, y: 7.0, z: 26), fps: 120)
        assertMatches(analyze(.penalty, frames), truth)
    }

    func testRealAirIsNotExactlyTheModelsAir() {
        let (frames, truth) = Scene.shot(spot: .penalty, velocity: Vec3(x: 7.2, y: 7.0, z: 26), drag: 0.010)
        assertMatches(analyze(.penalty, frames), truth, speedTolerance: 0.05)
    }

    func testNearlyEveryNoisyShotLandsWithinFivePercent() {
        let shots: [(ShotSpot, Vec3)] = [
            (.penalty, Vec3(x: 7.2, y: 7.0, z: 26)), (.edgeOfBox, Vec3(x: -3.4, y: 4.9, z: 22)),
            (.penalty, Vec3(x: 0, y: 4.6, z: 15)), (.penalty, Vec3(x: -5, y: 4, z: 30))
        ]
        var within = 0, total = 0
        for (spot, velocity) in shots {
            for seed in 1...10 {
                let (frames, truth) = Scene.shot(spot: spot, velocity: velocity, seed: UInt64(seed))
                total += 1
                if let result = analyze(spot, frames), abs(result.averageSpeed / truth.averageSpeed - 1) <= 0.05 { within += 1 }
            }
        }
        XCTAssertGreaterThanOrEqual(Double(within) / Double(total), 0.95, "\(within)/\(total)")
    }

    func testABallThatIsNeverKickedIsNoShot() {
        let basis = Scene.basis(Scene.Rig(), spot: .penalty)
        let ball = Scene.ballSighting(Vec3(x: 0, y: 0.11, z: 0), basis)
        let frames = (0..<240).map { DrillFrame(time: Double($0) / 240, ball: ball) }

        XCTAssertNil(analyze(.penalty, frames))
    }

    func testKilometresPerHour() {
        let result = ShotResult(
            kickTime: 0, flightTime: 0.5, distance: 12.5, averageSpeed: 25,
            crossing: DrillPoint(x: 1, y: 1), placement: .onTarget(column: 0, row: 1)
        )
        XCTAssertEqual(result.kilometresPerHour, 90, accuracy: 1e-9)
    }
}
