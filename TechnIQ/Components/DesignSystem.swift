import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors (Stadium Night)
    struct Colors {
        // Surfaces (dark-only)
        static let surfaceBase = Color(red: 0.051, green: 0.059, blue: 0.055)      // #0D0F0E
        static let surfaceRaised = Color(red: 0.082, green: 0.098, blue: 0.090)    // #151917
        static let surfaceOverlay = Color(red: 0.118, green: 0.137, blue: 0.125)   // #1E2320
        static let surfaceHighlight = Color(red: 0.165, green: 0.184, blue: 0.173) // #2A2F2C

        // Accents
        static let accentLime = Color(red: 0.800, green: 1.000, blue: 0.000)       // #CCFF00
        static let accentLimeDim = Color(red: 0.561, green: 0.702, blue: 0.000)    // #8FB300
        static let bloodOrange = Color(red: 1.000, green: 0.294, blue: 0.122)      // #FF4B1F

        // Text (chalk tones)
        static let chalkWhite = Color(red: 0.949, green: 0.941, blue: 0.902)       // #F2F0E6
        static let mutedIvory = Color(red: 0.659, green: 0.647, blue: 0.604)       // #A8A59A
        static let dimIvory = Color(red: 0.420, green: 0.412, blue: 0.384)         // #6B6962

        // MARK: - Semantic aliases (legacy token names → Stadium Night)

        // Primary brand (was emerald green)
        static let primaryGreen = accentLime
        static let primaryGreenLight = accentLime
        static let primaryGreenDark = accentLimeDim

        // Gold/secondary (collapsed to lime)
        static let secondaryBlue = accentLime
        static let secondaryBlueLight = accentLime
        static let accentGold = accentLime
        static let accentOrange = bloodOrange
        static let accentYellow = accentLime

        // Gamification
        static let successGreen = accentLime
        static let streakOrange = bloodOrange
        static let xpGold = accentLime
        static let levelPurple = accentLime
        static let coinGold = accentLime

        // Semantic
        static let success = accentLime
        static let warning = bloodOrange
        static let error = bloodOrange
        static let info = accentLime

        // Text aliases
        static let textPrimary = chalkWhite
        static let textSecondary = mutedIvory
        static let textTertiary = dimIvory
        static let textOnAccent = surfaceBase
        static let primaryDark = surfaceBase

        // Background aliases
        static let background = surfaceBase
        static let backgroundSecondary = surfaceRaised
        static let backgroundTertiary = surfaceOverlay
        static let cardBackground = surfaceRaised
        static let cardBorder = chalkWhite.opacity(0.08)
        static let darkModeBackground = surfaceBase
        static let cellBackground = surfaceRaised

        // Preserved: rarity system (players recognize these)
        static let rarityCommon = Color(red: 0.62, green: 0.62, blue: 0.62)
        static let rarityUncommon = Color(red: 0.3, green: 0.69, blue: 0.31)
        static let rarityRare = Color(red: 0.13, green: 0.59, blue: 0.95)
        static let rarityEpic = Color(red: 0.61, green: 0.15, blue: 0.69)
        static let rarityLegendary = Color(red: 1.0, green: 0.76, blue: 0.03)

        // Legacy neutrals (aliases to chalk tones)
        static let neutral100 = chalkWhite
        static let neutral200 = chalkWhite.opacity(0.12)
        static let neutral300 = chalkWhite.opacity(0.08)
        static let neutral400 = mutedIvory
        static let neutral500 = mutedIvory
        static let neutral600 = dimIvory
        static let neutral700 = dimIvory
        static let neutral800 = surfaceHighlight
        static let neutral900 = surfaceBase

        // Confetti palette
        static let confettiColors: [Color] = [
            accentLime,
            bloodOrange,
            chalkWhite,
            accentLimeDim
        ]

        // Gradients (all collapsed to lime or blood orange)
        static let primaryGradient = LinearGradient(
            colors: [accentLime, accentLimeDim],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let secondaryGradient = primaryGradient
        static let athleticGradient = primaryGradient
        static let xpGradient = primaryGradient
        static let levelUpGradient = primaryGradient
        static let celebrationGradient = primaryGradient
        static let streakGradient = LinearGradient(
            colors: [bloodOrange, bloodOrange.opacity(0.7)],
            startPoint: .bottom,
            endPoint: .top
        )
        static let backgroundGradient = LinearGradient(
            colors: [surfaceBase, surfaceRaised],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography (Stadium Night: compressed, heavy, screaming)
    struct Typography {
        // Display — compressed, black-weight SF Pro (Nike Training hero feel)
        static let heroDisplay = Font.system(size: 72, weight: .black).width(.compressed)
        static let displayLarge = Font.system(size: 56, weight: .black).width(.compressed)
        static let displayMedium = Font.system(size: 42, weight: .heavy).width(.compressed)
        static let displaySmall = Font.system(size: 32, weight: .heavy).width(.compressed)

        // Headlines — restrained, readable
        static let headlineLarge = Font.system(size: 24, weight: .bold)
        static let headlineMedium = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 17, weight: .semibold)

        // Titles
        static let titleLarge = Font.system(size: 22, weight: .semibold)
        static let titleMedium = Font.system(size: 16, weight: .semibold)
        static let titleSmall = Font.system(size: 14, weight: .medium)

        // Labels — compressed/heavy for buttons, tags, uppercase metadata
        static let labelLarge = Font.system(size: 15, weight: .heavy).width(.compressed)
        static let labelMedium = Font.system(size: 13, weight: .heavy).width(.compressed)
        static let labelSmall = Font.system(size: 11, weight: .heavy).width(.compressed)

        // Body — stays clean and readable
        static let bodyLarge = Font.system(size: 17, weight: .regular)
        static let bodyMedium = Font.system(size: 15, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)

        // Numbers — monospaced for stat alignment
        static let numberLarge = Font.system(size: 36, weight: .black, design: .monospaced)
        static let numberMedium = Font.system(size: 24, weight: .black, design: .monospaced)
        static let numberSmall = Font.system(size: 17, weight: .semibold, design: .monospaced)
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
    
    // MARK: - Corner Radius (Stadium Night: sharper)
    struct CornerRadius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16

        // Specific use cases
        static let button: CGFloat = sm
        static let card: CGFloat = lg
        static let textField: CGFloat = sm
        static let image: CGFloat = sm
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows (Stadium Night: flat, hard edges; glow aliases are dead)
    struct Shadow {
        static let small = (color: Color.black.opacity(0.3), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.4), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let large = (color: Color.black.opacity(0.5), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let xl = (color: Color.black.opacity(0.6), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))

        // Legacy glow aliases — flattened
        static let glowSmall = small
        static let glowMedium = medium
        static let glowLarge = large
        static let glowGold = medium
    }

    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)

        // Athletic transition curves
        static let heroSpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.82)
        static let staggerSpring = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.85)
        static let tabMorph = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let microBounce = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
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
    
    // Apply consistent card styling (adaptive glow in dark, shadow in light)
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .modifier(AdaptiveShadowModifier())
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

// MARK: - Adaptive Shadow Modifier
struct AdaptiveShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.customShadow(DesignSystem.Shadow.glowMedium)
        } else {
            content.customShadow(DesignSystem.Shadow.medium)
        }
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