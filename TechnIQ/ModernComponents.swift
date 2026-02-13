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
                        .font(DesignSystem.Typography.labelMedium)
                }
                Text(title)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
            }
            .padding(DesignSystem.Spacing.buttonPadding)
            .frame(maxWidth: .infinity)
            .background(backgroundForStyle)
            .foregroundColor(foregroundColorForStyle)
            .cornerRadius(DesignSystem.CornerRadius.button)
            .overlay(
                // Gradient sheen
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .fill(LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .top, endPoint: .bottom))
            )
            .overlay(borderForStyle)
            .customShadow(shadowForStyle)
            .scaleEffect(isPressed ? 0.95 : 1.0)
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
            return DesignSystem.Colors.primaryGreen
        case .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }

    private var borderForStyle: some View {
        Group {
            switch style {
            case .secondary:
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 1.5)
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
    @Environment(\.colorScheme) private var colorScheme

    init(
        padding: CGFloat = DesignSystem.Spacing.cardPadding,
        accentEdge: Edge? = nil,
        accentColor: Color = DesignSystem.Colors.primaryGreen,
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
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .overlay(accentBorder)
        .customShadow(colorScheme == .dark ? DesignSystem.Shadow.glowMedium : DesignSystem.Shadow.medium)
        .scaleEffect(isPressed ? 0.97 : 1.0)
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
                .foregroundColor(isFocused ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
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
            .background(DesignSystem.Colors.backgroundSecondary)
            .cornerRadius(DesignSystem.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField)
                    .stroke(
                        isFocused ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
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
                .stroke(DesignSystem.Colors.neutral200, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.smooth, value: progress)
        }
        .frame(width: size, height: size)
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
                        ProgressRing(progress: progress, color: color)
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)
                            .frame(width: 40, height: 40)
                            .background(color.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.sm)
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(color)
                .cornerRadius(28)
                .customShadow(DesignSystem.Shadow.large)
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
                            withAnimation(DesignSystem.Animation.quick) {
                                selectedIndex = index
                            }
                        }) {
                            Text(option)
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(selectedIndex == index ? .semibold : .regular)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .frame(minWidth: 60)
                                .background(
                                    selectedIndex == index 
                                        ? DesignSystem.Colors.primaryGreen 
                                        : DesignSystem.Colors.neutral200
                                )
                                .foregroundColor(
                                    selectedIndex == index 
                                        ? .white 
                                        : DesignSystem.Colors.textSecondary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Fill remaining space if needed
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
                                .fontWeight(selectedOptions.contains(option) ? .semibold : .regular)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .frame(minWidth: 50)
                                .background(
                                    selectedOptions.contains(option)
                                        ? DesignSystem.Colors.primaryGreen 
                                        : DesignSystem.Colors.neutral200
                                )
                                .foregroundColor(
                                    selectedOptions.contains(option)
                                        ? .white 
                                        : DesignSystem.Colors.textSecondary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Fill remaining space if needed
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
        .background(DesignSystem.Colors.background)
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
                    withAnimation(DesignSystem.Animation.quick) {
                        selectedIndex = index
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let icons = icons, index < icons.count {
                            Image(systemName: icons[index])
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(option)
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm + 2)
                    .background(
                        Group {
                            if selectedIndex == index {
                                Capsule()
                                    .fill(DesignSystem.Colors.primaryGreen)
                                    .matchedGeometryEffect(id: "segment_bg", in: segmentAnimation)
                            }
                        }
                    )
                    .foregroundColor(
                        selectedIndex == index
                            ? .white
                            : DesignSystem.Colors.textSecondary
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.backgroundSecondary)
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
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == index {
                                Capsule()
                                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.2))
                                    .frame(width: 56, height: 32)
                                    .matchedGeometryEffect(id: "tab_bg", in: tabAnimation)
                            }
                            Image(systemName: tab.0)
                                .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                        }
                        Text(tab.1)
                            .font(DesignSystem.Typography.labelSmall)
                    }
                    .foregroundColor(selectedTab == index ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
    }
}

// MARK: - Preview Provider
struct ModernComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModernButton("Primary Button", icon: "play.fill") {}
            ModernButton("Secondary Button", style: .secondary) {}
            
            ModernTextField("Email", text: .constant(""), placeholder: "Enter your email", icon: "envelope.fill")
            
            StatCard(title: "Total Sessions", value: "12", subtitle: "completed", icon: "calendar")
            
            PillSelector(options: ["All", "Physical", "Tactical"], selectedIndex: .constant(0), columns: 3)
            
            MultiSelectPillSelector(options: ["GK", "CB", "LB", "RB", "CM"], selectedOptions: .constant(Set(["CB", "CM"])), columns: 3)
        }
        .padding()
    }
}