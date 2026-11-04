import AVFoundation
import CoreML

/// Models bundled with the app.
enum DrillModels {
    /// The ball detector (`BallDetector`, label "ball"): YOLOX-S (Apache-2.0, see LicencesView), today the
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

/// Front camera (the player watches the screen) at 720p / 60 fps (30 where it can't), delivering sample buffers on a private
/// queue. The connection rotates buffers upright (portrait) and leaves them unmirrored, so body sides
/// are real; only the preview is a mirror image.
final class CameraCapture: NSObject, DrillFrameSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CaptureError: Error { case denied, noCamera }

    /// Width / height of the upright frame (720 × 1280).
    static let aspect = 720.0 / 1280.0

    /// How to turn this camera's buffers upright: the connection is asked to rotate them, but that
    /// doesn't always take (seen on an iPhone 17 Pro front camera), so each buffer's shape decides.
    /// Set on `queue` from the latest buffer; read there by the analyser.
    private(set) var orientation = CGImagePropertyOrientation.up

    /// Portrait app: a landscape buffer is the sensor's raw landscape, upright after a quarter turn
    /// clockwise (both cameras; the front camera's buffers are unmirrored).
    static func uprightOrientation(width: Int, height: Int) -> CGImagePropertyOrientation {
        width > height ? .right : .up
    }
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
    /// Frames delivered since start (capture queue).
    private var frames = 0

    /// Asks for camera access, configures and starts the session; `onFrame` runs on `queue`.
    func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CaptureError?) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { completion(.denied); return }
            self.queue.async {
                self.onFrame = onFrame
                guard self.configure() else { completion(.noCamera); return }
                #if DEBUG
                NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                                       object: self.session, queue: nil) { note in
                    print("CameraCapture: runtime error \(String(describing: note.userInfo?[AVCaptureSessionErrorKey]))")
                }
                NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                                                       object: self.session, queue: nil) { note in
                    let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                        .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
                    print("CameraCapture: interrupted, reason \(String(describing: reason)) (\(String(describing: note.userInfo)))")
                }
                NotificationCenter.default.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
                                                       object: self.session, queue: nil) { _ in
                    print("CameraCapture: interruption ended")
                }
                #endif
                self.session.startRunning()
                #if DEBUG
                print("CameraCapture: running \(self.session.isRunning)")
                #endif
                self.fallBackIfSilent()
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

        // 60 fps where the camera can (twice the looks at the ball around each touch, half the blur), else
        // 30. Late frames are dropped, so a slower phone just analyses fewer; the counters run on timestamps.
        if (try? camera.lockForConfiguration()) != nil {
            let rate: Int32
            if let format = Self.format(for: camera, fps: 60) {
                camera.activeFormat = format
                rate = 60
            } else {
                rate = 30
            }
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: rate)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: rate)
            camera.unlockForConfiguration()
            #if DEBUG
            print("CameraCapture: \(rate) fps, format \(camera.activeFormat)")
            #endif
        }
        return true
    }

    /// 60 fps is new on device: if no frame arrives within 2 s of starting, drop to the session preset's
    /// 30 fps rather than leave the player with a dead camera.
    private func fallBackIfSilent() {
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            #if DEBUG
            print("CameraCapture: after 2 s: \(self == nil ? "released" : "running \(self!.session.isRunning), \(self!.frames) frames")")
            #endif
            guard let self, self.frames == 0, self.onFrame != nil,
                  let camera = (self.session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
            #if DEBUG
            print("CameraCapture: no frames at 60 fps, falling back to 30")
            #endif
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720
            if (try? camera.lockForConfiguration()) != nil {
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                camera.unlockForConfiguration()
            }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
            #if DEBUG
            print("CameraCapture: at 30 fps, running \(self.session.isRunning)")
            #endif
        }
    }

    #if DEBUG
    deinit { print("CameraCapture: released") }
    #endif

    /// A 1280 × 720 full-range 4:2:0 format that runs at `fps`.
    private static func format(for camera: AVCaptureDevice, fps: Double) -> AVCaptureDevice.Format? {
        camera.formats.first { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.width == 1280 && size.height == 720
                && CMFormatDescriptionGetMediaSubType(format.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= fps }
        }
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
        frames += 1
        if let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) {
            orientation = Self.uprightOrientation(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
            #if DEBUG
            if delivered == 0 { print("CameraCapture: first frame \(CVPixelBufferGetWidth(pixels))×\(CVPixelBufferGetHeight(pixels))") }
            delivered += 1
            #endif
        }
        onFrame?(sampleBuffer)
    }

    #if DEBUG
    private var delivered = 0
    private var dropped = 0

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dropped += 1
        if dropped % 60 == 1 { print("CameraCapture: dropped \(dropped) late frames (\(delivered) delivered)") }
    }
    #endif
}
