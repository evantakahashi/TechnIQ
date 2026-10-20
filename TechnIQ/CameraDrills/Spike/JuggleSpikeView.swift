#if DEBUG
import AVFoundation
import SwiftUI

/// Phase-1 juggling spike (DEBUG only): live count + overlays + fps, detector A/B, clip capture.
/// Open from You → Juggle spike, or launch with `-TQScreen jugglespike`.
struct JuggleSpikeView: View {
    @StateObject private var pipeline = JuggleSpikePipeline()
    @Environment(\.dismiss) private var dismiss
    @State private var detectorIndex = 1

    private static let detectors = FrameAnalyzer.Detector.allCases
    /// 720×1280 portrait buffers.
    private static let aspect = 720.0 / 1280.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let size = fittedSize(in: geo.size)
                ZStack {
                    SpikeCameraPreview(session: pipeline.session)
                    overlay(size: size)
                }
                .frame(width: size.width, height: size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.sm) {
                header
                Spacer()
                countPanel
                controls
            }
            .padding(DesignSystem.Spacing.md)
        }
        .onAppear { pipeline.start() }
        .onDisappear { pipeline.stop() }
        .onChange(of: detectorIndex) { _, index in pipeline.detector = Self.detectors[index] }
        .statusBarHidden()
    }

    private var header: some View {
        HStack {
            TQIconButton("xmark", accessibilityLabel: "Close") { dismiss() }
            Spacer()
            Text(String(format: "%.0f fps", pipeline.fps))
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(pipeline.fps >= 28 ? DesignSystem.Colors.grass : DesignSystem.Colors.error)
                .padding(DesignSystem.Spacing.xs)
                .background(Color.black.opacity(0.6))
        }
    }

    private var countPanel: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("\(pipeline.count)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(statusLine)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(.white.opacity(0.85))
            if let error = pipeline.error {
                Text(error).font(DesignSystem.Typography.bodySmall).foregroundColor(DesignSystem.Colors.error)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.black.opacity(0.45))
    }

    private var statusLine: String {
        var parts = ["best \(pipeline.best)"]
        if let touch = pipeline.lastTouch { parts.append("last: \(touch.rawValue)") }
        if let end = pipeline.lastEnd { parts.append("ended \(end)") }
        if pipeline.savedClips > 0 { parts.append("\(pipeline.savedClips) clips saved") }
        return parts.joined(separator: " · ")
    }

    private var controls: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            TQSegment(options: Self.detectors.map(\.rawValue), selectedIndex: $detectorIndex)
            HStack(spacing: DesignSystem.Spacing.sm) {
                TQButton(pipeline.isRecording ? "Stop clip" : "Record clip",
                         icon: pipeline.isRecording ? "stop.fill" : "record.circle",
                         style: pipeline.isRecording ? .destructive : .primary) { pipeline.toggleRecording() }
                TQButton("Reset", style: .raised, fullWidth: false) { pipeline.resetRun() }
                TQButton(pipeline.speakCount ? "Voice on" : "Voice off", style: .ghost, fullWidth: false) {
                    pipeline.speakCount.toggle()
                }
            }
        }
    }

    // MARK: - Overlay

    private func fittedSize(in container: CGSize) -> CGSize {
        let width = min(container.width, container.height * Self.aspect)
        return CGSize(width: width, height: width / Self.aspect)
    }

    private func overlay(size: CGSize) -> some View {
        Canvas { context, _ in
            guard let frame = pipeline.frame else { return }
            func point(_ p: DrillPoint) -> CGPoint {
                CGPoint(x: p.x / Self.aspect * size.width, y: (1 - p.y) * size.height)
            }
            if let pose = frame.pose {
                for joint in pose.joints.values {
                    let c = point(joint)
                    context.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)),
                                 with: .color(DesignSystem.Colors.cone))
                }
            }
            if let ball = frame.ball {
                let c = point(ball.center)
                let r = ball.radius * size.height
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(DesignSystem.Colors.grass), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
    }
}

/// AVCaptureVideoPreviewLayer host; the parent sizes it to the buffer's 9:16 so overlays line up.
private struct SpikeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
#endif
