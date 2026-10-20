@testable import JuggleCore

/// Builds synthetic juggling footage as DrillFrames: a standing player and a ball on ballistic arcs.
/// Units follow CameraDrillTypes: y up, image-height units. Ball radius 0.03 ⇒ 0.27 units per metre.
enum SyntheticScene {
    static let fps = 30.0
    static let ballRadius = 0.03
    static let unitsPerMetre = ballRadius / 0.11
    static let gravity = 9.81 * unitsPerMetre

    /// Player standing at x = 0.30, right foot raised for a touch.
    static let pose = BodyPose(joints: [
        .nose: DrillPoint(x: 0.30, y: 0.53),
        .leftShoulder: DrillPoint(x: 0.26, y: 0.47), .rightShoulder: DrillPoint(x: 0.34, y: 0.47),
        .leftElbow: DrillPoint(x: 0.22, y: 0.40), .rightElbow: DrillPoint(x: 0.38, y: 0.40),
        .leftWrist: DrillPoint(x: 0.21, y: 0.33), .rightWrist: DrillPoint(x: 0.39, y: 0.33),
        .leftHip: DrillPoint(x: 0.28, y: 0.33), .rightHip: DrillPoint(x: 0.32, y: 0.33),
        .leftKnee: DrillPoint(x: 0.28, y: 0.22), .rightKnee: DrillPoint(x: 0.34, y: 0.25),
        .leftAnkle: DrillPoint(x: 0.28, y: 0.10), .rightAnkle: DrillPoint(x: 0.36, y: 0.15),
    ])

    /// Ball-centre heights for a touch on each part (x = 0.36 unless overridden).
    static let footContact = DrillPoint(x: 0.37, y: 0.17)
    static let thighContact = DrillPoint(x: 0.36, y: 0.30)
    static let headContact = DrillPoint(x: 0.30, y: 0.57)
    static let wristContact = DrillPoint(x: 0.40, y: 0.31)
    /// Ball resting on the floor: ground ≈ ankle baseline 0.10 − 0.08 m.
    static let groundContact = DrillPoint(x: 0.42, y: 0.10 - 0.08 * unitsPerMetre + ballRadius)

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
