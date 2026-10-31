import Foundation
@testable import JuggleCore

/// Synthetic shots for ShotAnalyzer: a full-size goal, a phone on the ground behind the ball (portrait),
/// a ball flown with gravity + drag by an integrator independent of the analyzer's.
///
/// World space: x right, y up, z from the ball spot towards the goal (metres). The ball rests at
/// (0, 0.11, 0); the goal line is z = spot distance, posts at x = ±3.66.
enum ShotScene {
    static let aspect = 9.0 / 16
    /// iPhone main camera, 16:9 video held in portrait: ~69° along the long (vertical) side.
    static let camera = ShotCamera(verticalFOV: 69, aspect: aspect)

    struct Rig {
        /// Phone on the ground, 3 m behind and 1 m left of the ball.
        var position = Vec3(x: -1, y: 0.15, z: -3)
        /// Aimed at the middle of the goal.
        var lookAtHeight = 1.0
    }

    struct Truth {
        var flightTime: Double
        var crossing: DrillPoint
        var averageSpeed: Double
    }

    struct Basis {
        var right: Vec3, up: Vec3, forward: Vec3, origin: Vec3

        func toCamera(_ world: Vec3) -> Vec3 {
            let d = world - origin
            return Vec3(x: d.dot(right), y: d.dot(up), z: d.dot(forward))
        }
    }

    static func basis(_ rig: Rig, spot: ShotSpot) -> Basis {
        let forward = (Vec3(x: 0, y: rig.lookAtHeight, z: spot.distance) - rig.position).normalized
        let right = Vec3(x: 0, y: 1, z: 0).cross(forward).normalized
        return Basis(right: right, up: forward.cross(right), forward: forward, origin: rig.position)
    }

    static func image(_ world: Vec3, _ basis: Basis) -> DrillPoint {
        camera.project(basis.toCamera(world))!
    }

    static func corners(spot: ShotSpot, rig: Rig = Rig()) -> GoalCorners {
        let b = basis(rig, spot: spot), z = spot.distance
        return GoalCorners(
            topLeft: image(Vec3(x: -3.66, y: 2.44, z: z), b),
            topRight: image(Vec3(x: 3.66, y: 2.44, z: z), b),
            bottomRight: image(Vec3(x: 3.66, y: 0, z: z), b),
            bottomLeft: image(Vec3(x: -3.66, y: 0, z: z), b)
        )
    }

    static func ballSighting(_ world: Vec3, _ basis: Basis) -> BallSighting {
        let c = basis.toCamera(world)
        return BallSighting(center: camera.project(c)!, radius: camera.focal * 0.11 / c.z)
    }

    /// Ball at rest for 0.4 s, kicked at t = 0 with `velocity`, then caught by the net just behind the line.
    static func shot(
        spot: ShotSpot, velocity: Vec3, rig: Rig = Rig(), fps: Double = 240, drag: Double = 0.013,
        noise: Double = 0.0006, seed: UInt64 = 1
    ) -> (frames: [DrillFrame], truth: Truth) {
        let b = basis(rig, spot: spot)
        let start = Vec3(x: 0, y: 0.11, z: 0)
        var rng = SeededRandom(seed: seed)

        // Fly at 0.5 ms steps until the goal line.
        var path: [(t: Double, p: Vec3)] = [(0, start)]
        var p = start, v = velocity, t = 0.0
        let dt = 0.0005
        while p.z < spot.distance, t < 3 {
            let speed = v.length
            v += Vec3(x: -drag * speed * v.x, y: -9.81 - drag * speed * v.y, z: -drag * speed * v.z) * dt
            p += v * dt
            t += dt
            path.append((t, p))
        }
        let (t0, p0) = path[path.count - 2], (t1, p1) = path[path.count - 1]
        let f = (spot.distance - p0.z) / (p1.z - p0.z)
        let cross = p0 + (p1 - p0) * f
        let flightTime = t0 + (t1 - t0) * f
        let truth = Truth(
            flightTime: flightTime,
            crossing: DrillPoint(x: cross.x + 3.66, y: cross.y),
            averageSpeed: (cross - start).length / flightTime
        )
        let inNet = cross + Vec3(x: 0, y: 0, z: 0.6)

        var frames: [DrillFrame] = []
        var time = -0.4
        while time < flightTime + 0.4 {
            defer { time += 1 / fps }
            // The kicking leg hides the ball around the kick; the detector misses some frames.
            if time > -0.05 && time < 0.02 { continue }
            if rng.next() < 0.1 { frames.append(DrillFrame(time: time)); continue }
            let world: Vec3
            if time <= 0 {
                world = start
            } else if time >= flightTime {
                world = inNet
            } else {
                let i = path.firstIndex { $0.t >= time }!
                let a = path[i - 1], c = path[i]
                world = a.p + (c.p - a.p) * ((time - a.t) / (c.t - a.t))
            }
            var ball = ballSighting(world, b)
            ball.center.x += noise * rng.gaussian()
            ball.center.y += noise * rng.gaussian()
            ball.radius *= 1 + 0.08 * rng.gaussian()
            frames.append(DrillFrame(time: time, ball: ball))
        }
        return (frames, truth)
    }
}

/// Deterministic noise for synthetic scenes.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1 }

    /// Uniform in [0, 1).
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }

    mutating func gaussian() -> Double {
        let u = max(next(), 1e-12), v = next()
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }
}
