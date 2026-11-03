import Foundation

/// Counts wall passes: the player faces the phone with a wall to one side and passes against it. A pass
/// counts when the ball leaves the feet, goes away (out of frame, or far off), and comes back to the feet
/// within `missTimeout`; a miss that has to be fetched doesn't. The session's clock ends the run (`finish`).
final class WallPassCounter: DrillCounter {
    struct Config {
        /// Ball centre within this (m) of an ankle = at the feet.
        var near = 0.35
        /// Ball this far (m) from both ankles = on its way to the wall.
        var far = 1.0
        /// Ball unseen this long (s) after leaving the feet = gone to the wall.
        var goneAfter = 0.15
        /// Away this long (s) without coming back = a miss.
        var missTimeout = 4.0
        /// Size-5 ball radius (m), the ruler.
        var ballRadius = 0.11
    }

    private enum State {
        case idle
        case atFeet
        case leaving(lastSeen: Double)
        case away(since: Double)
    }

    let config: Config
    private(set) var count = 0
    private var state = State.idle
    private var isRunning = false
    private var lastSeen = 0.0

    init(config: Config = Config()) {
        self.config = config
    }

    func process(_ frame: DrillFrame) -> [DrillEvent] {
        let distance = feetDistance(frame)
        switch state {
        case .idle:
            if let distance, distance <= config.near { state = .atFeet }
        case .atFeet:
            if let distance, distance > config.near { state = .leaving(lastSeen: frame.time) }
        case let .leaving(seen):
            if let distance {
                if distance <= config.near {
                    state = .atFeet
                } else if distance >= config.far {
                    state = .away(since: frame.time)
                } else {
                    state = .leaving(lastSeen: frame.time)
                }
            } else if frame.time - seen >= config.goneAfter {
                state = .away(since: frame.time)
            }
        case let .away(since):
            if frame.time - since > config.missTimeout {
                state = .idle
            } else if let distance, distance <= config.near {
                state = .atFeet
                isRunning = true
                count += 1
                return [.touch(count: count, part: .foot, time: frame.time)]
            }
        }
        return []
    }

    func finish(at time: Double) -> [DrillEvent] {
        guard isRunning else { return [] }
        isRunning = false
        return [.runEnded(count: count, reason: .stopped, time: time)]
    }

    /// Ball centre to the nearer ankle (m), nil without a ball or ankles.
    private func feetDistance(_ frame: DrillFrame) -> Double? {
        guard let ball = frame.ball, let pose = frame.pose else { return nil }
        let metre = ball.radius / config.ballRadius
        return [pose[.leftAnkle], pose[.rightAnkle]].compactMap { $0?.distance(to: ball.center) }.min().map { $0 / metre }
    }
}
