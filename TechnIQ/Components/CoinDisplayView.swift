import SwiftUI

/// Animated coin counter display for showing player's coin balance
struct CoinDisplayView: View {
    @StateObject private var viewModel = CoinBalanceViewModel()
    let size: CoinDisplaySize

    enum CoinDisplaySize {
        case small   // For inline use
        case medium  // For cards
        case large   // For headers

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }

        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.labelSmall
            case .medium: return DesignSystem.Typography.labelMedium
            case .large: return DesignSystem.Typography.titleMedium
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium:
                return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .large:
                return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            }
        }
    }

    init(size: CoinDisplaySize = .medium) {
        self.size = size
    }

    var body: some View {
        HStack(spacing: 6) {
            // Coin icon
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: size.iconSize))
                .foregroundColor(DesignSystem.Colors.coinGold)

            // Balance with animation
            Text("\(viewModel.balance)")
                .font(size.font)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: viewModel.balance)

            // Animated change indicator
            if let amount = viewModel.animatingAmount {
                Text(amount > 0 ? "+\(amount)" : "\(amount)")
                    .font(DesignSystem.Typography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(amount > 0 ? DesignSystem.Colors.successGreen : DesignSystem.Colors.error)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(size.padding)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.coinGold.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.coinGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Coin Earned Animation View

/// Floating animation for showing coins earned
struct CoinEarnedAnimationView: View {
    let amount: Int
    let onComplete: () -> Void

    @State private var isVisible = false
    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(DesignSystem.Colors.coinGold)
            Text("+\(amount)")
                .fontWeight(.bold)
        }
        .font(DesignSystem.Typography.titleMedium)
        .foregroundColor(DesignSystem.Colors.coinGold)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .scaleEffect(scale)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
                scale = 1.0
            }

            // Float up
            withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
                offset = -50
            }

            // Fade out
            withAnimation(.easeOut(duration: 0.3).delay(1.5)) {
                isVisible = false
            }

            // Complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        }
    }
}

// MARK: - Coins Breakdown View

/// Shows a breakdown of coins earned from various sources
struct CoinsBreakdownView: View {
    let items: [(label: String, amount: Int)]
    let total: Int

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(DesignSystem.Colors.coinGold)
                Text("Coins Earned")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                Spacer()
                Text("+\(total)")
                    .font(DesignSystem.Typography.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.coinGold)
            }

            Divider()

            // Breakdown items
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(items.indices, id: \.self) { index in
                    HStack {
                        Text(items[index].label)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("+\(items[index].amount)")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.coinGold.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.card)
    }
}

// MARK: - Coin Burst Animation

/// Particle effect for coin collection celebrations
struct CoinBurstView: View {
    let particleCount: Int
    @State private var particles: [CoinParticle] = []

    struct CoinParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var scale: CGFloat
        var opacity: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.coinGold)
                    .scaleEffect(particle.scale)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }

    private func createParticles() {
        particles = (0..<particleCount).map { _ in
            CoinParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2,
                rotation: 0,
                scale: 0.5,
                opacity: 1.0
            )
        }
    }

    private func animateParticles() {
        for i in particles.indices {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 100...200)
            let delay = Double(i) * 0.02

            withAnimation(.easeOut(duration: 0.8).delay(delay)) {
                particles[i].x += cos(angle) * distance
                particles[i].y += sin(angle) * distance
                particles[i].rotation = Double.random(in: -180...180)
                particles[i].scale = CGFloat.random(in: 0.8...1.2)
            }

            withAnimation(.easeIn(duration: 0.3).delay(delay + 0.5)) {
                particles[i].opacity = 0
            }
        }
    }
}

// MARK: - Inline Coin Label

/// Simple inline coin display for use in text or lists
struct InlineCoinLabel: View {
    let amount: Int
    let showSign: Bool

    init(_ amount: Int, showSign: Bool = false) {
        self.amount = amount
        self.showSign = showSign
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.coinGold)

            Text(showSign && amount > 0 ? "+\(amount)" : "\(amount)")
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Previews

#Preview("Coin Display Sizes") {
    VStack(spacing: 20) {
        CoinDisplayView(size: .small)
        CoinDisplayView(size: .medium)
        CoinDisplayView(size: .large)
    }
    .padding()
}

#Preview("Coin Earned Animation") {
    CoinEarnedAnimationView(amount: 25) {}
}

#Preview("Coins Breakdown") {
    CoinsBreakdownView(
        items: [
            ("Session Complete", 15),
            ("First Session Today", 10),
            ("3 Day Streak", 15),
            ("Perfect Rating", 15)
        ],
        total: 55
    )
    .padding()
}

#Preview("Inline Coin Label") {
    VStack(spacing: 10) {
        HStack {
            Text("Price:")
            InlineCoinLabel(150)
        }

        HStack {
            Text("Earned:")
            InlineCoinLabel(25, showSign: true)
        }
    }
    .padding()
}
