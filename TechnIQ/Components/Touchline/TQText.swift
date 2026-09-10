import SwiftUI

// MARK: - Text primitives
//
// Eyebrows, section headers, condensed display titles and figure rows. These carry the
// tracking / casing rules so screens never set them ad hoc.

/// Grass eyebrow above every hero and section: 12 pt bold uppercase, +1.2 tracking.
struct TQEyebrow: View {
    enum Tone { case grass, muted, onPitch }

    let text: String
    var tone: Tone = .grass
    var size: CGFloat = 12

    init(_ text: String, tone: Tone = .grass, size: CGFloat = 12) {
        self.text = text
        self.tone = tone
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(Font.system(size: size, weight: .bold))
            .textCase(.uppercase)
            .tracking(DesignSystem.Typography.Tracking.eyebrow)
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private var color: Color {
        switch tone {
        case .grass: return DesignSystem.Colors.grass
        case .muted: return DesignSystem.Colors.dimIvory
        case .onPitch: return DesignSystem.Colors.textOnPitch
        }
    }
}

/// Condensed uppercase group header ("TRAINING", "STEPS", "CLOSE MATCHES IN YOUR LIBRARY").
struct TQGroupHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Font.system(size: 12, weight: .bold).width(.condensed))
            .textCase(.uppercase)
            .tracking(DesignSystem.Typography.Tracking.eyebrow)
            .foregroundColor(DesignSystem.Colors.dimIvory)
            .padding(.bottom, 6)
    }
}

/// Section header with an optional trailing value ("THIS WEEK  3 / 4").
struct TQSectionHeader<Trailing: View>: View {
    let text: String
    let trailing: Trailing

    init(_ text: String, @ViewBuilder trailing: () -> Trailing) {
        self.text = text
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(Font.system(size: 14, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.85)
                .foregroundColor(DesignSystem.Colors.dimIvory)
            Spacer()
            trailing
        }
    }
}

extension TQSectionHeader where Trailing == EmptyView {
    init(_ text: String) {
        self.init(text) { EmptyView() }
    }
}

/// Condensed uppercase display title (drill names, plan names, screen headlines).
struct TQDisplayTitle: View {
    enum Size { case hero, large, medium, mediumLarge, small, card, strip }

    let text: String
    var size: Size = .medium
    var color: Color = DesignSystem.Colors.chalkWhite

    init(_ text: String, size: Size = .medium, color: Color = DesignSystem.Colors.chalkWhite) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(font)
            .textCase(.uppercase)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var font: Font {
        switch size {
        case .hero: return DesignSystem.Typography.heroDisplay          // 60 sign-in
        case .large: return DesignSystem.Typography.displayLarge        // 56 session complete (52 in mock)
        case .mediumLarge: return DesignSystem.Typography.displayMediumLarge // 44–46 onboarding question
        case .medium: return DesignSystem.Typography.displayMedium      // 40 drill names
        case .small: return DesignSystem.Typography.displaySmall        // 30 screen titles
        case .card: return Font.system(size: 26, weight: .semibold).width(.condensed).leading(.tight) // 26–28 card titles
        case .strip: return Font.system(size: 22, weight: .semibold).width(.condensed).leading(.tight) // 19–22 strip titles
        }
    }

    private var tracking: CGFloat {
        switch size {
        case .hero, .large: return DesignSystem.Typography.Tracking.display
        case .mediumLarge: return -0.6
        case .medium: return DesignSystem.Typography.Tracking.displayTight
        default: return 0
        }
    }

    private var lineSpacing: CGFloat {
        // Mocks use line-height .88–.98; SwiftUI can't go below 1.0 so keep it tight.
        0
    }
}

/// Figures row: "15 MIN  120 REPS  L FOOT  2 LVL" — condensed, tabular, unit in the muted tone.
struct TQFigureRow: View {
    struct Figure: Identifiable {
        let id = UUID()
        let value: String
        let unit: String
    }

    let figures: [Figure]
    var onPitch: Bool = true
    var valueSize: CGFloat = 20
    var unitSize: CGFloat = 15
    var spacing: CGFloat = 18

    init(_ figures: [(String, String)], onPitch: Bool = true, valueSize: CGFloat = 20, unitSize: CGFloat = 15, spacing: CGFloat = 18) {
        self.figures = figures.map { Figure(value: $0.0, unit: $0.1) }
        self.onPitch = onPitch
        self.valueSize = valueSize
        self.unitSize = unitSize
        self.spacing = spacing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            ForEach(figures) { figure in
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(figure.value)
                        .font(Font.system(size: valueSize, weight: .semibold).width(.condensed).monospacedDigit())
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    Text(figure.unit)
                        .font(Font.system(size: unitSize, weight: .semibold).width(.condensed))
                        .textCase(.uppercase)
                        .foregroundColor(onPitch ? DesignSystem.Colors.textOnPitch : DesignSystem.Colors.dimIvory)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Condensed meta text ("WK 3 · DAY 2", "TECHNICAL · LVL 2 · 15 MIN").
struct TQMeta: View {
    enum Tone { case onPitch, muted, chalk }

    let text: String
    var tone: Tone = .muted
    var size: CGFloat = 14
    var weight: Font.Weight = .semibold
    var uppercase: Bool = true

    init(_ text: String, tone: Tone = .muted, size: CGFloat = 14, weight: Font.Weight = .semibold, uppercase: Bool = true) {
        self.text = text
        self.tone = tone
        self.size = size
        self.weight = weight
        self.uppercase = uppercase
    }

    var body: some View {
        Text(text)
            .font(Font.system(size: size, weight: weight).width(.condensed).monospacedDigit())
            .textCase(uppercase ? .uppercase : nil)
            .tracking(uppercase ? 0.4 : 0)
            .foregroundColor(color)
            .lineLimit(1)
    }

    private var color: Color {
        switch tone {
        case .onPitch: return DesignSystem.Colors.textOnPitch
        case .muted: return DesignSystem.Colors.dimIvory
        case .chalk: return DesignSystem.Colors.chalkWhite
        }
    }
}

/// Body copy at 14/1.5 (coach reasoning, descriptions).
struct TQBody: View {
    enum Tone { case onPitch, base, muted, italicMuted }

    let text: String
    var tone: Tone = .base
    var size: CGFloat = 14

    init(_ text: String, tone: Tone = .base, size: CGFloat = 14) {
        self.text = text
        self.tone = tone
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(Font.system(size: size, weight: .regular))
            .italic(tone == .italicMuted)
            .lineSpacing(size * 0.45)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var color: Color {
        switch tone {
        case .onPitch: return DesignSystem.Colors.bodyOnPitch
        case .base: return DesignSystem.Colors.mutedIvory
        case .muted: return DesignSystem.Colors.dimIvory
        case .italicMuted: return DesignSystem.Colors.mutedOnPitch
        }
    }
}

/// Footer line: "LVL 12 · 2,450 XP · 5 DAY STREAK".
struct TQFooterLine: View {
    struct Item {
        let value: String
        let label: String
        var valueLeading: Bool = false   // "LVL 12" puts the label first
        var accent: Bool = false
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("·").foregroundColor(DesignSystem.Colors.dimIvory)
                }
                HStack(spacing: 4) {
                    if item.valueLeading {
                        Text(item.label)
                        Text(item.value).foregroundColor(item.accent ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite)
                    } else {
                        Text(item.value).foregroundColor(item.accent ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite)
                        Text(item.label)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(Font.system(size: 14, weight: .regular).width(.condensed).monospacedDigit())
        .textCase(.uppercase)
        .tracking(0.5)
        .foregroundColor(DesignSystem.Colors.dimIvory)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Text") {
    VStack(alignment: .leading, spacing: 14) {
        TQEyebrow("Today's session")
        TQGroupHeader("Training")
        TQSectionHeader("This week") { TQMeta("3 / 4", tone: .chalk, size: 16) }
        TQDisplayTitle("Two-touch wall passing")
        TQFigureRow([("15", "min"), ("120", "reps"), ("L", "foot"), ("2", "lvl")], onPitch: false)
        TQMeta("Technical · Lvl 2 · 15 min", size: 13)
        TQBody("Weak-foot passing rated lowest across your last three sessions.")
        TQFooterLine(items: [.init(value: "12", label: "LVL", valueLeading: true), .init(value: "2,450", label: "XP"), .init(value: "5", label: "day streak", accent: true)])
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
