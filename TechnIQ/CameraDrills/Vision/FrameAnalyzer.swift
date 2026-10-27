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
    private let ballTracker = BallTracker()
    private let gapFiller = BallGapFiller()
    /// Fresh per seed: dropping the handler releases the previous tracker.
    private var trackHandler = VNSequenceRequestHandler()
    private var trackRequest: VNTrackObjectRequest?

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
            let visionModel = try VNCoreMLModel(for: yoloModel)
            // The NMS stage defaults to 0.25; go lower and let BallTracker throw out scenery.
            visionModel.featureProvider = try? MLDictionaryFeatureProvider(dictionary: [
                "confidenceThreshold": Self.ballConfidence, "iouThreshold": 0.45
            ])
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .scaleFit
            yoloRequest = request
        }
        #if targetEnvironment(simulator)
        // No Neural Engine / GPU path for these models in the simulator: run them on the CPU.
        for request in [poseRequest, yoloRequest].compactMap({ $0 as VNRequest? }) { Self.useCPU(request) }
        #endif
    }

    enum AnalyzerError: Error { case missingModel }

    #if DEBUG
    private var loggedFailure = false
    #endif

    /// Minimum "sports ball" confidence. Low on purpose: on real juggling clips 0.1 sees the ball in
    /// ~65% of frames vs ~50% at the model's default 0.25, and BallTracker drops the extra scenery hits.
    static var ballConfidence = 0.1

    /// Fill short detector misses with Vision's object tracker (BallGapFiller decides when).
    static var fillGaps = true

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
        do {
            try imageHandler.perform(requests)
        } catch {
            #if DEBUG
            if !loggedFailure { print("FrameAnalyzer: Vision failed: \(error)"); loggedFailure = true }
            #endif
        }
        if let trajectoryRequest {
            try? sequenceHandler.perform([trajectoryRequest], on: sampleBuffer, orientation: orientation)
        }

        let pose = bestPose(aspect: aspect)
        let ball: BallSighting?
        switch detector {
        case .trajectory: ball = trajectoryBall(aspect: aspect, at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        case .yolo:
            let detected = ballTracker.pick(yoloBalls(aspect: aspect), at: time)
            ball = Self.fillGaps
                ? gapFiller.ball(detected: detected, at: time,
                                 seed: { seedTracker($0, on: sampleBuffer, orientation: orientation, aspect: aspect) },
                                 track: { trackedBall(on: sampleBuffer, orientation: orientation, aspect: aspect) })
                : detected
        }
        return DrillFrame(time: time, ball: ball, pose: pose)
    }

    #if targetEnvironment(simulator)
    private static func useCPU(_ request: VNRequest) {
        guard let devices = try? request.supportedComputeStageDevices[.main],
              let cpu = devices.first(where: { if case .cpu = $0 { return true } else { return false } }) else { return }
        request.setComputeDevice(cpu, for: .main)
    }
    #endif

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

    /// Starts a tracker on `ball` in this frame (the tracker learns the ball's look from it).
    private func seedTracker(_ ball: BallSighting, on buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation, aspect: Double) {
        // A little margin: the ball alone is tiny and blurs; some context keeps the tracker on it.
        let side = 2 * ball.radius * 1.5
        let box = CGRect(x: ball.center.x / aspect - side / aspect / 2, y: ball.center.y - side / 2,
                         width: side / aspect, height: side)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !box.isEmpty else { trackRequest = nil; return }
        let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: box))
        request.trackingLevel = .accurate
        trackHandler = VNSequenceRequestHandler()
        trackRequest = (try? trackHandler.perform([request], on: buffer, orientation: orientation)) != nil ? request : nil
    }

    private func trackedBall(on buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation, aspect: Double) -> BallSighting? {
        guard let trackRequest, (try? trackHandler.perform([trackRequest], on: buffer, orientation: orientation)) != nil,
              let observation = trackRequest.results?.first as? VNDetectedObjectObservation else { return nil }
        trackRequest.inputObservation = observation
        let box = observation.boundingBox
        return BallSighting(center: DrillPoint(x: Double(box.midX) * aspect, y: Double(box.midY)),
                            radius: Double(box.height) / 2, confidence: Double(observation.confidence))
    }

    private func yoloBalls(aspect: Double) -> [BallSighting] {
        (yoloRequest?.results as? [VNRecognizedObjectObservation] ?? []).compactMap { obs -> BallSighting? in
            guard let label = obs.labels.first(where: { $0.identifier == "sports ball" }), label.confidence > Float(Self.ballConfidence) else {
                return nil
            }
            let box = obs.boundingBox
            return BallSighting(
                center: DrillPoint(x: Double(box.midX) * aspect, y: Double(box.midY)),
                radius: (Double(box.width) * aspect + Double(box.height)) / 4,
                confidence: Double(label.confidence)
            )
        }
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
