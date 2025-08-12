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
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
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
            .overlay(overlayForStyle)
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
                DesignSystem.Colors.primaryGradient
            case .secondary:
                DesignSystem.Colors.background
            case .ghost:
                Color.clear
            case .danger:
                DesignSystem.Colors.error
            }
        }
    }
    
    private var foregroundColorForStyle: Color {
        switch style {
        case .primary, .danger:
            return .white
        case .secondary:
            return DesignSystem.Colors.primaryGreen
        case .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }
    
    private var overlayForStyle: some View {
        Group {
            switch style {
            case .secondary:
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
            default:
                EmptyView()
            }
        }
    }
    
    private var shadowForStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch style {
        case .primary, .danger:
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
    
    init(padding: CGFloat = DesignSystem.Spacing.cardPadding, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding(padding)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.medium)
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