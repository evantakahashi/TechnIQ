import SwiftUI

// MARK: - TQStatRail
//
// 2–4 figures in a row separated by 1 px rules: value (condensed, tabular), optional unit in the
// muted tone, label underneath. `.regular` = 26 pt (Plan detail), `.compact` = 24 pt (You),
// `.hero` = 40 pt bold on the pitch header with uppercase labels (Session complete).

struct TQStatRail: View {
    struct Item: Identifiable {
        let id = UUID()
        let value: String
        var unit: String? = nil
        let label: String
        var accent: Bool = false

        init(_ value: String, unit: String? = nil, label: String, accent: Bool = false) {
            self.value = value
            self.unit = unit
            self.label = label
            self.accent = accent
        }
    }

    enum Style { case regular, compact, hero }

    let items: [Item]
    var style: Style = .regular

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(item.value)
                            .font(valueFont)
                            .foregroundColor(item.accent ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite)
                        if let unit = item.unit {
                            Text(unit)
                                .font(unitFont)
                                .foregroundColor(unitColor)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    Text(item.label)
                        .font(labelFont)
                        .textCase(style == .hero ? .uppercase : nil)
                        .tracking(style == .hero ? 1 : 0)
                        .foregroundColor(labelColor)
                        .lineLimit(1)
                }
                .padding(.vertical, verticalPadding)
                .padding(.leading, index == 0 ? 0 : innerPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    if index < items.count - 1 {
                        Rectangle().fill(ruleColor).frame(width: 1)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.value)\(item.unit ?? "") \(item.label)")
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(ruleColor).frame(height: 1) }
        .overlay(alignment: .bottom) {
            if style != .hero { Rectangle().fill(ruleColor).frame(height: 1) }
        }
    }

    private var valueFont: Font {
        switch style {
        case .regular: return DesignSystem.Typography.numberMedium
        case .compact: return Font.system(size: 24, weight: .semibold).width(.condensed).monospacedDigit()
        case .hero: return DesignSystem.Typography.numberLarge
        }
    }

    private var unitFont: Font {
        switch style {
        case .regular: return Font.system(size: 16, weight: .semibold).width(.condensed)
        case .compact: return Font.system(size: 15, weight: .semibold).width(.condensed)
        case .hero: return Font.system(size: 22, weight: .semibold).width(.condensed)
        }
    }

    private var labelFont: Font {
        switch style {
        case .hero: return Font.system(size: 12, weight: .bold)
        default: return Font.system(size: 12, weight: .semibold)
        }
    }

    private var unitColor: Color { style == .hero ? DesignSystem.Colors.textOnPitch : DesignSystem.Colors.dimIvory }
    private var labelColor: Color { style == .hero ? DesignSystem.Colors.textOnPitch : DesignSystem.Colors.dimIvory }
    private var ruleColor: Color { style == .hero ? DesignSystem.Colors.chalkWhite.opacity(0.2) : DesignSystem.Colors.surfaceOverlay }
    private var verticalPadding: CGFloat { style == .hero ? 14 : 12 }
    private var innerPadding: CGFloat { style == .hero ? 16 : 14 }
}

#if DEBUG
#Preview("Stat rail") {
    VStack(spacing: 24) {
        TQStatRail(items: [.init("31", unit: "%", label: "complete"), .init("3", unit: "/8", label: "week"), .init("24", unit: "h", label: "total"), .init("11", label: "done", accent: true)])
        TQStatRail(items: [.init("24", label: "sessions"), .init("18", unit: "h", label: "trained"), .init("5", label: "streak", accent: true), .init("4G 3A", label: "season")], style: .compact)
        TQStatRail(items: [.init("+180", label: "xp", accent: true), .init("6", label: "day streak"), .init("+25", label: "coins")], style: .hero)
            .padding(16)
            .background(DesignSystem.Colors.pitch)
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
