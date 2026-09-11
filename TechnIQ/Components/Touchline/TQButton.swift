import SwiftUI

// MARK: - TQButton
//
// The one grass button per screen, plus its quieter siblings. Styles: .primary (grass),
// .inverse (chalk), .raised, .ghost. Sizes: .regular 54 pt, .compact 40–44 pt, .auth 52 pt
// (text face, sign-in). Every button renders pressed (0.97 + darker fill), disabled
// (#2A342D on #8E968F — never a faded primary) and loading (spinner replaces the icon, label
// stays; primary loading uses the 35 % grass "waiting" fill from 9c).

struct TQButton: View {
    enum Style { case primary, inverse, raised, ghost, destructive }
    enum Size { case regular, compact, auth }
    enum LabelFace { case display, text }

    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var size: Size = .regular
    var face: LabelFace = .display
    var isLoading: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String,
         icon: String? = nil,
         style: Style = .primary,
         size: Size = .regular,
         face: LabelFace = .display,
         isLoading: Bool = false,
         fullWidth: Bool = true,
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.face = face
        self.isLoading = isLoading
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button {
            guard !isLoading else { return }
            switch style {
            case .primary, .inverse, .destructive: HapticManager.shared.mediumTap()
            case .raised, .ghost: HapticManager.shared.selectionChanged()
            }
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    TQSpinner(color: foreground, lineWidth: 2, size: 14)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .bold))
                }
                Text(title)
                    .font(font)
                    .textCase(face == .display ? .uppercase : nil)
                    .tracking(face == .display ? tracking : 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(TQPressStyle(fill: fill, pressedFill: pressedFill, cornerRadius: cornerRadius))
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
    }

    // MARK: Metrics

    private var height: CGFloat {
        switch size {
        case .regular: return 54
        case .compact: return 44
        case .auth: return 52
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .compact: return DesignSystem.CornerRadius.md
        default: return DesignSystem.CornerRadius.button
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 14
        default: return 16
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .regular: return 13
        case .compact: return 11
        case .auth: return 16
        }
    }

    private var font: Font {
        if face == .text { return size == .auth ? Font.system(size: 17, weight: .semibold) : Font.system(size: 15, weight: .bold) }
        if style == .ghost { return Font.system(size: 14, weight: .semibold) }
        switch size {
        case .regular: return DesignSystem.Typography.labelLarge
        case .compact: return Font.system(size: 15, weight: .bold).width(.condensed)
        case .auth: return DesignSystem.Typography.labelLarge
        }
    }

    private var tracking: CGFloat {
        if style == .ghost { return 0 }
        switch size {
        case .regular, .auth: return DesignSystem.Typography.Tracking.button
        case .compact: return 0.6
        }
    }

    // MARK: Colours

    private var foreground: Color {
        if !isEnabled { return DesignSystem.Colors.dimIvory }
        switch style {
        case .primary, .inverse: return DesignSystem.Colors.textOnAccent
        case .raised: return DesignSystem.Colors.chalkWhite
        case .ghost: return DesignSystem.Colors.dimIvory
        case .destructive: return DesignSystem.Colors.error
        }
    }

    private var fill: Color {
        if !isEnabled { return style == .ghost ? .clear : DesignSystem.Colors.surfaceHighlight }
        switch style {
        case .primary: return isLoading ? DesignSystem.Colors.grass.opacity(0.35) : DesignSystem.Colors.grass
        case .inverse: return DesignSystem.Colors.chalkWhite
        case .raised, .destructive: return DesignSystem.Colors.surfaceRaised
        case .ghost: return .clear
        }
    }

    private var pressedFill: Color {
        if !isEnabled { return fill }
        switch style {
        case .primary: return DesignSystem.Colors.grassPressed
        case .inverse: return DesignSystem.Colors.chalkWhite.opacity(0.85)
        case .raised, .destructive: return DesignSystem.Colors.surfaceHighlight
        case .ghost: return DesignSystem.Colors.surfaceRaised
        }
    }
}

// MARK: - Press style (0.97 scale + darker fill)

struct TQPressStyle: ButtonStyle {
    let fill: Color
    let pressedFill: Color
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? pressedFill : fill)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Spinner (ring, keeps the label beside it)

struct TQSpinner: View {
    var color: Color = DesignSystem.Colors.grass
    var lineWidth: CGFloat = 2
    var size: CGFloat = 14

    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
            .accessibilityHidden(true)
    }
}

// MARK: - Icon buttons

/// Square or circular icon-only button. `.translucent` is the 35 % base overlay used on pitch
/// surfaces (close / menu / pause / next), `.raised` the flat raised square (share, +PLAN).
struct TQIconButton: View {
    enum Style { case translucent, raised, primary }
    enum Shape { case circle, square }

    let systemImage: String
    var style: Style = .translucent
    var shape: Shape = .circle
    var size: CGFloat = 36
    var iconSize: CGFloat = 14
    var accessibilityLabel: String
    let action: () -> Void

    init(_ systemImage: String,
         style: Style = .translucent,
         shape: Shape = .circle,
         size: CGFloat = 36,
         iconSize: CGFloat = 14,
         accessibilityLabel: String,
         action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.style = style
        self.shape = shape
        self.size = size
        self.iconSize = iconSize
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(foreground)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(TQPressStyle(fill: fill, pressedFill: pressedFill, cornerRadius: shape == .circle ? size / 2 : DesignSystem.CornerRadius.button))
        .accessibilityLabel(accessibilityLabel)
    }

    private var foreground: Color {
        switch style {
        case .translucent: return DesignSystem.Colors.chalkWhite
        case .raised: return DesignSystem.Colors.mutedIvory
        case .primary: return DesignSystem.Colors.textOnAccent
        }
    }

    private var fill: Color {
        switch style {
        case .translucent: return DesignSystem.Colors.surfaceBase.opacity(0.35)
        case .raised: return DesignSystem.Colors.surfaceRaised
        case .primary: return DesignSystem.Colors.grass
        }
    }

    private var pressedFill: Color {
        switch style {
        case .translucent: return DesignSystem.Colors.surfaceBase.opacity(0.55)
        case .raised: return DesignSystem.Colors.surfaceHighlight
        case .primary: return DesignSystem.Colors.grassPressed
        }
    }
}

/// Raised square with a short condensed label ("+PLAN"), paired beside a primary button.
struct TQLabelSquare: View {
    let label: String
    var size: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            Text(label)
                .font(DesignSystem.Typography.labelTile)
                .tracking(0.5)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(TQPressStyle(fill: DesignSystem.Colors.surfaceRaised, pressedFill: DesignSystem.Colors.surfaceHighlight, cornerRadius: DesignSystem.CornerRadius.button))
        .accessibilityLabel(label)
    }
}

/// Text link with a grass arrow ("Train as a guest →", "or build a plan first").
struct TQTextLink: View {
    let title: String
    var arrow: Bool = true
    var tone: Tone = .muted
    let action: () -> Void

    enum Tone { case muted, onPitch }

    init(_ title: String, arrow: Bool = true, tone: Tone = .muted, action: @escaping () -> Void) {
        self.title = title
        self.arrow = arrow
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(Font.system(size: tone == .muted ? 14 : 13, weight: .semibold))
                    .foregroundColor(tone == .muted ? DesignSystem.Colors.dimIvory : DesignSystem.Colors.textOnPitch)
                    .underline(tone == .onPitch, color: DesignSystem.Colors.chalkWhite)
                if arrow {
                    Text("→")
                        .font(Font.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.grass)
                }
            }
            .frame(minHeight: DesignSystem.Spacing.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Buttons") {
    VStack(spacing: 10) {
        TQButton("Start session", icon: "play.fill") {}
        TQButton("Kick off", style: .inverse) {}
        TQButton("Edit the request", style: .raised) {}
        TQButton("Sign out", style: .ghost) {}
        TQButton("Disabled") {}.disabled(true)
        TQButton("Coach is picking your drill", isLoading: true) {}
        HStack { TQButton("+ New drill", size: .compact, fullWidth: false) {}; Spacer() }
        TQButton("Continue with Apple", icon: "apple.logo", style: .inverse, size: .auth, face: .text) {}
        HStack(spacing: 10) {
            TQIconButton("pause.fill", shape: .square, size: 64, iconSize: 20, accessibilityLabel: "Pause") {}
            TQButton("+ 10 reps", size: .regular) {}
            TQIconButton("chevron.right", shape: .square, size: 64, iconSize: 18, accessibilityLabel: "Next") {}
        }
        .padding(16)
        .background(DesignSystem.Colors.pitch)
        TQTextLink("Train as a guest") {}
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
