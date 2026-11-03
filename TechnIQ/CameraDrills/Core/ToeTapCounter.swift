import Foundation

/// Counts toe taps: the ball rests on the ground and the player's soles take turns on top of it.
///
/// A tap starts when an ankle comes within `contact` of the top of the ball and ends when it lifts past
/// `release` (hysteresis, so a foot resting on the ball is one tap). Only a tap with the other foot from the
/// last one counts. The run starts on the first tap; the session's clock ends it (`finish`).
final class ToeTapCounter: DrillCounter {
    struct Config {
        /// Ankle within this (m) of the top of the ball = sole on the ball.
        var contact = 0.15
        /// Ankle beyond this (m) = foot back off the ball.
        var release = 0.22
        /// Size-5 ball radius (m), the ruler.
        var ballRadius = 0.11
    }

    let config: Config
    private(set) var count = 0
    private var isRunning = false
    private var onBall: BodySide?
    private var lastTap: BodySide?

    init(config: Config = Config()) {
        self.config = config
    }

    func process(_ frame: DrillFrame) -> [DrillEvent] {
        guard let ball = frame.ball, let pose = frame.pose else { return [] }
        let metre = ball.radius / config.ballRadius
        let top = DrillPoint(x: ball.center.x, y: ball.center.y + ball.radius)
        func gap(_ joint: BodyJoint) -> Double { pose[joint].map { $0.distance(to: top) / metre } ?? .infinity }
        let gaps: [(BodySide, Double)] = [(.left, gap(.leftAnkle)), (.right, gap(.rightAnkle))]

        if let side = onBall, gaps.first(where: { $0.0 == side })!.1 > config.release {
            onBall = nil
        }
        guard onBall == nil, let (side, distance) = gaps.min(by: { $0.1 < $1.1 }), distance <= config.contact else {
            return []
        }
        onBall = side
        guard side != lastTap else { return [] }
        lastTap = side
        isRunning = true
        count += 1
        return [.touch(count: count, part: .foot, time: frame.time, side: side)]
    }

    func finish(at time: Double) -> [DrillEvent] {
        guard isRunning else { return [] }
        isRunning = false
        return [.runEnded(count: count, reason: .stopped, time: time)]
    }
}
