import SwiftUI

/// Reusable mascot component that displays "Kicko" in various emotional states
/// Uses SF Symbols as placeholders until custom mascot assets are added
struct MascotView: View {
    let state: MascotState
    let size: MascotSize
    var showSpeechBubble: Bool = false
    var speechText: String? = nil
    var animated: Bool = true

    @State private var isAnimating = false
    @State private var bounceOffset: CGFloat = 0

    enum MascotSize {
        case small      // 40pt - for inline use
        case medium     // 80pt - for cards
        case large      // 120pt - for modals
        case xlarge     // 180pt - for onboarding

        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 80
            case .large: return 120
            case .xlarge: return 180
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 40
            case .large: return 60
            case .xlarge: return 90
            }
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if showSpeechBubble, let text = speechText {
                speechBubble(text: text)
            }

            mascotBody
                .offset(y: bounceOffset)
        }
        .onAppear {
            if animated {
                startAnimation()
            }
        }
    }

    // MARK: - Mascot Body

    private var mascotBody: some View {
        ZStack {
            // Background circle (soccer ball body)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(.systemGray6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.dimension, height: size.dimension)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Soccer ball pattern
            soccerBallPattern

            // Face overlay
            faceOverlay

            // Accessories based on state
            accessoriesOverlay
        }
        .scaleEffect(animationScale)
    }

    // MARK: - Soccer Ball Pattern

    private var soccerBallPattern: some View {
        ZStack {
            // Pentagon patterns (simplified)
            ForEach(0..<5, id: \.self) { index in
                Pentagon()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: size.dimension * 0.2, height: size.dimension * 0.2)
                    .offset(pentagonOffset(for: index))
            }
        }
    }

    private func pentagonOffset(for index: Int) -> CGSize {
        let angle = (Double(index) / 5.0) * 2 * .pi - .pi / 2
        let radius = size.dimension * 0.28
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }

    // MARK: - Face Overlay

    private var faceOverlay: some View {
        VStack(spacing: size.dimension * 0.05) {
            // Eyes
            HStack(spacing: size.dimension * 0.15) {
                eyeView(isLeft: true)
                eyeView(isLeft: false)
            }

            // Mouth
            mouthView
        }
        .offset(y: size.dimension * 0.05)
    }

    private func eyeView(isLeft: Bool) -> some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(Color.white)
                .frame(width: size.dimension * 0.18, height: size.dimension * 0.22)
                .shadow(color: Color.black.opacity(0.1), radius: 1)

            // Pupil
            Circle()
                .fill(Color.black)
                .frame(width: size.dimension * 0.08, height: size.dimension * 0.08)
                .offset(x: eyePupilOffset.width * (isLeft ? 1 : -1), y: eyePupilOffset.height)

            // Eye highlight
            Circle()
                .fill(Color.white)
                .frame(width: size.dimension * 0.03, height: size.dimension * 0.03)
                .offset(x: size.dimension * 0.02, y: -size.dimension * 0.03)

            // Eyelids for tired/sleeping states
            if state == .tired || state == .sleeping {
                Ellipse()
                    .fill(Color(.systemGray5))
                    .frame(width: size.dimension * 0.18, height: size.dimension * (state == .sleeping ? 0.22 : 0.11))
                    .offset(y: state == .sleeping ? 0 : -size.dimension * 0.055)
            }
        }
    }

    private var eyePupilOffset: CGSize {
        switch state {
        case .thinking:
            return CGSize(width: size.dimension * 0.02, height: -size.dimension * 0.03)
        case .excited, .surprised:
            return CGSize(width: 0, height: -size.dimension * 0.02)
        case .disappointed:
            return CGSize(width: 0, height: size.dimension * 0.02)
        default:
            return .zero
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch state {
        case .happy, .waving, .coaching:
            // Happy smile
            SmilePath()
                .stroke(Color.black, lineWidth: size.dimension * 0.02)
                .frame(width: size.dimension * 0.25, height: size.dimension * 0.12)

        case .excited, .celebrating, .surprised:
            // Open mouth smile
            Ellipse()
                .fill(Color.black)
                .frame(width: size.dimension * 0.18, height: size.dimension * 0.12)
            Ellipse()
                .fill(Color(red: 0.9, green: 0.4, blue: 0.4))
                .frame(width: size.dimension * 0.12, height: size.dimension * 0.06)
                .offset(y: size.dimension * 0.02)

        case .proud, .encouraging:
            // Confident smile
            SmilePath()
                .stroke(Color.black, lineWidth: size.dimension * 0.025)
                .frame(width: size.dimension * 0.3, height: size.dimension * 0.15)

        case .thinking:
            // Neutral/pondering
            Capsule()
                .fill(Color.black)
                .frame(width: size.dimension * 0.12, height: size.dimension * 0.04)
                .offset(x: size.dimension * 0.05)

        case .tired, .sleeping:
            // Neutral/slight frown
            Capsule()
                .fill(Color.black)
                .frame(width: size.dimension * 0.15, height: size.dimension * 0.03)

        case .disappointed:
            // Sad mouth
            FrownPath()
                .stroke(Color.black, lineWidth: size.dimension * 0.02)
                .frame(width: size.dimension * 0.2, height: size.dimension * 0.08)
        }
    }

    // MARK: - Accessories

    @ViewBuilder
    private var accessoriesOverlay: some View {
        switch state {
        case .celebrating:
            // Party hat
            PartyHat()
                .fill(DesignSystem.Colors.accentYellow)
                .frame(width: size.dimension * 0.3, height: size.dimension * 0.35)
                .offset(x: size.dimension * 0.15, y: -size.dimension * 0.4)

        case .coaching:
            // Whistle
            Image(systemName: "megaphone.fill")
                .font(.system(size: size.dimension * 0.15))
                .foregroundColor(DesignSystem.Colors.accentOrange)
                .offset(x: size.dimension * 0.35, y: size.dimension * 0.1)

        case .thinking:
            // Thought bubble
            Image(systemName: "bubble.left.fill")
                .font(.system(size: size.dimension * 0.2))
                .foregroundColor(Color(.systemGray4))
                .offset(x: size.dimension * 0.35, y: -size.dimension * 0.3)

        case .sleeping:
            // ZZZ
            Text("Z")
                .font(.system(size: size.dimension * 0.15, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryBlue)
                .offset(x: size.dimension * 0.3, y: -size.dimension * 0.3)
            Text("z")
                .font(.system(size: size.dimension * 0.1, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryBlue.opacity(0.7))
                .offset(x: size.dimension * 0.4, y: -size.dimension * 0.4)

        case .excited, .surprised:
            // Sparkles
            Image(systemName: "sparkles")
                .font(.system(size: size.dimension * 0.15))
                .foregroundColor(DesignSystem.Colors.xpGold)
                .offset(x: size.dimension * 0.35, y: -size.dimension * 0.35)

        case .proud:
            // Star
            Image(systemName: "star.fill")
                .font(.system(size: size.dimension * 0.12))
                .foregroundColor(DesignSystem.Colors.xpGold)
                .offset(x: size.dimension * 0.35, y: -size.dimension * 0.35)

        default:
            EmptyView()
        }
    }

    // MARK: - Speech Bubble

    private func speechBubble(text: String) -> some View {
        Text(text)
            .font(size == .small ? DesignSystem.Typography.labelSmall : DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                SpeechBubbleShape()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Animation

    private var animationScale: CGFloat {
        guard animated else { return 1.0 }

        switch state {
        case .excited, .celebrating:
            return isAnimating ? 1.1 : 1.0
        case .surprised:
            return isAnimating ? 1.15 : 1.0
        default:
            return 1.0
        }
    }

    private func startAnimation() {
        switch state {
        case .happy, .waving, .encouraging:
            // Gentle bounce
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                bounceOffset = -5
            }

        case .excited, .celebrating:
            // Excited bounce
            withAnimation(
                .spring(response: 0.4, dampingFraction: 0.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
                bounceOffset = -10
            }

        case .thinking:
            // Slow sway
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                bounceOffset = -3
            }

        case .sleeping:
            // Very slow breathing effect
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                bounceOffset = -2
            }

        default:
            break
        }
    }
}

// MARK: - Helper Shapes

struct Pentagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<5 {
            let angle = (Double(i) / 5.0) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.5)
        )
        return path
    }
}

struct FrownPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

struct PartyHat: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 12
        let tailSize: CGFloat = 10

        // Main bubble
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height - tailSize),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Tail
        path.move(to: CGPoint(x: rect.midX - tailSize, y: rect.height - tailSize))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.addLine(to: CGPoint(x: rect.midX + tailSize, y: rect.height - tailSize))

        return path
    }
}

// MARK: - Convenience Initializers

extension MascotView {
    /// Create mascot for achievement celebrations
    static func forAchievement(size: MascotSize = .large) -> MascotView {
        MascotView(state: .excited, size: size)
    }

    /// Create mascot for level up celebrations
    static func forLevelUp(size: MascotSize = .large) -> MascotView {
        MascotView(state: .proud, size: size)
    }

    /// Create mascot for onboarding screens
    static func forOnboarding(screenIndex: Int, size: MascotSize = .xlarge) -> MascotView {
        MascotView(state: MascotState.forOnboarding(screenIndex: screenIndex), size: size)
    }

    /// Create mascot for empty states
    static func forEmptyState(context: EmptyStateContext, size: MascotSize = .large) -> MascotView {
        MascotView(state: MascotState.forEmptyState(context: context), size: size)
    }

    /// Create mascot based on time of day
    static func forTimeOfDay(size: MascotSize = .medium) -> MascotView {
        MascotView(state: MascotState.forTimeOfDay(), size: size)
    }
}

// MARK: - Preview

#Preview("All States") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            ForEach(MascotState.allCases) { state in
                VStack {
                    MascotView(state: state, size: .medium)
                    Text(state.displayName)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("With Speech") {
    VStack(spacing: 40) {
        MascotView(
            state: .coaching,
            size: .large,
            showSpeechBubble: true,
            speechText: "Let's train!"
        )

        MascotView(
            state: .encouraging,
            size: .large,
            showSpeechBubble: true,
            speechText: "You can do it!"
        )
    }
}
