// Shared with TechnIQTests (symlinked) for the session tests.
#if canImport(JuggleCore)
@testable import JuggleCore
#else
@testable import TechnIQ
#endif

/// Builds synthetic juggling footage as DrillFrames: a standing player and a ball on ballistic arcs.
/// Units follow CameraDrillTypes: y up, image-height units. Drawn for a player ~2.5 m away (nose to
/// ankle ≈ 56% of the frame, HandsFreeFlow's in-position distance): points are authored at the old
/// 4 m scale and enlarged by `scale` about the standing foot.
enum SyntheticScene {
    static let fps = 30.0
    static let scale = 1.3
    static let ballRadius = 0.03 * scale

    /// An authored point placed at the scene's scale.
    static func at(_ x: Double, _ y: Double) -> DrillPoint {
        DrillPoint(x: 0.30 + (x - 0.30) * scale, y: 0.10 + (y - 0.10) * scale)
    }
    static let unitsPerMetre = ballRadius / 0.11
    static let gravity = 9.81 * unitsPerMetre

    /// Player standing at x = 0.30, right foot raised for a touch.
    static let pose = BodyPose(joints: [
        .nose: at(0.30, 0.53),
        .leftShoulder: at(0.26, 0.47), .rightShoulder: at(0.34, 0.47),
        .leftElbow: at(0.22, 0.40), .rightElbow: at(0.38, 0.40),
        .leftWrist: at(0.21, 0.33), .rightWrist: at(0.39, 0.33),
        .leftHip: at(0.28, 0.33), .rightHip: at(0.32, 0.33),
        .leftKnee: at(0.28, 0.22), .rightKnee: at(0.34, 0.25),
        .leftAnkle: at(0.28, 0.10), .rightAnkle: at(0.36, 0.15)
    ])

    /// Ball-centre heights for a touch on each part (x = 0.36 unless overridden).
    static let footContact = at(0.37, 0.17)
    static let thighContact = at(0.36, 0.30)
    static let headContact = at(0.30, 0.57)
    static let wristContact = at(0.40, 0.31)
    /// Ball resting on the floor: ground ≈ ankle baseline 0.10 − 0.08 m.
    static let groundContact = DrillPoint(x: at(0.42, 0).x, y: 0.10 - 0.08 * unitsPerMetre + ballRadius)

    struct Builder {
        private(set) var frames: [DrillFrame] = []
        var time = 0.0
        var pose: BodyPose? = SyntheticScene.pose
        var noise: (Int) -> Double = { _ in 0 }

        /// Ball dropped from `from` falling until it reaches `to` (inclusive), then the caller adds the next leg.
        mutating func fall(from: DrillPoint, to: DrillPoint) {
            let drop = from.y - to.y
            let duration = (2 * drop / SyntheticScene.gravity).squareRoot()
            arc(from: from, to: to, vy0: 0, duration: duration)
        }

        /// Ball launched from `from` rising `height` units and landing at `to`.
        mutating func pop(from: DrillPoint, height: Double, to: DrillPoint) {
            let g = SyntheticScene.gravity
            let vy0 = (2 * g * height).squareRoot()
            let apex = from.y + height
            let duration = vy0 / g + (2 * (apex - to.y) / g).squareRoot()
            arc(from: from, to: to, vy0: vy0, duration: duration)
        }

        /// Frames with no ball (detector lost it).
        mutating func gap(seconds: Double) {
            let n = Int((seconds * SyntheticScene.fps).rounded())
            for _ in 0..<n { append(ball: nil) }
        }

        mutating func hold(_ point: DrillPoint, seconds: Double) {
            let n = Int((seconds * SyntheticScene.fps).rounded())
            for _ in 0..<n { append(ball: point) }
        }

        private mutating func arc(from: DrillPoint, to: DrillPoint, vy0: Double, duration: Double) {
            let g = SyntheticScene.gravity
            let steps = max(1, Int((duration * SyntheticScene.fps).rounded()))
            for i in 1...steps {
                let t = duration * Double(i) / Double(steps)
                let x = from.x + (to.x - from.x) * Double(i) / Double(steps)
                let y = from.y + vy0 * t - 0.5 * g * t * t
                append(ball: DrillPoint(x: x, y: i == steps ? to.y : y))
            }
        }

        private mutating func append(ball: DrillPoint?) {
            let jitter = noise(frames.count)
            let sighting = ball.map {
                BallSighting(center: DrillPoint(x: $0.x, y: $0.y + jitter), radius: SyntheticScene.ballRadius)
            }
            frames.append(DrillFrame(time: time, ball: sighting, pose: pose))
            time += 1 / SyntheticScene.fps
        }
    }

    /// Feeds frames through a fresh counter and returns every event.
    static func run(_ frames: [DrillFrame], counter: JuggleCounter = JuggleCounter()) -> [DrillEvent] {
        frames.flatMap { counter.process($0) } + counter.finish(at: frames.last?.time ?? 0)
    }
}

extension Array where Element == DrillEvent {
    var touches: [(count: Int, part: TouchPart)] {
        compactMap { if case let .touch(count, part, _) = $0 { return (count, part) } else { return nil } }
    }

    var runEnds: [(count: Int, reason: RunEndReason)] {
        compactMap { if case let .runEnded(count, reason, _) = $0 { return (count, reason) } else { return nil } }
    }
}
