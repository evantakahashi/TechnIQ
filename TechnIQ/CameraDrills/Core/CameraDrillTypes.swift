import Foundation

// Value types the camera-drill counters consume. Platform-agnostic (no Vision/AVFoundation) so the
// Mac harness (tools/juggle-harness) and unit tests drive the same code the app runs.
//
// Coordinate space: y points up, both axes in units of image height (x is pre-scaled by the
// frame's aspect ratio), so distances are isotropic. The ball radius doubles as the ruler:
// a size-5 ball is 0.11 m, so `radius / 0.11` converts metres to frame units.

struct DrillPoint: Equatable {
    var x: Double
    var y: Double

    func distance(to other: DrillPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }

    /// Distance from this point to the segment a–b.
    func distance(toSegment a: DrillPoint, _ b: DrillPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(to: a) }
        let t = max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / lengthSquared))
        return distance(to: DrillPoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}

enum BodyJoint: String, CaseIterable {
    case nose
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

struct BodyPose: Equatable {
    var joints: [BodyJoint: DrillPoint]

    subscript(_ joint: BodyJoint) -> DrillPoint? { joints[joint] }
}

struct BallSighting: Equatable {
    var center: DrillPoint
    var radius: Double
    var confidence: Double = 1
}

/// One analysed camera frame: where the ball and the player were at `time` (seconds).
struct DrillFrame: Equatable {
    var time: Double
    var ball: BallSighting?
    var pose: BodyPose?
}

/// The body part a touch landed on. Arms are never legal; the counter uses `.arm` to end a run.
enum TouchPart: String {
    case foot, thigh, chest, head, arm
    /// Ball reversed above the ground but no pose was available to say what touched it.
    case unknown
}

enum RunEndReason: String {
    case ground
    case handball
    case lostBall
    /// Footage or session ended mid-run.
    case stopped
}

enum JuggleEvent: Equatable {
    case touch(count: Int, part: TouchPart, time: Double)
    case runEnded(count: Int, reason: RunEndReason, time: Double)
}
