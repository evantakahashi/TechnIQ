#if DEBUG
import AVFoundation
import CoreImage

/// DEBUG stand-in for the camera: plays a recorded clip into a camera-drill session in real time, so the
/// whole session (outline → countdown → count → result → saved run) runs in the simulator.
/// `-TQCameraFile <path>` (absolute, or a file name in Documents/ or the app bundle).
///
/// Vision's body-pose request can't run in the simulator, so a `<clip>.frames.json` beside the clip
/// (`juggle-harness … --frames-out`, the same analyser run on the Mac) replaces live analysis there.
final class VideoFileSource: DrillFrameSource {
    let queue = DispatchQueue(label: "camera-drills.file", qos: .userInteractive)
    private(set) var orientation = CGImagePropertyOrientation.up
    private(set) var aspect = CameraCapture.aspect
    var previewSession: AVCaptureSession? { nil }
    /// Each frame upright, for the on-screen preview (called on `queue`).
    var onPreview: ((CGImage) -> Void)?

    private let url: URL
    /// Pre-analysed frames keyed by presentation time in milliseconds.
    private let precomputed: [Int: DrillFrame]
    private var running = false
    /// Kept alive for the whole playback (the track output needs it).
    private var reader: AVAssetReader?
    private let ciContext = CIContext()

    init(url: URL) {
        self.url = url
        let framesURL = url.deletingPathExtension().appendingPathExtension("frames.json")
        let frames = (try? Data(contentsOf: framesURL)).flatMap { try? JSONDecoder().decode([DrillFrame].self, from: $0) } ?? []
        precomputed = Dictionary(frames.map { (Self.key($0.time), $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The pre-analysed frame for `buffer`, when the clip came with one.
    func precomputedFrame(for buffer: CMSampleBuffer) -> DrillFrame? {
        precomputed[Self.key(CMSampleBufferGetPresentationTimeStamp(buffer).seconds)]
    }

    private static func key(_ time: Double) -> Int { Int((time * 1000).rounded()) }

    /// The clip named by `-TQCameraFile`, if any.
    static var fromLaunchArguments: VideoFileSource? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-TQCameraFile"), args.indices.contains(i + 1) else { return nil }
        let name = args[i + 1]
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let candidates = [URL(fileURLWithPath: name), documents?.appendingPathComponent(name),
                          Bundle.main.url(forResource: name, withExtension: nil)].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }.map(VideoFileSource.init)
    }

    func start(onFrame: @escaping (CMSampleBuffer) -> Void, completion: @escaping (CameraCapture.CaptureError?) -> Void) {
        Task {
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let transform = try? await track.load(.preferredTransform),
                  let size = try? await track.load(.naturalSize),
                  let reader = try? AVAssetReader(asset: asset) else {
                completion(.noCamera)
                return
            }
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ])
            reader.add(output)
            reader.startReading()
            queue.async {
                self.reader = reader
                self.orientation = Self.orientation(of: transform)
                let upright = [.left, .right].contains(self.orientation) ? CGSize(width: size.height, height: size.width) : size
                self.aspect = upright.width / upright.height
                self.running = true
                completion(nil)
                self.pump(output, onFrame: onFrame, startedAt: CACurrentMediaTime())
            }
        }
    }

    func stop() {
        queue.async {
            self.running = false
            self.reader?.cancelReading()
            self.reader = nil
        }
    }

    /// Delivers frames at their own timestamps, like a camera would.
    private func pump(_ output: AVAssetReaderTrackOutput, onFrame: @escaping (CMSampleBuffer) -> Void, startedAt: CFTimeInterval) {
        guard running, reader?.status == .reading, let buffer = output.copyNextSampleBuffer() else { return }
        let due = startedAt + CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        let wait = max(0, due - CACurrentMediaTime())
        queue.asyncAfter(deadline: .now() + wait) {
            guard self.running else { return }
            onFrame(buffer)
            if let onPreview = self.onPreview, let pixels = CMSampleBufferGetImageBuffer(buffer) {
                let image = CIImage(cvPixelBuffer: pixels).oriented(self.orientation)
                if let cgImage = self.ciContext.createCGImage(image, from: image.extent) { onPreview(cgImage) }
            }
            self.pump(output, onFrame: onFrame, startedAt: startedAt)
        }
    }

    private static func orientation(of t: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (t.a.rounded(), t.b.rounded(), t.c.rounded(), t.d.rounded()) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}
#endif
