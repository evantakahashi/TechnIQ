import SwiftUI
import CoreData

// MARK: - Avatar Slot

/// Represents the different customizable slots on an avatar
enum AvatarSlot: String, CaseIterable, Identifiable {
    case skinTone = "skin_tone"
    case hairStyle = "hair_style"
    case hairColor = "hair_color"
    case faceStyle = "face_style"
    case jersey = "jersey"
    case shorts = "shorts"
    case socks = "socks"
    case cleats = "cleats"
    case accessory = "accessory"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skinTone: return "Skin Tone"
        case .hairStyle: return "Hair Style"
        case .hairColor: return "Hair Color"
        case .faceStyle: return "Face"
        case .jersey: return "Jersey"
        case .shorts: return "Shorts"
        case .socks: return "Socks"
        case .cleats: return "Cleats"
        case .accessory: return "Accessories"
        }
    }

    var icon: String {
        switch self {
        case .skinTone: return "hand.raised.fill"
        case .hairStyle: return "comb.fill"
        case .hairColor: return "paintpalette.fill"
        case .faceStyle: return "face.smiling.fill"
        case .jersey: return "tshirt.fill"
        case .shorts: return "rectangle.fill"
        case .socks: return "figure.walk"
        case .cleats: return "shoe.fill"
        case .accessory: return "sparkles"
        }
    }

    /// Whether this slot requires purchasing items (vs just selecting options)
    var requiresPurchase: Bool {
        switch self {
        case .skinTone, .hairColor, .faceStyle:
            return false // Free customization options
        case .hairStyle, .jersey, .shorts, .socks, .cleats, .accessory:
            return true // Items that can be purchased
        }
    }
}

// MARK: - Item Rarity

/// Rarity tiers for avatar items with associated pricing and level requirements
enum ItemRarity: String, CaseIterable, Identifiable, Comparable {
    case starter
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    /// Price range for this rarity tier (min, max)
    var priceRange: (min: Int, max: Int) {
        switch self {
        case .starter: return (0, 0)
        case .common: return (50, 150)
        case .uncommon: return (200, 400)
        case .rare: return (500, 800)
        case .epic: return (1000, 2000)
        case .legendary: return (2500, 5000)
        }
    }

    /// Minimum level required to purchase items of this rarity
    var levelRequirement: Int {
        switch self {
        case .starter: return 0
        case .common: return 0
        case .uncommon: return 5
        case .rare: return 15
        case .epic: return 25
        case .legendary: return 40
        }
    }

    var color: Color {
        switch self {
        case .starter: return DesignSystem.Colors.textSecondary
        case .common: return DesignSystem.Colors.rarityCommon
        case .uncommon: return DesignSystem.Colors.rarityUncommon
        case .rare: return DesignSystem.Colors.rarityRare
        case .epic: return DesignSystem.Colors.rarityEpic
        case .legendary: return DesignSystem.Colors.rarityLegendary
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .starter:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .common:
            return LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .uncommon:
            return LinearGradient(colors: [Color(red: 0.3, green: 0.69, blue: 0.31), Color(red: 0.4, green: 0.8, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rare:
            return LinearGradient(colors: [Color(red: 0.13, green: 0.59, blue: 0.95), Color(red: 0.3, green: 0.7, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic:
            return LinearGradient(colors: [Color(red: 0.61, green: 0.15, blue: 0.69), Color(red: 0.8, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.76, blue: 0.03), Color(red: 1.0, green: 0.9, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Sort order for Comparable conformance
    private var sortOrder: Int {
        switch self {
        case .starter: return 0
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 4
        case .legendary: return 5
        }
    }

    static func < (lhs: ItemRarity, rhs: ItemRarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Avatar Item

/// Represents a purchasable/equippable avatar item
struct AvatarItem: Identifiable, Hashable {
    let id: String
    let name: String
    let slot: AvatarSlot
    let rarity: ItemRarity
    let price: Int
    let assetName: String // Maps to asset catalog: avatar_[slot]_[assetName]
    let description: String
    let levelRequirement: Int

    /// Whether this item is available in the starter set (free)
    var isStarter: Bool {
        rarity == .starter
    }

    /// Full asset name for the asset catalog
    var fullAssetName: String {
        "avatar_\(slot.rawValue)_\(assetName)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AvatarItem, rhs: AvatarItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Avatar State

/// Represents the current state of a player's avatar configuration
struct AvatarState: Equatable {
    var skinTone: SkinTone
    var hairStyle: HairStyle
    var hairColor: HairColor
    var faceStyle: FaceStyle
    var jerseyStyle: JerseyStyle
    var shortsStyle: ShortsStyle
    var socksStyle: SocksStyle
    var cleatsStyle: CleatsStyle

    /// Default avatar configuration for new players
    static let `default` = AvatarState(
        skinTone: .medium,
        hairStyle: .shortWavy,
        hairColor: .brown,
        faceStyle: .happy,
        jerseyStyle: .starterGreen,
        shortsStyle: .starterWhite,
        socksStyle: .greenStriped,
        cleatsStyle: .starterGreen
    )

    /// Direct initialization
    init(
        skinTone: SkinTone,
        hairStyle: HairStyle,
        hairColor: HairColor,
        faceStyle: FaceStyle,
        jerseyStyle: JerseyStyle,
        shortsStyle: ShortsStyle,
        socksStyle: SocksStyle,
        cleatsStyle: CleatsStyle
    ) {
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.faceStyle = faceStyle
        self.jerseyStyle = jerseyStyle
        self.shortsStyle = shortsStyle
        self.socksStyle = socksStyle
        self.cleatsStyle = cleatsStyle
    }

    /// Initialize from raw string values (for Core Data compatibility)
    init(
        skinToneRaw: String?,
        hairStyleRaw: String?,
        hairColorRaw: String?,
        faceStyleRaw: String?,
        jerseyStyleRaw: String?,
        shortsStyleRaw: String?,
        socksStyleRaw: String?,
        cleatsStyleRaw: String?
    ) {
        self.skinTone = SkinTone(rawValue: skinToneRaw ?? "medium") ?? .medium
        self.hairStyle = HairStyle(rawValue: hairStyleRaw ?? "short_wavy") ?? .shortWavy
        self.hairColor = HairColor(rawValue: hairColorRaw ?? "brown") ?? .brown
        self.faceStyle = FaceStyle(rawValue: faceStyleRaw ?? "happy") ?? .happy
        self.jerseyStyle = JerseyStyle(rawValue: jerseyStyleRaw ?? "starter_green") ?? .starterGreen
        self.shortsStyle = ShortsStyle(rawValue: shortsStyleRaw ?? "starter_white") ?? .starterWhite
        self.socksStyle = SocksStyle(rawValue: socksStyleRaw ?? "green_striped") ?? .greenStriped
        self.cleatsStyle = CleatsStyle(rawValue: cleatsStyleRaw ?? "starter_green") ?? .starterGreen
    }
}

// MARK: - Skin Tone Options

/// Available skin tone options (free customization)
enum SkinTone: String, CaseIterable, Identifiable {
    case light = "light"
    case lightMedium = "light_medium"
    case medium = "medium"
    case mediumTan = "medium_tan"
    case tan = "tan"
    case brown = "brown"
    case darkBrown = "dark_brown"
    case dark = "dark"
    case deep = "deep"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .lightMedium: return "Light Medium"
        case .medium: return "Medium"
        case .mediumTan: return "Medium Tan"
        case .tan: return "Tan"
        case .brown: return "Brown"
        case .darkBrown: return "Dark Brown"
        case .dark: return "Dark"
        case .deep: return "Deep"
        }
    }

    var color: Color {
        switch self {
        case .light: return Color(red: 1.0, green: 0.87, blue: 0.77)
        case .lightMedium: return Color(red: 0.96, green: 0.8, blue: 0.69)
        case .medium: return Color(red: 0.87, green: 0.72, blue: 0.53)
        case .mediumTan: return Color(red: 0.78, green: 0.61, blue: 0.43)
        case .tan: return Color(red: 0.69, green: 0.49, blue: 0.33)
        case .brown: return Color(red: 0.55, green: 0.38, blue: 0.26)
        case .darkBrown: return Color(red: 0.43, green: 0.29, blue: 0.2)
        case .dark: return Color(red: 0.32, green: 0.21, blue: 0.15)
        case .deep: return Color(red: 0.22, green: 0.14, blue: 0.1)
        }
    }

    /// Asset name for body image
    var bodyAssetName: String {
        "body_\(rawValue)"
    }

    /// Tint color for face to match skin tone
    var faceTintColor: Color {
        color
    }
}

// MARK: - Hair Color Options

/// Available hair color options (free customization)
enum HairColor: String, CaseIterable, Identifiable {
    case black = "black"
    case darkBrown = "dark_brown"
    case brown = "brown"
    case auburn = "auburn"
    case red = "red"
    case strawberryBlonde = "strawberry_blonde"
    case blonde = "blonde"
    case platinum = "platinum"
    case white = "white"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .darkBrown: return "Dark Brown"
        case .brown: return "Brown"
        case .auburn: return "Auburn"
        case .red: return "Red"
        case .strawberryBlonde: return "Strawberry Blonde"
        case .blonde: return "Blonde"
        case .platinum: return "Platinum"
        case .white: return "White"
        }
    }

    var color: Color {
        switch self {
        case .black: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .darkBrown: return Color(red: 0.26, green: 0.15, blue: 0.07)
        case .brown: return Color(red: 0.4, green: 0.26, blue: 0.13)
        case .auburn: return Color(red: 0.55, green: 0.27, blue: 0.07)
        case .red: return Color(red: 0.7, green: 0.25, blue: 0.15)
        case .strawberryBlonde: return Color(red: 0.85, green: 0.65, blue: 0.45)
        case .blonde: return Color(red: 0.9, green: 0.8, blue: 0.55)
        case .platinum: return Color(red: 0.95, green: 0.95, blue: 0.9)
        case .white: return Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
}

// MARK: - Face Style Options

/// Available face expression options (free customization)
enum FaceStyle: String, CaseIterable, Identifiable {
    case happy = "happy"
    case determined = "determined"
    case cool = "cool"
    case excited = "excited"
    case focused = "focused"
    case celebrating = "celebrating"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .determined: return "face.dashed"
        case .cool: return "eyeglasses"
        case .excited: return "face.smiling.inverse"
        case .focused: return "eye"
        case .celebrating: return "star.fill"
        }
    }

    /// Asset name for face image
    var assetName: String {
        "face_\(rawValue)"
    }
}

// MARK: - Hair Style Options

/// Available hair style options
enum HairStyle: String, CaseIterable, Identifiable {
    case shortWavy = "short_wavy"
    case mediumWavy = "medium_wavy"
    case longWavy = "long_wavy"
    case buzzCut = "buzz_cut"
    case crewCut = "crew_cut"
    case afro = "afro"
    case braided = "braided"
    case slickedBack = "slicked_back"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortWavy: return "Short Wavy"
        case .mediumWavy: return "Medium Wavy"
        case .longWavy: return "Long Wavy"
        case .buzzCut: return "Buzz Cut"
        case .crewCut: return "Crew Cut"
        case .afro: return "Afro"
        case .braided: return "Braided"
        case .slickedBack: return "Slicked Back"
        }
    }

    /// Get asset name for this hair style with a given color
    func assetName(color: HairColor) -> String {
        "hair_\(rawValue)_\(color.rawValue)"
    }
}

// MARK: - Jersey Style Options

/// Available jersey styles
enum JerseyStyle: String, CaseIterable, Identifiable {
    case starterGreen = "starter_green"
    case classicWhite = "classic_white"
    case strikerRed = "striker_red"
    case royalBlue = "royal_blue"
    case brazilYellow = "brazil_yellow"
    case barcelonaStyle = "barcelona_style"
    case classicBlack = "classic_black"
    case orangeBlaze = "orange_blaze"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starterGreen: return "Starter Green"
        case .classicWhite: return "Classic White"
        case .strikerRed: return "Striker Red"
        case .royalBlue: return "Royal Blue"
        case .brazilYellow: return "Brazil Yellow"
        case .barcelonaStyle: return "Barcelona Style"
        case .classicBlack: return "Classic Black"
        case .orangeBlaze: return "Orange Blaze"
        }
    }

    var assetName: String {
        "jersey_\(rawValue)"
    }

    var isStarter: Bool {
        self == .starterGreen
    }
}

// MARK: - Shorts Style Options

/// Available shorts styles
enum ShortsStyle: String, CaseIterable, Identifiable {
    case starterWhite = "starter_white"
    case classicBlack = "classic_black"
    case matchingGreen = "matching_green"
    case blueAthletic = "blue_athletic"
    case redSport = "red_sport"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starterWhite: return "Starter White"
        case .classicBlack: return "Classic Black"
        case .matchingGreen: return "Matching Green"
        case .blueAthletic: return "Blue Athletic"
        case .redSport: return "Red Sport"
        }
    }

    var assetName: String {
        "shorts_\(rawValue)"
    }

    var isStarter: Bool {
        self == .starterWhite
    }
}

// MARK: - Socks Style Options

/// Available socks styles
enum SocksStyle: String, CaseIterable, Identifiable {
    case greenStriped = "green_striped"
    case whiteClassic = "white_classic"
    case blackAthletic = "black_athletic"
    case matchingColor = "matching_color"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .greenStriped: return "Green Striped"
        case .whiteClassic: return "White Classic"
        case .blackAthletic: return "Black Athletic"
        case .matchingColor: return "Matching Color"
        }
    }

    var assetName: String {
        "socks_\(rawValue)"
    }

    var isStarter: Bool {
        self == .greenStriped
    }
}

// MARK: - Cleats Style Options

/// Available cleats styles
enum CleatsStyle: String, CaseIterable, Identifiable {
    case starterGreen = "starter_green"
    case classicBlack = "classic_black"
    case speedWhite = "speed_white"
    case goldElite = "gold_elite"
    case neonBlue = "neon_blue"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starterGreen: return "Starter Green"
        case .classicBlack: return "Classic Black"
        case .speedWhite: return "Speed White"
        case .goldElite: return "Gold Elite"
        case .neonBlue: return "Neon Blue"
        }
    }

    var assetName: String {
        "cleats_\(rawValue)"
    }

    var isStarter: Bool {
        self == .starterGreen
    }
}

// MARK: - Coin Earning Event

/// Events that can earn coins
enum CoinEarningEvent {
    case sessionCompleted(duration: Int) // Duration in minutes
    case dailyStreakBonus(streakDay: Int)
    case weeklyStreakMilestone // 7 day streak
    case firstSessionOfDay
    case fiveStarRating
    case trainingPlanWeekCompleted
    case trainingPlanCompleted
    case achievementUnlocked(xpReward: Int)
    case levelUp(newLevel: Int)

    var coins: Int {
        switch self {
        case .sessionCompleted(let duration):
            // 10-25 coins based on duration
            let baseCoinPerMinute = 0.5
            let coins = Int(Double(duration) * baseCoinPerMinute)
            return min(max(coins, 10), 25)
        case .dailyStreakBonus(let streakDay):
            return 5 * streakDay
        case .weeklyStreakMilestone:
            return 50
        case .firstSessionOfDay:
            return 10
        case .fiveStarRating:
            return 15
        case .trainingPlanWeekCompleted:
            return 75
        case .trainingPlanCompleted:
            return 200
        case .achievementUnlocked(let xpReward):
            // Scale with achievement XP reward: 25-100 coins
            let coins = xpReward / 4
            return min(max(coins, 25), 100)
        case .levelUp(let newLevel):
            return 50 + (newLevel * 5)
        }
    }

    var displayName: String {
        switch self {
        case .sessionCompleted:
            return "Session Completed"
        case .dailyStreakBonus(let day):
            return "\(day) Day Streak"
        case .weeklyStreakMilestone:
            return "Weekly Streak!"
        case .firstSessionOfDay:
            return "First Session Today"
        case .fiveStarRating:
            return "Perfect Rating"
        case .trainingPlanWeekCompleted:
            return "Training Week Done"
        case .trainingPlanCompleted:
            return "Training Plan Complete!"
        case .achievementUnlocked:
            return "Achievement Unlocked"
        case .levelUp(let level):
            return "Level \(level)!"
        }
    }
}
