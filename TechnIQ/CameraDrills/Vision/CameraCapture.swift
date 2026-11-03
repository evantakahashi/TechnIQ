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

/// Where a camera-drill session's frames come from: the front camera, or (DEBUG) a recorded clip.
protocol DrillFrameSource: AnyObject {
    /// Queue `onFrame` runs on.
    var queue: DispatchQueue { get }
    /// Orientation that makes the buffers upright.
    var orientation: CGImagePropertyOrientation { get }
    /// Width / height of the upright frame.
    var aspect: Double { get }
    /// Live camera preview, when there is one.
    var previewSession: AVCaptureSession? { get }
    /// The preview is a mirror image (front camera): overlays flip x to match it. Frames stay unmirrored.
    var isMirrored: Bool { get }
    func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CameraCapture.CaptureError?) -> Void)
    func stop()
}

/// Front camera (the player watches the screen) at 720p / 30 fps, delivering sample buffers on a private
/// queue. The connection rotates buffers upright (portrait) and leaves them unmirrored, so body sides
/// are real; only the preview is a mirror image.
final class CameraCapture: NSObject, DrillFrameSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CaptureError: Error { case denied, noCamera }

    /// Buffers arrive upright.
    static let orientation = CGImagePropertyOrientation.up
    /// Width / height of the upright frame (720 × 1280).
    static let aspect = 720.0 / 1280.0

    var orientation: CGImagePropertyOrientation { Self.orientation }
    var aspect: Double { Self.aspect }
    var previewSession: AVCaptureSession? { session }
    var isMirrored: Bool { position == .front }

    let position: AVCaptureDevice.Position

    init(position: AVCaptureDevice.Position = .front) {
        self.position = position
    }

    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "camera-drills.capture", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var onFrame: ((CMSampleBuffer) -> Void)?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

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
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return false }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        // Upright portrait buffers, never mirrored (the preview layer mirrors the front camera itself).
        // The rotation that makes this camera's buffers upright comes from the system (front and back
        // sensors differ), kept up to date while the phone is propped portrait.
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
        rotationCoordinator = coordinator
        applyRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            self?.queue.async { self?.applyRotation(angle) }
        }

        // Lock 30 fps so the counter's timing and the gate's numbers are comparable.
        if (try? camera.lockForConfiguration()) != nil {
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        }
        return true
    }

    /// Portrait angles only (90 / 270): the frame is always 720 × 1280. A phone lying flat reports
    /// other angles; keep the last portrait one.
    private func applyRotation(_ angle: CGFloat) {
        let portrait = angle == 90 || angle == 270 ? angle : 90
        guard let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(portrait),
              connection.videoRotationAngle != portrait,
              angle == 90 || angle == 270 || connection.videoRotationAngle == 0 else { return }
        connection.videoRotationAngle = portrait
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
