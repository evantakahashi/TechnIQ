// Replays recorded juggling clips through the app's counting pipeline and scores it.
//
//   swift run -c release --package-path tools/juggle-harness juggle-harness <clips-dir> \
//       [--detector trajectory|yolo|both] [--model path/to/yolo11n.mlpackage] [--conf 0.1] [--dump] [--frames-out dir]
//
// <clips-dir>/labels.csv:  file,count   (one attempt per clip; count = true touches)
// Phase-1 gate: ≥ 90% of clips within ±1.

import AVFoundation
import CoreML
import Foundation
@testable import JuggleCore

struct Options {
    var clipsDir: URL
    var detectors: [FrameAnalyzer.Detector] = [.trajectory, .yolo]
    var modelPath: String?
    var dump = false
    /// Writes each clip's analysed frames to `<clip>.frames.json` here (replayed by the app's DEBUG
    /// `-TQCameraFile`, since Vision pose doesn't run in the simulator).
    var framesOut: URL?
}

func parseOptions() -> Options {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let dir = args.first, !dir.hasPrefix("--") else {
        print("usage: juggle-harness <clips-dir> [--detector trajectory|yolo|both] [--model yolo11n.mlpackage] [--conf 0.1] [--dump] [--frames-out dir]")
        exit(2)
    }
    args.removeFirst()
    var options = Options(clipsDir: URL(fileURLWithPath: dir))
    while let flag = args.first {
        args.removeFirst()
        switch flag {
        case "--detector":
            let value = args.isEmpty ? "both" : args.removeFirst()
            options.detectors = value == "both" ? [.trajectory, .yolo] : [FrameAnalyzer.Detector(rawValue: value)].compactMap { $0 }
        case "--model": options.modelPath = args.isEmpty ? nil : args.removeFirst()
        case "--conf": FrameAnalyzer.ballConfidence = args.isEmpty ? FrameAnalyzer.ballConfidence : Double(args.removeFirst()) ?? FrameAnalyzer.ballConfidence
        case "--dump": options.dump = true
        case "--frames-out": options.framesOut = args.isEmpty ? nil : URL(fileURLWithPath: args.removeFirst())
        default: print("unknown flag \(flag)"); exit(2)
        }
    }
    return options
}

func loadLabels(in dir: URL) -> [(file: String, count: Int)] {
    guard let text = try? String(contentsOf: dir.appendingPathComponent("labels.csv"), encoding: .utf8) else {
        print("missing \(dir.path)/labels.csv"); exit(2)
    }
    return text.split(whereSeparator: \.isNewline).compactMap { line in
        let cols = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cols.count >= 2, let count = Int(cols[1]) else { return nil }  // skips the header
        return (cols[0], count)
    }
}

func loadYOLO(_ path: String?) -> MLModel? {
    guard let path else { return nil }
    do {
        let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: path))
        return try MLModel(contentsOf: compiled)
    } catch {
        print("could not load model at \(path): \(error)"); exit(2)
    }
}

/// Width / height of the upright frame.
func aspect(of track: AVAssetTrack, orientation: CGImagePropertyOrientation) -> Double {
    let size = track.naturalSize
    return [.left, .right].contains(orientation) ? size.height / size.width : size.width / size.height
}

/// Orientation that makes a recorded track upright (iPhone portrait video is stored landscape + rotated).
func orientation(of track: AVAssetTrack) async -> CGImagePropertyOrientation {
    guard let t = try? await track.load(.preferredTransform) else { return .up }
    switch (t.a.rounded(), t.b.rounded(), t.c.rounded(), t.d.rounded()) {
    case (0, 1, -1, 0): return .right
    case (0, -1, 1, 0): return .left
    case (-1, 0, 0, -1): return .down
    default: return .up
    }
}

struct ClipResult {
    var predicted: Int
    var runs: [Int]
    var frames: Int
    var ballFrames: Int
    var poseFrames: Int
    var unknownTouches: Int
    var seconds: Double
    var inPositionFrames = 0
}

func analyze(clip url: URL, detector: FrameAnalyzer.Detector, model: MLModel?, dump: Bool, framesOut: URL? = nil) async throws -> ClipResult {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw NSError(domain: "harness", code: 1, userInfo: [NSLocalizedDescriptionKey: "no video track"])
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    ])
    reader.add(output)
    reader.startReading()

    let imageOrientation = await orientation(of: track)
    let analyzer = try FrameAnalyzer(detector: detector, yoloModel: model)
    let counter = JuggleCounter()
    let flow = HandsFreeFlow(mode: .streak, aspect: aspect(of: track, orientation: imageOrientation))
    var inPositionFrames = 0
    var analysed: [DrillFrame] = []
    var result = ClipResult(predicted: 0, runs: [], frames: 0, ballFrames: 0, poseFrames: 0, unknownTouches: 0, seconds: 0)
    var lastTime = 0.0
    let start = Date()

    func record(_ events: [DrillEvent]) {
        for event in events {
            switch event {
            case let .touch(_, part, _): if part == .unknown { result.unknownTouches += 1 }
            case let .runEnded(count, _, _): result.runs.append(count)
            }
            if dump { print("    event \(event)") }
        }
    }

    while let buffer = output.copyNextSampleBuffer() {
        let frame = analyzer.analyze(buffer, orientation: imageOrientation)
        result.frames += 1
        if framesOut != nil { analysed.append(frame) }
        if frame.ball != nil { result.ballFrames += 1 }
        if frame.pose != nil { result.poseFrames += 1 }
        lastTime = frame.time
        if dump {
            let b = frame.ball.map { String(format: "%.3f,%.3f,%.4f", $0.center.x, $0.center.y, $0.radius) } ?? ",,"
            print(String(format: "    %.3f,%@,%d", frame.time, b, frame.pose?.joints.count ?? 0))
        }
        record(counter.process(frame))
        if let pose = frame.pose, HandsFreeFlow.isInPosition(pose, aspect: flow.aspect) { inPositionFrames += 1 }
        let cues = flow.update(pose: frame.pose, time: frame.time)
        if dump, !cues.isEmpty { print("    flow \(cues) at \(String(format: "%.2f", frame.time))") }
    }
    record(counter.finish(at: lastTime))
    result.inPositionFrames = inPositionFrames
    if let framesOut {
        let file = framesOut.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".frames.json")
        try JSONEncoder().encode(analysed).write(to: file)
    }
    result.seconds = Date().timeIntervalSince(start)
    result.predicted = result.runs.max() ?? 0
    return result
}

let options = parseOptions()
let labels = loadLabels(in: options.clipsDir)
let model = options.detectors.contains(.yolo) ? loadYOLO(options.modelPath) : nil
if options.detectors.contains(.yolo), model == nil {
    print("--detector yolo needs --model path/to/yolo11n.mlpackage"); exit(2)
}

for detector in options.detectors {
    print("\n=== detector: \(detector.rawValue) ===")
    print("clip".padding(toLength: 28, withPad: " ", startingAt: 0) + " true  pred   err  runs        ball%  pose%  inpos%  unk  fps")
    var within1 = 0, absErrors: [Int] = []
    for (file, truth) in labels {
        let url = options.clipsDir.appendingPathComponent(file)
        do {
            let r = try await analyze(clip: url, detector: detector, model: model, dump: options.dump, framesOut: options.framesOut)
            let err = r.predicted - truth
            absErrors.append(abs(err))
            if abs(err) <= 1 { within1 += 1 }
            let pct = { (n: Int) in r.frames == 0 ? 0 : 100 * n / r.frames }
            print(String(format: "%@ %5d %5d %+5d  %@ %5d%% %5d%% %6d%% %4d %4.0f",
                         file.padding(toLength: 28, withPad: " ", startingAt: 0), truth, r.predicted, err,
                         r.runs.map(String.init).joined(separator: ",").padding(toLength: 10, withPad: " ", startingAt: 0),
                         pct(r.ballFrames), pct(r.poseFrames), pct(r.inPositionFrames), r.unknownTouches, Double(r.frames) / max(r.seconds, 0.001)))
        } catch {
            print("\(file): \(error.localizedDescription)")
        }
    }
    guard !absErrors.isEmpty else { continue }
    let rate = 100 * Double(within1) / Double(absErrors.count)
    let mae = Double(absErrors.reduce(0, +)) / Double(absErrors.count)
    print(String(format: "within ±1: %d/%d (%.0f%%)  mean |err|: %.2f  gate (≥90%%): %@",
                 within1, absErrors.count, rate, mae, rate >= 90 ? "PASS" : "FAIL"))
}
