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
        /// No ball and no player for this long (s) mid-run ends the run.
        var lostBall = 1.0
        /// No ball for this long (s) while the player is still in frame ends the run: the detector loses a
        /// ball against similar-coloured clothing for a second or two (seen on device), the player hasn't.
        var hiddenBall = 2.5
        /// Window (s) over which the lowest ankle defines the floor.
        var floorWindow = 2.0
        /// Ball radius used as the ruler (size 5 ≈ 0.11 m).
        var ballRadius = 0.11
        /// Juggling variants: which foot touches count.
        var footRule = FootRule.any
        /// A detector gap at least this long (s) can hide a touch.
        var hiddenTouchGap = 0.1
        /// Ball back this much (m) above where free fall would have taken it across a gap = it was touched
        /// while hidden (seen on device: the ball is lost below the knees, where every touch happens).
        var hiddenTouchRise = 0.25
        /// Gravity (m/s²), for the free-fall check.
        var gravity = 9.81
        /// A hidden contact is placed once this long (s) of rise has been seen, or three sightings.
        var settleTime = 0.15
        /// Judge: which body parts may touch, and how high the ball may go.
        var partRule = PartRule.any
        var heightLimit: HeightLimit?
        /// A rule is only called when the illegal body part is this much (m) closer to the ball than any legal
        /// one, and the touch was seen (not estimated across a detector gap): ambiguous evidence never ends a run.
        var callMargin = 0.08
        /// The ball must clear a height limit by this much (m) on `tooHighFrames` sightings in a row.
        var heightMargin = 0.05
        var tooHighFrames = 2
        /// A ball at floor level within this (m) of an ankle may be a low touch, not the ground (a phone on
        /// the floor sees a ball just in front of the feet as low as the floor): it's the ground only once
        /// it has stayed down `groundHold` seconds.
        var footClear = 0.25
        var groundHold = 0.4
    }

    enum PartRule: String, Codable {
        /// Any legal part (feet, thighs, chest, head).
        case any
        /// Feet only: a clear thigh / chest / head touch ends the run.
        case feetOnly
    }

    /// The ball must stay below this part of the body.
    enum HeightLimit: String, Codable {
        case knee, waist
    }

    enum FootRule: Equatable {
        /// Plain juggling: any legal part counts.
        case any
        /// Weak-foot juggling: only this foot counts; the other foot ends the run.
        case only(BodySide)
        /// Alternating juggling: feet must alternate; the same foot twice ends the run.
        case alternate
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
    private var lastFoot: BodySide?
    /// Sightings in a row above the height limit.
    private var aboveLimit = 0
    /// Latest sightings (≤ 0.3 s), for the ball's velocity going into a detector gap.
    private var recent: [Sample] = []
    /// When the ball last came down to floor level (nil while it's above it).
    private var floorSince: Double?

    /// A touch that happened out of the detector's sight, waiting for a few rising sightings so the contact
    /// point can be placed where the fall and the rise meet.
    private struct PendingContact {
        var high: Double
        var pre: [Sample]
        var post: [Sample]
        var hidden: Bool
    }
    private var pending: PendingContact?

    init(config: Config = Config()) {
        self.config = config
    }

    func process(_ frame: DrillFrame) -> [DrillEvent] {
        trackFloor(frame)
        guard let ball = frame.ball else {
            if let pending, let last = pending.post.last, frame.time - last.time > config.settleTime {
                let events = settle(pending)
                self.pending = nil
                return events
            }
            let timeout = frame.pose == nil ? config.lostBall : config.hiddenBall
            if isRunning, let last = lastSightingTime, frame.time - last > timeout {
                return [endRun(.lostBall, at: frame.time)]
            }
            return []
        }
        lastSightingTime = frame.time
        radius = radius.map { $0 * 0.8 + ball.radius * 0.2 } ?? ball.radius
        let sample = Sample(time: frame.time, center: ball.center, radius: ball.radius, pose: frame.pose)
        var events: [DrillEvent] = []

        events += advancePending(with: sample)

        floorSince = isOnFloor(sample) ? (floorSince ?? sample.time) : nil
        if isRunning, isGround(sample) {
            events.append(endRun(.ground, at: frame.time))
        }
        if isRunning, isTooHigh(sample) {
            events.append(endRun(.tooHigh, at: frame.time))
        }

        defer {
            recent.append(sample)
            recent.removeAll { sample.time - $0.time > 0.3 }
        }
        if wasTouchedWhileHidden(sample) {
            phase = .seekingHigh(high: sample.center.y)
            if let earlier = pending { events += settle(earlier) }
            pending = PendingContact(high: .infinity, pre: recent, post: [sample], hidden: true)
            recent.removeAll()
            return events
        }

        switch phase {
        case nil:
            phase = .seekingLow(low: sample, high: sample.center.y)
        case let .seekingLow(low, high):
            events += descend(low: low, high: high, sample: sample)
        case let .seekingHigh(high):
            if sample.center.y > high {
                phase = .seekingHigh(high: sample.center.y)
            } else if high - sample.center.y >= metres(config.reversal) {
                phase = .seekingLow(low: sample, high: high)
            }
        }
        return events
    }

    /// The ball is coming down: follow it to its low point, then count the contact once it rises again (or
    /// rests there).
    private func descend(low: Sample, high: Double, sample: Sample) -> [DrillEvent] {
        var events: [DrillEvent] = []
        if sample.center.y < low.center.y {
            phase = .seekingLow(low: sample, high: high)
        } else if sample.center.y - low.center.y >= metres(config.reversal) {
            phase = .seekingHigh(high: sample.center.y)
            if sample.time - low.time >= config.hiddenTouchGap {
                // The ball was out of sight around the contact: place it once the rise is clear.
                if let earlier = pending { events += settle(earlier) }
                pending = PendingContact(high: high, pre: recent.filter { $0.time <= low.time },
                                         post: [sample], hidden: false)
            } else {
                events += contact(at: low, drop: high - low.center.y)
            }
        } else if sample.time - low.time >= config.stall {
            phase = .seekingHigh(high: sample.center.y)
            // Came to rest at floor level: the ground, even beside a foot (no rebound, no touch).
            if isOnFloor(low) {
                if isRunning { events.append(endRun(.ground, at: sample.time)) }
            } else {
                events += contact(at: low, drop: high - low.center.y)
            }
        }
        return events
    }

    /// Ends an open run (footage over, or the player stopped the session).
    func finish(at time: Double) -> [DrillEvent] {
        var events: [DrillEvent] = []
        if let waiting = pending {
            pending = nil
            events += settle(waiting)
        }
        return events + (isRunning ? [endRun(.stopped, at: time)] : [])
    }

    /// Adds a rising sighting to a pending contact; settles it once the rise is clear.
    private func advancePending(with sample: Sample) -> [DrillEvent] {
        guard var waiting = pending else { return [] }
        waiting.post.append(sample)
        guard waiting.post.count >= 3 || sample.time - waiting.post[0].time >= config.settleTime else {
            pending = waiting
            return []
        }
        pending = nil
        return settle(waiting)
    }

    /// Counts a pending contact at its estimated point (never judged: the touch wasn't seen).
    private func settle(_ waiting: PendingContact) -> [DrillEvent] {
        let point = estimatedContact(pre: waiting.pre, post: waiting.post)
            ?? (waiting.hidden ? waiting.post[0] : waiting.pre.last ?? waiting.post[0])
        let drop = waiting.high == .infinity ? .infinity : waiting.high - point.center.y
        return contact(at: point, drop: drop, hidden: waiting.hidden, seen: false)
    }

    /// The ball clearly above the run's height limit, `tooHighFrames` sightings in a row.
    private func isTooHigh(_ sample: Sample) -> Bool {
        guard let limit = config.heightLimit, let pose = sample.pose,
              // A detection far off the ball's usual size is something else (seen on device: a quarter-size
              // false detection near the top of the frame).
              let usual = radius, sample.radius > usual * 0.6, sample.radius < usual * 1.6 else { aboveLimit = 0; return false }
        let joints: [BodyJoint] = limit == .waist ? [.leftHip, .rightHip] : [.leftKnee, .rightKnee]
        let ys = joints.compactMap { pose[$0]?.y }
        guard !ys.isEmpty else { aboveLimit = 0; return false }
        let line = ys.reduce(0, +) / Double(ys.count)
        aboveLimit = sample.center.y - sample.radius > line + metres(config.heightMargin) ? aboveLimit + 1 : 0
        return aboveLimit >= config.tooHighFrames
    }

    /// Where the ball's fall (last sightings before the gap) and rise (first sightings after it) meet, both
    /// under gravity: the contact point the detector didn't see. Nil without two sightings on each side.
    private func estimatedContact(pre: [Sample], post: [Sample]) -> Sample? {
        let down = Array(pre.suffix(4)), up = Array(post.prefix(4))
        guard down.count >= 2, up.count >= 2, let p = down.last, let q = up.first, q.time > p.time,
              let vp = velocity(at: p.time, down), let vq = velocity(at: q.time, up) else { return nil }
        let g = metres(config.gravity)
        // y_down(t) = y_p + v_p (t − t_p) − g/2 (t − t_p)², y_up likewise from q; the g t² terms cancel.
        let tq = q.time - p.time
        let a = vp - vq - g * tq
        let b = p.center.y - q.center.y + vq * tq + 0.5 * g * tq * tq
        guard abs(a) > 1e-9 else { return nil }
        let t = min(max(-b / a, 0), tq)
        let y = p.center.y + vp * t - 0.5 * g * t * t
        let x = p.center.x + (q.center.x - p.center.x) * t / tq
        return Sample(time: p.time + t, center: DrillPoint(x: x, y: y), radius: p.radius,
                      pose: t < tq / 2 ? (p.pose ?? q.pose) : (q.pose ?? p.pose))
    }

    /// Vertical velocity at `time` from a least-squares fit over `samples` (gravity-corrected to that time).
    private func velocity(at time: Double, _ samples: [Sample]) -> Double? {
        guard samples.count >= 2 else { return nil }
        let n = Double(samples.count)
        let mt = samples.map(\.time).reduce(0, +) / n, my = samples.map(\.center.y).reduce(0, +) / n
        let sxx = samples.reduce(0) { $0 + ($1.time - mt) * ($1.time - mt) }
        guard sxx > 0 else { return nil }
        let slope = samples.reduce(0) { $0 + ($1.time - mt) * ($1.center.y - my) } / sxx
        return slope - metres(config.gravity) * (time - mt)
    }

    // MARK: - Contacts

    /// The ball reappeared after a detector gap well above where free fall from its last sightings would
    /// have put it: something pushed it up while it was hidden.
    private func wasTouchedWhileHidden(_ sample: Sample) -> Bool {
        guard let last = recent.last, sample.time - last.time >= config.hiddenTouchGap, !isOnFloor(last),
              let vy = verticalVelocity() else { return false }
        let dt = sample.time - last.time
        let freeFall = last.center.y + vy * dt - 0.5 * metres(config.gravity) * dt * dt
        return sample.center.y - freeFall >= metres(config.hiddenTouchRise)
    }

    /// Least-squares vertical velocity (units/s) over the recent sightings; nil with fewer than two.
    private func verticalVelocity() -> Double? {
        guard recent.count >= 2 else { return nil }
        let n = Double(recent.count)
        let mt = recent.map(\.time).reduce(0, +) / n, my = recent.map(\.center.y).reduce(0, +) / n
        let sxx = recent.reduce(0) { $0 + ($1.time - mt) * ($1.time - mt) }
        guard sxx > 0 else { return nil }
        return recent.reduce(0) { $0 + ($1.time - mt) * ($1.center.y - my) } / sxx
    }

    /// - Parameter hidden: the touch happened out of the detector's sight (`wasTouchedWhileHidden`): no drop or
    ///   floor check, and the ball's position now doesn't say what touched it (never a handball).
    /// - Parameter seen: the contact point was seen, not estimated; only seen touches are judged.
    private func contact(at sample: Sample, drop: Double, hidden: Bool = false, seen: Bool = true) -> [DrillEvent] {
        guard drop >= metres(config.minDrop) else { return [] }
        if !hidden, isOnFloor(sample), !isAtFeet(sample) {
            return isRunning ? [endRun(.ground, at: sample.time)] : []
        }
        var (part, side) = classify(sample)
        if hidden, part == .arm { (part, side) = (.unknown, nil) }
        if part == .arm {
            return isRunning ? [endRun(.handball, at: sample.time)] : []
        }
        let judged = seen && !hidden
        if config.partRule == .feetOnly, isRunning, judged, let reason = Self.partReason[part],
           isClear(sample, illegal: { $0.part == part }, legal: { $0.part == .foot }) {
            return [endRun(reason, at: sample.time)]
        }
        switch config.footRule {
        case .any:
            break
        case let .only(allowed):
            guard part == .foot, let side else { return [] }
            if side != allowed, judged,
               isClear(sample, illegal: { $0.part == .foot && $0.side == side }, legal: { $0.part == .foot && $0.side == allowed }) {
                return isRunning ? [endRun(.wrongFoot, at: sample.time)] : []
            }
        case .alternate:
            guard part == .foot, let side else { return [] }
            if isRunning, side == lastFoot, judged,
               isClear(sample, illegal: { $0.part == .foot && $0.side == side }, legal: { $0.part == .foot && $0.side != side }) {
                return [endRun(.wrongFoot, at: sample.time)]
            }
        }
        if !isRunning {
            isRunning = true
            count = 0
        }
        if part == .foot { lastFoot = side }
        count += 1
        return [.touch(count: count, part: part, time: sample.time, side: side)]
    }

    private func endRun(_ reason: RunEndReason, at time: Double) -> DrillEvent {
        isRunning = false
        lastFoot = nil
        return .runEnded(count: count, reason: reason, time: time)
    }

    private static let partReason: [TouchPart: RunEndReason] = [.thigh: .thighTouch, .chest: .chestTouch, .head: .headTouch]

    private typealias Candidate = (part: TouchPart, side: BodySide?, gap: Double)

    /// The illegal option is closer to the ball than every legal one by at least `callMargin`.
    private func isClear(_ sample: Sample, illegal: (Candidate) -> Bool, legal: (Candidate) -> Bool) -> Bool {
        let all = candidates(sample)
        guard let bad = all.filter(illegal).map(\.gap).min() else { return false }
        guard let good = all.filter(legal).map(\.gap).min() else { return true }
        return good - bad >= metres(config.callMargin)
    }

    /// Nearest body part to the ball (with its side for legs), or `.unknown` if there is no pose or
    /// nothing within reach.
    private func classify(_ sample: Sample) -> (TouchPart, BodySide?) {
        guard sample.pose != nil else { return (.unknown, nil) }
        guard let best = candidates(sample).min(by: { $0.gap < $1.gap }),
              best.gap <= sample.radius + metres(config.reach) else { return (.unknown, nil) }
        return (best.part, best.side)
    }

    /// Every body part's gap to the ball (distance minus the part's thickness).
    private func candidates(_ sample: Sample) -> [Candidate] {
        guard let pose = sample.pose else { return [] }
        let ball = sample.center
        var all: [Candidate] = []

        func consider(_ part: TouchPart, side: BodySide? = nil, thickness: Double, _ distance: Double?) {
            guard let distance else { return }
            all.append((part, side, distance - metres(thickness)))
        }
        func segment(_ a: BodyJoint, _ b: BodyJoint) -> Double? {
            guard let pa = pose[a], let pb = pose[b] else { return nil }
            return ball.distance(toSegment: pa, pb)
        }

        for (side, ankle, knee, hip) in [(BodySide.left, BodyJoint.leftAnkle, BodyJoint.leftKnee, BodyJoint.leftHip),
                                         (.right, .rightAnkle, .rightKnee, .rightHip)] {
            consider(.foot, side: side, thickness: 0.10, pose[ankle].map(ball.distance(to:)))
            consider(.foot, side: side, thickness: 0.05, segment(knee, ankle))
            consider(.thigh, side: side, thickness: 0.08, segment(hip, knee))
        }
        // Arms only when the hand is raised to mid-chest or higher: hanging arms overlap the thighs front-on,
        // and a phone on the floor even sees hanging hands a little above the hips (seen on device: thigh
        // touches ended runs as handballs).
        let hipY = [pose[.leftHip], pose[.rightHip]].compactMap { $0?.y }.max()
        let shoulderY = [pose[.leftShoulder], pose[.rightShoulder]].compactMap { $0?.y }.min()
        let raisedAbove = hipY.map { hip in shoulderY.map { hip + ($0 - hip) / 2 } ?? hip + metres(0.25) }
        for (shoulder, elbow, wrist) in [(BodyJoint.leftShoulder, BodyJoint.leftElbow, BodyJoint.leftWrist),
                                         (.rightShoulder, .rightElbow, .rightWrist)] {
            if let raisedAbove, let hand = pose[wrist], hand.y < raisedAbove { continue }
            consider(.arm, thickness: 0.05, segment(elbow, wrist))
            consider(.arm, thickness: 0.05, segment(shoulder, elbow))
        }
        if let ls = pose[.leftShoulder], let rs = pose[.rightShoulder],
           let lh = pose[.leftHip], let rh = pose[.rightHip] {
            let top = DrillPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let mid = DrillPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            let chestBottom = DrillPoint(x: (top.x + mid.x) / 2, y: (top.y + mid.y) / 2)
            // Below the hips it's a thigh, never the chest (seen on device: hip-height touches called chest).
            if ball.y > mid.y { consider(.chest, thickness: 0.12, ball.distance(toSegment: top, chestBottom)) }
        }
        consider(.head, thickness: 0.12, pose[.nose].map(ball.distance(to:)))
        return all
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

    /// The ball is down: at floor level away from the feet, or at floor level for `groundHold` seconds.
    private func isGround(_ sample: Sample) -> Bool {
        guard isOnFloor(sample) else { return false }
        return !isAtFeet(sample) || sample.time - (floorSince ?? sample.time) >= config.groundHold
    }

    private func isAtFeet(_ sample: Sample) -> Bool {
        guard let pose = sample.pose else { return false }
        let reach = sample.radius + metres(config.footClear)
        return [pose[.leftAnkle], pose[.rightAnkle]].contains { $0.map { $0.distance(to: sample.center) <= reach } ?? false }
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
