import SwiftUI

// MARK: - Modern Button Component
struct ModernButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void

    @State private var isPressed = false

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
        Button(action: {
            switch style {
            case .primary, .danger, .accent:
                HapticManager.shared.mediumTap()
            case .secondary, .ghost:
                HapticManager.shared.selectionChanged()
            }
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .heavy))
                }
                Text(title)
                    .font(DesignSystem.Typography.labelLarge)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .padding(DesignSystem.Spacing.buttonPadding)
            .frame(maxWidth: .infinity)
            .background(backgroundForStyle)
            .foregroundColor(foregroundColorForStyle)
            .cornerRadius(DesignSystem.CornerRadius.button)
            .overlay(borderForStyle)
            .customShadow(shadowForStyle)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var backgroundForStyle: some View {
        Group {
            switch style {
            case .primary:
                DesignSystem.Colors.primaryGreen
            case .secondary:
                isPressed ? DesignSystem.Colors.primaryGreen.opacity(0.12) : Color.clear
            case .ghost:
                isPressed ? DesignSystem.Colors.surfaceHighlight : Color.clear
            case .danger:
                DesignSystem.Colors.error
            case .accent:
                DesignSystem.Colors.accentGold
            }
        }
    }

    private var foregroundColorForStyle: Color {
        switch style {
        case .primary, .accent:
            return DesignSystem.Colors.textOnAccent
        case .danger:
            return .white
        case .secondary:
            return DesignSystem.Colors.chalkWhite
        case .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }

    private var borderForStyle: some View {
        Group {
            switch style {
            case .secondary:
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.chalkWhite, lineWidth: 1)
            default:
                EmptyView()
            }
        }
    }

    private var shadowForStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch style {
        case .primary, .danger, .accent:
            return DesignSystem.Shadow.medium
        default:
            return DesignSystem.Shadow.small
        }
    }
}

// MARK: - Modern Card Component
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
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(DesignSystem.Colors.chalkWhite.opacity(0.08), lineWidth: 1)
        )
        .overlay(accentBorder)
        .customShadow(DesignSystem.Shadow.medium)
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

// MARK: - Compact Action Button (for horizontal button rows)
struct CompactActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(color.opacity(0.12))
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Modern Text Field Component
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.labelMedium)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundColor(isFocused ? DesignSystem.Colors.accentLime : DesignSystem.Colors.textSecondary)
                .animation(DesignSystem.Animation.quick, value: isFocused)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isFocused ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.bodyMedium)
                        .animation(DesignSystem.Animation.quick, value: isFocused)
                }
                
                Group {
                    if isSecure && !isSecureVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(DesignSystem.Typography.bodyMedium)
                .focused($isFocused)
                
                if isSecure {
                    Button(action: { isSecureVisible.toggle() }) {
                        Image(systemName: isSecureVisible ? DesignSystem.Icons.eyeClosed : DesignSystem.Icons.eyeOpen)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                }
            }
            .padding(DesignSystem.Spacing.textFieldPadding)
            .background(DesignSystem.Colors.surfaceHighlight)
            .cornerRadius(DesignSystem.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField)
                    .stroke(
                        isFocused ? DesignSystem.Colors.primaryGreen : Color.white.opacity(0.1),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(DesignSystem.Animation.quick, value: isFocused)
        }
    }
}

// MARK: - Progress Ring Component
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
                .stroke(DesignSystem.Colors.chalkWhite.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    DesignSystem.Colors.accentLime,
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

// MARK: - Stat Card Component
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
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(title)
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(value)
                            .font(DesignSystem.Typography.displaySmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let progress = progress {
                        ProgressRing(progress: progress, color: color)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)
                            .frame(width: 40, height: 40)
                            .background(color.opacity(0.08))
                            .clipShape(Circle())
                            .shadow(color: color.opacity(0.15), radius: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let color: Color
    
    @State private var isPressed = false
    
    init(icon: String, color: Color = DesignSystem.Colors.primaryGreen, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.mediumTap()
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(color)
                .cornerRadius(28)
                .shadow(color: color.opacity(0.4), radius: 12)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Pill Selector Component (Single Select)
struct PillSelector: View {
    let options: [String]
    @Binding var selectedIndex: Int
    let columns: Int
    
    init(options: [String], selectedIndex: Binding<Int>, columns: Int = 4) {
        self.options = options
        self._selectedIndex = selectedIndex
        self.columns = columns
    }
    
    var body: some View {
        let chunkedOptions = Array(options.enumerated()).chunked(into: columns)
        
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(chunkedOptions.enumerated()), id: \.offset) { rowIndex, rowOptions in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(rowOptions, id: \.offset) { index, option in
                        Button(action: {
                            HapticManager.shared.selectionChanged()
                            withAnimation(DesignSystem.Animation.quick) {
                                selectedIndex = index
                            }
                        }) {
                            Text(option)
                                .font(DesignSystem.Typography.labelMedium)
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .frame(minWidth: 60)
                                .background(
                                    selectedIndex == index
                                        ? DesignSystem.Colors.accentLime
                                        : DesignSystem.Colors.surfaceHighlight
                                )
                                .foregroundColor(
                                    selectedIndex == index
                                        ? DesignSystem.Colors.surfaceBase
                                        : DesignSystem.Colors.textSecondary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if rowOptions.count < columns {
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Multi-Select Pill Selector Component
struct MultiSelectPillSelector: View {
    let options: [String]
    @Binding var selectedOptions: Set<String>
    let columns: Int
    
    init(options: [String], selectedOptions: Binding<Set<String>>, columns: Int = 3) {
        self.options = options
        self._selectedOptions = selectedOptions
        self.columns = columns
    }
    
    var body: some View {
        let chunkedOptions = options.chunked(into: columns)
        
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(chunkedOptions.enumerated()), id: \.offset) { rowIndex, rowOptions in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(rowOptions, id: \.self) { option in
                        Button(action: {
                            HapticManager.shared.selectionChanged()
                            withAnimation(DesignSystem.Animation.quick) {
                                if selectedOptions.contains(option) {
                                    selectedOptions.remove(option)
                                } else {
                                    selectedOptions.insert(option)
                                }
                            }
                        }) {
                            Text(option)
                                .font(DesignSystem.Typography.labelMedium)
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .frame(minWidth: 50)
                                .background(
                                    selectedOptions.contains(option)
                                        ? DesignSystem.Colors.accentLime
                                        : DesignSystem.Colors.surfaceHighlight
                                )
                                .foregroundColor(
                                    selectedOptions.contains(option)
                                        ? DesignSystem.Colors.surfaceBase
                                        : DesignSystem.Colors.textSecondary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if rowOptions.count < columns {
                        Spacer()
                    }
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
                ModernButton(primaryButtonTitle, style: .primary, action: primaryAction)
                
                if let secondaryButtonTitle = secondaryButtonTitle {
                    ModernButton(secondaryButtonTitle, style: .ghost, action: secondaryAction ?? {})
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.surfaceOverlay)
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .customShadow(DesignSystem.Shadow.xl)
    }
}

// MARK: - Loading Spinner Component
struct SoccerBallSpinner: View {
    @State private var isRotating = false
    
    var body: some View {
        Image(systemName: "soccerball")
            .font(.title)
            .foregroundColor(DesignSystem.Colors.primaryGreen)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(DesignSystem.Animation.smooth.repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - Modern Segment Control
struct ModernSegmentControl: View {
    let options: [String]
    @Binding var selectedIndex: Int
    let icons: [String]?

    @Namespace private var segmentAnimation

    init(options: [String], selectedIndex: Binding<Int>, icons: [String]? = nil) {
        self.options = options
        self._selectedIndex = selectedIndex
        self.icons = icons
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    HapticManager.shared.selectionChanged()
                    withAnimation(DesignSystem.Animation.quick) {
                        selectedIndex = index
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let icons = icons, index < icons.count {
                            Image(systemName: icons[index])
                                .font(.system(size: 13, weight: .heavy))
                        }
                        Text(option)
                            .font(DesignSystem.Typography.labelMedium)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm + 2)
                    .background(
                        Group {
                            if selectedIndex == index {
                                Capsule()
                                    .fill(DesignSystem.Colors.accentLime)
                                    .matchedGeometryEffect(id: "segment_bg", in: segmentAnimation)
                            }
                        }
                    )
                    .foregroundColor(
                        selectedIndex == index
                            ? DesignSystem.Colors.surfaceBase
                            : DesignSystem.Colors.textSecondary
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.surfaceHighlight)
        .cornerRadius(DesignSystem.CornerRadius.pill)
    }
}

// MARK: - Custom Tab Bar Component
struct ModernTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, title: String)]
    
    var body: some View {
        HStack {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarItem(
                    icon: tab.icon,
                    title: tab.title,
                    isSelected: selectedTab == index
                ) {
                    selectedTab = index
                }
                
                if index < tabs.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.CornerRadius.xl)
        .customShadow(DesignSystem.Shadow.large)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                
                Text(title)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Animated Tab Content
struct AnimatedTabContent<Content: View>: View {
    @Binding var selectedTab: Int
    let content: (Int) -> Content

    @State private var previousTab: Int = 0

    private var slideDirection: Edge {
        selectedTab > previousTab ? .trailing : .leading
    }

    var body: some View {
        ZStack {
            content(selectedTab)
                .id(selectedTab)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection).combined(with: .opacity),
                    removal: .opacity
                ))
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: selectedTab)
        .onChange(of: selectedTab) { oldValue, _ in
            previousTab = oldValue
        }
    }
}

// MARK: - Animated Tab Bar
struct AnimatedTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tabs = [
        ("house.fill", "Home"),
        ("figure.run", "Train"),
        ("calendar.badge.clock", "Plans"),
        ("person.3.fill", "Community"),
        ("person.fill", "You")
    ]

    var body: some View {
        HStack {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    HapticManager.shared.tabChanged()
                    if reduceMotion {
                        selectedTab = index
                    } else {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
                            selectedTab = index
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == index {
                                Capsule()
                                    .fill(DesignSystem.Colors.accentLime)
                                    .frame(width: 56, height: 32)
                                    .matchedGeometryEffect(id: "tab_bg", in: tabAnimation)
                            }
                            Image(systemName: tab.0)
                                .font(.system(size: 18, weight: selectedTab == index ? .heavy : .semibold))
                                .foregroundColor(selectedTab == index ? DesignSystem.Colors.surfaceBase : DesignSystem.Colors.mutedIvory)
                        }
                        Text(tab.1)
                            .font(DesignSystem.Typography.labelSmall)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundColor(selectedTab == index ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.mutedIvory)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            DesignSystem.Colors.surfaceRaised
                .overlay(
                    Rectangle()
                        .fill(DesignSystem.Colors.chalkWhite.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}

// MARK: - Glow Badge Component
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
                    .font(.system(size: 11, weight: .heavy))
            }
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .foregroundColor(DesignSystem.Colors.surfaceBase)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Action Chip Component
struct ActionChip: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, icon: String, color: Color = DesignSystem.Colors.primaryGreen, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(DesignSystem.Colors.accentLime)
                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(isPressed ? DesignSystem.Colors.surfaceOverlay : DesignSystem.Colors.surfaceHighlight)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Pitch Line Divider

/// A chalk-white horizontal line used to separate sections, evoking a pitch line.
struct PitchDivider: View {
    var opacity: Double = 0.4
    var horizontalPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.chalkWhite.opacity(opacity))
            .frame(height: 1)
            .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Corner Bracket (pitch corner arc stylized as an L)

/// An L-shaped bracket drawn in one corner, evoking a pitch corner arc.
struct CornerBracketShape: Shape {
    var length: CGFloat = 20
    var thickness: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: length, height: thickness))
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: thickness, height: length))
        return path
    }
}

// MARK: - Hero Card Modifier

private struct HeroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.cardPadding)
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.chalkWhite.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                CornerBracketShape(length: 20, thickness: 2)
                    .fill(DesignSystem.Colors.chalkWhite.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .padding(10),
                alignment: .topLeading
            )
            .customShadow(DesignSystem.Shadow.medium)
    }
}

extension View {
    /// Wraps content in a Stadium Night hero card with a chalk corner bracket.
    func heroCard() -> some View {
        self.modifier(HeroCardModifier())
    }
}

// MARK: - Turf Background

/// Root-level background: surfaceBase with a subtle procedural grain overlay.
struct TurfBackground: View {
    var body: some View {
        ZStack {
            DesignSystem.Colors.surfaceBase
            TurfGrainCanvas()
                .opacity(0.05)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct TurfGrainCanvas: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededRandomNumberGenerator(seed: 0xA11CE)
            for _ in 0..<1800 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(DesignSystem.Colors.chalkWhite))
            }
        }
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdead_beef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Preview Provider
struct ModernComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModernButton("Primary Button", icon: "play.fill") {}
            ModernButton("Secondary Button", style: .secondary) {}
            ModernButton("Accent Button", style: .accent) {}

            ModernTextField("Email", text: .constant(""), placeholder: "Enter your email", icon: "envelope.fill")

            StatCard(title: "Total Sessions", value: "12", subtitle: "completed", icon: "calendar")

            PillSelector(options: ["All", "Physical", "Tactical"], selectedIndex: .constant(0), columns: 3)

            MultiSelectPillSelector(options: ["GK", "CB", "LB", "RB", "CM"], selectedOptions: .constant(Set(["CB", "CM"])), columns: 3)

            GlowBadge("Level 5", icon: "star.fill")

            ActionChip("Add Drill", icon: "plus.circle") {}
        }
        .padding()
    }
}