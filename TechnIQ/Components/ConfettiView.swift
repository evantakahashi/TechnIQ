import SwiftUI

/// A celebratory confetti particle animation view
/// Used for achievements, level ups, and milestone celebrations
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let particleCount: Int
    let duration: Double
    let colors: [Color]

    init(
        particleCount: Int = 50,
        duration: Double = 3.0,
        colors: [Color] = DesignSystem.Colors.confettiColors
    ) {
        self.particleCount = particleCount
        self.duration = duration
        self.colors = colors
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                startAnimation()
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 6...14),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: 200...400)
                ),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 180...540),
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle
            )
        }
    }

    private func startAnimation() {
        withAnimation(.linear(duration: duration)) {
            isAnimating = true
        }
    }
}

/// Represents a single confetti particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let velocity: CGPoint
    var rotation: Double
    let rotationSpeed: Double
    let shape: ConfettiShape
}

/// Shapes for confetti particles
enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case triangle
    case star
}

/// View for rendering a single confetti particle with animation
struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    @State private var position: CGPoint
    @State private var rotation: Double
    @State private var opacity: Double = 1.0

    init(particle: ConfettiParticle) {
        self.particle = particle
        self._position = State(initialValue: particle.position)
        self._rotation = State(initialValue: particle.rotation)
    }

    var body: some View {
        particleShape
            .frame(width: particle.size, height: particle.size * aspectRatio)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
            .onAppear {
                animateParticle()
            }
    }

    private var aspectRatio: CGFloat {
        switch particle.shape {
        case .rectangle: return 1.5
        case .circle: return 1.0
        case .triangle: return 1.0
        case .star: return 1.0
        }
    }

    @ViewBuilder
    private var particleShape: some View {
        switch particle.shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: 2).fill(particle.color)
        case .circle:
            Circle().fill(particle.color)
        case .triangle:
            Triangle().fill(particle.color)
        case .star:
            Star(corners: 5, smoothness: 0.45).fill(particle.color)
        }
    }

    private func animateParticle() {
        let duration = Double.random(in: 2.5...3.5)

        // Animate position with physics-like motion
        withAnimation(.easeIn(duration: duration)) {
            position = CGPoint(
                x: position.x + particle.velocity.x * duration * 0.5,
                y: position.y + particle.velocity.y * duration + 200 // gravity effect
            )
        }

        // Animate rotation
        withAnimation(.linear(duration: duration)) {
            rotation = particle.rotation + particle.rotationSpeed * duration
        }

        // Fade out near the end
        withAnimation(.easeIn(duration: duration).delay(duration * 0.6)) {
            opacity = 0
        }
    }
}

/// Triangle shape for confetti
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Star shape for confetti
struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        var currentAngle = -CGFloat.pi / 2
        let angleAdjustment = .pi * 2 / CGFloat(corners * 2)
        let innerX = center.x * smoothness
        let innerY = center.y * smoothness
        var path = Path()

        path.move(to: CGPoint(
            x: center.x * cos(currentAngle) + center.x,
            y: center.y * sin(currentAngle) + center.y
        ))

        for corner in 0..<corners * 2 {
            let sinAngle = sin(currentAngle)
            let cosAngle = cos(currentAngle)

            if corner.isMultiple(of: 2) {
                path.addLine(to: CGPoint(
                    x: center.x * cosAngle + center.x,
                    y: center.y * sinAngle + center.y
                ))
            } else {
                path.addLine(to: CGPoint(
                    x: innerX * cosAngle + center.x,
                    y: innerY * sinAngle + center.y
                ))
            }

            currentAngle += angleAdjustment
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Burst Effect

/// A burst confetti effect that starts from a specific point
struct ConfettiBurstView: View {
    let origin: CGPoint
    let particleCount: Int
    let colors: [Color]

    @State private var particles: [BurstParticle] = []

    init(
        origin: CGPoint = .zero,
        particleCount: Int = 30,
        colors: [Color] = DesignSystem.Colors.confettiColors
    ) {
        self.origin = origin
        self.particleCount = particleCount
        self.colors = colors
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                BurstParticleView(particle: particle)
            }
        }
        .onAppear {
            createBurstParticles()
        }
        .allowsHitTesting(false)
    }

    private func createBurstParticles() {
        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 150...350)
            return BurstParticle(
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 4...10),
                position: origin,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                rotation: Double.random(in: 0...360)
            )
        }
    }
}

struct BurstParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    let velocity: CGPoint
    var rotation: Double
}

struct BurstParticleView: View {
    let particle: BurstParticle

    @State private var position: CGPoint
    @State private var rotation: Double
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    init(particle: BurstParticle) {
        self.particle = particle
        self._position = State(initialValue: particle.position)
        self._rotation = State(initialValue: particle.rotation)
    }

    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
            .onAppear {
                animateParticle()
            }
    }

    private func animateParticle() {
        let duration = Double.random(in: 0.8...1.5)

        withAnimation(.easeOut(duration: duration)) {
            position = CGPoint(
                x: position.x + particle.velocity.x * duration,
                y: position.y + particle.velocity.y * duration + 100 // gravity
            )
            scale = 0.3
        }

        withAnimation(.easeIn(duration: duration * 0.8).delay(duration * 0.3)) {
            opacity = 0
        }
    }
}

// MARK: - Sparkle Effect

/// A sparkle effect for subtle celebrations
struct SparkleView: View {
    let position: CGPoint
    let color: Color
    let count: Int

    @State private var sparkles: [Sparkle] = []

    init(position: CGPoint = .zero, color: Color = DesignSystem.Colors.xpGold, count: Int = 8) {
        self.position = position
        self.color = color
        self.count = count
    }

    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                SparkleParticle(sparkle: sparkle, color: color)
            }
        }
        .onAppear {
            createSparkles()
        }
        .allowsHitTesting(false)
    }

    private func createSparkles() {
        sparkles = (0..<count).map { i in
            let angle = (Double(i) / Double(count)) * 2 * .pi
            return Sparkle(
                position: position,
                angle: angle,
                distance: CGFloat.random(in: 20...50),
                delay: Double.random(in: 0...0.3)
            )
        }
    }
}

struct Sparkle: Identifiable {
    let id = UUID()
    let position: CGPoint
    let angle: Double
    let distance: CGFloat
    let delay: Double
}

struct SparkleParticle: View {
    let sparkle: Sparkle
    let color: Color

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var offset: CGSize = .zero

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12))
            .foregroundColor(color)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(sparkle.position)
            .offset(offset)
            .onAppear {
                animateSparkle()
            }
    }

    private func animateSparkle() {
        let targetOffset = CGSize(
            width: CGFloat(cos(sparkle.angle)) * sparkle.distance,
            height: CGFloat(sin(sparkle.angle)) * sparkle.distance
        )

        withAnimation(.easeOut(duration: 0.4).delay(sparkle.delay)) {
            scale = 1.0
            opacity = 1.0
            offset = targetOffset
        }

        withAnimation(.easeIn(duration: 0.3).delay(sparkle.delay + 0.4)) {
            scale = 0
            opacity = 0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        ConfettiView()
    }
}
