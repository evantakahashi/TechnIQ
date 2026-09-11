import SwiftUI

// MARK: - TQLevelBar
//
// 8 pt track (raised), previous fill in surfaceHighlight, current fill in grass that animates
// from `previous` to `current` over 0.8 s ease-out when it appears. Header row: "LEVEL 12" and
// "630 / 720 · 90 to lvl 13".

struct TQLevelBar: View {
    let previous: Double     // 0…1
    let current: Double      // 0…1
    var title: String? = nil          // "Level 12"
    var detail: String? = nil         // "630 / 720 · "
    var detailAccent: String? = nil   // "90 to lvl 13"
    var height: CGFloat = 8
    var animates: Bool = true
    var onPitch: Bool = false         // darker track when drawn on a pitch card

    @State private var fill: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            if title != nil || detail != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(Font.system(size: 15, weight: .semibold).width(.condensed))
                            .textCase(.uppercase)
                            .tracking(0.9)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                    }
                    Spacer()
                    if detail != nil || detailAccent != nil {
                        (Text(detail ?? "").foregroundColor(DesignSystem.Colors.dimIvory)
                         + Text(detailAccent ?? "").foregroundColor(DesignSystem.Colors.chalkWhite))
                            .font(Font.system(size: 15, weight: .regular).width(.condensed).monospacedDigit())
                    }
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(onPitch ? DesignSystem.Colors.surfaceBase.opacity(0.45) : DesignSystem.Colors.surfaceRaised)
                    Capsule().fill(onPitch ? DesignSystem.Colors.chalkWhite.opacity(0.18) : DesignSystem.Colors.surfaceHighlight)
                        .frame(width: clamp(previous) * proxy.size.width)
                    Capsule().fill(DesignSystem.Colors.grass)
                        .frame(width: clamp(fill) * proxy.size.width)
                }
            }
            .frame(height: height)
        }
        .onAppear {
            fill = animates ? previous : current
            guard animates else { return }
            if reduceMotion {
                fill = current
            } else {
                withAnimation(DesignSystem.Animation.levelBar) { fill = current }
            }
        }
        .onChange(of: current) { _, newValue in
            withAnimation(reduceMotion ? nil : DesignSystem.Animation.levelBar) { fill = newValue }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "Level progress")
        .accessibilityValue("\(Int((clamp(current) * 100).rounded())) percent\(detail.map { ", " + $0 + (detailAccent ?? "") } ?? "")")
    }

    private func clamp(_ value: Double) -> Double { max(0, min(1, value)) }
}

#if DEBUG
#Preview("Level bar") {
    VStack(spacing: 24) {
        TQLevelBar(previous: 0.62, current: 0.87, title: "Level 12", detail: "630 / 720 · ", detailAccent: "90 to lvl 13")
        TQLevelBar(previous: 0, current: 0.62, height: 4, animates: false)
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
