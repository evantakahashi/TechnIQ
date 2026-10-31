import Foundation

/// The set spots a shot is taken from. Raw values are persisted — never rename.
enum ShotSpot: String, CaseIterable, Codable {
    case penalty
    case edgeOfBox

    /// Ball spot to goal line (m).
    var distance: Double {
        switch self {
        case .penalty: return 11
        case .edgeOfBox: return 16.5
        }
    }
}

enum ShotPlacement: Equatable {
    /// In the goal mouth: column 0–2 left → right, row 0–2 bottom → top, as seen from behind the shooter.
    case onTarget(column: Int, row: Int)
    case wideLeft
    case wideRight
    case over
}

struct ShotResult: Equatable {
    var kickTime: Double
    /// Kick → goal line (s).
    var flightTime: Double
    /// Straight line from the spot to where the ball crossed the goal line (m).
    var distance: Double
    /// distance / flightTime (m/s) — the "avg speed" we show.
    var averageSpeed: Double
    /// Where the ball crossed the goal plane: x metres from the left post, y metres up.
    var crossing: DrillPoint
    var placement: ShotPlacement

    var kilometresPerHour: Double { averageSpeed * 3.6 }
}

/// Measures one shot from its ball track: when it was kicked, when and where it crossed the goal line.
///
/// The ball's flight is a physical model (gravity + air drag, from the spot) fitted to every sighting
/// between kick and goal line — its image position plus its size — so a blurred or missed frame barely
/// moves the answer. Runs after the shot on the recorded clip, not live.
final class ShotAnalyzer {
    struct Config {
        /// Size-5 ball (m).
        var ballRadius = 0.11
        var gravity = 9.81
        /// Air drag per metre, ρ·Cd·A / 2m for a size-5 ball.
        var drag = 0.013
        /// The ball has left its spot once it's this many radii away (and keeps going).
        var kickRadii = 1.5
        /// Sightings within this many radii of the first one are the ball at rest.
        var restRadii = 0.3
        /// Sightings needed at rest before a kick counts.
        var minRestSightings = 3
        /// First fit uses this much flight (s) — never past the goal.
        var firstWindow = 0.2
        /// Image-size residuals weigh this much against position residuals.
        var sizeWeight = 0.5
        /// Integration step (s).
        var step = 0.001
        var maxFlight = 3.0
        /// Plausible average speeds (m/s); outside → no result.
        var speedRange = 4.0...50.0
    }

    private struct Sighting {
        var time: Double
        var ball: BallSighting
    }

    private struct Kick {
        var rest: BallSighting
        var lastRest: Double
        var firstMove: Int
    }

    let camera: ShotCamera
    let goal: GoalPose
    let spot: ShotSpot
    let config: Config

    init(camera: ShotCamera, goal: GoalPose, spot: ShotSpot, config: Config = Config()) {
        self.camera = camera
        self.goal = goal
        self.spot = spot
        self.config = config
    }

    func analyze(_ frames: [DrillFrame]) -> ShotResult? {
        let sightings = frames.compactMap { frame in frame.ball.map { Sighting(time: frame.time, ball: $0) } }
        guard let kick = findKick(sightings),
              let start = goal.point(on: camera.ray(through: kick.rest.center), distanceInFront: spot.distance)
        else { return nil }
        let flight = Array(sightings[kick.firstMove...])
        let firstMove = flight[0].time

        // Fit on the first stretch of flight, then on everything up to the predicted goal line.
        let towardsGoal = (goal.point(u: GoalPose.width / 2, v: 1) - start).normalized
        var params = [towardsGoal.x * 25, towardsGoal.y * 25, towardsGoal.z * 25, (kick.lastRest + firstMove) / 2]
        let kickBounds = kick.lastRest...firstMove
        var window = flight.filter { $0.time <= firstMove + config.firstWindow }
        var crossing: (time: Double, point: Vec3)?
        for _ in 0..<6 {
            guard window.count >= 4 else { return nil }
            params = searchKick(params, start: start, sightings: window, kickBounds: kickBounds)
            params = fit(params, start: start, sightings: dropOutliers(window, params, start), kickBounds: kickBounds)
            crossing = crossingPoint(params, start: start)
            guard let crossing else { return nil }
            let next = flight.filter { $0.time <= params[3] + crossing.time }
            if next.count == window.count { break }
            window = next
        }
        guard let crossing else { return nil }

        let distance = (crossing.point - start).length
        let speed = distance / crossing.time
        guard config.speedRange.contains(speed) else { return nil }
        let inGoal = goal.goalCoordinates(of: crossing.point)
        return ShotResult(
            kickTime: params[3], flightTime: crossing.time, distance: distance, averageSpeed: speed,
            crossing: inGoal, placement: placement(inGoal)
        )
    }

    // MARK: - Kick

    /// The ball sits still, then leaves its spot and keeps going. Sightings just off the spot are neither
    /// rest nor flight (the ball's first instants in the air barely move it on screen).
    private func findKick(_ sightings: [Sighting]) -> Kick? {
        var rest: [Sighting] = []
        for (i, s) in sightings.enumerated() {
            guard let anchor = rest.first?.ball else { rest = [s]; continue }
            let offset = s.ball.center.distance(to: anchor.center)
            if offset <= config.restRadii * anchor.radius {
                rest.append(s)
                continue
            }
            if offset <= config.kickRadii * anchor.radius { continue }
            let next = sightings.dropFirst(i + 1).prefix(2)
            let keepsGoing = next.count == 2 && zip([s] + next, next).allSatisfy { a, b in
                b.ball.center.distance(to: anchor.center) > a.ball.center.distance(to: anchor.center)
            }
            guard keepsGoing else { continue }
            guard rest.count >= config.minRestSightings, let last = rest.last else {
                rest = [s]
                continue
            }
            let center = DrillPoint(
                x: rest.map(\.ball.center.x).reduce(0, +) / Double(rest.count),
                y: rest.map(\.ball.center.y).reduce(0, +) / Double(rest.count)
            )
            let radius = rest.map(\.ball.radius).sorted()[rest.count / 2]
            return Kick(rest: BallSighting(center: center, radius: radius), lastRest: last.time, firstMove: i)
        }
        return nil
    }

    // MARK: - Flight model

    /// Positions every `step` seconds after the kick.
    private func trajectory(velocity: Vec3, start: Vec3, duration: Double) -> [Vec3] {
        let down = goal.up * -config.gravity
        var p = start, v = velocity
        var path = [p]
        path.reserveCapacity(Int(duration / config.step) + 2)
        var t = 0.0
        while t < duration {
            v += (down - v * (config.drag * v.length)) * config.step
            p += v * config.step
            path.append(p)
            t += config.step
        }
        return path
    }

    private func position(_ path: [Vec3], at time: Double) -> Vec3? {
        let i = time / config.step
        guard i >= 0 else { return path.first }
        let lower = Int(i)
        guard lower + 1 < path.count else { return nil }
        let f = i - Double(lower)
        return path[lower] + (path[lower + 1] - path[lower]) * f
    }

    private func residuals(_ params: [Double], start: Vec3, sightings: [Sighting]) -> [Double] {
        let velocity = Vec3(x: params[0], y: params[1], z: params[2])
        let duration = (sightings.last?.time ?? 0) - params[3] + 0.01
        let path = trajectory(velocity: velocity, start: start, duration: max(duration, config.step))
        var out: [Double] = []
        out.reserveCapacity(sightings.count * 3)
        for s in sightings {
            guard let p = position(path, at: s.time - params[3]), let image = camera.project(p) else {
                out += [1, 1, 1]
                continue
            }
            out.append(image.x - s.ball.center.x)
            out.append(image.y - s.ball.center.y)
            out.append((camera.focal * config.ballRadius / p.z - s.ball.radius) * config.sizeWeight)
        }
        return out
    }

    /// Levenberg–Marquardt on (velocity, kick time); kick time stays between the last rest and first move.
    private func fit(_ initial: [Double], start: Vec3, sightings: [Sighting], kickBounds: ClosedRange<Double>) -> [Double] {
        func clamp(_ p: [Double]) -> [Double] {
            var p = p
            p[3] = min(max(p[3], kickBounds.lowerBound), kickBounds.upperBound)
            return p
        }
        func cost(_ r: [Double]) -> Double { r.reduce(0) { $0 + $1 * $1 } }

        var params = clamp(initial)
        var r = residuals(params, start: start, sightings: sightings)
        var current = cost(r)
        var damping = 1e-3
        let steps = [1e-3, 1e-3, 1e-3, 1e-5]
        for _ in 0..<40 {
            let jacobian: [[Double]] = (0..<4).map { k in
                var p = params
                p[k] += steps[k]
                let shifted = residuals(p, start: start, sightings: sightings)
                return zip(shifted, r).map { ($0 - $1) / steps[k] }
            }
            var normal = (0..<4).map { i in (0..<4).map { j in zip(jacobian[i], jacobian[j]).reduce(0) { $0 + $1.0 * $1.1 } } }
            let gradient = (0..<4).map { i in -zip(jacobian[i], r).reduce(0) { $0 + $1.0 * $1.1 } }
            var improved = false
            for _ in 0..<8 {
                for i in 0..<4 { normal[i][i] *= 1 + damping }
                defer { for i in 0..<4 { normal[i][i] /= 1 + damping } }
                guard let delta = solveLinear(normal, gradient) else { break }
                let candidate = clamp(zip(params, delta).map(+))
                let candidateResiduals = residuals(candidate, start: start, sightings: sightings)
                let candidateCost = cost(candidateResiduals)
                if candidateCost < current {
                    let gain = current - candidateCost
                    params = candidate
                    r = candidateResiduals
                    current = candidateCost
                    damping = max(damping / 3, 1e-9)
                    improved = gain > current * 1e-9
                    break
                }
                damping *= 4
            }
            if !improved { break }
        }
        return params
    }

    /// Kick time and speed trade off against each other (the leg hides the kick), so try kick times across
    /// the gap with the speed free, then fit everything from the best.
    private func searchKick(_ initial: [Double], start: Vec3, sightings: [Sighting], kickBounds: ClosedRange<Double>) -> [Double] {
        let tries = 6
        let span = kickBounds.upperBound - kickBounds.lowerBound
        let candidates = [initial] + (0...tries).map { i in
            var p = initial
            p[3] = kickBounds.lowerBound + span * Double(i) / Double(tries)
            return fit(p, start: start, sightings: sightings, kickBounds: p[3]...p[3])
        }
        let best = candidates.min { cost($0, start, sightings) < cost($1, start, sightings) } ?? initial
        return fit(best, start: start, sightings: sightings, kickBounds: kickBounds)
    }

    private func cost(_ params: [Double], _ start: Vec3, _ sightings: [Sighting]) -> Double {
        residuals(params, start: start, sightings: sightings).reduce(0) { $0 + $1 * $1 }
    }

    /// Drops sightings far off the fitted flight (a wrong detection, a ball rolling in the net).
    private func dropOutliers(_ sightings: [Sighting], _ params: [Double], _ start: Vec3) -> [Sighting] {
        let r = residuals(params, start: start, sightings: sightings)
        let errors = sightings.indices.map { (r[3 * $0] * r[3 * $0] + r[3 * $0 + 1] * r[3 * $0 + 1]).squareRoot() }
        let limit = max(4 * errors.sorted()[errors.count / 2], 0.004)
        let kept = sightings.indices.filter { errors[$0] <= limit }.map { sightings[$0] }
        return kept.count >= 4 ? kept : sightings
    }

    private func crossingPoint(_ params: [Double], start: Vec3) -> (time: Double, point: Vec3)? {
        let path = trajectory(velocity: Vec3(x: params[0], y: params[1], z: params[2]), start: start, duration: config.maxFlight)
        var previous = goal.distanceInFront(of: path[0])
        for i in 1..<path.count {
            let d = goal.distanceInFront(of: path[i])
            if d <= 0 {
                let f = previous / (previous - d)
                return (config.step * (Double(i - 1) + f), path[i - 1] + (path[i] - path[i - 1]) * f)
            }
            previous = d
        }
        return nil
    }

    private func placement(_ crossing: DrillPoint) -> ShotPlacement {
        if crossing.x < 0 { return .wideLeft }
        if crossing.x > GoalPose.width { return .wideRight }
        if crossing.y > GoalPose.height { return .over }
        let column = min(2, Int(crossing.x / (GoalPose.width / 3)))
        let row = min(2, Int(max(0, crossing.y) / (GoalPose.height / 3)))
        return .onTarget(column: column, row: row)
    }
}
