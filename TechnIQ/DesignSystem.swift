import SwiftUI
import UIKit

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand colors - Emerald
        static let primaryGreen = Color(red: 0.0, green: 0.902, blue: 0.463) // #00E676
        static let primaryGreenLight = Color(red: 0.2, green: 0.945, blue: 0.565) // Lighter emerald
        static let primaryGreenDark = Color(red: 0.0, green: 0.72, blue: 0.37) // Darker emerald

        // Secondary colors - Gold (repurposed)
        static let secondaryBlue = Color(red: 1.0, green: 0.843, blue: 0.251) // #FFD740 Gold
        static let secondaryBlueLight = Color(red: 1.0, green: 0.894, blue: 0.463) // Lighter gold

        // Gold accent alias
        static let accentGold = secondaryBlue

        // Accent colors
        static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0) // #FF9800
        static let accentYellow = Color(red: 1.0, green: 0.92, blue: 0.23) // #FFEB3B

        // Celebration & Gamification colors
        static let successGreen = Color(red: 0.0, green: 0.9, blue: 0.4)
        static let streakOrange = Color(red: 1.0, green: 0.45, blue: 0.1)
        static let xpGold = Color(red: 1.0, green: 0.84, blue: 0.0)
        static let levelPurple = Color(red: 0.6, green: 0.4, blue: 0.9)

        // Coin currency color
        static let coinGold = Color(red: 1.0, green: 0.76, blue: 0.03) // #FFC107

        // Item Rarity colors
        static let rarityCommon = Color(red: 0.62, green: 0.62, blue: 0.62)
        static let rarityUncommon = Color(red: 0.3, green: 0.69, blue: 0.31)
        static let rarityRare = Color(red: 0.13, green: 0.59, blue: 0.95)
        static let rarityEpic = Color(red: 0.61, green: 0.15, blue: 0.69)
        static let rarityLegendary = Color(red: 1.0, green: 0.76, blue: 0.03)

        // Confetti colors
        static let confettiColors: [Color] = [
            primaryGreen,
            accentGold,
            accentOrange,
            accentYellow,
            Color(red: 0.9, green: 0.3, blue: 0.5), // Pink
            Color(red: 0.6, green: 0.4, blue: 0.9), // Purple
            Color(red: 0.2, green: 0.8, blue: 0.9)  // Cyan
        ]

        // Semantic colors
        static let success = primaryGreen
        static let warning = Color(red: 1.0, green: 0.671, blue: 0.251) // #FFAB40
        static let error = Color(red: 1.0, green: 0.231, blue: 0.361) // #FF3B5C
        static let info = secondaryBlue

        // Dark-first surface colors (adaptive)
        static let surfaceBase = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1)
                : UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1)
        })
        static let surfaceRaised = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1)
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        })
        static let surfaceOverlay = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.118, green: 0.118, blue: 0.133, alpha: 1)
                : UIColor(red: 0.941, green: 0.941, blue: 0.949, alpha: 1)
        })
        static let surfaceHighlight = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.165, green: 0.165, blue: 0.188, alpha: 1)
                : UIColor(red: 0.910, green: 0.910, blue: 0.925, alpha: 1)
        })

        // Neutral colors
        static let neutral100 = Color(red: 0.98, green: 0.98, blue: 0.98) // #FAFAFA
        static let neutral200 = Color(red: 0.96, green: 0.96, blue: 0.96) // #F5F5F5
        static let neutral300 = Color(red: 0.93, green: 0.93, blue: 0.93) // #EEEEEE
        static let neutral400 = Color(red: 0.74, green: 0.74, blue: 0.74) // #BDBDBD
        static let neutral500 = Color(red: 0.62, green: 0.62, blue: 0.62) // #9E9E9E
        static let neutral600 = Color(red: 0.46, green: 0.46, blue: 0.46) // #757575
        static let neutral700 = Color(red: 0.38, green: 0.38, blue: 0.38) // #616161
        static let neutral800 = Color(red: 0.26, green: 0.26, blue: 0.26) // #424242
        static let neutral900 = Color(red: 0.13, green: 0.13, blue: 0.13) // #212121

        // Background colors (mapped to surface tokens)
        static let background = surfaceBase
        static let backgroundSecondary = surfaceRaised
        static let backgroundTertiary = surfaceOverlay

        // Text colors (adaptive dark-first)
        static let textPrimary = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.95)
                : UIColor.label
        })
        static let textSecondary = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.60)
                : UIColor.secondaryLabel
        })
        static let textTertiary = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.38)
                : UIColor.tertiaryLabel
        })
        static let textOnAccent = Color(red: 0.039, green: 0.039, blue: 0.047) // #0A0A0C
        static let primaryDark = neutral900

        // Card backgrounds (mapped to surface tokens)
        static let cardBackground = surfaceRaised
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
            colors: [surfaceBase, surfaceRaised],
            startPoint: .top,
            endPoint: .bottom
        )

        // Athletic gradient (emerald → gold diagonal)
        static let athleticGradient = LinearGradient(
            colors: [primaryGreen, accentGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Celebration gradients
        static let xpGradient = LinearGradient(
            colors: [xpGold, accentOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let levelUpGradient = LinearGradient(
            colors: [primaryGreen, accentGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let streakGradient = LinearGradient(
            colors: [streakOrange, accentYellow],
            startPoint: .bottom,
            endPoint: .top
        )

        static let celebrationGradient = LinearGradient(
            colors: [primaryGreen, primaryGreenDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Dark mode backgrounds (mapped to surface tokens)
        static let darkModeBackground = Color(red: 0.039, green: 0.039, blue: 0.047) // #0A0A0C
        static let cellBackground = Color(red: 0.086, green: 0.086, blue: 0.094) // #161618
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

// MARK: - Adaptive Background
struct AdaptiveBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                DesignSystem.Colors.surfaceBase
            } else {
                DesignSystem.Colors.backgroundGradient
            }
        }
    }
}

extension View {
    /// Applies adaptive background: gradient in light mode, solid dark grey in dark mode
    func adaptiveBackground() -> some View {
        self.background(AdaptiveBackground().ignoresSafeArea())
    }
}