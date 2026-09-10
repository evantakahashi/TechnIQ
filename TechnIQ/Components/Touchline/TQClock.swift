import SwiftUI

// MARK: - TQClock
//
// Active-session clock: 128 pt condensed bold with tabular digits, tight tracking, and a 15 pt
// uppercase sub-line ("OF 15:00 · SET 2 OF 4"). Paused dims the digits slightly.

struct TQClock: View {
    let seconds: Int
    var subtitle: String? = nil
    var isRunning: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            Text(TQClock.format(seconds))
                .font(DesignSystem.Typography.numberHero)
                .tracking(-5)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .opacity(isRunning ? 1 : 0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .animation(DesignSystem.Animation.quick, value: isRunning)
            if let subtitle {
                Text(subtitle)
                    .font(Font.system(size: 15, weight: .semibold).width(.condensed).monospacedDigit())
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(DesignSystem.Colors.textOnPitch)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock")
        .accessibilityValue("\(TQClock.spoken(seconds))\(isRunning ? "" : ", paused")\(subtitle.map { ", " + $0 } ?? "")")
    }

    static func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func spoken(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60, r = s % 60
        if m == 0 { return "\(r) seconds" }
        return "\(m) minute\(m == 1 ? "" : "s") \(r) second\(r == 1 ? "" : "s")"
    }
}

#if DEBUG
#Preview("Clock") {
    VStack(spacing: 30) {
        TQClock(seconds: 7 * 60 + 28, subtitle: "of 15:00 · set 2 of 4")
        TQClock(seconds: 42, subtitle: "elapsed", isRunning: false)
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(DesignSystem.Colors.pitch)
}
#endif
