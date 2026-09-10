import SwiftUI

// MARK: - Design System (Touchline)
//
// Token NAMES are stable so call sites don't change; VALUES follow the Touchline handoff
// (design_handoff_touchline, Sep 2026). Surfaces are near-black greens, one pitch-green hero per
// screen, grass for the single primary action, condensed SF Pro for names and figures.
// No shadows, no gradients, no glows: depth comes from surface steps (base → raised → pitch).
struct DesignSystem {

    // MARK: - Colors
    struct Colors {
        // Surfaces (dark-only)
        static let surfaceBase = Color(hex: 0x0E1210)       // screen background
        static let surfaceRaised = Color(hex: 0x161C18)     // search field, segment track, tiles, idle chips
        static let surfaceOverlay = Color(hex: 0x1F2722)    // 1 px rules and borders, skeleton blocks
        static let surfaceHighlight = Color(hex: 0x2A342D)  // level-bar track, inactive ring, disabled
        static let pitch = Color(hex: 0x173A26)             // the one tappable hero per screen
        static let pitchLine = Color(hex: 0xEEF1EC).opacity(0.24) // pitch markings on pitch surfaces

        // Accents
        static let accentLime = Color(hex: 0x5CCB5F)        // grass: primary button, selected, done, eyebrows
        static let grass = accentLime
        static let accentLimeDim = Color(hex: 0x3E9A48)     // pressed state of grass
        static let grassPressed = accentLimeDim
        static let bloodOrange = Color(hex: 0xF0A33A)       // cone: diagram cones, "Advanced" badge
        static let cone = bloodOrange
        static let error = Color(hex: 0xB23A3A)             // destructive, "Elite" badge, error banner

        // Text (chalk tones)
        static let chalkWhite = Color(hex: 0xEEF1EC)        // primary text, inverse button fill
        static let mutedIvory = Color(hex: 0xB9C1BB)        // body text on dark
        static let dimIvory = Color(hex: 0x8E968F)          // secondary labels, figure units
        static let textTertiary = Color(hex: 0x4E5651)      // idle tab icons, chevrons, disabled day letters
        static let textOnPitch = Color(hex: 0xBFD3C4)       // meta / body on pitch surfaces
        static let bodyOnPitch = Color(hex: 0xD7E3DA)       // coach copy on pitch surfaces
        static let mutedOnPitch = Color(hex: 0x8FA896)      // italic "unavailable offline" note on pitch
        static let bannerText = Color(hex: 0xD7DDD8)        // banner message body

        // MARK: Semantic aliases (legacy token names → Touchline)

        // Primary brand
        static let primaryGreen = accentLime
        static let primaryGreenLight = accentLime
        static let primaryGreenDark = accentLimeDim

        // Secondary / gold (collapsed to grass; orange → cone)
        static let secondaryBlue = accentLime
        static let secondaryBlueLight = accentLime
        static let accentGold = accentLime
        static let accentOrange = cone
        static let accentYellow = accentLime

        // Gamification — demoted to one footer line; everything reads grass
        static let successGreen = accentLime
        static let streakOrange = accentLime
        static let xpGold = accentLime
        static let levelPurple = accentLime
        static let coinGold = accentLime

        // Semantic
        static let success = accentLime
        static let warning = cone
        static let info = accentLime

        // Text aliases
        static let textPrimary = chalkWhite
        static let textSecondary = mutedIvory
        static let textOnAccent = surfaceBase
        static let primaryDark = surfaceBase

        // Background aliases
        static let background = surfaceBase
        static let backgroundSecondary = surfaceRaised
        static let backgroundTertiary = surfaceOverlay
        static let cardBackground = surfaceRaised
        static let cardBorder = surfaceOverlay
        static let darkModeBackground = surfaceBase
        static let cellBackground = surfaceRaised

        // Preserved: rarity system (players recognize these)
        static let rarityCommon = Color(red: 0.62, green: 0.62, blue: 0.62)
        static let rarityUncommon = Color(red: 0.3, green: 0.69, blue: 0.31)
        static let rarityRare = Color(red: 0.13, green: 0.59, blue: 0.95)
        static let rarityEpic = Color(red: 0.61, green: 0.15, blue: 0.69)
        static let rarityLegendary = Color(red: 1.0, green: 0.76, blue: 0.03)

        // Legacy neutrals (aliases to chalk tones / surfaces)
        static let neutral100 = chalkWhite
        static let neutral200 = surfaceHighlight
        static let neutral300 = surfaceOverlay
        static let neutral400 = mutedIvory
        static let neutral500 = mutedIvory
        static let neutral600 = dimIvory
        static let neutral700 = dimIvory
        static let neutral800 = surfaceHighlight
        static let neutral900 = surfaceBase

        // Confetti palette (session complete no longer uses confetti; kept for achievements)
        static let confettiColors: [Color] = [
            accentLime,
            chalkWhite,
            cone,
            accentLimeDim
        ]
    }

    // MARK: - Typography
    //
    // Display = SF Pro .width(.condensed) semibold/bold, uppercase at the call site.
    // Text = SF Pro regular width. Numbers get .monospacedDigit(), never the monospaced design.
    struct Typography {
        // Display — condensed, uppercase
        static let heroDisplay = Font.system(size: 60, weight: .bold).width(.condensed).leading(.tight)      // sign-in headline
        static let displayLarge = Font.system(size: 56, weight: .bold).width(.condensed).leading(.tight)     // session complete
        static let displayMedium = Font.system(size: 40, weight: .semibold).width(.condensed).leading(.tight) // drill name in hero / detail / session
        static let displayMediumLarge = Font.system(size: 46, weight: .semibold).width(.condensed).leading(.tight) // larger hero titles
        static let displaySmall = Font.system(size: 30, weight: .semibold).width(.condensed).leading(.tight) // screen titles (Train, Plans, You)

        // Headlines — text face, sentences and card titles
        static let headlineLarge = Font.system(size: 22, weight: .bold)
        static let headlineMedium = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 17, weight: .semibold)

        // Titles
        static let titleLarge = Font.system(size: 20, weight: .semibold)
        static let titleMedium = Font.system(size: 15, weight: .semibold)   // row titles
        static let titleSmall = Font.system(size: 13, weight: .medium)

        // Labels — condensed uppercase for buttons, chips, meta; eyebrow is the text face
        static let labelLarge = Font.system(size: 19, weight: .bold).width(.condensed)       // primary button label
        static let labelMedium = Font.system(size: 14, weight: .semibold).width(.condensed)  // chips, segment, row meta, WK 3 · DAY 2
        static let labelSmall = Font.system(size: 12, weight: .bold)                         // eyebrow: TODAY'S SESSION, ACTIVE PLAN
        static let labelCompact = Font.system(size: 16, weight: .bold).width(.condensed)     // compact button label
        static let labelTile = Font.system(size: 13, weight: .bold).width(.condensed)        // TEC / PHY / TAC tiles, badges

        // Body — text face
        static let bodyLarge = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .regular)   // coach copy, descriptions, steps
        static let bodySmall = Font.system(size: 13, weight: .regular)    // row subtitles, dates, footers
        static let bodySmallStrong = Font.system(size: 13, weight: .semibold)

        // Numbers — condensed with tabular digits
        static let numberHero = Font.system(size: 128, weight: .bold).width(.condensed).monospacedDigit().leading(.tight)   // active-session clock
        static let numberLarge = Font.system(size: 40, weight: .bold).width(.condensed).monospacedDigit().leading(.tight)   // session-complete figures
        static let numberMedium = Font.system(size: 26, weight: .semibold).width(.condensed).monospacedDigit() // stat rails
        static let numberSmall = Font.system(size: 15, weight: .semibold).width(.condensed).monospacedDigit()  // figure units, meta numbers

        // Letter spacing (apply with .tracking())
        struct Tracking {
            static let display: CGFloat = -1      // displayLarge / heroDisplay
            static let displayTight: CGFloat = -0.4 // displayMedium
            static let button: CGFloat = 1        // labelLarge
            static let label: CGFloat = 0.6       // labelMedium
            static let eyebrow: CGFloat = 1.2     // labelSmall
            static let badge: CGFloat = 0.7       // TQBadge
        }

        // Line spacing (apply with .lineSpacing()) — body 14 at 1.5 line height
        static let bodyLineSpacing: CGFloat = 14 * 0.5
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
        static let screenPadding: CGFloat = 20
        static let section: CGFloat = 16
        static let sectionLarge: CGFloat = 18
        static let rowVertical: CGFloat = 12
        static let rowVerticalLarge: CGFloat = 14
        static let rowGap: CGFloat = 12
        static let heroPadding: CGFloat = 18
        static let cardPadding: CGFloat = md
        static let hitTarget: CGFloat = 44
        static let buttonPadding: EdgeInsets = EdgeInsets(top: md, leading: 20, bottom: md, trailing: 20)
        static let textFieldPadding: EdgeInsets = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16

        // Specific use cases
        static let button: CGFloat = 8
        static let card: CGFloat = 12
        static let pitchCard: CGFloat = 14
        static let pitchCardCompact: CGFloat = 12
        static let tile: CGFloat = 6
        static let chip: CGFloat = 6
        static let badge: CGFloat = 3
        static let segmentTrack: CGFloat = 6
        static let segmentInner: CGFloat = 4
        static let banner: CGFloat = 6
        static let textField: CGFloat = 8
        static let image: CGFloat = 6
        /// Touchline does not use pills. Kept so legacy call sites compile.
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows (Touchline: none — depth comes from surface steps)
    struct Shadow {
        static let none = (color: Color.clear, radius: CGFloat(0), x: CGFloat(0), y: CGFloat(0))
        static let small = none
        static let medium = none
        static let large = none
        static let xl = none

        // Legacy glow aliases — dead
        static let glowSmall = none
        static let glowMedium = none
        static let glowLarge = none
        static let glowGold = none
    }

    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)

        // Athletic transition curves (kept)
        static let heroSpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.82)
        static let staggerSpring = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.85)
        static let tabMorph = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let microBounce = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

        // Touchline
        static let levelBar = SwiftUI.Animation.easeOut(duration: 0.8)
        static let skeletonPulse = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }

    // MARK: - Icons
    struct Icons {
        // Soccer-themed icons
        static let soccer = "soccerball"
        static let goal = "target"
        static let training = "figure.soccer"
        static let stats = "chart.bar.fill"
        static let trophy = "trophy.fill"
        static let star = "star.fill"
        static let time = "clock.fill"
        static let calendar = "calendar"
        static let streak = "flame.fill"
        static let ai = "sparkles"
        static let technical = "soccerball"
        static let physical = "bolt.fill"
        static let tactical = "brain"
        static let video = "play.rectangle.fill"

        // Navigation icons (outline idle / .fill selected — see Tab)
        static let home = "house.fill"
        static let sessions = "calendar"
        static let exercises = "figure.soccer"
        static let profile = "person.crop.circle.fill"

        /// Tab bar symbol pairs (idle, selected). Icon only; the screen title names the tab.
        enum Tab: Int, CaseIterable {
            case home = 0, train, plans, community, you

            var idle: String {
                switch self {
                case .home: return "house"
                case .train: return "figure.soccer"
                case .plans: return "calendar"
                case .community: return "person.2"
                case .you: return "person.crop.circle"
                }
            }

            var selected: String {
                switch self {
                case .home: return "house.fill"
                case .train: return "figure.soccer"
                case .plans: return "calendar"
                case .community: return "person.2.fill"
                case .you: return "person.crop.circle.fill"
                }
            }

            var accessibilityLabel: String {
                switch self {
                case .home: return "Home"
                case .train: return "Train"
                case .plans: return "Plans"
                case .community: return "Community"
                case .you: return "You"
                }
            }
        }

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

// MARK: - Color helpers
extension Color {
    /// Exact hex colour, e.g. `Color(hex: 0x5CCB5F)`.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - View Extensions
extension View {
    // Shadows are clear in Touchline; kept so legacy call sites compile.
    func customShadow(_ shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    // Flat raised card
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.card)
    }

    // Grass primary button
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.textOnAccent)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(DesignSystem.Colors.accentLime)
            .cornerRadius(DesignSystem.CornerRadius.button)
    }

    // Raised secondary button
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.button)
    }

    // Raised text field with a 1 px highlight border
    func modernTextFieldStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.textFieldPadding)
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.textField)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField)
                    .stroke(DesignSystem.Colors.surfaceHighlight, lineWidth: 1)
            )
    }

    /// Uppercase condensed display text with the Touchline display tracking.
    func displayStyle(tracking: CGFloat = DesignSystem.Typography.Tracking.displayTight) -> some View {
        self.textCase(.uppercase).tracking(tracking)
    }
}

// MARK: - Adaptive Shadow Modifier (no-op; shadows are gone)
struct AdaptiveShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Press animation
struct PressAnimation: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
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
    func pressAnimation() -> some View {
        self.modifier(PressAnimation())
    }
}

// MARK: - Adaptive Background (flat surfaceBase; the app is dark-only)
struct AdaptiveBackground: View {
    var body: some View {
        DesignSystem.Colors.surfaceBase
    }
}

extension View {
    /// Applies the flat Touchline base surface behind a screen.
    func adaptiveBackground() -> some View {
        self.background(AdaptiveBackground().ignoresSafeArea())
    }
}
