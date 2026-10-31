// Replays recorded shots (slo-mo clips) through ShotAnalyzer and scores them against hand-marked truth.
//
//   swift run -c release --package-path tools/juggle-harness shot-harness <clips-dir> --model BallDetector.mlpackage \
//       [--vfov 69] [--fps 240] [--dump]
//
// <clips-dir>/shots.csv:        file,spot,kick,cross,zone   (spot = penalty | edgeOfBox; kick / cross = seconds into
//                               the clip, hand-marked; zone = "column,row" (0–2, from bottom-left) | wideLeft | wideRight
//                               | over; truth columns may be blank)
// <clips-dir>/<clip>.goal.json: {"topLeft": {"x": px, "y": px}, "topRight": …, "bottomRight": …, "bottomLeft": …}
//                               goal-mouth corners in the upright frame, pixels from the top-left.
// --vfov: the camera's field of view along the frame height; without it the focal length comes from the
//         resting ball (ShotGeometry.estimateFocal). --fps: frame times from the frame index (for exports whose
//         timestamps were slowed down); default uses the file's timestamps.
// Phase S1 gate: speed within ±5% on ≥ 90% of shots, zone right on ≥ 90%.

import AVFoundation
import CoreImage
import CoreML
import Foundation
import Vision
@testable import JuggleCore

struct Options {
    var clipsDir: URL
    var modelPath: String?
    var verticalFOV: Double?
    var fps: Double?
    var dump = false
}

func parseOptions() -> Options {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let dir = args.first, !dir.hasPrefix("--") else {
        print("usage: shot-harness <clips-dir> --model BallDetector.mlpackage [--vfov 69] [--fps 240] [--dump]")
        exit(2)
    }
    args.removeFirst()
    var options = Options(clipsDir: URL(fileURLWithPath: dir))
    while let flag = args.first {
        args.removeFirst()
        switch flag {
        case "--model": options.modelPath = args.isEmpty ? nil : args.removeFirst()
        case "--vfov": options.verticalFOV = args.isEmpty ? nil : Double(args.removeFirst())
        case "--fps": options.fps = args.isEmpty ? nil : Double(args.removeFirst())
        case "--dump": options.dump = true
        default: print("unknown flag \(flag)"); exit(2)
        }
    }
    return options
}

struct ShotTruth {
    var file: String
    var spot: ShotSpot
    var kick: Double?
    var cross: Double?
    var zone: String?
}

func loadShots(in dir: URL) -> [ShotTruth] {
    guard let text = try? String(contentsOf: dir.appendingPathComponent("shots.csv"), encoding: .utf8) else {
        print("missing \(dir.path)/shots.csv"); exit(2)
    }
    return text.split(whereSeparator: \.isNewline).compactMap { line in
        let cols = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard cols.count >= 2, let spot = ShotSpot(rawValue: cols[1]) else { return nil }  // skips the header
        let value = { (i: Int) in i < cols.count ? Double(cols[i]) : nil }
        let zone = cols.count > 4 ? cols[4...].joined(separator: ",") : ""
        return ShotTruth(file: cols[0], spot: spot, kick: value(2), cross: value(3), zone: zone.isEmpty ? nil : zone)
    }
}

struct PixelCorners: Codable {
    struct Point: Codable { var x, y: Double }
    var topLeft, topRight, bottomRight, bottomLeft: Point

    /// Upright pixel corners → DrillPoints (y up, image-height units).
    func corners(height: Double) -> GoalCorners {
        let p = { (q: Point) in DrillPoint(x: q.x / height, y: 1 - q.y / height) }
        return GoalCorners(topLeft: p(topLeft), topRight: p(topRight), bottomRight: p(bottomRight), bottomLeft: p(bottomLeft))
    }
}

func loadModel(_ path: String?) -> VNCoreMLModel {
    guard let path else { print("--model is required"); exit(2) }
    do {
        let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: path))
        let model = try VNCoreMLModel(for: MLModel(contentsOf: compiled))
        // Same thresholds as the app's FrameAnalyzer (the NMS stage defaults to 0.25).
        model.featureProvider = try? MLDictionaryFeatureProvider(dictionary: [
            "confidenceThreshold": FrameAnalyzer.ballConfidence, "iouThreshold": 0.45
        ])
        return model
    } catch {
        print("could not load model at \(path): \(error)"); exit(2)
    }
}

func orientation(of track: AVAssetTrack) async -> CGImagePropertyOrientation {
    guard let t = try? await track.load(.preferredTransform) else { return .up }
    switch (t.a.rounded(), t.b.rounded(), t.c.rounded(), t.d.rounded()) {
    case (0, 1, -1, 0): return .right
    case (0, -1, 1, 0): return .left
    case (-1, 0, 0, -1): return .down
    default: return .up
    }
}

/// Ball detector run on the whole frame and on a crop around the goal, where the ball is only a few pixels.
final class ShotBallFinder {
    private let model: VNCoreMLModel
    private let labels: Set<String> = ["ball", "sports ball"]
    private var last: (time: Double, ball: BallSighting)?

    init(model: VNCoreMLModel) { self.model = model }

    func find(in image: CIImage, goalCrop: CGRect, time: Double) -> BallSighting? {
        let candidates = detect(image, crop: image.extent) + detect(image, crop: goalCrop)
        let pick: BallSighting?
        if let last, time - last.time < 0.1 {
            pick = candidates.min { $0.center.distance(to: last.ball.center) < $1.center.distance(to: last.ball.center) }
        } else {
            pick = candidates.max { $0.confidence < $1.confidence }
        }
        if let pick { last = (time, pick) }
        return pick
    }

    /// Detections in `crop` (pixels, origin bottom-left as CIImage), returned in full-frame DrillPoints.
    private func detect(_ image: CIImage, crop: CGRect) -> [BallSighting] {
        let full = image.extent
        let region = crop.intersection(full)
        guard region.width > 8, region.height > 8 else { return [] }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(ciImage: image.cropped(to: region).transformed(by: .init(translationX: -region.minX, y: -region.minY)))
        try? handler.perform([request])
        let h = full.height
        return (request.results as? [VNRecognizedObjectObservation] ?? []).compactMap { obs in
            guard let label = obs.labels.first(where: { labels.contains($0.identifier) }), label.confidence >= 0.1 else { return nil }
            let box = obs.boundingBox
            let x = region.minX + box.midX * region.width, y = region.minY + box.midY * region.height
            let radius = (box.width * region.width + box.height * region.height) / 4
            return BallSighting(center: DrillPoint(x: x / h, y: y / h), radius: radius / h, confidence: Double(label.confidence))
        }
    }
}

struct ClipShot {
    var result: ShotResult?
    var focal: Double?
    var frames: Int
    var ballFrames: Int
    var seconds: Double
}

func analyze(_ shot: ShotTruth, dir: URL, model: VNCoreMLModel, options: Options) async throws -> ClipShot {
    let url = dir.appendingPathComponent(shot.file)
    let goalURL = url.deletingPathExtension().appendingPathExtension("goal.json")
    let pixelCorners = try JSONDecoder().decode(PixelCorners.self, from: Data(contentsOf: goalURL))
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw NSError(domain: "shot-harness", code: 1, userInfo: [NSLocalizedDescriptionKey: "no video track"])
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    reader.add(output)
    reader.startReading()
    let imageOrientation = await orientation(of: track)
    let start = Date()

    var frames: [DrillFrame] = []
    var finder: ShotBallFinder?
    var corners: GoalCorners?
    var aspect = 1.0
    var goalCrop = CGRect.zero
    while let buffer = output.copyNextSampleBuffer() {
        guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { continue }
        let image = CIImage(cvPixelBuffer: pixels).oriented(imageOrientation)
        if corners == nil {
            let w = image.extent.width, h = image.extent.height
            aspect = w / h
            let goal = pixelCorners.corners(height: h)
            corners = goal
            // Goal mouth in CIImage pixels (origin bottom-left), widened for wides and overs.
            let xs = [goal.topLeft.x, goal.topRight.x, goal.bottomRight.x, goal.bottomLeft.x].map { $0 * h }
            let ys = [goal.topLeft.y, goal.topRight.y, goal.bottomRight.y, goal.bottomLeft.y].map { $0 * h }
            let gw = xs.max()! - xs.min()!, gh = ys.max()! - ys.min()!
            goalCrop = CGRect(x: xs.min()! - 0.5 * gw, y: ys.min()! - 0.5 * gh, width: 2 * gw, height: 2.5 * gh)
            finder = ShotBallFinder(model: model)
        }
        let time = options.fps.map { Double(frames.count) / $0 } ?? CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        let ball = finder?.find(in: image, goalCrop: goalCrop, time: time)
        frames.append(DrillFrame(time: time, ball: ball))
        if options.dump {
            let b = ball.map { String(format: "%.4f,%.4f,%.5f,%.2f", $0.center.x, $0.center.y, $0.radius, $0.confidence) } ?? ",,,"
            print(String(format: "    %.4f,%@", time, b))
        }
    }
    let seconds = Date().timeIntervalSince(start)
    let ballFrames = frames.filter { $0.ball != nil }.count
    guard let corners else { return ClipShot(result: nil, focal: nil, frames: 0, ballFrames: 0, seconds: seconds) }

    let focal: Double?
    if let vfov = options.verticalFOV {
        focal = ShotCamera(verticalFOV: vfov, aspect: aspect).focal
    } else if let resting = frames.prefix(30).compactMap(\.ball).first {
        focal = ShotGeometry.estimateFocal(corners: corners, aspect: aspect, restingBall: resting, spot: shot.spot)
    } else {
        focal = nil
    }
    guard let focal else { return ClipShot(result: nil, focal: nil, frames: frames.count, ballFrames: ballFrames, seconds: seconds) }
    let camera = ShotCamera(focal: focal, aspect: aspect)
    let result = GoalPose(corners: corners, camera: camera).flatMap {
        ShotAnalyzer(camera: camera, goal: $0, spot: shot.spot).analyze(frames)
    }
    return ClipShot(result: result, focal: focal, frames: frames.count, ballFrames: ballFrames, seconds: seconds)
}

func zoneName(_ placement: ShotPlacement) -> String {
    switch placement {
    case let .onTarget(column, row): return "\(column),\(row)"
    case .wideLeft: return "wideLeft"
    case .wideRight: return "wideRight"
    case .over: return "over"
    }
}

/// Truth speed: spot → the middle of the marked zone, over the marked flight time.
func truthSpeed(_ shot: ShotTruth) -> Double? {
    guard let kick = shot.kick, let cross = shot.cross, cross > kick else { return nil }
    var lateral = 0.0, height = 1.0
    if let zone = shot.zone {
        let parts = zone.split(separator: ",").compactMap { Double($0) }
        if parts.count == 2 {
            lateral = (parts[0] + 0.5) * GoalPose.width / 3 - GoalPose.width / 2
            height = (parts[1] + 0.5) * GoalPose.height / 3
        }
    }
    let distance = (shot.spot.distance * shot.spot.distance + lateral * lateral + (height - 0.11) * (height - 0.11)).squareRoot()
    return distance / (cross - kick)
}

let options = parseOptions()
let model = loadModel(options.modelPath)
let shots = loadShots(in: options.clipsDir)
print("clip".padding(toLength: 28, withPad: " ", startingAt: 0) + "  km/h  truth   err%  flight  zone       truth-zone  ball%  focal   fps")
var speedOK = 0, speedTotal = 0, zoneOK = 0, zoneTotal = 0
for shot in shots {
    do {
        let r = try await analyze(shot, dir: options.clipsDir, model: model, options: options)
        let kmh = r.result.map { $0.kilometresPerHour }
        let truth = truthSpeed(shot).map { $0 * 3.6 }
        var err = ""
        if let truth {
            speedTotal += 1
            if let kmh {
                let e = 100 * (kmh / truth - 1)
                err = String(format: "%+.1f", e)
                if abs(e) <= 5 { speedOK += 1 }
            }
        }
        let zone = r.result.map { zoneName($0.placement) } ?? "-"
        if let truthZone = shot.zone {
            zoneTotal += 1
            if zone == truthZone { zoneOK += 1 }
        }
        print(String(format: "%@ %5@ %6@ %6@  %6@  %@ %@ %5d%% %6@ %5.0f",
                     shot.file.padding(toLength: 28, withPad: " ", startingAt: 0),
                     kmh.map { String(format: "%.1f", $0) } ?? "-", truth.map { String(format: "%.1f", $0) } ?? "-", err,
                     r.result.map { String(format: "%.3f", $0.flightTime) } ?? "-",
                     zone.padding(toLength: 10, withPad: " ", startingAt: 0),
                     (shot.zone ?? "-").padding(toLength: 11, withPad: " ", startingAt: 0),
                     r.frames == 0 ? 0 : 100 * r.ballFrames / r.frames,
                     r.focal.map { String(format: "%.3f", $0) } ?? "-", Double(r.frames) / max(r.seconds, 0.001)))
    } catch {
        print("\(shot.file): \(error.localizedDescription)")
    }
}
if speedTotal > 0 || zoneTotal > 0 {
    let pct = { (ok: Int, total: Int) in total == 0 ? 0 : 100 * Double(ok) / Double(total) }
    let pass = pct(speedOK, speedTotal) >= 90 && pct(zoneOK, zoneTotal) >= 90
    print(String(format: "speed within ±5%%: %d/%d (%.0f%%)  zone right: %d/%d (%.0f%%)  gate: %@",
                 speedOK, speedTotal, pct(speedOK, speedTotal), zoneOK, zoneTotal, pct(zoneOK, zoneTotal), pass ? "PASS" : "FAIL"))
}
