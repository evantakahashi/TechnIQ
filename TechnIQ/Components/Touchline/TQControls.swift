import SwiftUI

// MARK: - TQSegment
//
// Raised track (r6, 3 pt inset); selected option is a chalk fill (r4, 36 pt) with base text.
// `.detached` renders the options as separate 40 pt chips with a 6 pt gap (Session complete
// "How did it feel?").

struct TQSegment: View {
    enum Style { case track, detached }

    let options: [String]
    @Binding var selectedIndex: Int
    var style: Style = .track

    init(options: [String], selectedIndex: Binding<Int>, style: Style = .track) {
        self.options = options
        self._selectedIndex = selectedIndex
        self.style = style
    }

    var body: some View {
        HStack(spacing: style == .track ? 0 : 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = index == selectedIndex
                Button {
                    HapticManager.shared.selectionChanged()
                    withAnimation(DesignSystem.Animation.quick) { selectedIndex = index }
                } label: {
                    segmentLabel(option, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .padding(style == .track ? 3 : 0)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.segmentTrack, style: .continuous)
                .fill(style == .track ? DesignSystem.Colors.surfaceRaised : Color.clear)
        )
    }

    private func segmentLabel(_ option: String, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .bold : .semibold
        let foreground: Color = isSelected ? DesignSystem.Colors.textOnAccent : DesignSystem.Colors.dimIvory
        let height: CGFloat = style == .track ? 36 : 40
        let radius: CGFloat = style == .track ? DesignSystem.CornerRadius.segmentInner : DesignSystem.CornerRadius.md
        let idleFill: Color = style == .track ? Color.clear : DesignSystem.Colors.surfaceRaised
        let fill: Color = isSelected ? DesignSystem.Colors.chalkWhite : idleFill
        return Text(option)
            .font(Font.system(size: 14, weight: weight).width(.condensed))
            .textCase(.uppercase)
            .tracking(0.7)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .contentShape(Rectangle())
    }
}

// MARK: - TQChip

/// Filter chip: 14 pt condensed uppercase, r4, 6×11 padding; chalk when selected, raised idle.
struct TQChip: View {
    let title: String
    var isSelected: Bool = false
    var icon: String? = nil
    let action: () -> Void

    init(_ title: String, isSelected: Bool = false, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? DesignSystem.Colors.textOnAccent : DesignSystem.Colors.mutedIvory)
            .padding(.vertical, 6)
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.surfaceRaised)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

/// Horizontal chip row that scrolls past the screen padding.
struct TQChipRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { content }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        }
        .padding(.horizontal, -DesignSystem.Spacing.screenPadding)
    }
}

// MARK: - TQBadge

struct TQBadge: View {
    enum Level: String { case beginner, intermediate, advanced, elite }
    enum Kind {
        case level(Level)
        case count(Int)
        case status(String)
        case text(String)   // "AI" on the empty-Home row
    }

    let kind: Kind

    init(_ kind: Kind) { self.kind = kind }

    /// Maps the app's difficulty strings / numbers to a level badge.
    init(difficulty: String) {
        switch difficulty.lowercased() {
        case "beginner", "1": self.init(.level(.beginner))
        case "intermediate", "2": self.init(.level(.intermediate))
        case "advanced", "3": self.init(.level(.advanced))
        case "elite", "professional", "4", "5": self.init(.level(.elite))
        default: self.init(.level(.intermediate))
        }
    }

    var body: some View {
        Text(label)
            .font(Font.system(size: fontSize, weight: .bold).width(.condensed).monospacedDigit())
            .textCase(.uppercase)
            .tracking(0.7)
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(foreground)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .accessibilityLabel(accessibilityText)
    }

    private var label: String {
        switch kind {
        case .level(let level): return level.rawValue
        case .count(let n): return "\(n)"
        case .status(let s), .text(let s): return s
        }
    }

    private var accessibilityText: String {
        switch kind {
        case .level(let level): return "\(level.rawValue) level"
        case .count(let n): return "\(n) new"
        case .status(let s), .text(let s): return s
        }
    }

    private var fontSize: CGFloat {
        switch kind {
        case .count, .text: return 13
        default: return 12
        }
    }

    private var verticalPadding: CGFloat {
        switch kind {
        case .count, .text: return 2
        default: return 3
        }
    }

    private var cornerRadius: CGFloat {
        switch kind {
        case .count, .text: return DesignSystem.CornerRadius.sm
        default: return DesignSystem.CornerRadius.badge
        }
    }

    private var foreground: Color {
        switch kind {
        case .level(.intermediate), .level(.elite): return DesignSystem.Colors.chalkWhite
        default: return DesignSystem.Colors.textOnAccent
        }
    }

    private var background: Color {
        switch kind {
        case .level(.beginner): return DesignSystem.Colors.grass
        case .level(.intermediate): return DesignSystem.Colors.surfaceHighlight
        case .level(.advanced): return DesignSystem.Colors.cone
        case .level(.elite): return DesignSystem.Colors.error
        case .count, .status, .text: return DesignSystem.Colors.grass
        }
    }
}

// MARK: - TQTile

/// 42 pt leading tile: TEC / PHY / TAC / VID / AI text, a number + unit ("8W"), or a symbol.
struct TQTile: View {
    enum Style { case raised, ai }

    enum Content {
        case text(String)
        case number(String, unit: String, accent: Bool)
        case symbol(String)
    }

    let content: Content
    var style: Style = .raised
    var size: CGFloat = 42

    init(_ text: String, style: Style = .raised, size: CGFloat = 42) {
        self.content = .text(text)
        self.style = style
        self.size = size
    }

    init(number: String, unit: String, accent: Bool = false, size: CGFloat = 42) {
        self.content = .number(number, unit: unit, accent: accent)
        self.style = .raised
        self.size = size
    }

    init(symbol: String, size: CGFloat = 42) {
        self.content = .symbol(symbol)
        self.style = .raised
        self.size = size
    }

    /// Category → tile text used across Train, Community, and the AI drill screens.
    static func category(_ category: String?, isAI: Bool = false, isVideo: Bool = false) -> TQTile {
        if isAI { return TQTile("AI", style: .ai) }
        if isVideo { return TQTile("VID") }
        switch (category ?? "").lowercased() {
        case "technical": return TQTile("TEC")
        case "physical": return TQTile("PHY")
        case "tactical": return TQTile("TAC")
        case "mental": return TQTile("MEN")
        case "video", "youtube": return TQTile("VID")
        default:
            let prefix = String((category ?? "DRL").prefix(3)).uppercased()
            return TQTile(prefix.isEmpty ? "DRL" : prefix)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.tile, style: .continuous)
                .fill(style == .ai ? DesignSystem.Colors.pitch : DesignSystem.Colors.surfaceRaised)
            switch content {
            case .text(let text):
                Text(text)
                    .font(DesignSystem.Typography.labelTile)
                    .tracking(0.5)
                    .foregroundColor(style == .ai ? DesignSystem.Colors.grass : DesignSystem.Colors.mutedIvory)
            case .number(let number, let unit, let accent):
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(number)
                        .font(Font.system(size: 16, weight: .bold).width(.condensed).monospacedDigit())
                        .foregroundColor(accent ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite)
                    Text(unit)
                        .font(Font.system(size: 10, weight: .bold).width(.condensed))
                        .tracking(0.4)
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                }
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.mutedIvory)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - TQStepper

/// "01 ── ── ── 04": current step in grass, bars 2 pt (grass for done/current).
struct TQStepper: View {
    let current: Int   // 1-based
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", current))
                .font(Font.system(size: 14, weight: .bold).width(.condensed))
                .tracking(1.1)
                .foregroundColor(DesignSystem.Colors.grass)
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Rectangle()
                        .fill(index < current ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight)
                        .frame(height: 2)
                }
            }
            Text(String(format: "%02d", total))
                .font(Font.system(size: 14, weight: .semibold).width(.condensed))
                .tracking(1.1)
                .foregroundColor(DesignSystem.Colors.dimIvory)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

// MARK: - TQProgressBar

/// Plain single-fill bar (Plans card 6 pt, You card 4 pt). For the animated two-layer level bar see TQLevelBar.
struct TQProgressBar: View {
    let progress: Double      // 0…1
    var height: CGFloat = 6
    var track: Color = DesignSystem.Colors.surfaceBase.opacity(0.5)
    var fill: Color = DesignSystem.Colors.grass

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((max(0, min(1, progress)) * 100).rounded())) percent")
    }
}

#if DEBUG
#Preview("Controls") {
    VStack(alignment: .leading, spacing: 16) {
        TQSegment(options: ["Feed", "Drills", "Leaderboard"], selectedIndex: .constant(1))
        TQSegment(options: ["Easy", "OK", "Good", "Hard"], selectedIndex: .constant(2), style: .detached)
        TQChipRow {
            TQChip("All", isSelected: true) {}
            TQChip("Saved") {}
            TQChip("Technical") {}
            TQChip("Physical") {}
            TQChip("Tactical") {}
            TQChip("Video") {}
        }
        HStack(spacing: 6) {
            TQBadge(.level(.beginner)); TQBadge(.level(.intermediate)); TQBadge(.level(.advanced)); TQBadge(.level(.elite)); TQBadge(.status("Active")); TQBadge(.count(3))
        }
        HStack(spacing: 6) {
            TQTile("TEC"); TQTile("PHY"); TQTile("TAC"); TQTile("AI", style: .ai); TQTile("VID"); TQTile(number: "8", unit: "W", accent: true); TQTile(symbol: "plus")
        }
        TQStepper(current: 1, total: 4)
        TQProgressBar(progress: 0.31)
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
