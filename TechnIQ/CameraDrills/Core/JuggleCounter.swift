import Foundation

/// Counts juggling touches from a stream of analysed frames.
///
/// The ball's height is followed as a zig-zag: a low point is confirmed once the ball climbs back
/// `reversal` above it (or stalls there), and each confirmed low point after a real drop is a contact.
/// The contact is classified against the player's pose: legs/chest/head count, an arm ends the run as
/// handball, and a contact at floor level ends it as ground. A run starts on its first legal touch.
/// Unconfirmed contacts never count — the counter would rather miss a touch than invent one.
final class JuggleCounter: DrillCounter {
    struct Config {
        /// Rise (m) above a low point that confirms it — must clear detector jitter.
        var reversal = 0.06
        /// Minimum drop (m) into a low point for it to be a contact rather than wobble.
        var minDrop = 0.10
        /// Ball held still this long (s) at a low point confirms it (a catch, or a ball at rest).
        var stall = 0.25
        /// Ankle joint height above the floor (m).
        var ankleHeight = 0.08
        /// Ball bottom within this of the floor (m) is a ground contact.
        var groundTolerance = 0.05
        /// Contact reach (m) beyond a body part's own thickness.
        var reach = 0.10
        /// No ball for this long (s) mid-run ends the run.
        var lostBall = 1.0
        /// Window (s) over which the lowest ankle defines the floor.
        var floorWindow = 2.0
        /// Ball radius used as the ruler (size 5 ≈ 0.11 m).
        var ballRadius = 0.11
    }

    private struct Sample {
        var time: Double
        var center: DrillPoint
        var radius: Double
        var pose: BodyPose?
    }

    private enum Phase {
        case seekingLow(low: Sample, high: Double)
        case seekingHigh(high: Double)
    }

    let config: Config
    private(set) var count = 0
    private(set) var isRunning = false

    private var phase: Phase?
    private var lastSightingTime: Double?
    private var radius: Double?
    private var ankleHistory: [(time: Double, y: Double)] = []

    init(config: Config = Config()) {
        self.config = config
    }

    func process(_ frame: DrillFrame) -> [DrillEvent] {
        trackFloor(frame)
        guard let ball = frame.ball else {
            if isRunning, let last = lastSightingTime, frame.time - last > config.lostBall {
                return [endRun(.lostBall, at: frame.time)]
            }
            return []
        }
        lastSightingTime = frame.time
        radius = radius.map { $0 * 0.8 + ball.radius * 0.2 } ?? ball.radius
        let sample = Sample(time: frame.time, center: ball.center, radius: ball.radius, pose: frame.pose)
        var events: [DrillEvent] = []

        if isRunning, isOnFloor(sample) {
            events.append(endRun(.ground, at: frame.time))
        }

        switch phase {
        case nil:
            phase = .seekingLow(low: sample, high: sample.center.y)
        case let .seekingLow(low, high):
            if sample.center.y < low.center.y {
                phase = .seekingLow(low: sample, high: high)
            } else if sample.center.y - low.center.y >= metres(config.reversal)
                        || sample.time - low.time >= config.stall {
                phase = .seekingHigh(high: sample.center.y)
                events += contact(at: low, drop: high - low.center.y)
            }
        case let .seekingHigh(high):
            if sample.center.y > high {
                phase = .seekingHigh(high: sample.center.y)
            } else if high - sample.center.y >= metres(config.reversal) {
                phase = .seekingLow(low: sample, high: high)
            }
        }
        return events
    }

    /// Ends an open run (footage over, or the player stopped the session).
    func finish(at time: Double) -> [DrillEvent] {
        isRunning ? [endRun(.stopped, at: time)] : []
    }

    // MARK: - Contacts

    private func contact(at sample: Sample, drop: Double) -> [DrillEvent] {
        guard drop >= metres(config.minDrop) else { return [] }
        if isOnFloor(sample) {
            return isRunning ? [endRun(.ground, at: sample.time)] : []
        }
        let part = classify(sample)
        if part == .arm {
            return isRunning ? [endRun(.handball, at: sample.time)] : []
        }
        if !isRunning {
            isRunning = true
            count = 0
        }
        count += 1
        return [.touch(count: count, part: part, time: sample.time)]
    }

    private func endRun(_ reason: RunEndReason, at time: Double) -> DrillEvent {
        isRunning = false
        return .runEnded(count: count, reason: reason, time: time)
    }

    /// Nearest body part to the ball, or `.unknown` if there is no pose or nothing within reach.
    private func classify(_ sample: Sample) -> TouchPart {
        guard let pose = sample.pose else { return .unknown }
        let ball = sample.center
        var best: (part: TouchPart, gap: Double)?

        func consider(_ part: TouchPart, thickness: Double, _ distance: Double?) {
            guard let distance else { return }
            let gap = distance - metres(thickness)
            if best == nil || gap < best!.gap { best = (part, gap) }
        }
        func segment(_ a: BodyJoint, _ b: BodyJoint) -> Double? {
            guard let pa = pose[a], let pb = pose[b] else { return nil }
            return ball.distance(toSegment: pa, pb)
        }

        for (ankle, knee, hip) in [(BodyJoint.leftAnkle, BodyJoint.leftKnee, BodyJoint.leftHip),
                                   (.rightAnkle, .rightKnee, .rightHip)] {
            consider(.foot, thickness: 0.10, pose[ankle].map(ball.distance(to:)))
            consider(.foot, thickness: 0.05, segment(knee, ankle))
            consider(.thigh, thickness: 0.08, segment(hip, knee))
        }
        for (shoulder, elbow, wrist) in [(BodyJoint.leftShoulder, BodyJoint.leftElbow, BodyJoint.leftWrist),
                                         (.rightShoulder, .rightElbow, .rightWrist)] {
            consider(.arm, thickness: 0.05, segment(elbow, wrist))
            consider(.arm, thickness: 0.05, segment(shoulder, elbow))
        }
        if let ls = pose[.leftShoulder], let rs = pose[.rightShoulder],
           let lh = pose[.leftHip], let rh = pose[.rightHip] {
            let top = DrillPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let mid = DrillPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            let chestBottom = DrillPoint(x: (top.x + mid.x) / 2, y: (top.y + mid.y) / 2)
            consider(.chest, thickness: 0.12, ball.distance(toSegment: top, chestBottom))
        }
        consider(.head, thickness: 0.12, pose[.nose].map(ball.distance(to:)))

        guard let best, best.gap <= sample.radius + metres(config.reach) else { return .unknown }
        return best.part
    }

    // MARK: - Floor and scale

    private func trackFloor(_ frame: DrillFrame) {
        let ankles = [frame.pose?[.leftAnkle], frame.pose?[.rightAnkle]].compactMap { $0?.y }
        if let lowest = ankles.min() {
            ankleHistory.append((frame.time, lowest))
        }
        ankleHistory.removeAll { frame.time - $0.time > config.floorWindow }
    }

    /// Floor height, from the lowest ankle seen recently (the standing foot). Nil without a pose.
    private var floorY: Double? {
        ankleHistory.map(\.y).min().map { $0 - metres(config.ankleHeight) }
    }

    private func isOnFloor(_ sample: Sample) -> Bool {
        guard let floorY else { return false }
        return sample.center.y - sample.radius <= floorY + metres(config.groundTolerance)
    }

    /// Converts metres to frame units using the ball as the ruler.
    private func metres(_ m: Double) -> Double {
        m * (radius ?? 0.03) / config.ballRadius
    }
}
