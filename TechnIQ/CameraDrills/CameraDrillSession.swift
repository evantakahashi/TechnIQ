import AVFoundation
import SwiftUI

/// One camera-drill session: capture → analyser → counter, paced by HandsFreeFlow, voiced, and each
/// finished run saved through CameraRunService. Frames are processed on the capture queue; everything
/// published here is updated on the main actor.
final class CameraDrillSession: ObservableObject {
    enum Phase: Equatable {
        case starting
        case positioning
        case countdown(Int)
        case live
        case result
        case finished
        case failed(String)
    }

    struct RunResult: Equatable {
        let count: Int
        let isPersonalBest: Bool
        let previousBest: Int?
        let xp: Int
        let coins: Int
    }

    let drill: CameraDrill
    @Published private(set) var phase: Phase = .starting
    @Published private(set) var count = 0
    @Published private(set) var inPosition = false
    /// Whole body in frame but too small for the ball to be tracked.
    @Published private(set) var tooFar = false
    @Published private(set) var timeLeft: Double?
    @Published private(set) var ball: BallSighting?
    @Published private(set) var lastResult: RunResult?
    @Published private(set) var runs: [RunResult] = []
    @Published var voiceOn = true
    /// Width / height of the upright frame, for mapping overlays.
    @Published private(set) var aspect: Double
    /// DEBUG clip playback: the current frame (there's no capture session to preview).
    @Published private(set) var previewImage: CGImage?

    var previewSession: AVCaptureSession? { source.previewSession }

    private let source: DrillFrameSource
    private let player: Player
    private let runService: CameraRunService?
    private var analyzer: FrameAnalyzer?
    // Source-queue state.
    private var flow: HandsFreeFlow
    private var counter: DrillCounter?
    private var liveStartedAt = 0.0
    private let speech = AVSpeechSynthesizer()

    /// - Parameters:
    ///   - source: frames to analyse; the back camera unless DEBUG `-TQCameraFile` names a clip.
    ///   - runService: where finished runs are recorded (`CameraRunService.shared` when nil).
    init(drill: CameraDrill, player: Player, source: DrillFrameSource? = nil, runService: CameraRunService? = nil) {
        self.drill = drill
        self.player = player
        self.runService = runService
        self.source = source ?? Self.defaultSource()
        aspect = self.source.aspect
        flow = HandsFreeFlow(mode: drill.mode, aspect: self.source.aspect)
    }

    private static func defaultSource() -> DrillFrameSource {
        #if DEBUG
        if let file = VideoFileSource.fromLaunchArguments { return file }
        #endif
        return CameraCapture()
    }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard CameraDrillSupport.isCurrentDeviceSupported else {
            phase = .failed("Camera drills need an iPhone 12 or newer.")
            return
        }
        guard let model = DrillModels.yolo, let analyzer = try? FrameAnalyzer(detector: .yolo, yoloModel: model) else {
            phase = .failed("The ball detector couldn't load.")
            return
        }
        self.analyzer = analyzer
        #if DEBUG
        (source as? VideoFileSource)?.onPreview = { [weak self] image in
            DispatchQueue.main.async { self?.previewImage = image }
        }
        #endif
        source.start(onFrame: { [weak self] buffer in self?.process(buffer) }, completion: { [weak self] error in
            // Sources call back on their queue; a clip's frame shape is only known now.
            if let self, error == nil {
                self.flow = HandsFreeFlow(mode: self.drill.mode, aspect: self.source.aspect)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                switch error {
                case .denied?: self.phase = .failed("Camera access is off. Turn it on in Settings → TechnIQ.")
                case .noCamera?: self.phase = .failed("No back camera available.")
                case nil:
                    self.aspect = self.source.aspect
                    self.phase = .positioning
                    self.say("Step into the outline")
                }
            }
        })
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        source.stop()
        speech.stopSpeaking(at: .immediate)
    }

    /// The on-screen Stop: ends a live run (it still counts) and the session.
    func endSession() {
        source.queue.async {
            // A run in progress still counts: close it at the last analysed frame.
            if self.flow.isLive, let counter = self.counter {
                self.handle(counter.finish(at: self.lastFrameTime))
            }
            DispatchQueue.main.async { self.phase = .finished }
        }
    }

    // MARK: - Source queue

    private var lastFrameTime = 0.0

    private func process(_ buffer: CMSampleBuffer) {
        #if DEBUG
        if let frame = (source as? VideoFileSource)?.precomputedFrame(for: buffer) {
            ingest(frame)
            return
        }
        #endif
        guard let analyzer else { return }
        ingest(analyzer.analyze(buffer, orientation: source.orientation))
    }

    /// One analysed frame through the flow and counter (source queue; tests call it directly).
    func ingest(_ frame: DrillFrame) {
        lastFrameTime = frame.time
        let wasLive = flow.isLive
        let cues = flow.update(pose: frame.pose, time: frame.time)

        if flow.isLive && !wasLive {
            counter = drill.makeCounter()
            liveStartedAt = frame.time
        }
        if wasLive, flow.isLive || cues.contains(.timeUp), let counter {
            handle(counter.process(frame))
            if cues.contains(.timeUp) { handle(counter.finish(at: frame.time)) }
        }

        let inPosition = frame.pose.map { HandsFreeFlow.isInPosition($0, aspect: flow.aspect) } ?? false
        let tooFar = frame.pose.map(HandsFreeFlow.isTooFar) ?? false
        let phase = Self.phase(for: flow.state, time: frame.time)
        let timeLeft = flow.timeLeft
        DispatchQueue.main.async {
            self.ball = frame.ball
            self.inPosition = inPosition
            self.tooFar = tooFar
            self.timeLeft = timeLeft
            if case .failed = self.phase { return }
            if self.phase != .finished { self.phase = phase }
            for cue in cues { self.speak(cue) }
        }
    }

    private func handle(_ events: [DrillEvent]) {
        for event in events {
            switch event {
            case let .touch(count, _, _):
                DispatchQueue.main.async {
                    self.count = count
                    self.say("\(count)")
                }
            case let .runEnded(count, _, time):
                if drill.mode == .streak { flow.runEnded(at: time) }
                let duration = time - liveStartedAt
                DispatchQueue.main.async { MainActor.assumeIsolated { self.finishRun(count: count, duration: duration) } }
            }
        }
    }

    private static func phase(for state: HandsFreeFlow.State, time: Double) -> Phase {
        switch state {
        case .positioning: return .positioning
        case let .countdown(startedAt): return .countdown(max(1, 3 - Int(time - startedAt)))
        case .live: return .live
        case .result: return .result
        case .finished: return .finished
        }
    }

    // MARK: - Main actor

    @MainActor
    private func finishRun(count: Int, duration: Double) {
        let outcome = (runService ?? .shared).record(drill: drill, count: count, duration: duration, player: player)
        let result = RunResult(count: count,
                               isPersonalBest: outcome?.isPersonalBest ?? false,
                               previousBest: outcome?.previousBest,
                               xp: outcome?.reward.xp ?? 0,
                               coins: outcome?.reward.coins ?? 0)
        lastResult = result
        runs.append(result)
        self.count = count
        if result.isPersonalBest {
            say("\(count). New best!")
        } else if count > 0 {
            say("\(count)")
        }
    }

    private func speak(_ cue: HandsFreeFlow.Cue) {
        switch cue {
        case .stepIn: say("Step into the outline")
        case .ready: count = 0; say("Ready")
        case let .countdown(n): say("\(n)")
        case .go: say("Go")
        case .timeUp: say("Time")
        case .finished: say("Done")
        }
    }

    private func say(_ text: String) {
        guard voiceOn else { return }
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.55
        speech.speak(utterance)
    }
}
