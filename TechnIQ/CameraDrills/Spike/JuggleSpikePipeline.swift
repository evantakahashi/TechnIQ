#if DEBUG
import AVFoundation
import CoreML
import SwiftUI

/// Phase-1 spike: back camera → FrameAnalyzer → JuggleCounter, all on device, plus optional clip
/// recording for the harness. Frames are processed on the capture queue; UI state is published on main.
final class JuggleSpikePipeline: ObservableObject {
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

    private let capture = CameraCapture()
    var session: AVCaptureSession { capture.session }
    private var videoQueue: DispatchQueue { capture.queue }
    private var analyzer: FrameAnalyzer?
    private var counter = JuggleCounter()
    private var recorder: SpikeClipRecorder?
    private var frameTimes: [CFTimeInterval] = []
    private let speech = AVSpeechSynthesizer()

    func start() {
        capture.start(onFrame: { [weak self] buffer in self?.process(buffer) }, completion: { [weak self] error in
            guard let self else { return }
            switch error {
            case .denied?: DispatchQueue.main.async { self.error = "Camera access denied — enable it in Settings." }
            case .noCamera?: DispatchQueue.main.async { self.error = "No back camera." }
            case nil: self.makeAnalyzer()
            }
        })
    }

    func stop() {
        videoQueue.async {
            if self.recorder != nil { self.finishRecording() }
        }
        capture.stop()
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

    // MARK: - Capture queue

    private func makeAnalyzer() {
        do {
            analyzer = try FrameAnalyzer(detector: detector, yoloModel: DrillModels.yolo)
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

    private func process(_ sampleBuffer: CMSampleBuffer) {
        recorder?.append(sampleBuffer)
        guard let analyzer else { return }
        let analysed = analyzer.analyze(sampleBuffer, orientation: CameraCapture.orientation)
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

    private func apply(_ event: DrillEvent) {
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
