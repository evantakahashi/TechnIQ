import SwiftUI

// MARK: - Avatar views
//
// The player's character is drawn in code (no image assets): flat shapes, one shade step, kit colours
// that are literal hues independent of the UI accent. `AvatarRenderer` draws in a fixed 200 × 300
// design space; the views only scale and crop it.

/// Full-body character that fills whatever frame it is given (2:3).
struct AvatarFigureView: View {
    let avatarState: AvatarState
    var kitNumber: Int?
    var showsBall = true

    var body: some View {
        Canvas { context, canvasSize in
            let k = min(canvasSize.width / AvatarRenderer.designSize.width,
                        canvasSize.height / AvatarRenderer.designSize.height)
            var ctx = context
            ctx.translateBy(x: (canvasSize.width - AvatarRenderer.designSize.width * k) / 2,
                            y: (canvasSize.height - AvatarRenderer.designSize.height * k) / 2)
            ctx.scaleBy(x: k, y: k)
            AvatarRenderer(state: avatarState, kitNumber: kitNumber, showsBall: showsBall).draw(in: ctx)
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Head-and-shoulders crop in a circle: headers, rows, option cells.
struct AvatarBustView: View {
    let avatarState: AvatarState
    var kitNumber: Int?
    var diameter: CGFloat = 44
    var background: Color = DesignSystem.Colors.surfaceRaised
    /// Design-space rect shown in the circle (default: head and shoulders).
    var focus: CGRect = AvatarRenderer.bustFocus
    var isCircular = true

    var body: some View {
        Canvas { context, canvasSize in
            let k = canvasSize.width / focus.width
            var ctx = context
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -focus.minX, y: -focus.minY)
            AvatarRenderer(state: avatarState, kitNumber: kitNumber, showsBall: false, showsGround: false).draw(in: ctx)
        }
        .frame(width: diameter, height: diameter)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: isCircular ? diameter / 2 : 0))
        .accessibilityHidden(true)
    }
}

// MARK: - Renderer

struct AvatarRenderer {
    static let designSize = CGSize(width: 200, height: 300)
    static let bustFocus = CGRect(x: 34, y: 14, width: 132, height: 132)
    static let kitFocus = CGRect(x: 30, y: 124, width: 140, height: 140)
    static let bootsFocus = CGRect(x: 52, y: 220, width: 96, height: 96)

    let state: AvatarState
    var kitNumber: Int?
    var showsBall = true
    var showsGround = true

    private var skin: Color { state.skinTone.color }
    private var hair: Color { state.hairColor.color }
    private var kit: AvatarKit { state.jerseyStyle.kit }
    private let ink = Color(hex: 0x1B1B1F)
    private let shade = Color.black.opacity(0.12)

    func draw(in context: GraphicsContext) {
        if showsGround { drawGround(context) }
        drawBackHair(context)
        drawLegs(context)
        drawShorts(context)
        drawArms(context)
        drawNeck(context)
        drawJersey(context)
        drawBraids(context)
        drawHead(context)
        drawFace(context)
        drawFrontHair(context)
        if showsBall { drawBall(context) }
    }

    // MARK: Ground

    private func drawGround(_ ctx: GraphicsContext) {
        ctx.fill(Ellipse().path(in: CGRect(x: 44, y: 286, width: 112, height: 11)), with: .color(.black.opacity(0.28)))
    }

    // MARK: Legs, socks, boots

    private func drawLegs(_ ctx: GraphicsContext) {
        let round = StrokeStyle(lineWidth: 19, lineCap: .round)
        for side: CGFloat in [-1, 1] {
            let x = 100 + side * 17
            var leg = Path()
            leg.move(to: CGPoint(x: x, y: 234))
            leg.addLine(to: CGPoint(x: x + side, y: 262))
            ctx.stroke(leg, with: .color(skin), style: round)

            // Sock
            let sockRect = CGRect(x: x + side - 10, y: 252, width: 20, height: 32)
            let sock = Path(roundedRect: sockRect, cornerRadius: 6)
            ctx.fill(sock, with: .color(socksColor))
            var clipped = ctx
            clipped.clip(to: sock)
            if state.socksStyle == .greenStriped {
                for y: CGFloat in [257, 265] {
                    clipped.fill(Path(CGRect(x: sockRect.minX, y: y, width: 20, height: 4)), with: .color(.white.opacity(0.9)))
                }
            } else {
                clipped.fill(Path(CGRect(x: sockRect.minX, y: 252, width: 20, height: 6)), with: .color(socksCuff))
            }
            clipped.fill(Path(CGRect(x: side > 0 ? x + 4 : sockRect.minX, y: 252, width: 7, height: 32)), with: .color(shade))

            // Boot: toe points outward
            let bootRect = CGRect(x: side > 0 ? x - 9 : x - 21, y: 279, width: 30, height: 14)
            let boot = Path(roundedRect: bootRect, cornerRadius: 7)
            ctx.fill(boot, with: .color(cleatsColor))
            var bootClip = ctx
            bootClip.clip(to: boot)
            bootClip.fill(Path(CGRect(x: bootRect.minX, y: 289, width: 30, height: 4)), with: .color(.black.opacity(0.35)))
            var stripe = Path()
            let sx = side > 0 ? bootRect.minX + 13 : bootRect.maxX - 13
            stripe.move(to: CGPoint(x: sx, y: 281))
            stripe.addLine(to: CGPoint(x: sx + side * 6, y: 288))
            bootClip.stroke(stripe, with: .color(cleatsAccent), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    // MARK: Shorts

    private func drawShorts(_ ctx: GraphicsContext) {
        var shorts = Path()
        shorts.move(to: CGPoint(x: 66, y: 204))
        shorts.addLine(to: CGPoint(x: 134, y: 204))
        shorts.addLine(to: CGPoint(x: 141, y: 243))
        shorts.addLine(to: CGPoint(x: 105, y: 243))
        shorts.addLine(to: CGPoint(x: 100, y: 230))
        shorts.addLine(to: CGPoint(x: 95, y: 243))
        shorts.addLine(to: CGPoint(x: 59, y: 243))
        shorts.closeSubpath()
        let outline = StrokeStyle(lineWidth: 5, lineJoin: .round)
        ctx.fill(shorts, with: .color(shortsColor))
        ctx.stroke(shorts, with: .color(shortsColor), style: outline)

        var clipped = ctx
        clipped.clip(to: shorts.strokedPath(outline).union(shorts))
        clipped.fill(Path(CGRect(x: 56, y: 239, width: 90, height: 8)), with: .color(shortsTrim))
        clipped.fill(Path(CGRect(x: 122, y: 200, width: 24, height: 50)), with: .color(shade))
    }

    // MARK: Arms

    private func drawArms(_ ctx: GraphicsContext) {
        for side: CGFloat in [-1, 1] {
            var arm = Path()
            arm.move(to: CGPoint(x: 100 + side * 50, y: 176))
            arm.addLine(to: CGPoint(x: 100 + side * 56, y: 206))
            ctx.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            ctx.fill(Circle().path(in: CGRect(x: 100 + side * 57 - 9.5, y: 203, width: 19, height: 19)), with: .color(skin))
        }
    }

    // MARK: Neck

    private func drawNeck(_ ctx: GraphicsContext) {
        let neck = Path(roundedRect: CGRect(x: 88, y: 118, width: 24, height: 34), cornerRadius: 8)
        ctx.fill(neck, with: .color(skin))
        var clipped = ctx
        clipped.clip(to: neck)
        clipped.fill(Ellipse().path(in: CGRect(x: 80, y: 112, width: 40, height: 24)), with: .color(.black.opacity(0.16)))
    }

    // MARK: Jersey

    private var torsoPath: Path {
        var torso = Path()
        torso.move(to: CGPoint(x: 68, y: 143))
        torso.addLine(to: CGPoint(x: 132, y: 143))
        torso.addLine(to: CGPoint(x: 140, y: 160))
        torso.addLine(to: CGPoint(x: 136, y: 210))
        torso.addLine(to: CGPoint(x: 64, y: 210))
        torso.addLine(to: CGPoint(x: 60, y: 160))
        torso.closeSubpath()
        return torso
    }

    private func sleevePath(_ side: CGFloat) -> Path {
        var sleeve = Path()
        sleeve.move(to: CGPoint(x: 100 + side * 32, y: 143))
        sleeve.addLine(to: CGPoint(x: 100 + side * 53, y: 153))
        sleeve.addLine(to: CGPoint(x: 100 + side * 62, y: 183))
        sleeve.addLine(to: CGPoint(x: 100 + side * 42, y: 189))
        sleeve.addLine(to: CGPoint(x: 100 + side * 36, y: 166))
        sleeve.closeSubpath()
        return sleeve
    }

    private func drawJersey(_ ctx: GraphicsContext) {
        let outline = StrokeStyle(lineWidth: 6, lineJoin: .round)
        var shirt = torsoPath
        shirt.addPath(sleevePath(-1))
        shirt.addPath(sleevePath(1))
        let silhouette = shirt.strokedPath(outline).union(shirt)
        ctx.fill(silhouette, with: .color(kit.base))

        var clipped = ctx
        clipped.clip(to: silhouette)
        switch kit.pattern {
        case .solid:
            break
        case .stripes(let second):
            for x in stride(from: CGFloat(47), to: 160, by: 26) {
                clipped.fill(Path(CGRect(x: x, y: 130, width: 13, height: 90)), with: .color(second))
            }
        case .sash(let second):
            var sash = Path()
            sash.move(to: CGPoint(x: 58, y: 140))
            sash.addLine(to: CGPoint(x: 80, y: 136))
            sash.addLine(to: CGPoint(x: 142, y: 206))
            sash.addLine(to: CGPoint(x: 124, y: 216))
            sash.closeSubpath()
            clipped.fill(sash, with: .color(second))
        case .hoop(let second):
            clipped.fill(Path(CGRect(x: 30, y: 163, width: 140, height: 12)), with: .color(second))
        }
        // Side shade + sleeve seams
        clipped.fill(Path(CGRect(x: 124, y: 130, width: 50, height: 90)), with: .color(shade))
        for side: CGFloat in [-1, 1] {
            var seam = Path()
            seam.move(to: CGPoint(x: 100 + side * 33, y: 147))
            seam.addLine(to: CGPoint(x: 100 + side * 38, y: 170))
            clipped.stroke(seam, with: .color(.black.opacity(0.14)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            var cuff = Path()
            cuff.move(to: CGPoint(x: 100 + side * 64, y: 183.5))
            cuff.addLine(to: CGPoint(x: 100 + side * 40, y: 190.5))
            clipped.stroke(cuff, with: .color(kit.trim), style: StrokeStyle(lineWidth: 6))
        }
        clipped.fill(Path(CGRect(x: 56, y: 208, width: 88, height: 6)), with: .color(.black.opacity(0.10)))

        // Collar: skin shows inside a crew neck
        var neckline = Path()
        neckline.move(to: CGPoint(x: 83, y: 139))
        neckline.addQuadCurve(to: CGPoint(x: 117, y: 139), control: CGPoint(x: 100, y: 161))
        var opening = neckline
        opening.closeSubpath()
        ctx.fill(opening, with: .color(skin))
        var openingClip = ctx
        openingClip.clip(to: opening)
        openingClip.fill(Ellipse().path(in: CGRect(x: 80, y: 124, width: 40, height: 22)), with: .color(.black.opacity(0.16)))
        ctx.stroke(neckline, with: .color(kit.trim), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        if let kitNumber {
            ctx.draw(
                Text("\(kitNumber)")
                    .font(.system(size: 30, weight: .bold).width(.condensed))
                    .foregroundColor(kit.number),
                at: CGPoint(x: 100, y: 183)
            )
        }
    }

    // MARK: Head

    private func headRect(expandedBy e: CGFloat = 0) -> CGRect {
        CGRect(x: 54 - e, y: 36 - e, width: 92 + 2 * e, height: 96 + 2 * e)
    }

    private func headPath(expandedBy e: CGFloat = 0) -> Path {
        Path(roundedRect: headRect(expandedBy: e), cornerRadius: 42 + e, style: .continuous)
    }

    private func drawHead(_ ctx: GraphicsContext) {
        for side: CGFloat in [-1, 1] {
            let cx = 100 + side * 46
            ctx.fill(Circle().path(in: CGRect(x: cx - 9, y: 82, width: 18, height: 20)), with: .color(skin))
            ctx.fill(Ellipse().path(in: CGRect(x: cx - 4, y: 87, width: 8, height: 10)), with: .color(.black.opacity(0.14)))
        }
        let head = headPath()
        ctx.fill(head, with: .color(skin))
        var clipped = ctx
        clipped.clip(to: head)
        clipped.fill(Path(CGRect(x: 128, y: 30, width: 30, height: 110)), with: .color(.black.opacity(0.06)))
        for side: CGFloat in [-1, 1] {
            clipped.fill(Circle().path(in: CGRect(x: 100 + side * 29 - 8, y: 100, width: 16, height: 12)),
                         with: .color(Color(hex: 0xE2574C).opacity(0.16)))
        }
    }

    // MARK: Face

    private func drawFace(_ ctx: GraphicsContext) {
        let style = state.faceStyle
        switch style {
        case .happy, .determined:
            drawEyes(ctx, width: 9, height: 12)
        case .excited:
            drawEyes(ctx, width: 11, height: 14, sparkle: true)
        case .focused:
            drawEyes(ctx, width: 10, height: 8)
            for side: CGFloat in [-1, 1] {
                var lid = Path()
                lid.move(to: CGPoint(x: 100 + side * 18 - 7, y: 87.5))
                lid.addLine(to: CGPoint(x: 100 + side * 18 + 7, y: 87.5))
                ctx.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        case .celebrating:
            for side: CGFloat in [-1, 1] {
                var arc = Path()
                arc.move(to: CGPoint(x: 100 + side * 18 - 7, y: 94))
                arc.addQuadCurve(to: CGPoint(x: 100 + side * 18 + 7, y: 94), control: CGPoint(x: 100 + side * 18, y: 84))
                ctx.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
        case .cool:
            drawSunglasses(ctx)
        }

        if style != .cool { drawBrows(ctx, style: style) }

        var nose = Path()
        nose.move(to: CGPoint(x: 96.5, y: 102))
        nose.addQuadCurve(to: CGPoint(x: 103.5, y: 102), control: CGPoint(x: 100, y: 107))
        ctx.stroke(nose, with: .color(.black.opacity(0.22)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        drawMouth(ctx, style: style)
    }

    private func drawEyes(_ ctx: GraphicsContext, width: CGFloat, height: CGFloat, sparkle: Bool = false) {
        for side: CGFloat in [-1, 1] {
            let c = CGPoint(x: 100 + side * 18, y: 92)
            ctx.fill(Ellipse().path(in: CGRect(x: c.x - width / 2, y: c.y - height / 2, width: width, height: height)), with: .color(ink))
            ctx.fill(Circle().path(in: CGRect(x: c.x - 0.5, y: c.y - height / 2 + 1.5, width: 3.6, height: 3.6)), with: .color(.white.opacity(0.95)))
            if sparkle {
                ctx.fill(Circle().path(in: CGRect(x: c.x - 3.5, y: c.y + 1.5, width: 2.2, height: 2.2)), with: .color(.white.opacity(0.8)))
            }
        }
    }

    private func drawBrows(_ ctx: GraphicsContext, style: FaceStyle) {
        let lift: CGFloat = style == .excited || style == .celebrating ? -3 : 0
        for side: CGFloat in [-1, 1] {
            let cx = 100 + side * 18
            var brow = Path()
            switch style {
            case .determined, .focused:
                // Slope down toward the nose.
                brow.move(to: CGPoint(x: cx - side * 8, y: 81))
                brow.addLine(to: CGPoint(x: cx + side * 8, y: 76))
            default:
                brow.move(to: CGPoint(x: cx - 8, y: 79 + lift))
                brow.addQuadCurve(to: CGPoint(x: cx + 8, y: 79 + lift), control: CGPoint(x: cx, y: 73.5 + lift))
            }
            ctx.stroke(brow, with: .color(browColor), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        }
    }

    private func drawSunglasses(_ ctx: GraphicsContext) {
        let frame = Color(hex: 0x101214)
        var arms = Path()
        arms.move(to: CGPoint(x: 55, y: 89))
        arms.addLine(to: CGPoint(x: 145, y: 89))
        ctx.stroke(arms, with: .color(frame), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        for side: CGFloat in [-1, 1] {
            let rect = CGRect(x: 100 + side * 19 - 15.5, y: 82, width: 31, height: 20)
            let lens = Path(roundedRect: rect, cornerRadius: 8, style: .continuous)
            ctx.fill(lens, with: .color(frame))
            var clipped = ctx
            clipped.clip(to: lens)
            var glint = Path()
            glint.move(to: CGPoint(x: rect.minX + 7, y: rect.maxY))
            glint.addLine(to: CGPoint(x: rect.minX + 17, y: rect.minY))
            clipped.stroke(glint, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 5))
        }
    }

    private func drawMouth(_ ctx: GraphicsContext, style: FaceStyle) {
        let lip = Color(hex: 0x3A1D1A)
        let line = StrokeStyle(lineWidth: 3.2, lineCap: .round)
        switch style {
        case .happy:
            var smile = Path()
            smile.move(to: CGPoint(x: 89, y: 112))
            smile.addQuadCurve(to: CGPoint(x: 111, y: 112), control: CGPoint(x: 100, y: 123))
            ctx.stroke(smile, with: .color(lip), style: line)
        case .excited, .celebrating:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 87, y: 110.5))
            mouth.addLine(to: CGPoint(x: 113, y: 110.5))
            mouth.addQuadCurve(to: CGPoint(x: 87, y: 110.5), control: CGPoint(x: 100, y: 133))
            mouth.closeSubpath()
            ctx.fill(mouth, with: .color(Color(hex: 0x4A1A1C)))
            ctx.stroke(mouth, with: .color(Color(hex: 0x4A1A1C)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            var clipped = ctx
            clipped.clip(to: mouth)
            clipped.fill(Path(CGRect(x: 86, y: 109, width: 28, height: 5.5)), with: .color(.white))
            clipped.fill(Ellipse().path(in: CGRect(x: 92, y: 118, width: 16, height: 10)), with: .color(Color(hex: 0xE0736F)))
        case .cool:
            var smirk = Path()
            smirk.move(to: CGPoint(x: 90, y: 114))
            smirk.addQuadCurve(to: CGPoint(x: 111, y: 110), control: CGPoint(x: 104, y: 119))
            ctx.stroke(smirk, with: .color(lip), style: line)
        case .determined:
            var firm = Path()
            firm.move(to: CGPoint(x: 91, y: 115))
            firm.addQuadCurve(to: CGPoint(x: 110, y: 113.5), control: CGPoint(x: 101, y: 117))
            ctx.stroke(firm, with: .color(lip), style: line)
        case .focused:
            var flat = Path()
            flat.move(to: CGPoint(x: 92, y: 115))
            flat.addLine(to: CGPoint(x: 108, y: 115))
            ctx.stroke(flat, with: .color(lip), style: line)
        }
    }

    // MARK: Hair

    private var hairHighlight: Color { .white.opacity(0.10) }
    private var hairLowlight: Color { .black.opacity(0.22) }

    private func drawBackHair(_ ctx: GraphicsContext) {
        switch state.hairStyle {
        case .longWavy:
            var back = Path(roundedRect: CGRect(x: 41, y: 28, width: 118, height: 146), cornerRadius: 50, style: .continuous)
            for x: CGFloat in [52, 76, 100, 124, 148] {
                back.addEllipse(in: CGRect(x: x - 13, y: 158, width: 26, height: 24))
            }
            ctx.fill(back, with: .color(hair))
            ctx.fill(back, with: .color(hairLowlight))
        case .afro:
            ctx.fill(afroPath, with: .color(hair))
        case .mediumWavy:
            let back = Path(roundedRect: CGRect(x: 45, y: 28, width: 110, height: 104), cornerRadius: 48, style: .continuous)
            ctx.fill(back, with: .color(hair))
            ctx.fill(back, with: .color(hairLowlight))
        default:
            break
        }
    }

    private var afroPath: Path {
        var afro = Path()
        afro.addEllipse(in: CGRect(x: 40, y: 6, width: 120, height: 112))
        for index in 0..<14 {
            let angle = CGFloat(index) / 14 * 2 * .pi
            let c = CGPoint(x: 100 + cos(angle) * 56, y: 62 + sin(angle) * 52)
            afro.addEllipse(in: CGRect(x: c.x - 14, y: c.y - 14, width: 28, height: 28))
        }
        return afro
    }

    /// Braids hang in front of the shoulders, so they sit between the jersey and the head.
    private func drawBraids(_ ctx: GraphicsContext) {
        guard state.hairStyle == .braided else { return }
        for side: CGFloat in [-1, 1] {
            for step in 0..<8 {
                let t = CGFloat(step)
                let c = CGPoint(x: 100 + side * (45 + t * 0.9), y: 100 + t * 10.5)
                ctx.fill(Ellipse().path(in: CGRect(x: c.x - 7.5, y: c.y - 7, width: 15, height: 14)), with: .color(hair))
                ctx.fill(Ellipse().path(in: CGRect(x: c.x - 7.5, y: c.y + 2, width: 15, height: 5)), with: .color(hairLowlight))
            }
            let end = CGPoint(x: 100 + side * 52.5, y: 186)
            ctx.fill(Path(roundedRect: CGRect(x: end.x - 6, y: end.y - 4, width: 12, height: 8), cornerRadius: 3), with: .color(kit.trim))
        }
    }

    private func drawFrontHair(_ ctx: GraphicsContext) {
        let style = state.hairStyle
        let volume: CGFloat
        switch style {
        case .buzzCut: volume = 0
        case .crewCut: volume = 2.5
        case .braided: volume = 3
        case .shortWavy: volume = 5
        case .slickedBack: volume = 5
        case .afro: volume = 6
        case .mediumWavy, .longWavy: volume = 8
        }

        var clipped = ctx
        clipped.clip(to: headPath(expandedBy: volume))
        let cap = hairline(for: style)
        clipped.fill(cap, with: .color(style == .buzzCut ? hair.opacity(0.62) : hair))

        var detail = clipped
        detail.clip(to: cap)
        switch style {
        case .shortWavy:
            strokeCurve(detail, from: CGPoint(x: 66, y: 60), to: CGPoint(x: 128, y: 48), control: CGPoint(x: 92, y: 36), color: hairHighlight, width: 7)
            strokeCurve(detail, from: CGPoint(x: 70, y: 74), to: CGPoint(x: 120, y: 66), control: CGPoint(x: 96, y: 60), color: hairLowlight.opacity(0.5), width: 2.5)
        case .mediumWavy, .longWavy:
            strokeCurve(detail, from: CGPoint(x: 100, y: 58), to: CGPoint(x: 100, y: 28), control: CGPoint(x: 96, y: 42), color: hairLowlight, width: 2.5)
            strokeCurve(detail, from: CGPoint(x: 58, y: 86), to: CGPoint(x: 88, y: 42), control: CGPoint(x: 60, y: 54), color: hairHighlight, width: 7)
            strokeCurve(detail, from: CGPoint(x: 142, y: 86), to: CGPoint(x: 112, y: 42), control: CGPoint(x: 140, y: 54), color: hairHighlight, width: 7)
        case .slickedBack:
            for x: CGFloat in [78, 92, 108, 122] {
                strokeCurve(detail, from: CGPoint(x: x, y: 62), to: CGPoint(x: 100 + (x - 100) * 0.7, y: 30),
                            control: CGPoint(x: x + (x < 100 ? -4 : 4), y: 44), color: hairHighlight, width: 3)
            }
        case .braided:
            for x: CGFloat in [70, 85, 100, 115, 130] {
                strokeCurve(detail, from: CGPoint(x: x, y: 70), to: CGPoint(x: 100 + (x - 100) * 0.75, y: 30),
                            control: CGPoint(x: x, y: 48), color: hairLowlight, width: 2.5)
            }
        case .crewCut:
            strokeCurve(detail, from: CGPoint(x: 68, y: 52), to: CGPoint(x: 132, y: 52), control: CGPoint(x: 100, y: 36), color: hairHighlight, width: 6)
        case .afro, .buzzCut:
            break
        }
    }

    private func strokeCurve(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, control: CGPoint, color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// The region above the hairline (clipped to the head silhouette by the caller).
    private func hairline(for style: HairStyle) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 30, y: 0))
        switch style {
        case .shortWavy:
            p.addLine(to: CGPoint(x: 30, y: 90))
            p.addLine(to: CGPoint(x: 58, y: 90))
            p.addLine(to: CGPoint(x: 59, y: 76))
            p.addCurve(to: CGPoint(x: 132, y: 64), control1: CGPoint(x: 66, y: 52), control2: CGPoint(x: 104, y: 76))
            p.addQuadCurve(to: CGPoint(x: 141, y: 78), control: CGPoint(x: 140, y: 66))
            p.addLine(to: CGPoint(x: 142, y: 90))
            p.addLine(to: CGPoint(x: 170, y: 90))
        case .crewCut, .braided:
            p.addLine(to: CGPoint(x: 30, y: 86))
            p.addLine(to: CGPoint(x: 58, y: 86))
            p.addLine(to: CGPoint(x: 60, y: 69))
            p.addCurve(to: CGPoint(x: 140, y: 69), control1: CGPoint(x: 74, y: 58), control2: CGPoint(x: 126, y: 58))
            p.addLine(to: CGPoint(x: 142, y: 86))
            p.addLine(to: CGPoint(x: 170, y: 86))
        case .buzzCut:
            p.addLine(to: CGPoint(x: 30, y: 82))
            p.addLine(to: CGPoint(x: 57, y: 82))
            p.addLine(to: CGPoint(x: 60, y: 66))
            p.addCurve(to: CGPoint(x: 140, y: 66), control1: CGPoint(x: 76, y: 56), control2: CGPoint(x: 124, y: 56))
            p.addLine(to: CGPoint(x: 143, y: 82))
            p.addLine(to: CGPoint(x: 170, y: 82))
        case .slickedBack:
            p.addLine(to: CGPoint(x: 30, y: 84))
            p.addLine(to: CGPoint(x: 57, y: 84))
            p.addLine(to: CGPoint(x: 59, y: 70))
            p.addQuadCurve(to: CGPoint(x: 100, y: 63), control: CGPoint(x: 76, y: 52))
            p.addQuadCurve(to: CGPoint(x: 141, y: 70), control: CGPoint(x: 124, y: 52))
            p.addLine(to: CGPoint(x: 143, y: 84))
            p.addLine(to: CGPoint(x: 170, y: 84))
        case .afro:
            p.addLine(to: CGPoint(x: 30, y: 84))
            p.addLine(to: CGPoint(x: 57, y: 84))
            p.addCurve(to: CGPoint(x: 143, y: 84), control1: CGPoint(x: 66, y: 56), control2: CGPoint(x: 134, y: 56))
            p.addLine(to: CGPoint(x: 170, y: 84))
        case .mediumWavy, .longWavy:
            let drop: CGFloat = style == .longWavy ? 118 : 106
            p.addLine(to: CGPoint(x: 30, y: drop))
            p.addLine(to: CGPoint(x: 59, y: drop))
            p.addQuadCurve(to: CGPoint(x: 100, y: 58), control: CGPoint(x: 62, y: 62))
            p.addQuadCurve(to: CGPoint(x: 141, y: drop), control: CGPoint(x: 138, y: 62))
            p.addLine(to: CGPoint(x: 170, y: drop))
        }
        p.addLine(to: CGPoint(x: 170, y: 0))
        p.closeSubpath()
        return p
    }

    // MARK: Ball

    private func drawBall(_ ctx: GraphicsContext) {
        let rect = CGRect(x: 141, y: 266, width: 27, height: 27)
        let ball = Circle().path(in: rect)
        ctx.fill(ball, with: .color(Color(hex: 0xEEF1EC)))
        var clipped = ctx
        clipped.clip(to: ball)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        clipped.fill(polygon(center: c, radius: 5.2, sides: 5, rotation: -.pi / 2), with: .color(ink))
        for index in 0..<5 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / 5
            let inner = CGPoint(x: c.x + cos(angle) * 5.2, y: c.y + sin(angle) * 5.2)
            let outer = CGPoint(x: c.x + cos(angle) * 15, y: c.y + sin(angle) * 15)
            var seam = Path()
            seam.move(to: inner)
            seam.addLine(to: outer)
            clipped.stroke(seam, with: .color(ink), style: StrokeStyle(lineWidth: 1.4))
            clipped.fill(polygon(center: outer, radius: 5, sides: 5, rotation: angle), with: .color(ink))
        }
        clipped.fill(Path(CGRect(x: rect.midX + 5, y: rect.minY, width: 12, height: 27)), with: .color(.black.opacity(0.10)))
    }

    private func polygon(center: CGPoint, radius: CGFloat, sides: Int, rotation: CGFloat) -> Path {
        var path = Path()
        for index in 0..<sides {
            let angle = rotation + CGFloat(index) * 2 * .pi / CGFloat(sides)
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: Colours

    private var browColor: Color {
        switch state.hairColor {
        case .platinum, .white, .blonde, .strawberryBlonde: return Color(hex: 0x7A6248)
        default: return state.hairColor.color
        }
    }

    private var shortsColor: Color { state.shortsStyle.color }

    private var shortsTrim: Color {
        switch state.shortsStyle {
        case .starterWhite: return .black.opacity(0.14)
        default: return .white.opacity(0.22)
        }
    }

    private var socksColor: Color {
        switch state.socksStyle {
        case .greenStriped: return AvatarKit.green
        case .whiteClassic: return AvatarKit.white
        case .blackAthletic: return AvatarKit.black
        case .matchingColor: return kit.base
        }
    }

    private var socksCuff: Color {
        switch state.socksStyle {
        case .whiteClassic: return .black.opacity(0.16)
        case .matchingColor: return kit.trim.opacity(0.9)
        default: return .white.opacity(0.28)
        }
    }

    private var cleatsColor: Color { state.cleatsStyle.color }

    private var cleatsAccent: Color {
        switch state.cleatsStyle {
        case .speedWhite: return AvatarKit.black
        case .classicBlack: return AvatarKit.white
        case .goldElite: return AvatarKit.black
        default: return AvatarKit.white
        }
    }
}

// MARK: - Kit palette

/// A jersey design: base colour, trim (collar, cuffs), number colour and pattern.
struct AvatarKit {
    enum Pattern {
        case solid
        case stripes(Color)
        case sash(Color)
        case hoop(Color)
    }

    let base: Color
    let trim: Color
    let number: Color
    var pattern: Pattern = .solid

    static let green = Color(hex: 0x3DB556)
    static let white = Color(hex: 0xF2F4F0)
    static let black = Color(hex: 0x24282A)
    static let red = Color(hex: 0xD63A3A)
    static let yellow = Color(hex: 0xF5D130)
    static let orange = Color(hex: 0xF07F2A)
    static let garnet = Color(hex: 0xA5183B)
    static let navy = Color(hex: 0x1E3F9E)
}

extension JerseyStyle {
    var kit: AvatarKit {
        switch self {
        case .starterGreen:
            return AvatarKit(base: AvatarKit.green, trim: AvatarKit.white, number: AvatarKit.white)
        case .classicWhite:
            return AvatarKit(base: AvatarKit.white, trim: AvatarKit.black, number: AvatarKit.black)
        case .strikerRed:
            return AvatarKit(base: AvatarKit.red, trim: AvatarKit.white, number: AvatarKit.white, pattern: .hoop(AvatarKit.white.opacity(0.9)))
        case .royalBlue:
            return AvatarKit(base: DesignSystem.Colors.kitBlue, trim: DesignSystem.Colors.kitGold, number: DesignSystem.Colors.kitGold)
        case .brazilYellow:
            return AvatarKit(base: AvatarKit.yellow, trim: Color(hex: 0x1F8A4C), number: Color(hex: 0x1F8A4C))
        case .barcelonaStyle:
            return AvatarKit(base: AvatarKit.garnet, trim: DesignSystem.Colors.kitGold, number: DesignSystem.Colors.kitGold, pattern: .stripes(AvatarKit.navy))
        case .classicBlack:
            return AvatarKit(base: AvatarKit.black, trim: AvatarKit.green, number: AvatarKit.green)
        case .orangeBlaze:
            return AvatarKit(base: AvatarKit.orange, trim: AvatarKit.black, number: AvatarKit.white, pattern: .sash(AvatarKit.black))
        }
    }
}

extension ShortsStyle {
    var color: Color {
        switch self {
        case .starterWhite: return AvatarKit.white
        case .classicBlack: return AvatarKit.black
        case .matchingGreen: return AvatarKit.green
        case .blueAthletic: return DesignSystem.Colors.kitBlue
        case .redSport: return AvatarKit.red
        }
    }
}

extension CleatsStyle {
    var color: Color {
        switch self {
        case .starterGreen: return AvatarKit.green
        case .classicBlack: return Color(hex: 0x2E3336)
        case .speedWhite: return AvatarKit.white
        case .goldElite: return DesignSystem.Colors.kitGold
        case .neonBlue: return Color(hex: 0x33A1FF)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Avatar") {
    let looks: [AvatarState] = [
        .default,
        AvatarState(skinTone: .dark, hairStyle: .afro, hairColor: .black, faceStyle: .cool, jerseyStyle: .royalBlue,
                    shortsStyle: .classicBlack, socksStyle: .whiteClassic, cleatsStyle: .speedWhite),
        AvatarState(skinTone: .light, hairStyle: .longWavy, hairColor: .blonde, faceStyle: .excited, jerseyStyle: .barcelonaStyle,
                    shortsStyle: .blueAthletic, socksStyle: .matchingColor, cleatsStyle: .goldElite),
        AvatarState(skinTone: .brown, hairStyle: .braided, hairColor: .darkBrown, faceStyle: .determined, jerseyStyle: .orangeBlaze,
                    shortsStyle: .classicBlack, socksStyle: .blackAthletic, cleatsStyle: .neonBlue)
    ]
    return VStack(spacing: 24) {
        HStack(spacing: 8) {
            ForEach(Array(looks.enumerated()), id: \.offset) { index, look in
                AvatarFigureView(avatarState: look, kitNumber: 7 + index).frame(width: 84)
            }
        }
        HStack(spacing: 12) {
            ForEach(Array(looks.enumerated()), id: \.offset) { _, look in
                AvatarBustView(avatarState: look, diameter: 56)
            }
        }
    }
    .padding(24)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
