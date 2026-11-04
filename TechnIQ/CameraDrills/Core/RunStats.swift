import Foundation

/// One counted touch, as the stats see it.
struct TouchRecord: Equatable, Codable {
    var time: Double
    var part: TouchPart
    var side: BodySide?
    /// The ball's sideways position at the touch, metres from the player's centre line. Positive = the
    /// player's own left (frames are unmirrored, so that's the right of the image).
    var offset: Double?
    /// Highest the ball went before the next touch (or the end of the run), metres above the floor.
    var apex: Double?
}

/// What one run was like: counts, splits, heights, tempo, drift, and how it ended. Pure; built by
/// `RunRecorder` from the frames and counter events the session already has.
struct RunStats: Equatable, Codable {
    var count: Int
    var endReason: RunEndReason?
    var touches: [TouchRecord]

    init(count: Int, endReason: RunEndReason?, touches: [TouchRecord]) {
        self.count = count
        self.endReason = endReason
        self.touches = touches
    }

    /// First touch to last touch (s).
    var duration: Double { (touches.last?.time ?? 0) - (touches.first?.time ?? 0) }

    var touchesPerMinute: Double? {
        guard touches.count >= 3, duration > 0 else { return nil }
        return Double(touches.count - 1) / duration * 60
    }

    var leftFoot: Int { touches.filter { $0.part == .foot && $0.side == .left }.count }
    var rightFoot: Int { touches.filter { $0.part == .foot && $0.side == .right }.count }
    /// Touches the camera couldn't attribute (hidden from the detector); counted, benefit of the doubt.
    var ambiguous: Int { touches.filter { $0.part == .unknown }.count }

    /// Typical (median) height after a left / right foot touch (m): one bad detection can't skew it.
    var apexLeft: Double? { Self.median(footApexes(.left)) }
    var apexRight: Double? { Self.median(footApexes(.right)) }
    /// How much the height after each touch varies (m): interquartile range, robust to odd readings.
    var apexSpread: Double? { Self.interquartileRange(touches.compactMap(\.apex)) }
    /// Mean sideways position of the touches (m, + = the player's left).
    var drift: Double? { Self.mean(touches.compactMap(\.offset)) }

    private func footApexes(_ side: BodySide) -> [Double] {
        touches.filter { $0.part == .foot && $0.side == side }.compactMap(\.apex)
    }

    // MARK: - Words

    /// Why the run ended, said plainly.
    var endLine: String {
        switch endReason {
        case .ground?: return "Ended: the ball hit the ground"
        case .handball?: return "Ended: hands touched it"
        case .wrongFoot?: return "Ended: wrong foot"
        case .thighTouch?: return "Ended: thigh touch (feet only)"
        case .chestTouch?: return "Ended: chest touch (feet only)"
        case .headTouch?: return "Ended: header (feet only)"
        case .tooHigh?: return "Ended: ball went too high"
        case .lostBall?: return "Ended: the camera lost the ball"
        case .stopped?, nil: return "Stopped"
        }
    }

    /// Things the player can't see for themselves, only when the numbers clearly say so.
    var insights: [String] {
        var lines: [String] = []
        let left = footApexes(.left), right = footApexes(.right)
        if left.count >= 3, right.count >= 3, let l = Self.median(left), let r = Self.median(right), min(l, r) > 0 {
            let ratio = max(l, r) / min(l, r) - 1
            if ratio >= 0.25 {
                let percent = Int((ratio * 100 / 5).rounded()) * 5
                lines.append(r > l ? "Right foot sends it \(percent)% higher than your left"
                                   : "Left foot sends it \(percent)% higher than your right")
            }
        }
        let feet = leftFoot + rightFoot
        if feet >= 6 {
            let leftShare = Double(leftFoot) / Double(feet)
            if leftShare <= 0.3 { lines.append("Left foot: \(Int((leftShare * 100).rounded()))% of touches") }
            if leftShare >= 0.7 { lines.append("Right foot: \(Int(((1 - leftShare) * 100).rounded()))% of touches") }
        }
        if touches.count >= 6, let drift, abs(drift) >= 0.3 {
            lines.append(String(format: "Drifting %.1f m to your %@", abs(drift), drift > 0 ? "left" : "right"))
        }
        if touches.count >= 6, let spread = apexSpread, spread >= 0.35 {
            lines.append("Heights vary a lot: aim for the same height every touch")
        }
        if touches.count >= 8, let tpm = touchesPerMinute {
            lines.append("\(Int(tpm.rounded())) touches a minute")
        }
        return lines
    }

    /// How runs usually end across a session, once there are a few to go on.
    static func sessionLine(_ runs: [RunStats]) -> String? {
        let ended = runs.compactMap(\.endReason).filter { $0 != .stopped }
        guard ended.count >= 2 else { return nil }
        let counts = Dictionary(grouping: ended, by: { $0 }).mapValues(\.count)
        guard let (reason, n) = counts.max(by: { $0.value < $1.value }), n >= 2 else { return nil }
        let how: String
        switch reason {
        case .ground: how = "with the ball hitting the ground"
        case .handball: how = "on a handball"
        case .wrongFoot: how = "on the wrong foot"
        case .thighTouch, .chestTouch, .headTouch: how = "on a touch that wasn't a foot"
        case .tooHigh: how = "with the ball going too high"
        case .lostBall: how = "when the camera lost the ball"
        case .stopped: return nil
        }
        return "\(n) of \(ended.count) runs ended \(how)"
    }

    // MARK: - Maths

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func median(_ values: [Double]) -> Double? {
        quantile(values, 0.5)
    }

    private static func interquartileRange(_ values: [Double]) -> Double? {
        guard values.count >= 4, let q1 = quantile(values, 0.25), let q3 = quantile(values, 0.75) else { return nil }
        return q3 - q1
    }

    private static func quantile(_ values: [Double], _ q: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = q * Double(sorted.count - 1)
        let lower = Int(position), upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
}

/// Follows a session's frames and counter events and hands back each finished run's `RunStats`.
final class RunRecorder {
    struct Config {
        /// Size-5 ball radius (m), the ruler.
        var ballRadius = 0.11
        /// Ankle joint height above the floor (m).
        var ankleHeight = 0.08
        /// Window (s) over which the lowest ankle defines the floor.
        var floorWindow = 2.0
    }

    private struct Sighting {
        var time: Double
        var ball: BallSighting
        var pose: BodyPose?
    }

    let config: Config
    private var touches: [TouchRecord] = []
    private var recent: [Sighting] = []
    private var ankles: [(time: Double, y: Double)] = []
    /// Highest sighting since the last touch.
    private var apex: Sighting?

    init(config: Config = Config()) {
        self.config = config
    }

    /// Feed every frame with the events the counter produced for it; returns the runs that ended.
    func record(_ frame: DrillFrame, events: [DrillEvent]) -> [RunStats] {
        if let lowest = [frame.pose?[.leftAnkle], frame.pose?[.rightAnkle]].compactMap({ $0?.y }).min() {
            ankles.append((frame.time, lowest))
        }
        ankles.removeAll { frame.time - $0.time > config.floorWindow }

        var finished: [RunStats] = []
        for event in events {
            switch event {
            case let .touch(_, part, time, side):
                closeApex()
                let at = recent.min { abs($0.time - time) < abs($1.time - time) }
                touches.append(TouchRecord(time: time, part: part, side: side, offset: at.flatMap(offset), apex: nil))
            case let .runEnded(count, reason, _):
                closeApex()
                if count > 0 { finished.append(RunStats(count: count, endReason: reason, touches: touches)) }
                touches = []
            }
        }

        if let ball = frame.ball {
            let sighting = Sighting(time: frame.time, ball: ball, pose: frame.pose)
            recent.append(sighting)
            recent.removeAll { frame.time - $0.time > 1 }
            if !touches.isEmpty, apex.map({ ball.center.y > $0.ball.center.y }) ?? true { apex = sighting }
        }
        return finished
    }

    /// Writes the highest point since the last touch onto that touch.
    private func closeApex() {
        defer { apex = nil }
        guard let apex, !touches.isEmpty, let lowestAnkle = ankles.map(\.y).min() else { return }
        let unitsPerMetre = apex.ball.radius / config.ballRadius
        guard unitsPerMetre > 0 else { return }
        let floor = lowestAnkle - config.ankleHeight * unitsPerMetre
        touches[touches.count - 1].apex = (apex.ball.center.y - floor) / unitsPerMetre
    }

    /// Ball's distance from the player's centre line (mid-hips), metres, + = the player's left.
    private func offset(_ sighting: Sighting) -> Double? {
        guard let pose = sighting.pose, let l = pose[.leftHip], let r = pose[.rightHip] else { return nil }
        let unitsPerMetre = sighting.ball.radius / config.ballRadius
        guard unitsPerMetre > 0 else { return nil }
        return (sighting.ball.center.x - (l.x + r.x) / 2) / unitsPerMetre
    }
}
