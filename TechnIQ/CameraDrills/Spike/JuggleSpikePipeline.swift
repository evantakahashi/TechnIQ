#if DEBUG
import AVFoundation
import CoreML
import SwiftUI

/// Phase-1 spike: back camera → FrameAnalyzer → JuggleCounter, all on device, plus optional clip
/// recording for the harness. Frames are processed on `videoQueue`; UI state is published on main.
final class JuggleSpikePipeline: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var frame: DrillFrame?
    @Published private(set) var count = 0
    @Published private(set) var best = 0
    @Published private(set) var lastTouch: TouchPart?
    @Published private(set) var lastEnd: String?
    @Published private(set) var fps: Double = 0
    @Published private(set) var isRecording = false
    @Published private(set) var savedClips = 0
    @Published private(set) var error: String?
    @Published var detector: FrameAnalyzer.Detector = .yolo {
        didSet { videoQueue.async { self.makeAnalyzer() } }
    }
    @Published var speakCount = true

    let session = AVCaptureSession()
    /// Portrait buffers from the back camera arrive landscape; Vision is told to rotate them.
    private let orientation = CGImagePropertyOrientation.right
    private let videoQueue = DispatchQueue(label: "juggle-spike.video", qos: .userInteractive)
    private let output = AVCaptureVideoDataOutput()
    private var analyzer: FrameAnalyzer?
    private var counter = JuggleCounter()
    private var recorder: SpikeClipRecorder?
    private var frameTimes: [CFTimeInterval] = []
    private let speech = AVSpeechSynthesizer()
    private static let yoloModel: MLModel? = {
        guard let url = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }()

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                DispatchQueue.main.async { self.error = "Camera access denied — enable it in Settings." }
                return
            }
            self.videoQueue.async {
                guard self.configure() else { return }
                self.makeAnalyzer()
                self.session.startRunning()
            }
        }
    }

    func stop() {
        videoQueue.async {
            if self.recorder != nil { self.finishRecording() }
            self.session.stopRunning()
        }
    }

    func resetRun() {
        videoQueue.async {
            self.counter = JuggleCounter()
            DispatchQueue.main.async { self.count = 0; self.lastEnd = nil; self.lastTouch = nil }
        }
    }

    func toggleRecording() {
        videoQueue.async {
            if self.recorder != nil {
                self.finishRecording()
            } else {
                do {
                    self.recorder = try SpikeClipRecorder()
                    DispatchQueue.main.async { self.isRecording = true }
                } catch {
                    DispatchQueue.main.async { self.error = "Recorder: \(error.localizedDescription)" }
                }
            }
        }
    }

    // MARK: - Setup (videoQueue)

    /// False when there is no usable back camera (e.g. the simulator).
    private func configure() -> Bool {
        guard session.inputs.isEmpty else { return true }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            DispatchQueue.main.async { self.error = "No back camera." }
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        // Lock 30 fps so device numbers are comparable with the gate.
        if (try? camera.lockForConfiguration()) != nil {
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        }
        return true
    }

    private func makeAnalyzer() {
        do {
            analyzer = try FrameAnalyzer(detector: detector, yoloModel: Self.yoloModel)
            counter = JuggleCounter()
            DispatchQueue.main.async { self.error = nil }
        } catch {
            analyzer = nil
            DispatchQueue.main.async { self.error = "YOLO model missing from bundle." }
        }
    }

    private func finishRecording() {
        let recorder = self.recorder
        self.recorder = nil
        recorder?.finish { ok in
            DispatchQueue.main.async {
                self.isRecording = false
                if ok { self.savedClips += 1 }
            }
        }
    }

    // MARK: - Frames (videoQueue)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        recorder?.append(sampleBuffer)
        guard let analyzer else { return }
        let analysed = analyzer.analyze(sampleBuffer, orientation: orientation)
        let events = counter.process(analysed)

        let now = CACurrentMediaTime()
        frameTimes.append(now)
        frameTimes.removeAll { now - $0 > 1 }
        let fps = Double(frameTimes.count)

        DispatchQueue.main.async {
            self.frame = analysed
            self.fps = fps
            for event in events { self.apply(event) }
        }
    }

    private func apply(_ event: JuggleEvent) {
        switch event {
        case let .touch(count, part, _):
            self.count = count
            lastTouch = part
            lastEnd = nil
            if speakCount { speak("\(count)") }
        case let .runEnded(count, reason, _):
            best = max(best, count)
            lastEnd = "\(count) · \(reason.rawValue)"
            if speakCount { speak(count > 0 ? "\(count). \(reason.rawValue)" : reason.rawValue) }
        }
    }

    private func speak(_ text: String) {
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.6
        speech.speak(utterance)
    }
}

/// Writes raw camera buffers to Documents/JuggleSpike/*.mov (portrait via track transform), so
/// clips can be pulled off the phone (Files app / Finder) and fed to tools/juggle-harness.
final class SpikeClipRecorder {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private var started = false

    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("JuggleSpike", isDirectory: true)
    }

    init() throws {
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = Self.directory.appendingPathComponent("juggle-\(formatter.string(from: Date())).mov")
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720
        ])
        input.expectsMediaDataInRealTime = true
        input.transform = CGAffineTransform(rotationAngle: .pi / 2)
        writer.add(input)
    }

    func append(_ buffer: CMSampleBuffer) {
        if !started {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
            started = true
        }
        if input.isReadyForMoreMediaData { input.append(buffer) }
    }

    func finish(_ completion: @escaping (Bool) -> Void) {
        guard started else { completion(false); return }
        input.markAsFinished()
        writer.finishWriting { completion(self.writer.status == .completed) }
    }
}
#endif
