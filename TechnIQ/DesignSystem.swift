import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand colors - Soccer field inspired
        static let primaryGreen = Color(red: 0.0, green: 0.78, blue: 0.33) // #00C853
        static let primaryGreenLight = Color(red: 0.3, green: 0.86, blue: 0.51) // #4CAF50
        static let primaryGreenDark = Color(red: 0.0, green: 0.6, blue: 0.25) // #009624
        
        // Secondary colors
        static let secondaryBlue = Color(red: 0.08, green: 0.4, blue: 0.75) // #1565C0
        static let secondaryBlueLight = Color(red: 0.25, green: 0.54, blue: 0.96) // #42A5F5
        
        // Accent colors
        static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0) // #FF9800
        static let accentYellow = Color(red: 1.0, green: 0.92, blue: 0.23) // #FFEB3B
        
        // Semantic colors
        static let success = primaryGreen
        static let warning = accentOrange
        static let error = Color(red: 0.96, green: 0.26, blue: 0.21) // #F44336
        static let info = secondaryBlue
        
        // Neutral colors with warm tint
        static let neutral100 = Color(red: 0.98, green: 0.98, blue: 0.98) // #FAFAFA
        static let neutral200 = Color(red: 0.96, green: 0.96, blue: 0.96) // #F5F5F5
        static let neutral300 = Color(red: 0.93, green: 0.93, blue: 0.93) // #EEEEEE
        static let neutral400 = Color(red: 0.74, green: 0.74, blue: 0.74) // #BDBDBD
        static let neutral500 = Color(red: 0.62, green: 0.62, blue: 0.62) // #9E9E9E
        static let neutral600 = Color(red: 0.46, green: 0.46, blue: 0.46) // #757575
        static let neutral700 = Color(red: 0.38, green: 0.38, blue: 0.38) // #616161
        static let neutral800 = Color(red: 0.26, green: 0.26, blue: 0.26) // #424242
        static let neutral900 = Color(red: 0.13, green: 0.13, blue: 0.13) // #212121
        
        // Background colors
        static let background = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let backgroundTertiary = Color(.tertiarySystemBackground)
        
        // Text colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        static let primaryDark = neutral900
        
        // Card backgrounds
        static let cardBackground = Color(.systemBackground)
        static let cardBorder = neutral200
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primaryGreen, primaryGreenLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let secondaryGradient = LinearGradient(
            colors: [secondaryBlue, secondaryBlueLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [neutral100, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography
    struct Typography {
        // Display fonts
        static let displayLarge = Font.system(size: 57, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 45, weight: .bold, design: .default)
        static let displaySmall = Font.system(size: 36, weight: .bold, design: .default)
        
        // Headline fonts
        static let headlineLarge = Font.system(size: 32, weight: .bold, design: .default)
        static let headlineMedium = Font.system(size: 28, weight: .bold, design: .default)
        static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
        
        // Title fonts
        static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 16, weight: .medium, design: .default)
        static let titleSmall = Font.system(size: 14, weight: .medium, design: .default)
        
        // Label fonts
        static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
        
        // Body fonts
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
        
        // Numbers (tabular for consistency in stats)
        static let numberLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
        static let numberMedium = Font.system(size: 24, weight: .bold, design: .monospaced)
        static let numberSmall = Font.system(size: 16, weight: .semibold, design: .monospaced)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        
        // Specific use cases
        static let cardPadding: CGFloat = md
        static let screenPadding: CGFloat = lg
        static let buttonPadding: EdgeInsets = EdgeInsets(top: md, leading: lg, bottom: md, trailing: lg)
        static let textFieldPadding: EdgeInsets = EdgeInsets(top: md, leading: md, bottom: md, trailing: md)
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        
        // Specific use cases
        static let button: CGFloat = md
        static let card: CGFloat = lg
        static let textField: CGFloat = md
        static let image: CGFloat = sm
        static let pill: CGFloat = 50 // For pill-shaped buttons
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Colors.neutral900.opacity(0.05), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Colors.neutral900.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let large = (color: Colors.neutral900.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let xl = (color: Colors.neutral900.opacity(0.2), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
    
    // MARK: - Icons
    struct Icons {
        // Soccer-themed icons
        static let soccer = "soccerball"
        static let goal = "target"
        static let training = "figure.run"
        static let stats = "chart.bar.fill"
        static let trophy = "trophy.fill"
        static let star = "star.fill"
        static let time = "clock.fill"
        static let calendar = "calendar"
        
        // Navigation icons
        static let home = "house.fill"
        static let sessions = "calendar"
        static let exercises = "book.fill"
        static let profile = "person.fill"
        
        // Action icons
        static let play = "play.fill"
        static let plus = "plus"
        static let edit = "pencil"
        static let settings = "gearshape.fill"
        static let menu = "ellipsis"
        
        // Form icons
        static let email = "envelope.fill"
        static let password = "lock.fill"
        static let eyeOpen = "eye"
        static let eyeClosed = "eye.slash"
        static let checkmark = "checkmark.circle.fill"
        static let xmark = "xmark.circle.fill"
    }
}

// MARK: - View Extensions
extension View {
    // Apply shadow
    func customShadow(_ shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // Apply consistent card styling
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(DesignSystem.Shadow.medium)
    }
    
    // Apply primary button styling
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(DesignSystem.Colors.primaryGradient)
            .cornerRadius(DesignSystem.CornerRadius.button)
            .customShadow(DesignSystem.Shadow.medium)
    }
    
    // Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.primaryGreen)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
            )
            .cornerRadius(DesignSystem.CornerRadius.button)
    }
    
    // Apply modern text field styling
    func modernTextFieldStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.textFieldPadding)
            .background(DesignSystem.Colors.backgroundSecondary)
            .cornerRadius(DesignSystem.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField)
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1)
            )
    }
}

// MARK: - Custom View Modifiers
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(DesignSystem.Animation.springBouncy.repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

struct PressAnimation: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseAnimation())
    }
    
    func pressAnimation() -> some View {
        self.modifier(PressAnimation())
    }
}