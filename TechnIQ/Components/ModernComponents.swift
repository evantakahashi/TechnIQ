import SwiftUI

// MARK: - Legacy component layer (Touchline)
//
// Screens in the Touchline revamp compose only `Components/Touchline/TQ*.swift`. The types below
// remain so out-of-scope screens (Shop, Settings, Match log, Analytics detail, Paywall, Avatar)
// keep compiling: `ModernButton` and `ModernSegmentControl` are thin wrappers over TQButton /
// TQSegment; `ModernCard`, `ModernTextField`, `StatCard`, `GlowBadge`, `SoccerBallSpinner`,
// `FloatingActionButton`, `CompactActionButton` are flattened to the new tokens and marked
// deprecated. Removed outright: TurfBackground, heroCard(), CornerBracketShape, PitchDivider,
// ActionChip, PillSelector, MultiSelectPillSelector, ModernTabBar, AnimatedTabBar.

// MARK: - Modern Button (wrapper → TQButton)

/// Deprecated: use TQButton. Kept as a wrapper for legacy call sites.
struct ModernButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case ghost
        case danger
        case accent
    }

    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        TQButton(title, icon: icon, style: tqStyle, action: action)
    }

    private var tqStyle: TQButton.Style {
        switch style {
        case .primary, .accent: return .primary
        case .secondary: return .raised
        case .ghost: return .ghost
        case .danger: return .destructive
        }
    }
}

// MARK: - Modern Card (flat raised surface)

/// Deprecated for new screens: Touchline uses pitch cards and flat rows. Kept for the search
/// field / segment track pattern and out-of-scope screens. Raised fill, r12, no border, no shadow.
struct ModernCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let accentEdge: Edge?
    let accentColor: Color
    let onTap: (() -> Void)?

    @State private var isPressed = false

    init(
        padding: CGFloat = DesignSystem.Spacing.cardPadding,
        accentEdge: Edge? = nil,
        accentColor: Color = DesignSystem.Colors.accentLime,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.accentEdge = accentEdge
        self.accentColor = accentColor
        self.onTap = onTap
    }

    var body: some View {
        let cardContent = VStack {
            content
        }
        .padding(padding)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .overlay(accentBorder)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.quick, value: isPressed)

        if let onTap {
            cardContent
                .onTapGesture {
                    HapticManager.shared.lightTap()
                    onTap()
                }
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    isPressed = pressing
                }, perform: {})
        } else {
            cardContent
        }
    }

    @ViewBuilder
    private var accentBorder: some View {
        if let edge = accentEdge {
            switch edge {
            case .leading:
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accentColor)
                        .frame(width: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
            case .top:
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accentColor)
                        .frame(height: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Modern Text Field

/// Raised field, r8, 1 px highlight border, grass border on focus, eyebrow label.
struct ModernTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool

    @State private var isSecureVisible = false
    @FocusState private var isFocused: Bool

    init(_ title: String, text: Binding<String>, placeholder: String = "", icon: String? = nil, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                TQEyebrow(title, tone: isFocused ? .grass : .muted, size: 11)
                    .animation(DesignSystem.Animation.quick, value: isFocused)
            }

            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isFocused ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                        .font(.system(size: 14, weight: .semibold))
                        .animation(DesignSystem.Animation.quick, value: isFocused)
                }

                Group {
                    if isSecure && !isSecureVisible {
                        SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(DesignSystem.Colors.dimIvory))
                    } else {
                        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DesignSystem.Colors.dimIvory))
                    }
                }
                .font(Font.system(size: 15, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .focused($isFocused)

                if isSecure {
                    Button(action: { isSecureVisible.toggle() }) {
                        Image(systemName: isSecureVisible ? DesignSystem.Icons.eyeClosed : DesignSystem.Icons.eyeOpen)
                            .foregroundColor(DesignSystem.Colors.dimIvory)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, -12)
                    .a11y(label: isSecureVisible ? "Hide password" : "Show password")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: DesignSystem.Spacing.hitTarget)
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField, style: .continuous)
                    .strokeBorder(
                        isFocused ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(DesignSystem.Animation.quick, value: isFocused)
        }
    }
}

// MARK: - Progress Ring

/// Deprecated: Touchline uses TQLevelBar / TQProgressBar. Flat ring kept for StatCard.
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color

    init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 60, color: Color = DesignSystem.Colors.primaryGreen) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.surfaceHighlight, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.smooth, value: progress)
        }
        .frame(width: size, height: size)
        .onChange(of: progress) { _, newValue in
            if newValue >= 1.0 {
                HapticManager.shared.success()
            }
        }
    }
}

// MARK: - Stat Card

/// Deprecated: use TQStatRail. Flat raised card kept for out-of-scope screens.
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double?

    init(title: String, value: String, subtitle: String = "", icon: String, color: Color = DesignSystem.Colors.primaryGreen, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }

    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.labelMedium)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(value)
                        .font(DesignSystem.Typography.numberMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                if let progress = progress {
                    ProgressRing(progress: progress, lineWidth: 6, size: 44, color: color)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                        .frame(width: 42, height: 42)
                        .background(DesignSystem.Colors.surfaceOverlay)
                        .cornerRadius(DesignSystem.CornerRadius.tile)
                }
            }
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Modern Alert Component
struct ModernAlert: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    init(title: String, message: String, primaryButtonTitle: String, primaryAction: @escaping () -> Void, secondaryButtonTitle: String? = nil, secondaryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(title)
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                TQButton(primaryButtonTitle, action: primaryAction)

                if let secondaryButtonTitle = secondaryButtonTitle {
                    TQButton(secondaryButtonTitle, style: .ghost, action: secondaryAction ?? {})
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.card)
    }
}

// MARK: - Loading Spinner

/// Deprecated: use TQSpinner. Grass ring, 24 pt.
struct SoccerBallSpinner: View {
    var body: some View {
        TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 3, size: 24)
    }
}

// MARK: - Modern Segment Control (wrapper → TQSegment)

/// Deprecated: use TQSegment. Icons are ignored (Touchline segments are text only).
struct ModernSegmentControl: View {
    let options: [String]
    @Binding var selectedIndex: Int
    let icons: [String]?

    init(options: [String], selectedIndex: Binding<Int>, icons: [String]? = nil) {
        self.options = options
        self._selectedIndex = selectedIndex
        self.icons = icons
    }

    var body: some View {
        TQSegment(options: options, selectedIndex: $selectedIndex)
    }
}

// MARK: - Animated Tab Content
struct AnimatedTabContent<Content: View>: View {
    @Binding var selectedTab: Int
    var tabCount: Int = 5
    let content: (Int) -> Content

    // Tabs stay alive once visited so navigation, scroll position, and
    // in-flight state survive tab switches; only the first visit builds a tab.
    @State private var visitedTabs: Set<Int> = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<tabCount, id: \.self) { index in
                    if index == selectedTab || visitedTabs.contains(index) {
                        content(index)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(index - selectedTab) * geometry.size.width)
                            .opacity(index == selectedTab ? 1 : 0)
                            .allowsHitTesting(index == selectedTab)
                            .accessibilityHidden(index != selectedTab)
                    }
                }
            }
            .clipped()
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: selectedTab)
            .onAppear { visitedTabs.insert(selectedTab) }
            .onChange(of: selectedTab) { _, newValue in
                visitedTabs.insert(newValue)
            }
        }
    }
}

// MARK: - Glow Badge

/// Deprecated: use TQBadge. Flat r3 badge kept for out-of-scope screens.
struct GlowBadge: View {
    let text: String
    let color: Color
    let icon: String?

    init(_ text: String, color: Color = DesignSystem.Colors.accentLime, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(Font.system(size: 12, weight: .bold).width(.condensed))
                .textCase(.uppercase)
                .tracking(0.7)
        }
        .foregroundColor(DesignSystem.Colors.textOnAccent)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color)
        .cornerRadius(DesignSystem.CornerRadius.badge)
    }
}

// MARK: - Preview Provider
struct ModernComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModernButton("Primary Button", icon: "play.fill") {}
            ModernButton("Secondary Button", style: .secondary) {}
            ModernButton("Danger", style: .danger) {}

            ModernTextField("Email", text: .constant(""), placeholder: "Enter your email", icon: "envelope.fill")

            StatCard(title: "Total Sessions", value: "12", subtitle: "completed", icon: "calendar")

            ModernSegmentControl(options: ["Feed", "Drills", "Leaderboard"], selectedIndex: .constant(1))

            GlowBadge("Level 5", icon: "star.fill")
        }
        .padding()
        .background(DesignSystem.Colors.surfaceBase)
    }
}
