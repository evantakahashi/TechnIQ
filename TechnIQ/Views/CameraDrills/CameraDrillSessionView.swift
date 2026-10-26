import AVFoundation
import SwiftUI

// MARK: - Camera drill session (full screen)
//
// Hands-free: the player is 3–4 m away, so everything is big and spoken. Stand in the outline →
// 3-2-1 → live count → result → stay in the outline to go again; both arms up (or Done) ends it.

struct CameraDrillSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: CameraDrillSession

    init(drill: CameraDrill, player: Player) {
        _session = StateObject(wrappedValue: CameraDrillSession(drill: drill, player: player))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    if let previewSession = session.previewSession {
                        CameraPreview(session: previewSession)
                    } else if let image = session.previewImage {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    overlay(in: geo.size)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                topBar
                Spacer()
                centrePanel
                Spacer()
                bottomPanel
            }
            .padding(DesignSystem.Spacing.md)
        }
        .statusBarHidden()
        .onAppear { session.start() }
        .onDisappear { session.stop() }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { dismiss() }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            TQIconButton("xmark", accessibilityLabel: "Close") { session.endSession() }
            Spacer()
            Text(session.drill.title)
                .font(DesignSystem.Typography.labelMedium)
                .textCase(.uppercase)
                .foregroundColor(.white)
            Spacer()
            TQIconButton(session.voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                         accessibilityLabel: session.voiceOn ? "Mute voice" : "Unmute voice") {
                session.voiceOn.toggle()
            }
        }
    }

    @ViewBuilder
    private var centrePanel: some View {
        switch session.phase {
        case .starting:
            ProgressView().tint(.white)
        case .positioning:
            prompt("Step into the outline", detail: "Whole body in frame, ball in your hands")
        case let .countdown(n):
            bigNumber("\(n)")
        case .live:
            VStack(spacing: DesignSystem.Spacing.xs) {
                bigNumber("\(session.count)")
                if let left = session.timeLeft {
                    Text(String(format: "0:%02d", Int(left.rounded(.up))))
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(.white)
                }
            }
        case .result:
            resultPanel
        case .finished:
            EmptyView()
        case let .failed(message):
            VStack(spacing: DesignSystem.Spacing.md) {
                prompt("Can't start the camera", detail: message)
                TQButton("Close", style: .inverse, fullWidth: false) { dismiss() }
            }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if session.phase == .result || session.phase == .positioning {
                Text(session.phase == .result ? "Stay in the outline to go again · both arms up to finish"
                                              : "Both arms up to finish")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(Color.black.opacity(0.55))
            }
            if !session.runs.isEmpty {
                TQButton("Done", style: .inverse) { session.endSession() }
            }
        }
    }

    private var resultPanel: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if let result = session.lastResult {
                if result.isPersonalBest {
                    TQBadge(.status("New best"))
                }
                bigNumber("\(result.count)")
                Text(resultDetail(result))
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.white)
            } else {
                prompt("No touches counted", detail: "Drop it from your hands and keep it up")
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.black.opacity(0.55))
    }

    private func resultDetail(_ result: CameraDrillSession.RunResult) -> String {
        var parts: [String] = []
        if let previous = result.previousBest, !result.isPersonalBest { parts.append("Best \(previous)") }
        if result.xp > 0 { parts.append("+\(result.xp) XP") }
        if result.coins > 0 { parts.append("+\(result.coins) coins") }
        return parts.isEmpty ? "Logged" : parts.joined(separator: " · ")
    }

    private func bigNumber(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 140, weight: .heavy).width(.condensed))
            .monospacedDigit()
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .contentTransition(.numericText())
            .animation(DesignSystem.Animation.quick, value: text)
    }

    private func prompt(_ title: String, detail: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.system(size: 30, weight: .heavy).width(.condensed))
                .textCase(.uppercase)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.black.opacity(0.55))
    }

    // MARK: Overlay (frame units → aspect-fill screen points)

    private func overlay(in size: CGSize) -> some View {
        let a = session.aspect
        let scale = max(size.width / a, size.height)
        let origin = CGPoint(x: (size.width - a * scale) / 2, y: (size.height - scale) / 2)
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + (1 - y) * scale)
        }
        let showOutline = session.phase == .positioning || session.phase == .result
            || { if case .countdown = session.phase { return true } else { return false } }()

        return Canvas { context, _ in
            if showOutline {
                let topLeft = point(0.25 * a, 0.82), bottomRight = point(0.75 * a, 0.03)
                let rect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
                context.stroke(Path(roundedRect: rect, cornerRadius: rect.width / 2),
                               with: .color(session.inPosition ? DesignSystem.Colors.grass : .white.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 4, dash: session.inPosition ? [] : [14, 10]))
            }
            if session.phase == .live, let ball = session.ball {
                let c = point(ball.center.x, ball.center.y)
                let r = ball.radius * scale * 1.2
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(DesignSystem.Colors.grass), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Full-screen camera preview (aspect fill), matching `overlay(in:)`'s mapping.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
