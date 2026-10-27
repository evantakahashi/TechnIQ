import XCTest
import Combine
import AVFoundation
import CoreData
@testable import TechnIQ

/// The camera-drill session end to end, minus the camera: scripted DrillFrames (SyntheticScene) go
/// through `ingest` → HandsFreeFlow → JuggleCounter → CameraRunService, and we check what the player
/// would see and what gets saved.
@MainActor
final class CameraDrillSessionTests: XCTestCase {
    private typealias Scene = SyntheticScene

    private final class NoSource: DrillFrameSource {
        let queue = DispatchQueue(label: "test")
        let orientation = CGImagePropertyOrientation.up
        let aspect = CameraCapture.aspect
        var previewSession: AVCaptureSession? { nil }
        func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CameraCapture.CaptureError?) -> Void) {}
        func stop() {}
    }

    private var stack: TestCoreDataStack!
    private var defaults: UserDefaults!
    private var player: Player!
    private var sut: CameraDrillSession!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        defaults = UserDefaults(suiteName: "CameraDrillSessionTests")
        defaults.removePersistentDomain(forName: "CameraDrillSessionTests")
        player = stack.makePlayer(xp: 0, coins: 0)
        let service = CameraRunService(context: stack.context, defaults: defaults,
                                       coins: CoinService(coreDataManager: stack))
        sut = CameraDrillSession(drill: .juggling, player: player, source: NoSource(), runService: service)
        sut.voiceOn = false
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "CameraDrillSessionTests")
        sut = nil
        player = nil
        stack = nil
        super.tearDown()
    }

    // MARK: Helpers

    /// Standing in the outline holding the ball, through the 1 s hold and 3-2-1 into the live run.
    private func stepInAndCountDown(_ b: inout Scene.Builder) {
        b.pose = Scene.pose
        b.hold(Scene.at(0.37, 0.35), seconds: 4.3)
    }

    /// Drop onto the foot, `touches` juggles, then the ball lands and rests.
    private func juggle(_ b: inout Scene.Builder, touches: Int, endOnGround: Bool = true) {
        b.fall(from: Scene.at(0.37, 0.35), to: Scene.footContact)
        for i in 0..<touches {
            let last = i == touches - 1 && endOnGround
            b.pop(from: Scene.footContact, height: 0.20 * Scene.scale, to: last ? Scene.groundContact : Scene.footContact)
        }
        if endOnGround { b.hold(Scene.groundContact, seconds: 0.5) }
    }

    private func feed(_ frames: [DrillFrame]) {
        for frame in frames { sut.ingest(frame) }
        drainMain()
    }

    /// The session publishes on the main queue; let it catch up.
    private func drainMain() {
        let done = expectation(description: "main queue")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    private func savedRuns() throws -> [CameraRun] {
        let request: NSFetchRequest<CameraRun> = CameraRun.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try stack.context.fetch(request)
    }

    // MARK: Tests

    func test_standingInTheOutline_countsDownThenGoesLive() {
        var b = Scene.Builder()
        b.pose = Scene.pose
        b.hold(Scene.at(0.37, 0.35), seconds: 1.5)
        feed(b.frames)
        XCTAssertEqual(sut.phase, .countdown(3))

        b = Scene.Builder()
        b.time = 1.5
        b.hold(Scene.at(0.37, 0.35), seconds: 3.0)
        feed(b.frames)
        XCTAssertEqual(sut.phase, .live)
    }

    func test_nobodyInFrame_staysPositioning() {
        var b = Scene.Builder()
        b.pose = nil
        b.hold(Scene.at(0.37, 0.35), seconds: 5)
        feed(b.frames)

        XCTAssertEqual(sut.phase, .positioning)
        XCTAssertFalse(sut.inPosition)
    }

    func test_standingTooFarAway_asksThePlayerToStepCloser() {
        // The old 4 m setup: whole body in frame but small.
        var far = BodyPose(joints: [:])
        for (joint, p) in Scene.pose.joints {
            far.joints[joint] = DrillPoint(x: 0.30 + (p.x - 0.30) / Scene.scale, y: 0.10 + (p.y - 0.10) / Scene.scale)
        }
        var b = Scene.Builder()
        b.pose = far
        b.hold(Scene.at(0.37, 0.35), seconds: 5)
        feed(b.frames)

        XCTAssertEqual(sut.phase, .positioning)
        XCTAssertTrue(sut.tooFar)
    }

    func test_aRunEndingOnTheGround_showsTheResult_andSavesTheRun() throws {
        var b = Scene.Builder()
        stepInAndCountDown(&b)
        juggle(&b, touches: 6)
        feed(b.frames)

        XCTAssertEqual(sut.phase, .result)
        XCTAssertEqual(sut.lastResult?.count, 6)
        XCTAssertEqual(sut.lastResult?.isPersonalBest, true)
        XCTAssertEqual(sut.lastResult?.xp, 30)
        let runs = try savedRuns()
        XCTAssertEqual(runs.map(\.count), [6])
        XCTAssertEqual(runs.first?.drill, CameraDrill.juggling.rawValue)
        XCTAssertEqual(player.totalXP, 30)
    }

    func test_touchesDuringTheCountdown_dontCount() throws {
        // Juggling straight away, before "go": the counter only starts when the run goes live.
        var b = Scene.Builder()
        b.pose = Scene.pose
        b.hold(Scene.at(0.37, 0.35), seconds: 1.2)
        juggle(&b, touches: 3, endOnGround: false)
        b.hold(Scene.at(0.37, 0.35), seconds: 3.0)  // caught; countdown runs out
        juggle(&b, touches: 4)
        feed(b.frames)

        XCTAssertEqual(sut.lastResult?.count, 4)
    }

    func test_stayingInTheOutline_goesAgain_andSavesBothRuns() throws {
        var b = Scene.Builder()
        stepInAndCountDown(&b)
        juggle(&b, touches: 5)
        b.hold(Scene.at(0.37, 0.35), seconds: 4.0 + 1.5 + 3.3)  // result, go-again hold, 3-2-1
        juggle(&b, touches: 8)
        feed(b.frames)

        XCTAssertEqual(sut.runs.map(\.count), [5, 8])
        XCTAssertEqual(sut.runs.map(\.isPersonalBest), [true, true])
        XCTAssertEqual(try savedRuns().map(\.count), [5, 8])
    }

    func test_done_duringALiveRun_savesItAndFinishes() throws {
        var b = Scene.Builder()
        stepInAndCountDown(&b)
        juggle(&b, touches: 4, endOnGround: false)
        feed(b.frames)
        XCTAssertEqual(sut.phase, .live)

        sut.endSession()
        let finished = expectation(description: "finished")
        let observer = sut.$phase.first { $0 == .finished }.sink { _ in finished.fulfill() }
        wait(for: [finished], timeout: 2)
        observer.cancel()
        drainMain()

        XCTAssertEqual(try savedRuns().map(\.count), [4])
    }

    func test_bothArmsUp_finishesTheSession() {
        var arms = Scene.pose
        arms.joints[.leftWrist] = Scene.at(0.22, 0.62)
        arms.joints[.rightWrist] = Scene.at(0.38, 0.62)
        var b = Scene.Builder()
        b.pose = arms
        b.gap(seconds: 1.0)
        feed(b.frames)

        XCTAssertEqual(sut.phase, .finished)
    }
}
