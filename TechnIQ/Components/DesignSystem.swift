import SwiftUI

// MARK: - Design System (Touchline)
//
// Values follow the Touchline handoff (Sep 2026). Surfaces are near-black greens, one pitch-green hero per
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
        static let grass = Color(hex: 0x5CCB5F)             // primary button, selected, done, eyebrows
        static let grassPressed = Color(hex: 0x3E9A48)      // pressed state of grass
        static let cone = Color(hex: 0xF0A33A)              // diagram cones, "Advanced" badge, warnings
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

        static let textOnAccent = surfaceBase               // labels on grass / chalk fills

        // Kit colours for avatar items — literal hues, independent of the UI accent.
        static let kitBlue = Color(hex: 0x2F6BFF)
        static let kitGold = Color(hex: 0xE5B93C)
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

        // Headline — text face
        static let headlineSmall = Font.system(size: 17, weight: .semibold)

        // Titles
        static let titleMedium = Font.system(size: 15, weight: .semibold)   // row titles
        static let titleSmall = Font.system(size: 13, weight: .medium)

        // Labels — condensed uppercase for buttons, chips, meta; eyebrow is the text face
        static let labelLarge = Font.system(size: 19, weight: .bold).width(.condensed)       // primary button label
        static let labelMedium = Font.system(size: 14, weight: .semibold).width(.condensed)  // chips, segment, row meta, WK 3 · DAY 2
        static let labelSmall = Font.system(size: 12, weight: .bold)                         // eyebrow: TODAY'S SESSION, ACTIVE PLAN
        static let labelTile = Font.system(size: 13, weight: .bold).width(.condensed)        // TEC / PHY / TAC tiles, badges

        // Body — text face
        static let bodyLarge = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .regular)   // coach copy, descriptions, steps
        static let bodySmall = Font.system(size: 13, weight: .regular)    // row subtitles, dates, footers
        static let bodySmallStrong = Font.system(size: 13, weight: .semibold)

        // Numbers — condensed with tabular digits
        static let numberHero = Font.system(size: 128, weight: .bold).width(.condensed).monospacedDigit().leading(.tight)   // active-session clock
        static let numberHeroCompact = Font.system(size: 88, weight: .bold).width(.condensed).monospacedDigit().leading(.tight)   // session clock under the drill film
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
        }
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48

        // Specific use cases
        static let screenPadding: CGFloat = 20
        static let section: CGFloat = 16
        static let sectionLarge: CGFloat = 18
        static let rowVertical: CGFloat = 12
        static let rowVerticalLarge: CGFloat = 14
        static let rowGap: CGFloat = 12
        static let hitTarget: CGFloat = 44
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12

        // Specific use cases
        static let button: CGFloat = 8
        static let card: CGFloat = 12
        static let pitchCard: CGFloat = 14
        static let pitchCardCompact: CGFloat = 12
        static let tile: CGFloat = 6
        static let badge: CGFloat = 3
        static let segmentTrack: CGFloat = 6
        static let segmentInner: CGFloat = 4
        static let banner: CGFloat = 6
        static let textField: CGFloat = 8
    }

    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let tabMorph = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let microBounce = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let levelBar = SwiftUI.Animation.easeOut(duration: 0.8)
        static let skeletonPulse = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }

    // MARK: - Icons
    struct Icons {
        static let technical = "soccerball"
        static let physical = "bolt.fill"
        static let tactical = "brain"

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

            /// Tabs on the bar: Community only behind `FeatureFlags.community`.
            static var visible: [Tab] { visible(community: FeatureFlags.community) }

            static func visible(community: Bool) -> [Tab] {
                allCases.filter { $0 != .community || community }
            }

            /// `-TQTab` value → tab: a name ("plans") or the stable raw index (0 home, 1 train, 2 plans,
            /// 3 community, 4 you). A hidden or unknown tab opens Home.
            static func fromLaunchValue(_ value: String, visible: [Tab]) -> Tab {
                let tab = Int(value).flatMap(Tab.init(rawValue:)) ?? allCases.first { String(describing: $0) == value.lowercased() }
                guard let tab, visible.contains(tab) else { return .home }
                return tab
            }
        }
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
