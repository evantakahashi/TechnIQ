import SwiftUI

// MARK: - TQSkeleton
//
// Placeholder block that pulses 0.5 → 1 over 1 s. Same height as the content it stands in for,
// so the layout never moves when data arrives. `.base` blocks are surfaceOverlay; `.pitch`
// blocks are chalk at 14 % (10 % for body lines) as in 9c.

struct TQSkeleton: View {
    enum Tone { case base, pitch, pitchSoft }

    var width: CGFloat? = nil
    var widthFraction: CGFloat? = nil
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 3
    var tone: Tone = .base

    @State private var isDim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let width {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(width: width, height: height)
            } else {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                        .frame(width: resolvedWidth(in: proxy.size.width), height: height)
                }
                .frame(height: height)
            }
        }
        .opacity(isDim ? 0.5 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(DesignSystem.Animation.skeletonPulse) { isDim = true }
        }
        .accessibilityHidden(true)
    }

    private func resolvedWidth(in available: CGFloat) -> CGFloat {
        if let width { return width }
        if let widthFraction { return available * widthFraction }
        return available
    }

    private var color: Color {
        switch tone {
        case .base: return DesignSystem.Colors.surfaceOverlay
        case .pitch: return DesignSystem.Colors.chalkWhite.opacity(0.14)
        case .pitchSoft: return DesignSystem.Colors.chalkWhite.opacity(0.10)
        }
    }
}

#if DEBUG
#Preview("Skeleton") {
    VStack(alignment: .leading, spacing: 6) {
        TQSkeleton(widthFraction: 0.4, height: 10)
        TQSkeleton(widthFraction: 0.8, height: 18, cornerRadius: 4)
        TQSkeleton(widthFraction: 0.6, height: 10)
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
