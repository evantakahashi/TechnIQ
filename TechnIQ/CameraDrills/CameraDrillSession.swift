import AVFoundation
import CoreImage
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
        /// Why it ended, said plainly ("Ended: thigh touch (feet only)").
        var endLine = ""
        /// A rule was broken (not just the ball dropping): shown as a failure.
        var brokeRule = false
        /// What the camera noticed about the run ("Right foot sends it 40% higher than your left").
        var insights: [String] = []
    }

    let drill: CameraDrill
    @Published private(set) var phase: Phase = .starting
    @Published private(set) var count = 0
    @Published private(set) var inPosition = false
    /// Why a visible player isn't in position (too small, head or feet cut off, off to the side).
    @Published private(set) var positionHint: HandsFreeFlow.PositionHint?
    #if DEBUG
    /// Positioning numbers for on-device debugging: buffer size, body height, nose / ankle.
    @Published private(set) var debugLine = ""
    private var bufferSize = ""
    #endif
    @Published private(set) var timeLeft: Double?
    @Published private(set) var ball: BallSighting?
    @Published private(set) var lastResult: RunResult?
    @Published private(set) var runs: [RunResult] = []
    /// How runs usually end this session, once there are a few ("3 of 4 runs ended on a thigh touch").
    @Published private(set) var sessionLine: String?
    @Published var voiceOn = true
    /// Width / height of the upright frame, for mapping overlays.
    @Published private(set) var aspect: Double
    /// DEBUG clip playback: the current frame (there's no capture session to preview).
    @Published private(set) var previewImage: CGImage?

    var previewSession: AVCaptureSession? { source.previewSession }
    var isMirrored: Bool { source.isMirrored }

    private let source: DrillFrameSource
    private let player: Player
    private let runService: CameraRunService?
    private var analyzer: FrameAnalyzer?
    // Source-queue state.
    private var flow: HandsFreeFlow
    private var counter: DrillCounter?
    private var recorder = RunRecorder()
    private var sessionStats: [RunStats] = []
    private var liveStartedAt = 0.0
    private let speech = AVSpeechSynthesizer()

    /// - Parameters:
    ///   - source: frames to analyse; the front camera unless DEBUG `-TQCameraFile` names a clip.
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
        guard let model = DrillModels.yolo, let analyzer = try? FrameAnalyzer(detector: .yolo, yoloModel: model, stillBall: drill.ballRests) else {
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
                case .noCamera?: self.phase = .failed("No front camera available.")
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
                let closing = counter.finish(at: self.lastFrameTime)
                self.handle(closing, stats: self.recorder.record(DrillFrame(time: self.lastFrameTime), events: closing))
            }
            DispatchQueue.main.async { self.phase = .finished }
        }
    }

    // MARK: - Source queue

    private var lastFrameTime = 0.0
    #if DEBUG
    private let debugDump = CameraDebugDump()
    #endif

    private func process(_ buffer: CMSampleBuffer) {
        #if DEBUG
        if let frame = (source as? VideoFileSource)?.precomputedFrame(for: buffer) {
            ingest(frame)
            return
        }
        #endif
        guard let analyzer else { return }
        #if DEBUG
        if let pixels = CMSampleBufferGetImageBuffer(buffer) {
            bufferSize = "\(CVPixelBufferGetWidth(pixels))×\(CVPixelBufferGetHeight(pixels))"
        }
        #endif
        let frame = analyzer.analyze(buffer, orientation: source.orientation)
        #if DEBUG
        debugDump.record(buffer, orientation: source.orientation, frame: frame)
        #endif
        ingest(frame)
    }

    /// One analysed frame through the flow and counter (source queue; tests call it directly).
    func ingest(_ frame: DrillFrame) {
        lastFrameTime = frame.time
        let wasLive = flow.isLive
        let cues = flow.update(pose: frame.pose, time: frame.time)

        if flow.isLive && !wasLive {
            counter = drill.makeCounter(dominantFoot: player.dominantFoot)
            recorder = RunRecorder()
            liveStartedAt = frame.time
        }
        if wasLive, flow.isLive || cues.contains(.timeUp), let counter {
            let events = counter.process(frame)
            handle(events, stats: recorder.record(frame, events: events))
            if cues.contains(.timeUp) {
                let closing = counter.finish(at: frame.time)
                handle(closing, stats: recorder.record(frame, events: closing))
            }
        }

        let inPosition = frame.pose.map { HandsFreeFlow.isInPosition($0, aspect: flow.aspect) } ?? false
        let hint = frame.pose.flatMap { HandsFreeFlow.positionHint($0, aspect: flow.aspect) }
        #if DEBUG
        let nose = frame.pose?[.nose]?.y, ankle = [frame.pose?[.leftAnkle], frame.pose?[.rightAnkle]].compactMap { $0?.y }.min()
        let fmt = { (v: Double?) in v.map { String(format: "%.2f", $0) } ?? "–" }
        let debug = "\(bufferSize) · joints \(frame.pose?.joints.count ?? 0) · nose \(fmt(nose)) · ankle \(fmt(ankle))"
            + " · body \(nose.flatMap { n in ankle.map { a in String(format: "%.0f%%", 100 * (n - a)) } } ?? "–")"
            + " · ball \(frame.ball == nil ? "no" : "yes")"
        #endif
        let phase = phase(for: flow.state, time: frame.time)
        let timeLeft = flow.timeLeft
        DispatchQueue.main.async {
            self.ball = frame.ball
            self.inPosition = inPosition
            self.positionHint = hint
            #if DEBUG
            self.debugLine = debug
            #endif
            self.timeLeft = timeLeft
            if case .failed = self.phase { return }
            if self.phase != .finished { self.phase = phase }
            for cue in cues { self.speak(cue) }
        }
    }

    /// - Parameter stats: the runs `events` ended, from the recorder (runs with no touches have none).
    private func handle(_ events: [DrillEvent], stats: [RunStats] = []) {
        var finished = stats
        for event in events {
            #if DEBUG
            debugDump.event("\(event)")
            #endif
            switch event {
            case let .touch(count, _, _, _):
                DispatchQueue.main.async {
                    self.count = count
                    self.say("\(count)")
                }
            case let .runEnded(count, reason, time):
                if drill.mode == .streak { flow.runEnded(at: time) }
                let duration = time - liveStartedAt
                let run = finished.first(where: { $0.count == count }) ?? RunStats(count: count, endReason: reason, touches: [])
                finished.removeAll { $0 == run }
                if count > 0 { sessionStats.append(run) }
                let sessionLine = RunStats.sessionLine(sessionStats)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.finishRun(count: count, duration: duration, stats: run, sessionLine: sessionLine) }
                }
            }
        }
    }

    private func phase(for state: HandsFreeFlow.State, time: Double) -> Phase {
        switch state {
        case .positioning: return .positioning
        case let .countdown(startedAt): return .countdown(flow.countdownNumber(startedAt: startedAt, time: time))
        case .live: return .live
        case .result: return .result
        case .finished: return .finished
        }
    }

    // MARK: - Main actor

    @MainActor
    private func finishRun(count: Int, duration: Double, stats: RunStats, sessionLine: String?) {
        let outcome = (runService ?? .shared).record(drill: drill, count: count, duration: duration, player: player)
        let brokeRule = Self.ruleCall[stats.endReason ?? .stopped] != nil
        let result = RunResult(count: count,
                               isPersonalBest: outcome?.isPersonalBest ?? false,
                               previousBest: outcome?.previousBest,
                               xp: outcome?.reward.xp ?? 0,
                               coins: outcome?.reward.coins ?? 0,
                               endLine: stats.endLine,
                               brokeRule: brokeRule,
                               insights: stats.insights)
        lastResult = result
        runs.append(result)
        self.sessionLine = sessionLine
        self.count = count
        // The judge says why first: "Thigh. 7."
        let call = stats.endReason.flatMap { Self.ruleCall[$0] }.map { "\($0). " } ?? ""
        if result.isPersonalBest {
            say("\(call)\(count). New best!")
        } else if count > 0 || !call.isEmpty {
            say("\(call)\(count)")
        }
    }

    /// What the judge says out loud when a run ends on a rule (the ball dropping isn't a call).
    private static let ruleCall: [RunEndReason: String] = [
        .handball: "Hands", .wrongFoot: "Wrong foot", .thighTouch: "Thigh", .chestTouch: "Chest",
        .headTouch: "Header", .tooHigh: "Too high"
    ]

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

#if DEBUG
/// Saves what the analyser saw, about once a second, to Documents/CameraDebug (frame_NN.jpg + .json with
/// the pose and ball, last 40 kept) so a device session can be pulled off and inspected on the Mac:
/// `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier
/// evan.TechnIQ --source Documents/CameraDebug --destination <dir>`. Also logs every analysed frame to
/// frames.jsonl (replayable through the counters on the Mac) and every counter event to events.txt.
/// Source queue only.
final class CameraDebugDump {
    private let directory: URL
    private let context = CIContext()
    private var frames = 0
    private var saved = 0
    private var frameLog: FileHandle?
    private var eventLog: FileHandle?
    private let encoder = JSONEncoder()

    /// Each session gets its own folder (CameraDebug/<time>); the last 5 are kept.
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("CameraDebug", isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        directory = root.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        let old = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
        for name in old.dropLast(4) { try? FileManager.default.removeItem(at: root.appendingPathComponent(name)) }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        frameLog = Self.open(directory.appendingPathComponent("frames.jsonl"))
        eventLog = Self.open(directory.appendingPathComponent("events.txt"))
    }

    private static func open(_ url: URL) -> FileHandle? {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try? FileHandle(forWritingTo: url)
    }

    func event(_ text: String) {
        eventLog?.write(Data((text + "\n").utf8))
    }

    func record(_ buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation, frame: DrillFrame) {
        frames += 1
        if let line = try? encoder.encode(frame) { frameLog?.write(line + Data("\n".utf8)) }
        guard frames % 30 == 1, let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        let name = String(format: "frame_%02d", saved % 40)
        saved += 1
        let image = CIImage(cvPixelBuffer: pixels).oriented(orientation)
        if let space = CGColorSpace(name: CGColorSpace.sRGB) {
            try? context.writeJPEGRepresentation(of: image, to: directory.appendingPathComponent(name + ".jpg"),
                                                 colorSpace: space, options: [:])
        }
        try? JSONEncoder().encode(frame).write(to: directory.appendingPathComponent(name + ".json"))
    }
}
#endif
