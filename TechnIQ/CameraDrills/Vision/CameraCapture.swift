import AVFoundation
import CoreML

/// Models bundled with the app.
enum DrillModels {
    /// The ball detector (`BallDetector`, label "ball"): YOLOX-nano (Apache-2.0, see LicencesView), today the
    /// COCO-pretrained "sports ball" class; replaced by our fine-tuned export from tools/ball-yolox.
    static let yolo: MLModel? = load("BallDetector")

    private static func load(_ name: String) -> MLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }
}

/// Where a camera-drill session's frames come from: the back camera, or (DEBUG) a recorded clip.
protocol DrillFrameSource: AnyObject {
    /// Queue `onFrame` runs on.
    var queue: DispatchQueue { get }
    /// Orientation that makes the buffers upright.
    var orientation: CGImagePropertyOrientation { get }
    /// Width / height of the upright frame.
    var aspect: Double { get }
    /// Live camera preview, when there is one.
    var previewSession: AVCaptureSession? { get }
    func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CameraCapture.CaptureError?) -> Void)
    func stop()
}

/// Back camera at 720p / 30 fps, delivering sample buffers on a private queue.
/// Portrait app: buffers arrive landscape, so analysers use `CameraCapture.orientation`.
final class CameraCapture: NSObject, DrillFrameSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CaptureError: Error { case denied, noCamera }

    static let orientation = CGImagePropertyOrientation.right
    /// Width / height of the upright frame (720 × 1280).
    static let aspect = 720.0 / 1280.0

    var orientation: CGImagePropertyOrientation { Self.orientation }
    var aspect: Double { Self.aspect }
    var previewSession: AVCaptureSession? { session }

    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "camera-drills.capture", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var onFrame: ((CMSampleBuffer) -> Void)?

    /// Asks for camera access, configures and starts the session; `onFrame` runs on `queue`.
    func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CaptureError?) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { completion(.denied); return }
            self.queue.async {
                self.onFrame = onFrame
                guard self.configure() else { completion(.noCamera); return }
                self.session.startRunning()
                completion(nil)
            }
        }
    }

    func stop() {
        queue.async {
            self.onFrame = nil
            self.session.stopRunning()
        }
    }

    private func configure() -> Bool {
        guard session.inputs.isEmpty else { return true }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return false }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        // Lock 30 fps so the counter's timing and the gate's numbers are comparable.
        if (try? camera.lockForConfiguration()) != nil {
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
