import SwiftUI

/// Bitmoji-style avatar with custom paths and organic shapes
/// Uses layered rendering for depth and realism
struct ProgrammaticAvatarView: View {
    let avatarState: AvatarState
    let size: AvatarSize

    enum AvatarSize {
        case small, medium, large, xlarge

        var dimension: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 120
            case .large: return 200
            case .xlarge: return 300
            }
        }

        var height: CGFloat { dimension * 1.5 }
    }

    init(avatarState: AvatarState, size: AvatarSize = .medium) {
        self.avatarState = avatarState
        self.size = size
    }

    private var scale: CGFloat { size.dimension / 200 }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            drawAvatar(context: context, center: center)
        }
        .frame(width: size.dimension, height: size.height)
    }

    // MARK: - Main Drawing Function

    private func drawAvatar(context: GraphicsContext, center: CGPoint) {
        let s = scale

        // Draw layers back to front
        drawBody(context: context, center: center, scale: s)
        drawClothing(context: context, center: center, scale: s)
        drawNeck(context: context, center: center, scale: s)
        drawHead(context: context, center: center, scale: s)
        drawEars(context: context, center: center, scale: s)
        drawHair(context: context, center: center, scale: s)
        drawFace(context: context, center: center, scale: s)
    }

    // MARK: - Body

    private func drawBody(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let skinColor = avatarState.skinTone.color

        // Torso - rounded organic shape
        var torsoPath = Path()
        let torsoCenter = CGPoint(x: center.x, y: center.y + 35 * s)
        torsoPath.addRoundedRect(
            in: CGRect(x: torsoCenter.x - 32 * s, y: torsoCenter.y - 35 * s, width: 64 * s, height: 70 * s),
            cornerSize: CGSize(width: 20 * s, height: 20 * s)
        )
        context.fill(torsoPath, with: .color(skinColor))

        // Arms - rounded capsule shapes
        let leftArmRect = CGRect(x: center.x - 52 * s, y: center.y + 5 * s, width: 16 * s, height: 50 * s)
        let rightArmRect = CGRect(x: center.x + 36 * s, y: center.y + 5 * s, width: 16 * s, height: 50 * s)

        context.fill(Capsule().path(in: leftArmRect), with: .color(skinColor))
        context.fill(Capsule().path(in: rightArmRect), with: .color(skinColor))

        // Legs
        let leftLegRect = CGRect(x: center.x - 26 * s, y: center.y + 70 * s, width: 20 * s, height: 55 * s)
        let rightLegRect = CGRect(x: center.x + 6 * s, y: center.y + 70 * s, width: 20 * s, height: 55 * s)

        context.fill(Capsule().path(in: leftLegRect), with: .color(skinColor))
        context.fill(Capsule().path(in: rightLegRect), with: .color(skinColor))
    }

    // MARK: - Clothing

    private func drawClothing(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let jerseyBase = jerseyColor
        let jerseyShadow = jerseyColor.opacity(0.7)
        let shortsBase = shortsColor

        // Jersey body
        var jerseyPath = Path()
        let jerseyCenter = CGPoint(x: center.x, y: center.y + 28 * s)
        jerseyPath.addRoundedRect(
            in: CGRect(x: jerseyCenter.x - 34 * s, y: jerseyCenter.y - 28 * s, width: 68 * s, height: 56 * s),
            cornerSize: CGSize(width: 16 * s, height: 16 * s)
        )

        // Jersey gradient
        context.fill(jerseyPath, with: .linearGradient(
            Gradient(colors: [jerseyBase, jerseyShadow]),
            startPoint: CGPoint(x: center.x, y: center.y),
            endPoint: CGPoint(x: center.x, y: center.y + 60 * s)
        ))

        // Jersey sleeves - wider and longer to fully cover arm skin
        let leftSleeveRect = CGRect(x: center.x - 54 * s, y: center.y + 2 * s, width: 22 * s, height: 36 * s)
        let rightSleeveRect = CGRect(x: center.x + 32 * s, y: center.y + 2 * s, width: 22 * s, height: 36 * s)

        context.fill(RoundedRectangle(cornerRadius: 8 * s).path(in: leftSleeveRect), with: .color(jerseyBase))
        context.fill(RoundedRectangle(cornerRadius: 8 * s).path(in: rightSleeveRect), with: .color(jerseyBase))

        // Jersey collar - V-neck
        var collarPath = Path()
        collarPath.move(to: CGPoint(x: center.x - 14 * s, y: center.y - 2 * s))
        collarPath.addLine(to: CGPoint(x: center.x, y: center.y + 12 * s))
        collarPath.addLine(to: CGPoint(x: center.x + 14 * s, y: center.y - 2 * s))
        context.stroke(collarPath, with: .color(collarColor), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round, lineJoin: .round))

        // Jersey number (subtle)
        let numberPosition = CGPoint(x: center.x, y: center.y + 28 * s)
        context.draw(
            Text("10")
                .font(.system(size: 14 * s, weight: .bold))
                .foregroundColor(collarColor.opacity(0.6)),
            at: numberPosition
        )

        // Shorts
        var shortsPath = Path()
        let shortsCenter = CGPoint(x: center.x, y: center.y + 68 * s)
        shortsPath.addRoundedRect(
            in: CGRect(x: shortsCenter.x - 28 * s, y: shortsCenter.y - 15 * s, width: 56 * s, height: 30 * s),
            cornerSize: CGSize(width: 10 * s, height: 10 * s)
        )
        context.fill(shortsPath, with: .linearGradient(
            Gradient(colors: [shortsBase, shortsBase.opacity(0.8)]),
            startPoint: CGPoint(x: center.x, y: center.y + 53 * s),
            endPoint: CGPoint(x: center.x, y: center.y + 83 * s)
        ))

        // Socks - start higher to cover leg skin under shorts
        let leftSockRect = CGRect(x: center.x - 28 * s, y: center.y + 78 * s, width: 22 * s, height: 42 * s)
        let rightSockRect = CGRect(x: center.x + 6 * s, y: center.y + 78 * s, width: 22 * s, height: 42 * s)

        context.fill(Capsule().path(in: leftSockRect), with: .color(socksColor))
        context.fill(Capsule().path(in: rightSockRect), with: .color(socksColor))

        // Cleats
        let leftCleatRect = CGRect(x: center.x - 28 * s, y: center.y + 118 * s, width: 22 * s, height: 10 * s)
        let rightCleatRect = CGRect(x: center.x + 6 * s, y: center.y + 118 * s, width: 22 * s, height: 10 * s)

        context.fill(Ellipse().path(in: leftCleatRect), with: .color(cleatsColor))
        context.fill(Ellipse().path(in: rightCleatRect), with: .color(cleatsColor))
    }

    // MARK: - Neck

    private func drawNeck(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let skinColor = avatarState.skinTone.color

        let neckRect = CGRect(x: center.x - 12 * s, y: center.y - 18 * s, width: 24 * s, height: 25 * s)
        context.fill(Capsule().path(in: neckRect), with: .color(skinColor))
    }

    // MARK: - Head

    private func drawHead(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let skinColor = avatarState.skinTone.color
        let skinShadow = avatarState.skinTone.color.opacity(0.8)

        // Head position
        let headCenter = CGPoint(x: center.x, y: center.y - 50 * s)

        // Main head shape - slightly taller oval with chin
        var headPath = Path()
        headPath.addEllipse(in: CGRect(
            x: headCenter.x - 32 * s,
            y: headCenter.y - 38 * s,
            width: 64 * s,
            height: 72 * s
        ))

        // Head base fill
        context.fill(headPath, with: .color(skinColor))

        // Head shading - subtle gradient for 3D effect
        context.fill(headPath, with: .radialGradient(
            Gradient(colors: [Color.clear, skinShadow.opacity(0.3)]),
            center: CGPoint(x: headCenter.x, y: headCenter.y - 10 * s),
            startRadius: 10 * s,
            endRadius: 40 * s
        ))

        // Cheek blush (subtle)
        let leftCheekRect = CGRect(x: headCenter.x - 26 * s, y: headCenter.y + 5 * s, width: 16 * s, height: 10 * s)
        let rightCheekRect = CGRect(x: headCenter.x + 10 * s, y: headCenter.y + 5 * s, width: 16 * s, height: 10 * s)

        context.fill(Ellipse().path(in: leftCheekRect), with: .color(Color.pink.opacity(0.15)))
        context.fill(Ellipse().path(in: rightCheekRect), with: .color(Color.pink.opacity(0.15)))
    }

    // MARK: - Ears

    private func drawEars(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let skinColor = avatarState.skinTone.color
        let earShadow = avatarState.skinTone.color.opacity(0.7)
        let headCenter = CGPoint(x: center.x, y: center.y - 50 * s)

        // Left ear
        let leftEarRect = CGRect(x: headCenter.x - 38 * s, y: headCenter.y - 8 * s, width: 12 * s, height: 18 * s)
        context.fill(Ellipse().path(in: leftEarRect), with: .color(skinColor))
        // Inner ear shadow
        let leftInnerRect = CGRect(x: headCenter.x - 35 * s, y: headCenter.y - 4 * s, width: 6 * s, height: 10 * s)
        context.fill(Ellipse().path(in: leftInnerRect), with: .color(earShadow))

        // Right ear
        let rightEarRect = CGRect(x: headCenter.x + 26 * s, y: headCenter.y - 8 * s, width: 12 * s, height: 18 * s)
        context.fill(Ellipse().path(in: rightEarRect), with: .color(skinColor))
        // Inner ear shadow
        let rightInnerRect = CGRect(x: headCenter.x + 29 * s, y: headCenter.y - 4 * s, width: 6 * s, height: 10 * s)
        context.fill(Ellipse().path(in: rightInnerRect), with: .color(earShadow))
    }

    // MARK: - Hair

    private func drawHair(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let hairColor = avatarState.hairColor.color
        let hairShadow = avatarState.hairColor.color.opacity(0.7)
        let headCenter = CGPoint(x: center.x, y: center.y - 50 * s)

        switch avatarState.hairStyle {
        case .shortWavy, .crewCut:
            // Short hair - cap style
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 30 * s,
                y: headCenter.y - 42 * s,
                width: 60 * s,
                height: 40 * s
            ))
            context.fill(hairPath, with: .linearGradient(
                Gradient(colors: [hairColor, hairShadow]),
                startPoint: CGPoint(x: headCenter.x, y: headCenter.y - 50 * s),
                endPoint: CGPoint(x: headCenter.x, y: headCenter.y - 10 * s)
            ))

        case .mediumWavy, .slickedBack:
            // Medium hair with sides
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 32 * s,
                y: headCenter.y - 45 * s,
                width: 64 * s,
                height: 48 * s
            ))
            context.fill(hairPath, with: .linearGradient(
                Gradient(colors: [hairColor, hairShadow]),
                startPoint: CGPoint(x: headCenter.x, y: headCenter.y - 50 * s),
                endPoint: CGPoint(x: headCenter.x, y: headCenter.y)
            ))

            // Side hair pieces
            let leftSideRect = CGRect(x: headCenter.x - 35 * s, y: headCenter.y - 20 * s, width: 12 * s, height: 30 * s)
            let rightSideRect = CGRect(x: headCenter.x + 23 * s, y: headCenter.y - 20 * s, width: 12 * s, height: 30 * s)
            context.fill(Capsule().path(in: leftSideRect), with: .color(hairShadow))
            context.fill(Capsule().path(in: rightSideRect), with: .color(hairShadow))

        case .longWavy:
            // Long flowing hair
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 34 * s,
                y: headCenter.y - 48 * s,
                width: 68 * s,
                height: 52 * s
            ))
            context.fill(hairPath, with: .color(hairColor))

            // Long side pieces
            let leftLongRect = CGRect(x: headCenter.x - 38 * s, y: headCenter.y - 25 * s, width: 16 * s, height: 65 * s)
            let rightLongRect = CGRect(x: headCenter.x + 22 * s, y: headCenter.y - 25 * s, width: 16 * s, height: 65 * s)
            context.fill(Capsule().path(in: leftLongRect), with: .linearGradient(
                Gradient(colors: [hairColor, hairShadow]),
                startPoint: CGPoint(x: headCenter.x - 30 * s, y: headCenter.y - 25 * s),
                endPoint: CGPoint(x: headCenter.x - 30 * s, y: headCenter.y + 40 * s)
            ))
            context.fill(Capsule().path(in: rightLongRect), with: .linearGradient(
                Gradient(colors: [hairColor, hairShadow]),
                startPoint: CGPoint(x: headCenter.x + 30 * s, y: headCenter.y - 25 * s),
                endPoint: CGPoint(x: headCenter.x + 30 * s, y: headCenter.y + 40 * s)
            ))

        case .buzzCut:
            // Very short buzz
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 28 * s,
                y: headCenter.y - 40 * s,
                width: 56 * s,
                height: 30 * s
            ))
            context.fill(hairPath, with: .color(hairColor.opacity(0.9)))

        case .afro:
            // Big round afro
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 42 * s,
                y: headCenter.y - 55 * s,
                width: 84 * s,
                height: 80 * s
            ))
            context.fill(hairPath, with: .radialGradient(
                Gradient(colors: [hairColor, hairShadow]),
                center: headCenter,
                startRadius: 10 * s,
                endRadius: 45 * s
            ))

        case .braided:
            // Braided style
            var hairPath = Path()
            hairPath.addEllipse(in: CGRect(
                x: headCenter.x - 30 * s,
                y: headCenter.y - 45 * s,
                width: 60 * s,
                height: 45 * s
            ))
            context.fill(hairPath, with: .color(hairColor))

            // Braids
            let leftBraidRect = CGRect(x: headCenter.x - 28 * s, y: headCenter.y - 10 * s, width: 10 * s, height: 50 * s)
            let rightBraidRect = CGRect(x: headCenter.x + 18 * s, y: headCenter.y - 10 * s, width: 10 * s, height: 50 * s)
            context.fill(Capsule().path(in: leftBraidRect), with: .color(hairShadow))
            context.fill(Capsule().path(in: rightBraidRect), with: .color(hairShadow))
        }
    }

    // MARK: - Face

    private func drawFace(context: GraphicsContext, center: CGPoint, scale s: CGFloat) {
        let headCenter = CGPoint(x: center.x, y: center.y - 50 * s)

        // Draw eyes based on face style
        switch avatarState.faceStyle {
        case .happy:
            drawNormalEyes(context: context, headCenter: headCenter, scale: s)
            drawSmile(context: context, headCenter: headCenter, scale: s)
        case .determined:
            drawDeterminedEyes(context: context, headCenter: headCenter, scale: s)
            drawNeutralMouth(context: context, headCenter: headCenter, scale: s)
        case .cool:
            drawSunglasses(context: context, headCenter: headCenter, scale: s)
            drawSmirk(context: context, headCenter: headCenter, scale: s)
        case .excited:
            drawExcitedEyes(context: context, headCenter: headCenter, scale: s)
            drawBigSmile(context: context, headCenter: headCenter, scale: s)
        case .focused:
            drawFocusedEyes(context: context, headCenter: headCenter, scale: s)
            drawNeutralMouth(context: context, headCenter: headCenter, scale: s)
        case .celebrating:
            drawClosedHappyEyes(context: context, headCenter: headCenter, scale: s)
            drawBigSmile(context: context, headCenter: headCenter, scale: s)
        }

        // Draw eyebrows
        drawEyebrows(context: context, headCenter: headCenter, scale: s)

        // Draw nose
        drawNose(context: context, headCenter: headCenter, scale: s)
    }

    // MARK: - Eye Variations

    private func drawNormalEyes(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let eyeY = headCenter.y - 5 * s
        let eyeSpacing: CGFloat = 14 * s

        for xOffset in [-eyeSpacing, eyeSpacing] {
            let eyeCenter = CGPoint(x: headCenter.x + xOffset, y: eyeY)

            // Eye white (sclera)
            let eyeRect = CGRect(x: eyeCenter.x - 9 * s, y: eyeCenter.y - 7 * s, width: 18 * s, height: 14 * s)
            context.fill(Ellipse().path(in: eyeRect), with: .color(.white))

            // Iris with gradient
            let irisRect = CGRect(x: eyeCenter.x - 5 * s, y: eyeCenter.y - 5 * s, width: 10 * s, height: 10 * s)
            context.fill(Circle().path(in: irisRect), with: .radialGradient(
                Gradient(colors: [Color(red: 0.4, green: 0.25, blue: 0.15), Color(red: 0.2, green: 0.1, blue: 0.05)]),
                center: eyeCenter,
                startRadius: 0,
                endRadius: 6 * s
            ))

            // Pupil
            let pupilRect = CGRect(x: eyeCenter.x - 2.5 * s, y: eyeCenter.y - 2.5 * s, width: 5 * s, height: 5 * s)
            context.fill(Circle().path(in: pupilRect), with: .color(.black))

            // Eye highlight (key for "alive" look)
            let highlightRect = CGRect(x: eyeCenter.x - 5 * s, y: eyeCenter.y - 5 * s, width: 4 * s, height: 4 * s)
            context.fill(Circle().path(in: highlightRect), with: .color(.white.opacity(0.9)))

            // Secondary smaller highlight
            let highlight2Rect = CGRect(x: eyeCenter.x + 1 * s, y: eyeCenter.y + 1 * s, width: 2 * s, height: 2 * s)
            context.fill(Circle().path(in: highlight2Rect), with: .color(.white.opacity(0.5)))
        }
    }

    private func drawDeterminedEyes(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        drawNormalEyes(context: context, headCenter: headCenter, scale: s)
    }

    private func drawExcitedEyes(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let eyeY = headCenter.y - 5 * s
        let eyeSpacing: CGFloat = 14 * s

        for xOffset in [-eyeSpacing, eyeSpacing] {
            let eyeCenter = CGPoint(x: headCenter.x + xOffset, y: eyeY)

            // Larger eye white
            let eyeRect = CGRect(x: eyeCenter.x - 10 * s, y: eyeCenter.y - 9 * s, width: 20 * s, height: 18 * s)
            context.fill(Ellipse().path(in: eyeRect), with: .color(.white))

            // Larger iris
            let irisRect = CGRect(x: eyeCenter.x - 6 * s, y: eyeCenter.y - 6 * s, width: 12 * s, height: 12 * s)
            context.fill(Circle().path(in: irisRect), with: .color(Color(red: 0.3, green: 0.2, blue: 0.1)))

            // Pupil
            let pupilRect = CGRect(x: eyeCenter.x - 3 * s, y: eyeCenter.y - 3 * s, width: 6 * s, height: 6 * s)
            context.fill(Circle().path(in: pupilRect), with: .color(.black))

            // Highlights
            let highlightRect = CGRect(x: eyeCenter.x - 6 * s, y: eyeCenter.y - 6 * s, width: 5 * s, height: 5 * s)
            context.fill(Circle().path(in: highlightRect), with: .color(.white.opacity(0.9)))
        }
    }

    private func drawFocusedEyes(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let eyeY = headCenter.y - 5 * s
        let eyeSpacing: CGFloat = 14 * s

        for xOffset in [-eyeSpacing, eyeSpacing] {
            let eyeCenter = CGPoint(x: headCenter.x + xOffset, y: eyeY)

            // Narrowed eye shape
            let eyeRect = CGRect(x: eyeCenter.x - 9 * s, y: eyeCenter.y - 4 * s, width: 18 * s, height: 8 * s)
            context.fill(Ellipse().path(in: eyeRect), with: .color(.white))

            // Iris
            let irisRect = CGRect(x: eyeCenter.x - 4 * s, y: eyeCenter.y - 4 * s, width: 8 * s, height: 8 * s)
            context.fill(Circle().path(in: irisRect), with: .color(Color(red: 0.3, green: 0.2, blue: 0.1)))

            // Pupil
            let pupilRect = CGRect(x: eyeCenter.x - 2 * s, y: eyeCenter.y - 2 * s, width: 4 * s, height: 4 * s)
            context.fill(Circle().path(in: pupilRect), with: .color(.black))
        }
    }

    private func drawClosedHappyEyes(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let eyeY = headCenter.y - 5 * s
        let eyeSpacing: CGFloat = 14 * s

        for xOffset in [-eyeSpacing, eyeSpacing] {
            let eyeCenter = CGPoint(x: headCenter.x + xOffset, y: eyeY)

            // Happy closed eye arc
            var arcPath = Path()
            arcPath.addArc(
                center: CGPoint(x: eyeCenter.x, y: eyeCenter.y + 2 * s),
                radius: 8 * s,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
            context.stroke(arcPath, with: .color(.black), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
        }
    }

    private func drawSunglasses(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let eyeY = headCenter.y - 5 * s

        // Left lens
        let leftLensRect = CGRect(x: headCenter.x - 28 * s, y: eyeY - 8 * s, width: 22 * s, height: 16 * s)
        context.fill(RoundedRectangle(cornerRadius: 4 * s).path(in: leftLensRect), with: .color(.black))

        // Right lens
        let rightLensRect = CGRect(x: headCenter.x + 6 * s, y: eyeY - 8 * s, width: 22 * s, height: 16 * s)
        context.fill(RoundedRectangle(cornerRadius: 4 * s).path(in: rightLensRect), with: .color(.black))

        // Bridge
        var bridgePath = Path()
        bridgePath.move(to: CGPoint(x: headCenter.x - 6 * s, y: eyeY - 2 * s))
        bridgePath.addLine(to: CGPoint(x: headCenter.x + 6 * s, y: eyeY - 2 * s))
        context.stroke(bridgePath, with: .color(.black), style: StrokeStyle(lineWidth: 3 * s))

        // Lens shine
        let shineRect = CGRect(x: headCenter.x - 24 * s, y: eyeY - 6 * s, width: 8 * s, height: 4 * s)
        context.fill(Ellipse().path(in: shineRect), with: .color(.white.opacity(0.2)))
    }

    // MARK: - Mouth Variations

    private func drawSmile(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        var smilePath = Path()
        smilePath.addArc(
            center: CGPoint(x: headCenter.x, y: headCenter.y + 12 * s),
            radius: 10 * s,
            startAngle: .degrees(20),
            endAngle: .degrees(160),
            clockwise: false
        )
        context.stroke(smilePath, with: .color(.black), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
    }

    private func drawBigSmile(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        // Open mouth smile
        let mouthRect = CGRect(x: headCenter.x - 14 * s, y: headCenter.y + 12 * s, width: 28 * s, height: 16 * s)

        // Mouth shape
        var mouthPath = Path()
        mouthPath.addEllipse(in: mouthRect)
        context.fill(mouthPath, with: .color(Color(red: 0.3, green: 0.1, blue: 0.1)))

        // Teeth hint
        let teethRect = CGRect(x: headCenter.x - 10 * s, y: headCenter.y + 12 * s, width: 20 * s, height: 6 * s)
        context.fill(Ellipse().path(in: teethRect), with: .color(.white))
    }

    private func drawSmirk(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        var smirkPath = Path()
        smirkPath.addArc(
            center: CGPoint(x: headCenter.x + 5 * s, y: headCenter.y + 12 * s),
            radius: 8 * s,
            startAngle: .degrees(30),
            endAngle: .degrees(150),
            clockwise: false
        )
        context.stroke(smirkPath, with: .color(.black), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
    }

    private func drawNeutralMouth(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let mouthRect = CGRect(x: headCenter.x - 8 * s, y: headCenter.y + 18 * s, width: 16 * s, height: 3 * s)
        context.fill(Capsule().path(in: mouthRect), with: .color(.black.opacity(0.8)))
    }

    // MARK: - Eyebrows

    private func drawEyebrows(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        let browColor = avatarState.hairColor.color.opacity(0.8)
        let browY = headCenter.y - 18 * s
        let browSpacing: CGFloat = 14 * s

        for (index, xOffset) in [-browSpacing, browSpacing].enumerated() {
            let browCenter = CGPoint(x: headCenter.x + xOffset, y: browY)

            var browPath = Path()
            if avatarState.faceStyle == .determined {
                // Angled eyebrows for determined look
                let angle: CGFloat = index == 0 ? -0.15 : 0.15
                browPath.move(to: CGPoint(x: browCenter.x - 8 * s, y: browCenter.y + angle * 20))
                browPath.addLine(to: CGPoint(x: browCenter.x + 8 * s, y: browCenter.y - angle * 20))
            } else {
                // Normal curved eyebrows
                browPath.addArc(
                    center: CGPoint(x: browCenter.x, y: browCenter.y + 15 * s),
                    radius: 16 * s,
                    startAngle: .degrees(240),
                    endAngle: .degrees(300),
                    clockwise: false
                )
            }
            context.stroke(browPath, with: .color(browColor), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
        }
    }

    // MARK: - Nose

    private func drawNose(context: GraphicsContext, headCenter: CGPoint, scale s: CGFloat) {
        // Subtle nose shadow
        let noseRect = CGRect(x: headCenter.x - 3 * s, y: headCenter.y + 2 * s, width: 6 * s, height: 10 * s)
        context.fill(Ellipse().path(in: noseRect), with: .color(avatarState.skinTone.color.opacity(0.7)))

        // Nose highlight
        let highlightRect = CGRect(x: headCenter.x - 2 * s, y: headCenter.y + 3 * s, width: 4 * s, height: 4 * s)
        context.fill(Ellipse().path(in: highlightRect), with: .color(.white.opacity(0.15)))
    }

    // MARK: - Color Properties

    private var jerseyColor: Color {
        switch avatarState.jerseyStyle {
        case .starterGreen: return DesignSystem.Colors.primaryGreen
        case .classicWhite: return .white
        case .strikerRed: return .red
        case .royalBlue: return DesignSystem.Colors.secondaryBlue
        case .brazilYellow: return .yellow
        case .barcelonaStyle: return Color(red: 0.6, green: 0.1, blue: 0.2)
        case .classicBlack: return .black
        case .orangeBlaze: return DesignSystem.Colors.accentOrange
        }
    }

    private var shortsColor: Color {
        switch avatarState.shortsStyle {
        case .starterWhite: return .white
        case .classicBlack: return .black
        case .matchingGreen: return DesignSystem.Colors.primaryGreen
        case .blueAthletic: return DesignSystem.Colors.secondaryBlue
        case .redSport: return .red
        }
    }

    private var socksColor: Color {
        switch avatarState.socksStyle {
        case .greenStriped: return DesignSystem.Colors.primaryGreen
        case .whiteClassic: return .white
        case .blackAthletic: return .black
        case .matchingColor: return jerseyColor
        }
    }

    private var cleatsColor: Color {
        switch avatarState.cleatsStyle {
        case .starterGreen: return DesignSystem.Colors.primaryGreen
        case .classicBlack: return .black
        case .speedWhite: return .white
        case .goldElite: return Color(red: 1.0, green: 0.84, blue: 0)
        case .neonBlue: return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }

    private var collarColor: Color {
        switch avatarState.jerseyStyle {
        case .classicWhite, .brazilYellow: return .black.opacity(0.8)
        default: return .white.opacity(0.9)
        }
    }
}

// MARK: - Compact Avatar (Head Only)

struct CompactProgrammaticAvatarView: View {
    let avatarState: AvatarState

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let s: CGFloat = size.width / 44

            // Background
            let bgRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.fill(Circle().path(in: bgRect), with: .color(jerseyColor.opacity(0.2)))

            // Head
            let headRect = CGRect(x: center.x - 16 * s, y: center.y - 18 * s, width: 32 * s, height: 36 * s)
            context.fill(Ellipse().path(in: headRect), with: .color(avatarState.skinTone.color))

            // Hair
            let hairRect = CGRect(x: center.x - 15 * s, y: center.y - 22 * s, width: 30 * s, height: 20 * s)
            context.fill(Ellipse().path(in: hairRect), with: .color(avatarState.hairColor.color))

            // Eyes
            for xOffset: CGFloat in [-6, 6] {
                let eyeRect = CGRect(x: center.x + xOffset * s - 3 * s, y: center.y - 4 * s, width: 6 * s, height: 6 * s)
                context.fill(Circle().path(in: eyeRect), with: .color(.white))
                let pupilRect = CGRect(x: center.x + xOffset * s - 1.5 * s, y: center.y - 2.5 * s, width: 3 * s, height: 3 * s)
                context.fill(Circle().path(in: pupilRect), with: .color(.black))
                // Highlight
                let hlRect = CGRect(x: center.x + xOffset * s - 2.5 * s, y: center.y - 3.5 * s, width: 2 * s, height: 2 * s)
                context.fill(Circle().path(in: hlRect), with: .color(.white.opacity(0.8)))
            }

            // Smile
            var smilePath = Path()
            smilePath.addArc(center: CGPoint(x: center.x, y: center.y + 6 * s), radius: 5 * s, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: true)
            context.stroke(smilePath, with: .color(.black), style: StrokeStyle(lineWidth: 1.5 * s, lineCap: .round))
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var jerseyColor: Color {
        switch avatarState.jerseyStyle {
        case .starterGreen: return DesignSystem.Colors.primaryGreen
        case .classicWhite: return .gray
        case .strikerRed: return .red
        case .royalBlue: return DesignSystem.Colors.secondaryBlue
        case .brazilYellow: return .yellow
        case .barcelonaStyle: return Color(red: 0.6, green: 0.1, blue: 0.2)
        case .classicBlack: return .black
        case .orangeBlaze: return DesignSystem.Colors.accentOrange
        }
    }
}

// MARK: - Previews

#Preview("Programmatic Avatar") {
    VStack(spacing: 30) {
        ProgrammaticAvatarView(avatarState: .default, size: .large)

        HStack(spacing: 20) {
            ProgrammaticAvatarView(
                avatarState: AvatarState(
                    skinTone: .dark,
                    hairStyle: .afro,
                    hairColor: .black,
                    faceStyle: .cool,
                    jerseyStyle: .royalBlue,
                    shortsStyle: .classicBlack,
                    socksStyle: .whiteClassic,
                    cleatsStyle: .speedWhite
                ),
                size: .medium
            )

            ProgrammaticAvatarView(
                avatarState: AvatarState(
                    skinTone: .light,
                    hairStyle: .longWavy,
                    hairColor: .blonde,
                    faceStyle: .excited,
                    jerseyStyle: .strikerRed,
                    shortsStyle: .starterWhite,
                    socksStyle: .whiteClassic,
                    cleatsStyle: .classicBlack
                ),
                size: .medium
            )
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Compact Avatar") {
    HStack(spacing: 15) {
        CompactProgrammaticAvatarView(avatarState: .default)
        CompactProgrammaticAvatarView(avatarState: AvatarState(
            skinTone: .dark,
            hairStyle: .afro,
            hairColor: .black,
            faceStyle: .happy,
            jerseyStyle: .royalBlue,
            shortsStyle: .classicBlack,
            socksStyle: .blackAthletic,
            cleatsStyle: .classicBlack
        ))
    }
    .padding()
}
