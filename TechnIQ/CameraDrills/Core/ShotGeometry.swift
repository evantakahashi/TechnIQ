import Foundation

// Shot analysis geometry (`tasks/shot_analysis.md`). Platform-agnostic like the rest of Core.
//
// Image points are DrillPoints (y up, image-height units, x pre-scaled by the aspect ratio). The camera is
// a pinhole with its focal length in image-height units and its principal point at the frame centre.
// Camera space: x right, y up, z forward, in metres.

struct Vec3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vec3, s: Double) -> Vec3 { Vec3(x: a.x * s, y: a.y * s, z: a.z * s) }
    static func += (a: inout Vec3, b: Vec3) { a = a + b }

    func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }
    func cross(_ o: Vec3) -> Vec3 { Vec3(x: y * o.z - z * o.y, y: z * o.x - x * o.z, z: x * o.y - y * o.x) }
    var length: Double { dot(self).squareRoot() }
    var normalized: Vec3 { self * (1 / length) }
}

struct ShotCamera: Equatable {
    /// Focal length in image-height units.
    var focal: Double
    /// Width / height of the frame.
    var aspect: Double

    init(focal: Double, aspect: Double) {
        self.focal = focal
        self.aspect = aspect
    }

    /// From the field of view along the frame's height (the long side in portrait).
    init(verticalFOV degrees: Double, aspect: Double) {
        self.init(focal: 0.5 / tan(degrees * .pi / 360), aspect: aspect)
    }

    var center: DrillPoint { DrillPoint(x: aspect / 2, y: 0.5) }

    func project(_ p: Vec3) -> DrillPoint? {
        guard p.z > 0.01 else { return nil }
        return DrillPoint(x: center.x + focal * p.x / p.z, y: center.y + focal * p.y / p.z)
    }

    /// Direction through an image point, scaled so z = 1 (multiply by a depth to get the point).
    func ray(through point: DrillPoint) -> Vec3 {
        Vec3(x: (point.x - center.x) / focal, y: (point.y - center.y) / focal, z: 1)
    }
}

/// The goal mouth's corners as tapped on screen (left / right as the camera sees them).
struct GoalCorners: Equatable, Codable {
    var topLeft: DrillPoint
    var topRight: DrillPoint
    var bottomRight: DrillPoint
    var bottomLeft: DrillPoint
}

/// A full-size goal (7.32 × 2.44 m) placed in camera space from its tapped corners.
/// Goal coordinates: u along the line from the left post, v up the posts (metres).
struct GoalPose {
    static let width = 7.32
    static let height = 2.44

    /// Foot of the left post.
    let origin: Vec3
    /// Unit vector left post → right post.
    let right: Vec3
    /// Unit vector up the posts (against gravity).
    let up: Vec3
    /// Unit normal of the goal plane, pointing out to the field (towards the camera).
    let normal: Vec3

    /// Nil when the corners can't be a goal (degenerate, or behind the camera).
    init?(corners: GoalCorners, camera: ShotCamera) {
        let pairs: [(u: Double, v: Double, image: DrillPoint)] = [
            (0, Self.height, corners.topLeft), (Self.width, Self.height, corners.topRight),
            (Self.width, 0, corners.bottomRight), (0, 0, corners.bottomLeft)
        ]
        // Homography goal (u, v) → ray (x/z, y/z), h33 = 1.
        var a: [[Double]] = []
        var b: [Double] = []
        for pair in pairs {
            let m = camera.ray(through: pair.image)
            a.append([pair.u, pair.v, 1, 0, 0, 0, -pair.u * m.x, -pair.v * m.x])
            b.append(m.x)
            a.append([0, 0, 0, pair.u, pair.v, 1, -pair.u * m.y, -pair.v * m.y])
            b.append(m.y)
        }
        guard let h = solveLinear(a, b) else { return nil }
        let h1 = Vec3(x: h[0], y: h[3], z: h[6]), h2 = Vec3(x: h[1], y: h[4], z: h[7]), h3 = Vec3(x: h[2], y: h[5], z: 1)
        guard h1.length > 0, h2.length > 0 else { return nil }
        var scale = 2 / (h1.length + h2.length)
        if h3.z * scale < 0 { scale = -scale }
        let r1 = (h1 * scale).normalized
        let r2raw = h2 * scale
        let r2 = (r2raw - r1 * r1.dot(r2raw)).normalized
        origin = h3 * scale
        guard origin.z > 0 else { return nil }
        right = r1
        up = r2
        let n = r1.cross(r2)
        normal = n.dot(origin) > 0 ? n * -1 : n
    }

    func point(u: Double, v: Double) -> Vec3 { origin + right * u + up * v }

    func goalCoordinates(of p: Vec3) -> DrillPoint {
        DrillPoint(x: right.dot(p - origin), y: up.dot(p - origin))
    }

    /// Signed distance in front of the goal plane (positive on the field side).
    func distanceInFront(of p: Vec3) -> Double { normal.dot(p - origin) }

    /// The point on `ray` that is `distance` in front of the goal plane.
    func point(on ray: Vec3, distanceInFront distance: Double) -> Vec3? {
        let along = normal.dot(ray)
        guard abs(along) > 1e-9 else { return nil }
        let s = (distance + normal.dot(origin)) / along
        return s > 0 ? ray * s : nil
    }
}

enum ShotGeometry {
    /// Focal length (image-height units) that puts the resting ball, sized as a real ball, `spot` metres in
    /// front of the goal. For clips whose camera isn't known (imports); nil if no focal length fits.
    static func estimateFocal(
        corners: GoalCorners, aspect: Double, restingBall: BallSighting, spot: ShotSpot, ballRadius: Double = 0.11
    ) -> Double? {
        func miss(_ focal: Double) -> Double? {
            let camera = ShotCamera(focal: focal, aspect: aspect)
            guard let goal = GoalPose(corners: corners, camera: camera) else { return nil }
            let ball = camera.ray(through: restingBall.center) * (focal * ballRadius / restingBall.radius)
            return goal.distanceInFront(of: ball) - spot.distance
        }
        var low = 0.3, high = 6.0
        guard let lowMiss = miss(low), let highMiss = miss(high), (lowMiss < 0) != (highMiss < 0) else { return nil }
        for _ in 0..<60 {
            let mid = (low + high) / 2
            guard let m = miss(mid) else { return nil }
            if (m < 0) == (lowMiss < 0) { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }
}

/// Solves a·x = b (Gaussian elimination, partial pivoting); nil when singular.
func solveLinear(_ a: [[Double]], _ b: [Double]) -> [Double]? {
    let n = b.count
    var m = a
    var x = b
    for col in 0..<n {
        guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }), abs(m[pivot][col]) > 1e-12 else {
            return nil
        }
        m.swapAt(col, pivot)
        x.swapAt(col, pivot)
        for row in (col + 1)..<n {
            let f = m[row][col] / m[col][col]
            guard f != 0 else { continue }
            for k in col..<n { m[row][k] -= f * m[col][k] }
            x[row] -= f * x[col]
        }
    }
    for row in stride(from: n - 1, through: 0, by: -1) {
        var sum = x[row]
        for k in (row + 1)..<n { sum -= m[row][k] * x[k] }
        x[row] = sum / m[row][row]
    }
    return x
}
