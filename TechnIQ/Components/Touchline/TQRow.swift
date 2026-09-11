import SwiftUI

// MARK: - TQRow
//
// Lists are flat rows separated by 1 px rules, never cards. Leading: none / 42 pt tile / index.
// Trailing: meta (condensed, optional grass accent) and/or a badge, then a chevron, heart, or
// saves count. Pressed = raised fill bleeding 8 pt past the text edge (r6). Disabled = secondary
// title, tertiary note, no chevron. Min height 44.

struct TQRow: View {
    enum Leading {
        case none
        case tile(TQTile)
        case index(String, tone: IndexTone = .grass)
    }

    enum IndexTone { case grass, muted }

    enum Accessory {
        case none
        case chevron
        case heart(isOn: Bool, action: () -> Void)
        case saves(Int)
    }

    struct Meta {
        var text: String
        var accent: String? = nil        // grass-coloured suffix, e.g. "W 3–1"
        var size: CGFloat = 15
        var face: Face = .display

        enum Face { case display, text }

        init(_ text: String, accent: String? = nil, size: CGFloat = 15, face: Face = .display) {
            self.text = text
            self.accent = accent
            self.size = size
            self.face = face
        }
    }

    let title: String
    var subtitle: String? = nil
    var leading: Leading = .none
    var meta: Meta? = nil
    var trailingBadge: TQBadge? = nil
    var accessory: Accessory = .chevron
    var note: String? = nil                // disabled note ("after your first session")
    var verticalPadding: CGFloat = DesignSystem.Spacing.rowVerticalLarge
    var titleFont: Font = DesignSystem.Typography.titleMedium
    var titleColor: Color = DesignSystem.Colors.chalkWhite
    var showsRule: Bool = true
    var action: (() -> Void)? = nil

    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String,
         subtitle: String? = nil,
         leading: Leading = .none,
         meta: Meta? = nil,
         badge: TQBadge? = nil,
         accessory: Accessory = .chevron,
         note: String? = nil,
         verticalPadding: CGFloat = DesignSystem.Spacing.rowVerticalLarge,
         titleFont: Font = DesignSystem.Typography.titleMedium,
         titleColor: Color = DesignSystem.Colors.chalkWhite,
         showsRule: Bool = true,
         action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.meta = meta
        self.trailingBadge = badge
        self.accessory = accessory
        self.note = note
        self.verticalPadding = verticalPadding
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.showsRule = showsRule
        self.action = action
    }

    var body: some View {
        Group {
            if let action, isEnabled {
                Button {
                    HapticManager.shared.lightTap()
                    action()
                } label: {
                    rowContent
                }
                .buttonStyle(TQRowPressStyle())
            } else {
                rowContent
            }
        }
        .overlay(alignment: .bottom) {
            if showsRule { TQRule() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("row.\(title)")
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            leadingView

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(isEnabled ? titleColor : DesignSystem.Colors.dimIvory)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    TQMeta(subtitle, tone: .muted, size: 13, weight: .regular)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isEnabled, let note {
                Text(note)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            } else {
                if let meta { metaView(meta) }
                if let trailingBadge { trailingBadge }
                accessoryView
            }
        }
        .padding(.vertical, verticalPadding)
        .frame(minHeight: DesignSystem.Spacing.hitTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .none:
            EmptyView()
        case .tile(let tile):
            tile
        case .index(let text, let tone):
            Text(text)
                .font(Font.system(size: 14, weight: .bold).width(.condensed))
                .tracking(0.6)
                .foregroundColor(tone == .grass ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                .frame(width: 22, alignment: .leading)
        }
    }

    @ViewBuilder
    private func metaView(_ meta: Meta) -> some View {
        switch meta.face {
        case .display:
            (Text(meta.text).foregroundColor(DesignSystem.Colors.dimIvory)
             + Text(meta.accent ?? "").foregroundColor(DesignSystem.Colors.grass).fontWeight(.semibold))
                .font(Font.system(size: meta.size, weight: .regular).width(.condensed).monospacedDigit())
                .lineLimit(1)
        case .text:
            Text(meta.text)
                .font(Font.system(size: meta.size, weight: .regular))
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            TQChevron()
        case .heart(let isOn, let action):
            Button(action: {
                HapticManager.shared.selectionChanged()
                action()
            }) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isOn ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight)
                    .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -14)
            .accessibilityLabel(isOn ? "Saved. Remove from saved" : "Save")
        case .saves(let count):
            HStack(spacing: 4) {
                Text(count.formatted())
                    .font(Font.system(size: 14, weight: .regular).width(.condensed).monospacedDigit())
                    .foregroundColor(DesignSystem.Colors.dimIvory)
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.grass)
            }
            .accessibilityLabel("\(count) saves")
        }
    }
}

// MARK: - Press style for rows (raised fill bleeding past the edges)

struct TQRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(configuration.isPressed ? DesignSystem.Colors.surfaceRaised : Color.clear)
                    .padding(.horizontal, -8)
            )
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Rule, chevron, list container

struct TQRule: View {
    var color: Color = DesignSystem.Colors.surfaceOverlay

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct TQChevron: View {
    var color: Color = DesignSystem.Colors.textTertiary

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .accessibilityHidden(true)
    }
}

/// Flat list: 1 px top rule, rows draw their own bottom rule.
struct TQRowList<Content: View>: View {
    let content: Content
    var topRule: Bool = true

    init(topRule: Bool = true, @ViewBuilder content: () -> Content) {
        self.topRule = topRule
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if topRule { TQRule() }
            content
        }
    }
}

// MARK: - Index rows (steps, recap)

/// "01  Stand 8 m from the wall…" — index in grass, body text; or "01  Two-touch wall passing  120 reps · 15′".
struct TQIndexRow: View {
    let index: String
    let text: String
    var meta: String? = nil
    var indexTone: TQRow.IndexTone = .grass
    var textColor: Color = DesignSystem.Colors.bannerText
    var indexWidth: CGFloat = 22
    var verticalPadding: CGFloat = 10
    var topRule: Bool = true

    var body: some View {
        HStack(alignment: meta == nil ? .top : .center, spacing: 12) {
            Text(index)
                .font(Font.system(size: meta == nil ? 14 : 13, weight: meta == nil ? .bold : .regular).width(.condensed))
                .tracking(0.6)
                .foregroundColor(indexTone == .grass ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                .frame(width: indexWidth, alignment: .leading)
                .padding(.top, meta == nil ? 1 : 0)
            Text(text)
                .font(Font.system(size: 14, weight: .regular))
                .lineSpacing(14 * 0.45)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let meta {
                TQMeta(meta, tone: .muted, size: 14, weight: .regular, uppercase: false)
            }
        }
        .padding(.vertical, verticalPadding)
        .overlay(alignment: .top) { if topRule { TQRule() } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pipeline step row (AI drill generating)

struct TQStepRow: View {
    enum State { case done, running, pending }

    let text: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch state {
                case .done:
                    ZStack {
                        Circle().fill(DesignSystem.Colors.grass)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textOnAccent)
                    }
                case .running:
                    TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 2, size: 14)
                case .pending:
                    Circle().stroke(DesignSystem.Colors.surfaceHighlight, lineWidth: 1.5)
                }
            }
            .frame(width: 14, height: 14)
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(state == .pending ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.chalkWhite)
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.rowVertical)
        .overlay(alignment: .bottom) { TQRule() }
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .done ? "done" : state == .running ? "in progress" : "pending")
    }
}

// MARK: - Option row (onboarding choices)

/// Selectable row: number, title, one-line consequence, radio. Selected = pitch fill + grass border.
struct TQOptionRow: View {
    let number: String
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Text(number)
                    .font(Font.system(size: 14, weight: .bold).width(.condensed))
                    .tracking(0.8)
                    .foregroundColor(isSelected ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                    .frame(width: 22, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(isSelected ? DesignSystem.Colors.textOnPitch : DesignSystem.Colors.dimIvory)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.grass : Color.clear)
                    Circle()
                        .stroke(isSelected ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight, lineWidth: 1.5)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(DesignSystem.Colors.textOnAccent)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.pitch : DesignSystem.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.grass : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

#if DEBUG
#Preview("Rows") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            TQRowList {
                TQRow("Striker Development", meta: .init("WK 3/8 · 31%"), action: {})
                TQRow("Last match", meta: .init("vs Northside · ", accent: "W 3–1"), action: {})
                TQRow("Drills from the coach", badge: TQBadge(.count(3)), action: {})
                TQRow("Drills from the coach", note: "after your first session").disabled(true)
                TQRow(
                    "Two-touch wall passing",
                    subtitle: "Technical · Lvl 2 · 15 min · from your coach",
                    leading: .tile(TQTile("AI", style: .ai)),
                    accessory: .heart(isOn: false, action: {}),
                    verticalPadding: 12,
                    action: {}
                )
                TQRow(
                    "Wall pass & spin",
                    subtitle: "Sofia R. · Lvl 2 · 12 min",
                    leading: .tile(TQTile("TEC")),
                    accessory: .saves(842),
                    verticalPadding: 12,
                    action: {}
                )
                TQRow("TechnIQ Pro", badge: TQBadge(.status("Active")), verticalPadding: 12, action: {})
            }
            VStack(spacing: 0) {
                TQIndexRow(index: "01", text: "Stand 8 m from the wall between the two cones.")
                TQIndexRow(index: "02", text: "Pass with the left foot, receive the rebound with one touch, pass again on the second.")
                TQIndexRow(index: "+2", text: "Coaching points, target skills", indexTone: .muted, textColor: DesignSystem.Colors.dimIvory)
                TQRule()
            }
            VStack(spacing: 0) {
                TQIndexRow(
                    index: "01",
                    text: "Two-touch wall passing",
                    meta: "120 reps · 15′",
                    indexTone: .muted,
                    textColor: DesignSystem.Colors.chalkWhite,
                    indexWidth: 34,
                    verticalPadding: 12
                )
                TQRule()
            }
            VStack(spacing: 0) {
                TQStepRow(text: "Picked the archetype · wall passing", state: .done)
                TQStepRow(text: "Laying out cones and the wall", state: .running)
                TQStepRow(text: "Checking geometry", state: .pending)
            }
            VStack(spacing: 8) {
                TQOptionRow(number: "01", title: "Improve Skills", subtitle: "Technique-heavy: touch, passing, finishing", isSelected: true, action: {})
                TQOptionRow(number: "02", title: "Build Fitness", subtitle: "More conditioning and speed work", isSelected: false, action: {})
            }
        }
        .padding(20)
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
