import SwiftUI

// MARK: - TQPitchMarkings
//
// Pitch geometry is the only decoration in Touchline and it only appears on pitch-green
// surfaces. Each preset reproduces the SVG overlay of a handoff mock: primitives are authored in
// the mock's viewBox and scaled independently on each axis (the mocks use
// `preserveAspectRatio="none"`), so a card of any size gets the same composition.

struct TQPitchMarkings: View {
    let preset: Preset

    var body: some View {
        MarkingsShape(preset: preset)
            .stroke(DesignSystem.Colors.chalkWhite, lineWidth: preset.lineWidth)
            .overlay(
                DotsShape(preset: preset)
                    .fill(DesignSystem.Colors.chalkWhite)
            )
            .opacity(preset.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Primitives (viewBox coordinates)

    enum Primitive {
        case rect(CGRect)
        case line(CGPoint, CGPoint)
        case circle(center: CGPoint, radius: CGFloat)
        case dot(center: CGPoint, radius: CGFloat)
        /// SVG-style arc between two points: `M from A r r 0 0 sweep to`.
        case arc(from: CGPoint, to: CGPoint, radius: CGFloat, sweep: Bool)
    }

    struct Preset {
        let viewBox: CGSize
        let opacity: Double
        let lineWidth: CGFloat
        let primitives: [Primitive]

        // Home hero (4a): full portrait pitch with both boxes.
        static let hero = Preset(viewBox: CGSize(width: 362, height: 260), opacity: 0.28, lineWidth: 1.5, primitives: [
            .rect(CGRect(x: 14, y: -40, width: 334, height: 330)),
            .line(CGPoint(x: 14, y: 130), CGPoint(x: 348, y: 130)),
            .circle(center: CGPoint(x: 181, y: 130), radius: 46),
            .dot(center: CGPoint(x: 181, y: 130), radius: 2.5),
            .rect(CGRect(x: 96, y: -40, width: 170, height: 70)),
            .rect(CGRect(x: 96, y: 230, width: 170, height: 70))
        ])

        // Hero without boxes (9b empty, 9c loading, 9d offline, 9e Train empty).
        static let heroSimple = Preset(viewBox: CGSize(width: 362, height: 260), opacity: 0.28, lineWidth: 1.5, primitives: [
            .rect(CGRect(x: 14, y: -40, width: 334, height: 330)),
            .line(CGPoint(x: 14, y: 130), CGPoint(x: 348, y: 130)),
            .circle(center: CGPoint(x: 181, y: 130), radius: 46)
        ])

        // Train "From your coach" strip (5a).
        static let strip = Preset(viewBox: CGSize(width: 362, height: 90), opacity: 0.25, lineWidth: 1.5, primitives: [
            .line(CGPoint(x: 0, y: 45), CGPoint(x: 362, y: 45)),
            .circle(center: CGPoint(x: 181, y: 45), radius: 34),
            .rect(CGRect(x: 0, y: 8, width: 60, height: 74)),
            .rect(CGRect(x: 302, y: 8, width: 60, height: 74))
        ])

        // Plans active-plan card (8a).
        static let plan = Preset(viewBox: CGSize(width: 362, height: 130), opacity: 0.22, lineWidth: 1.5, primitives: [
            .line(CGPoint(x: 0, y: 65), CGPoint(x: 362, y: 65)),
            .circle(center: CGPoint(x: 181, y: 65), radius: 46),
            .rect(CGRect(x: 0, y: 20, width: 56, height: 90)),
            .rect(CGRect(x: 306, y: 20, width: 56, height: 90))
        ])

        // Plan detail pinned "Today" card (5b).
        static let pinned = Preset(viewBox: CGSize(width: 362, height: 70), opacity: 0.22, lineWidth: 1.5, primitives: [
            .line(CGPoint(x: 0, y: 35), CGPoint(x: 362, y: 35)),
            .circle(center: CGPoint(x: 181, y: 35), radius: 26)
        ])

        // You profile card (6c).
        static let profile = Preset(viewBox: CGSize(width: 362, height: 150), opacity: 0.22, lineWidth: 1.5, primitives: [
            .line(CGPoint(x: 0, y: 75), CGPoint(x: 362, y: 75)),
            .circle(center: CGPoint(x: 181, y: 75), radius: 56),
            .dot(center: CGPoint(x: 181, y: 75), radius: 2.5)
        ])

        // Community "Drill of the week" (6b): a penalty box on the right.
        static let box = Preset(viewBox: CGSize(width: 362, height: 150), opacity: 0.22, lineWidth: 1.5, primitives: [
            .rect(CGRect(x: 240, y: -20, width: 160, height: 190)),
            .rect(CGRect(x: 300, y: 30, width: 100, height: 90)),
            .arc(from: CGPoint(x: 240, y: 40), to: CGPoint(x: 240, y: 110), radius: 50, sweep: false)
        ])

        // Active session (5c): the whole screen is the pitch.
        static let fullscreen = Preset(viewBox: CGSize(width: 402, height: 874), opacity: 0.2, lineWidth: 2, primitives: [
            .rect(CGRect(x: 18, y: -200, width: 366, height: 900)),
            .line(CGPoint(x: 18, y: 437), CGPoint(x: 384, y: 437)),
            .circle(center: CGPoint(x: 201, y: 437), radius: 90),
            .dot(center: CGPoint(x: 201, y: 437), radius: 3),
            .rect(CGRect(x: 92, y: 700, width: 218, height: 200)),
            .rect(CGRect(x: 146, y: 790, width: 110, height: 110)),
            .arc(from: CGPoint(x: 146, y: 700), to: CGPoint(x: 256, y: 700), radius: 62, sweep: true)
        ])

        // Session complete header (6a): bottom box with the D.
        static let sessionHeader = Preset(viewBox: CGSize(width: 402, height: 420), opacity: 0.22, lineWidth: 2, primitives: [
            .rect(CGRect(x: 18, y: -300, width: 366, height: 720)),
            .rect(CGRect(x: 92, y: 240, width: 218, height: 200)),
            .rect(CGRect(x: 146, y: 330, width: 110, height: 110)),
            .arc(from: CGPoint(x: 146, y: 240), to: CGPoint(x: 256, y: 240), radius: 62, sweep: true),
            .dot(center: CGPoint(x: 201, y: 300), radius: 3)
        ])

        // Sign-in header (7a): top box with the D below it.
        static let signIn = Preset(viewBox: CGSize(width: 402, height: 470), opacity: 0.24, lineWidth: 2, primitives: [
            .rect(CGRect(x: 18, y: 60, width: 366, height: 800)),
            .rect(CGRect(x: 92, y: 60, width: 218, height: 200)),
            .rect(CGRect(x: 146, y: 60, width: 110, height: 80)),
            .arc(from: CGPoint(x: 146, y: 260), to: CGPoint(x: 256, y: 260), radius: 62, sweep: false),
            .dot(center: CGPoint(x: 201, y: 200), radius: 3)
        ])

        // Drill diagram surface (7c, 9f): landscape half pitch.
        static let diagram = Preset(viewBox: CGSize(width: 362, height: 220), opacity: 0.28, lineWidth: 1.5, primitives: [
            .rect(CGRect(x: 16, y: 16, width: 330, height: 188)),
            .line(CGPoint(x: 181, y: 16), CGPoint(x: 181, y: 204)),
            .circle(center: CGPoint(x: 181, y: 110), radius: 34)
        ])

        // Component inventory swatch (9a): halfway line + centre circle.
        static let centre = Preset(viewBox: CGSize(width: 362, height: 100), opacity: 0.24, lineWidth: 1.5, primitives: [
            .line(CGPoint(x: 0, y: 50), CGPoint(x: 362, y: 50)),
            .circle(center: CGPoint(x: 181, y: 50), radius: 36)
        ])

        static let none = Preset(viewBox: CGSize(width: 1, height: 1), opacity: 0, lineWidth: 0, primitives: [])
    }

    // MARK: Shapes

    private struct MarkingsShape: Shape {
        let preset: Preset

        func path(in rect: CGRect) -> Path {
            var path = Path()
            for primitive in preset.primitives {
                switch primitive {
                case .rect(let r):
                    path.addRect(r)
                case .line(let a, let b):
                    path.move(to: a)
                    path.addLine(to: b)
                case .circle(let c, let r):
                    path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                case .arc(let from, let to, let radius, let sweep):
                    path.addPath(Self.arcPath(from: from, to: to, radius: radius, sweep: sweep))
                case .dot:
                    continue
                }
            }
            return path.applying(Self.transform(for: rect, viewBox: preset.viewBox))
        }

        /// Small (large-arc = 0) SVG arc between two points. `sweep` follows the SVG sweep flag
        /// (true = clockwise on screen, y down).
        static func arcPath(from: CGPoint, to: CGPoint, radius: CGFloat, sweep: Bool) -> Path {
            let dx = to.x - from.x, dy = to.y - from.y
            let d = sqrt(dx * dx + dy * dy)
            guard d > 0, radius >= d / 2 else {
                var p = Path(); p.move(to: from); p.addLine(to: to); return p
            }
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            let h = sqrt(max(radius * radius - (d / 2) * (d / 2), 0))
            // Unit perpendicular to the chord (chord direction rotated +90° in y-down space).
            let px = -dy / d, py = dx / d
            // Small arc: the centre sits opposite the bulge. In y-down coordinates a clockwise
            // sweep (SVG sweep-flag = 1) bulges toward -perp, so the centre is at mid + h·perp.
            let sign: CGFloat = sweep ? 1 : -1
            let center = CGPoint(x: mid.x + sign * h * px, y: mid.y + sign * h * py)
            let start = Angle(radians: atan2(from.y - center.y, from.x - center.x))
            let end = Angle(radians: atan2(to.y - center.y, to.x - center.x))
            var p = Path()
            p.move(to: from)
            // Path.addArc is defined for y-up space: `clockwise: false` walks increasing angles,
            // which is visually clockwise in SwiftUI's y-down space.
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: !sweep)
            return p
        }

        static func transform(for rect: CGRect, viewBox: CGSize) -> CGAffineTransform {
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height)
        }
    }

    private struct DotsShape: Shape {
        let preset: Preset

        func path(in rect: CGRect) -> Path {
            var path = Path()
            for case .dot(let c, let r) in preset.primitives {
                path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
            return path.applying(MarkingsShape.transform(for: rect, viewBox: preset.viewBox))
        }
    }
}

// MARK: - Pitch surface modifier

extension View {
    /// Fills the view with the pitch surface and draws the given markings behind the content.
    func pitchSurface(_ preset: TQPitchMarkings.Preset, cornerRadius: CGFloat = DesignSystem.CornerRadius.pitchCard) -> some View {
        self
            .background(
                ZStack {
                    DesignSystem.Colors.pitch
                    TQPitchMarkings(preset: preset)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
    }
}

#if DEBUG
#Preview("Markings") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach([("hero", TQPitchMarkings.Preset.hero, 260.0), ("strip", .strip, 90.0), ("plan", .plan, 130.0),
                     ("box", .box, 150.0), ("profile", .profile, 150.0), ("diagram", .diagram, 220.0),
                     ("signIn", .signIn, 470.0)], id: \.0) { item in
                Color.clear
                    .frame(height: item.2)
                    .pitchSurface(item.1)
                    .overlay(Text(item.0).font(DesignSystem.Typography.labelSmall).foregroundColor(DesignSystem.Colors.grass), alignment: .topLeading)
            }
        }
        .padding(20)
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
