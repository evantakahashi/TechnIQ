import SwiftUI

/// Composable avatar renderer that displays a soccer player character
/// Uses layered PNG assets with consistent 512x768 canvas for perfect stacking
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

        /// Avatar aspect ratio matches asset canvas (512:768 = 2:3)
        var height: CGFloat {
            dimension * 1.5
        }
    }

    init(avatarState: AvatarState, size: AvatarSize = .medium) {
        self.avatarState = avatarState
        self.size = size
    }

    var body: some View {
        // SIMPLIFIED: All assets have same 512x768 canvas with pre-positioned components
        // Just stack them with identical frames - no manual offsets needed
        ZStack {
            // Layer 1: Body with skin tone
            layerImage(avatarState.skinTone.bodyAssetName)

            // Layer 2: Shorts
            layerImage(avatarState.shortsStyle.assetName)

            // Layer 3: Jersey
            layerImage(avatarState.jerseyStyle.assetName)

            // Layer 4: Socks
            layerImage(avatarState.socksStyle.assetName)

            // Layer 5: Cleats
            layerImage(avatarState.cleatsStyle.assetName)

            // Layer 6: Face (tinted to match skin tone)
            layerImage(avatarState.faceStyle.assetName)
                .colorMultiply(avatarState.skinTone.faceTintColor)

            // Layer 7: Hair
            layerImage(avatarState.hairStyle.assetName(color: avatarState.hairColor))
        }
        .frame(width: size.dimension, height: size.height)
    }

    /// Helper to create consistent layer images - all use same frame
    @ViewBuilder
    private func layerImage(_ assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.dimension, height: size.height)
    }
}

// MARK: - Simple Avatar View (Full Body Render)

/// Renders full avatar as a single layered composition
struct SimpleAvatarView: View {
    let avatarState: AvatarState
    let size: CGFloat

    var body: some View {
        ZStack {
            // Body
            Image(avatarState.skinTone.bodyAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Face with skin tone tint
            Image(avatarState.faceStyle.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .colorMultiply(avatarState.skinTone.faceTintColor)

            // Hair
            Image(avatarState.hairStyle.assetName(color: avatarState.hairColor))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .frame(width: size, height: size * 1.5)
    }
}

// MARK: - Compact Avatar View

/// Smaller, simplified avatar for lists and headers - shows head only
struct CompactAvatarView: View {
    let avatarState: AvatarState

    init(avatarState: AvatarState) {
        self.avatarState = avatarState
    }

    var body: some View {
        ZStack {
            // Background circle with jersey color hint
            Circle()
                .fill(jerseyColor.opacity(0.2))

            // Face - use full layer, clip will handle the rest
            Image(avatarState.faceStyle.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .colorMultiply(avatarState.skinTone.faceTintColor)
                .frame(width: 32, height: 48)
                .offset(y: 8) // Show upper portion (face area)

            // Hair
            Image(avatarState.hairStyle.assetName(color: avatarState.hairColor))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 54)
                .offset(y: 8)
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var jerseyColor: Color {
        switch avatarState.jerseyStyle {
        case .starterGreen: return DesignSystem.Colors.primaryGreen
        case .royalBlue: return DesignSystem.Colors.secondaryBlue
        case .strikerRed: return Color.red
        case .brazilYellow: return Color.yellow
        case .barcelonaStyle: return Color(red: 0.6, green: 0.1, blue: 0.2)
        case .classicBlack: return Color.black
        case .classicWhite: return Color.gray
        case .orangeBlaze: return DesignSystem.Colors.accentOrange
        }
    }
}

// MARK: - Avatar Preview Cell

/// Preview cell for showing a single avatar option in customization grid
struct AvatarOptionPreview: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Helper Shapes (kept for fallback)

/// Arc shape for smiles/frowns (fallback if images fail to load)
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
            ForEach(SkinTone.allCases.prefix(4)) { skinTone in
                VStack {
                    AvatarView(
                        avatarState: AvatarState(
                            skinTone: skinTone,
                            hairStyle: .shortWavy,
                            hairColor: .brown,
                            faceStyle: .happy,
                            jerseyStyle: .starterGreen,
                            shortsStyle: .starterWhite,
                            socksStyle: .greenStriped,
                            cleatsStyle: .starterGreen
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
            ForEach(HairStyle.allCases) { hairStyle in
                VStack {
                    AvatarView(
                        avatarState: AvatarState(
                            skinTone: .medium,
                            hairStyle: hairStyle,
                            hairColor: .black,
                            faceStyle: .happy,
                            jerseyStyle: .starterGreen,
                            shortsStyle: .starterWhite,
                            socksStyle: .greenStriped,
                            cleatsStyle: .starterGreen
                        ),
                        size: .small
                    )
                    Text(hairStyle.displayName)
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
            skinTone: .dark,
            hairStyle: .afro,
            hairColor: .black,
            faceStyle: .happy,
            jerseyStyle: .royalBlue,
            shortsStyle: .classicBlack,
            socksStyle: .blackAthletic,
            cleatsStyle: .classicBlack
        ))
        CompactAvatarView(avatarState: AvatarState(
            skinTone: .light,
            hairStyle: .longWavy,
            hairColor: .blonde,
            faceStyle: .cool,
            jerseyStyle: .strikerRed,
            shortsStyle: .starterWhite,
            socksStyle: .whiteClassic,
            cleatsStyle: .speedWhite
        ))
    }
    .padding()
}
