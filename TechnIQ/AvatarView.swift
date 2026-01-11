import SwiftUI

/// Composable avatar renderer that displays a soccer player character
/// Uses layered composition with placeholder graphics (to be replaced with PNG assets)
struct AvatarView: View {
    let avatarState: AvatarState
    let size: AvatarSize

    enum AvatarSize {
        case small      // 60pt - for lists, inline use
        case medium     // 120pt - for cards
        case large      // 200pt - for profile views
        case xlarge     // 300pt - for customization preview

        var dimension: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 120
            case .large: return 200
            case .xlarge: return 300
            }
        }

        /// Scale factor relative to xlarge
        var scale: CGFloat {
            dimension / 300.0
        }
    }

    init(avatarState: AvatarState, size: AvatarSize = .medium) {
        self.avatarState = avatarState
        self.size = size
    }

    var body: some View {
        ZStack {
            // Layer 1: Shadow/Ground
            groundShadow

            // Layer 2: Body base with skin tone
            bodyBase

            // Layer 3: Shorts
            shortsLayer

            // Layer 4: Jersey
            jerseyLayer

            // Layer 5: Cleats
            cleatsLayer

            // Layer 6: Face expression
            faceLayer

            // Layer 7-8: Hair (back and front combined in placeholder)
            hairLayer

            // Layer 9-10: Accessories
            accessoriesLayer
        }
        .frame(width: size.dimension, height: size.dimension * 1.5)
    }

    // MARK: - Placeholder Layers

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.15))
            .frame(width: size.dimension * 0.6, height: size.dimension * 0.15)
            .offset(y: size.dimension * 0.65)
    }

    private var bodyBase: some View {
        // Placeholder: Simple body shape with skin tone
        VStack(spacing: 0) {
            // Head
            Circle()
                .fill(skinToneColor)
                .frame(width: size.dimension * 0.35, height: size.dimension * 0.35)

            // Body/Torso
            RoundedRectangle(cornerRadius: size.dimension * 0.1)
                .fill(skinToneColor)
                .frame(width: size.dimension * 0.4, height: size.dimension * 0.1)
                .offset(y: -size.dimension * 0.02)

            // Legs (visible below shorts)
            HStack(spacing: size.dimension * 0.08) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skinToneColor)
                    .frame(width: size.dimension * 0.1, height: size.dimension * 0.3)
                RoundedRectangle(cornerRadius: 4)
                    .fill(skinToneColor)
                    .frame(width: size.dimension * 0.1, height: size.dimension * 0.3)
            }
            .offset(y: size.dimension * 0.15)
        }
        .offset(y: -size.dimension * 0.1)
    }

    private var shortsLayer: some View {
        // Placeholder shorts
        RoundedRectangle(cornerRadius: size.dimension * 0.05)
            .fill(shortsColor)
            .frame(width: size.dimension * 0.4, height: size.dimension * 0.18)
            .offset(y: size.dimension * 0.12)
    }

    private var jerseyLayer: some View {
        // Placeholder jersey/shirt
        VStack(spacing: 0) {
            // Jersey body
            RoundedRectangle(cornerRadius: size.dimension * 0.08)
                .fill(jerseyColor)
                .frame(width: size.dimension * 0.45, height: size.dimension * 0.25)

            // Jersey number (placeholder)
            if size != .small {
                Text("10")
                    .font(.system(size: size.dimension * 0.08, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(y: -size.dimension * 0.15)
            }
        }
        .offset(y: -size.dimension * 0.05)
    }

    private var cleatsLayer: some View {
        // Placeholder cleats
        HStack(spacing: size.dimension * 0.1) {
            RoundedRectangle(cornerRadius: 2)
                .fill(cleatsColor)
                .frame(width: size.dimension * 0.12, height: size.dimension * 0.06)
            RoundedRectangle(cornerRadius: 2)
                .fill(cleatsColor)
                .frame(width: size.dimension * 0.12, height: size.dimension * 0.06)
        }
        .offset(y: size.dimension * 0.58)
    }

    private var faceLayer: some View {
        // Placeholder face based on expression
        VStack(spacing: size.dimension * 0.02) {
            // Eyes
            HStack(spacing: size.dimension * 0.08) {
                Circle()
                    .fill(Color.black)
                    .frame(width: size.dimension * 0.04, height: size.dimension * 0.04)
                Circle()
                    .fill(Color.black)
                    .frame(width: size.dimension * 0.04, height: size.dimension * 0.04)
            }

            // Mouth based on expression
            faceExpression
        }
        .offset(y: -size.dimension * 0.35)
    }

    @ViewBuilder
    private var faceExpression: some View {
        switch avatarState.faceStyle {
        case "happy", "celebrating":
            // Smile
            ArcShape(startAngle: .degrees(0), endAngle: .degrees(180))
                .stroke(Color.black, lineWidth: size.dimension * 0.015)
                .frame(width: size.dimension * 0.1, height: size.dimension * 0.05)
        case "determined", "focused":
            // Neutral
            Rectangle()
                .fill(Color.black)
                .frame(width: size.dimension * 0.08, height: size.dimension * 0.015)
        case "cool":
            // Slight smirk
            ArcShape(startAngle: .degrees(10), endAngle: .degrees(170))
                .stroke(Color.black, lineWidth: size.dimension * 0.015)
                .frame(width: size.dimension * 0.08, height: size.dimension * 0.03)
        case "surprised":
            // Open mouth
            Circle()
                .fill(Color.black)
                .frame(width: size.dimension * 0.05, height: size.dimension * 0.05)
        default:
            // Default happy
            ArcShape(startAngle: .degrees(0), endAngle: .degrees(180))
                .stroke(Color.black, lineWidth: size.dimension * 0.015)
                .frame(width: size.dimension * 0.1, height: size.dimension * 0.05)
        }
    }

    private var hairLayer: some View {
        // Placeholder hair with color tinting
        Group {
            switch avatarState.hairStyle {
            case "short_1", "short_2", "short_3":
                // Short hair - cap-like shape on top
                Capsule()
                    .fill(hairToneColor)
                    .frame(width: size.dimension * 0.35, height: size.dimension * 0.15)
                    .offset(y: -size.dimension * 0.52)

            case "medium_1", "medium_2":
                // Medium hair - extends slightly
                VStack(spacing: 0) {
                    Capsule()
                        .fill(hairToneColor)
                        .frame(width: size.dimension * 0.38, height: size.dimension * 0.12)
                    Rectangle()
                        .fill(hairToneColor)
                        .frame(width: size.dimension * 0.35, height: size.dimension * 0.08)
                        .offset(y: -size.dimension * 0.02)
                }
                .offset(y: -size.dimension * 0.5)

            case "long_1", "ponytail":
                // Long hair
                VStack(spacing: 0) {
                    Capsule()
                        .fill(hairToneColor)
                        .frame(width: size.dimension * 0.38, height: size.dimension * 0.12)
                    RoundedRectangle(cornerRadius: size.dimension * 0.05)
                        .fill(hairToneColor)
                        .frame(width: size.dimension * 0.3, height: size.dimension * 0.2)
                        .offset(y: -size.dimension * 0.02)
                }
                .offset(y: -size.dimension * 0.48)

            case "afro":
                // Afro - larger rounded shape
                Circle()
                    .fill(hairToneColor)
                    .frame(width: size.dimension * 0.45, height: size.dimension * 0.45)
                    .offset(y: -size.dimension * 0.45)

            case "mohawk":
                // Mohawk - strip on top
                Capsule()
                    .fill(hairToneColor)
                    .frame(width: size.dimension * 0.08, height: size.dimension * 0.2)
                    .offset(y: -size.dimension * 0.55)

            case "bald":
                // No hair
                EmptyView()

            default:
                // Default short hair
                Capsule()
                    .fill(hairToneColor)
                    .frame(width: size.dimension * 0.35, height: size.dimension * 0.15)
                    .offset(y: -size.dimension * 0.52)
            }
        }
    }

    private var accessoriesLayer: some View {
        // Placeholder accessories
        ZStack {
            ForEach(avatarState.accessoryIds, id: \.self) { accessoryId in
                accessoryView(for: accessoryId)
            }
        }
    }

    @ViewBuilder
    private func accessoryView(for accessoryId: String) -> some View {
        switch accessoryId {
        case "captain_armband":
            // Yellow armband on left arm
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow)
                .frame(width: size.dimension * 0.05, height: size.dimension * 0.03)
                .offset(x: -size.dimension * 0.25, y: -size.dimension * 0.02)

        case "headband_white", "headband_black":
            // Headband
            RoundedRectangle(cornerRadius: 2)
                .fill(accessoryId.contains("white") ? Color.white : Color.black)
                .frame(width: size.dimension * 0.35, height: size.dimension * 0.025)
                .offset(y: -size.dimension * 0.42)

        case "wristband_left":
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: size.dimension * 0.04, height: size.dimension * 0.02)
                .offset(x: -size.dimension * 0.23, y: size.dimension * 0.05)

        case "sunglasses":
            // Sunglasses over eyes
            HStack(spacing: size.dimension * 0.02) {
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: size.dimension * 0.08, height: size.dimension * 0.05)
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: size.dimension * 0.08, height: size.dimension * 0.05)
            }
            .offset(y: -size.dimension * 0.38)

        default:
            EmptyView()
        }
    }

    // MARK: - Color Helpers

    private var skinToneColor: Color {
        guard let skinTone = SkinTone(rawValue: avatarState.skinTone) else {
            return SkinTone.medium.color
        }
        return skinTone.color
    }

    private var hairToneColor: Color {
        guard let hairColor = HairColor(rawValue: avatarState.hairColor) else {
            return HairColor.brown.color
        }
        return hairColor.color
    }

    private var jerseyColor: Color {
        // Map jersey ID to color (placeholder until real assets)
        switch avatarState.jerseyId {
        case "starter_jersey":
            return DesignSystem.Colors.primaryGreen
        case "jersey_blue":
            return DesignSystem.Colors.secondaryBlue
        case "jersey_red":
            return Color.red
        case "jersey_black":
            return Color.black
        case "jersey_white":
            return Color.white
        case "jersey_yellow":
            return Color.yellow
        case "jersey_stripes":
            return DesignSystem.Colors.primaryGreen // Would be pattern in real asset
        default:
            return DesignSystem.Colors.primaryGreen
        }
    }

    private var shortsColor: Color {
        switch avatarState.shortsId {
        case "starter_shorts":
            return Color.white
        case "shorts_black":
            return Color.black
        case "shorts_blue":
            return DesignSystem.Colors.secondaryBlue
        case "shorts_match":
            return jerseyColor.opacity(0.9)
        default:
            return Color.white
        }
    }

    private var cleatsColor: Color {
        switch avatarState.cleatsId {
        case "starter_cleats":
            return Color.black
        case "cleats_white":
            return Color.white
        case "cleats_gold":
            return DesignSystem.Colors.xpGold
        case "cleats_neon":
            return Color.green
        default:
            return Color.black
        }
    }
}

// MARK: - Helper Shapes

/// Arc shape for smiles/frowns
struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Compact Avatar View

/// Smaller, simplified avatar for lists and headers
struct CompactAvatarView: View {
    let avatarState: AvatarState

    init(avatarState: AvatarState) {
        self.avatarState = avatarState
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(jerseyColor.opacity(0.2))

            // Simple face representation
            VStack(spacing: 2) {
                // Hair
                Capsule()
                    .fill(hairColor)
                    .frame(width: 24, height: 8)
                    .offset(y: 2)

                // Face
                Circle()
                    .fill(skinColor)
                    .frame(width: 22, height: 22)
                    .overlay(
                        VStack(spacing: 3) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.black).frame(width: 3, height: 3)
                                Circle().fill(Color.black).frame(width: 3, height: 3)
                            }
                            ArcShape(startAngle: .degrees(0), endAngle: .degrees(180))
                                .stroke(Color.black, lineWidth: 1)
                                .frame(width: 8, height: 3)
                        }
                        .offset(y: 1)
                    )

                // Jersey hint
                RoundedRectangle(cornerRadius: 4)
                    .fill(jerseyColor)
                    .frame(width: 20, height: 10)
                    .offset(y: -2)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var skinColor: Color {
        SkinTone(rawValue: avatarState.skinTone)?.color ?? SkinTone.medium.color
    }

    private var hairColor: Color {
        HairColor(rawValue: avatarState.hairColor)?.color ?? HairColor.brown.color
    }

    private var jerseyColor: Color {
        switch avatarState.jerseyId {
        case "starter_jersey": return DesignSystem.Colors.primaryGreen
        case "jersey_blue": return DesignSystem.Colors.secondaryBlue
        case "jersey_red": return Color.red
        default: return DesignSystem.Colors.primaryGreen
        }
    }
}

// MARK: - Previews

#Preview("Avatar Sizes") {
    ScrollView {
        VStack(spacing: 40) {
            AvatarView(avatarState: .default, size: .small)
            AvatarView(avatarState: .default, size: .medium)
            AvatarView(avatarState: .default, size: .large)
        }
        .padding()
    }
}

#Preview("Avatar Customizations") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            // Different skin tones
            ForEach(SkinTone.allCases.prefix(4)) { skinTone in
                VStack {
                    AvatarView(
                        avatarState: AvatarState(
                            skinTone: skinTone.rawValue,
                            hairStyle: "short_1",
                            hairColor: "brown",
                            faceStyle: "happy",
                            jerseyId: "starter_jersey",
                            shortsId: "starter_shorts",
                            cleatsId: "starter_cleats",
                            accessoryIds: []
                        ),
                        size: .medium
                    )
                    Text(skinTone.displayName)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("Hair Styles") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            ForEach(["short_1", "medium_1", "long_1", "afro", "mohawk", "bald"], id: \.self) { hairStyle in
                VStack {
                    AvatarView(
                        avatarState: AvatarState(
                            skinTone: "medium",
                            hairStyle: hairStyle,
                            hairColor: "black",
                            faceStyle: "happy",
                            jerseyId: "starter_jersey",
                            shortsId: "starter_shorts",
                            cleatsId: "starter_cleats",
                            accessoryIds: []
                        ),
                        size: .small
                    )
                    Text(hairStyle)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("Compact Avatar") {
    HStack(spacing: 20) {
        CompactAvatarView(avatarState: .default)
        CompactAvatarView(avatarState: AvatarState(
            skinTone: "dark",
            hairStyle: "afro",
            hairColor: "black",
            faceStyle: "happy",
            jerseyId: "jersey_blue",
            shortsId: "shorts_black",
            cleatsId: "starter_cleats",
            accessoryIds: []
        ))
        CompactAvatarView(avatarState: AvatarState(
            skinTone: "light",
            hairStyle: "long_1",
            hairColor: "blonde",
            faceStyle: "cool",
            jerseyId: "jersey_red",
            shortsId: "starter_shorts",
            cleatsId: "cleats_white",
            accessoryIds: []
        ))
    }
    .padding()
}
