import CoreMedia
import CoreML
import Vision

/// Turns camera (or recorded) frames into DrillFrames: Vision body pose + one of two ball detectors.
/// Runs entirely on device. Shared with the Mac harness, so keep it free of UIKit.
final class FrameAnalyzer {
    enum Detector: String, CaseIterable {
        /// Vision's built-in parabolic-trajectory detector. No model; only sees the ball in flight.
        case trajectory
        /// YOLO11n Core ML, COCO "sports ball" class (spike only: AGPL-3.0).
        case yolo
    }

    let detector: Detector
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var trajectoryRequest: VNDetectTrajectoriesRequest?
    private var yoloRequest: VNCoreMLRequest?
    private var lastBall: DrillPoint?

    /// - Parameter yoloModel: compiled YOLO model; required for `.yolo`.
    init(detector: Detector, yoloModel: MLModel? = nil) throws {
        self.detector = detector
        switch detector {
        case .trajectory:
            let request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 5)
            request.objectMinimumNormalizedRadius = 0.004
            request.objectMaximumNormalizedRadius = 0.08
            trajectoryRequest = request
        case .yolo:
            guard let yoloModel else { throw AnalyzerError.missingModel }
            let request = VNCoreMLRequest(model: try VNCoreMLModel(for: yoloModel))
            request.imageCropAndScaleOption = .scaleFit
            yoloRequest = request
        }
    }

    enum AnalyzerError: Error { case missingModel }

    func analyze(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) -> DrillFrame {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return DrillFrame(time: time)
        }
        var width = Double(CVPixelBufferGetWidth(pixelBuffer))
        var height = Double(CVPixelBufferGetHeight(pixelBuffer))
        if [.left, .right, .leftMirrored, .rightMirrored].contains(orientation) { swap(&width, &height) }
        let aspect = width / height

        var requests: [VNRequest] = [poseRequest]
        if let yoloRequest { requests.append(yoloRequest) }
        let imageHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation)
        try? imageHandler.perform(requests)
        if let trajectoryRequest {
            try? sequenceHandler.perform([trajectoryRequest], on: sampleBuffer, orientation: orientation)
        }

        let pose = bestPose(aspect: aspect)
        let ball: BallSighting?
        switch detector {
        case .trajectory: ball = trajectoryBall(aspect: aspect, at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        case .yolo: ball = yoloBall(aspect: aspect)
        }
        lastBall = ball?.center
        return DrillFrame(time: time, ball: ball, pose: pose)
    }

    // MARK: - Pose

    private static let jointNames: [BodyJoint: VNHumanBodyPoseObservation.JointName] = [
        .nose: .nose,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle
    ]

    /// The largest person in frame (the juggler, not someone walking past behind).
    private func bestPose(aspect: Double) -> BodyPose? {
        let poses: [BodyPose] = (poseRequest.results ?? []).compactMap { observation in
            guard let points = try? observation.recognizedPoints(.all) else { return nil }
            var joints: [BodyJoint: DrillPoint] = [:]
            for (joint, name) in Self.jointNames {
                guard let p = points[name], p.confidence > 0.3 else { continue }
                joints[joint] = DrillPoint(x: Double(p.location.x) * aspect, y: Double(p.location.y))
            }
            return joints.count >= 6 ? BodyPose(joints: joints) : nil
        }
        return poses.max { $0.extent < $1.extent }
    }

    // MARK: - Ball

    private func trajectoryBall(aspect: Double, at time: CMTime) -> BallSighting? {
        // Each observation carries its whole path; only one whose range ends on this frame says where
        // the ball is now (older ones repeat a stale last point).
        let live = (trajectoryRequest?.results ?? []).filter {
            !$0.detectedPoints.isEmpty && abs(($0.timeRange.end - time).seconds) < 0.02
        }
        guard let best = live.max(by: { $0.confidence < $1.confidence }),
              let point = best.detectedPoints.last else { return nil }
        // movingAverageRadius is normalised to the image like the points; treat it as height units.
        return BallSighting(
            center: DrillPoint(x: Double(point.x) * aspect, y: Double(point.y)),
            radius: Double(best.movingAverageRadius),
            confidence: Double(best.confidence)
        )
    }

    private func yoloBall(aspect: Double) -> BallSighting? {
        let balls = (yoloRequest?.results as? [VNRecognizedObjectObservation] ?? []).compactMap { obs -> BallSighting? in
            guard let label = obs.labels.first(where: { $0.identifier == "sports ball" }), label.confidence > 0.25 else {
                return nil
            }
            let box = obs.boundingBox
            return BallSighting(
                center: DrillPoint(x: Double(box.midX) * aspect, y: Double(box.midY)),
                radius: (Double(box.width) * aspect + Double(box.height)) / 4,
                confidence: Double(label.confidence)
            )
        }
        // Prefer the ball nearest last frame's; otherwise the most confident.
        if let lastBall, let nearest = balls.min(by: { $0.center.distance(to: lastBall) < $1.center.distance(to: lastBall) }),
           nearest.center.distance(to: lastBall) < 0.15 {
            return nearest
        }
        return balls.max { $0.confidence < $1.confidence }
    }
}

private extension BodyPose {
    /// Bounding-box area of the visible joints.
    var extent: Double {
        let xs = joints.values.map(\.x), ys = joints.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return (maxX - minX) * (maxY - minY)
    }
}
