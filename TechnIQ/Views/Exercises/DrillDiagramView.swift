import SwiftUI

// MARK: - Backward-Compatible Wrapper

/// Simple wrapper that preserves the old API for existing callers
struct DrillDiagramView: View {
    let diagram: DrillDiagram

    var body: some View {
        AnimatedDrillDiagramView(
            diagram: diagram,
            instructions: [],
            currentStep: .constant(nil),
            isAutoPlaying: .constant(false)
        )
    }
}

// MARK: - Animated Drill Diagram View

struct AnimatedDrillDiagramView: View {
    let diagram: DrillDiagram
    let instructions: [String]
    @Binding var currentStep: Int?
    @Binding var isAutoPlaying: Bool
    var playbackSpeed: Double = 1.0
    var isTrainingMode: Bool = false
    var onStepCompleted: ((Int) -> Void)? = nil
    /// false when embedded in TQDiagram: no card background, no dimension label, no step controls.
    var chrome: Bool = true

    // Element sizes
    private let coneSize: CGFloat = 16
    private let playerSize: CGFloat = 26
    private let targetSize: CGFloat = 20
    private let goalWidth: CGFloat = 32
    private let goalHeight: CGFloat = 12
    private let ballSize: CGFloat = 12
    private var fieldPadding: CGFloat { chrome ? 24 : 16 }

    // Path animation
    @State private var pathAnimationProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var autoPlayTimer: Timer?

    /// Original step numbers of the practiced (non-reset) actions, in order.
    /// Resets are ball-logic plumbing the kid never watches.
    private var visibleStepNumbers: [Int] {
        guard let paths = diagram.paths else { return [] }
        let nums = paths.filter { $0.reset != true && $0.alt != true }
            .compactMap { $0.step }
        return Array(Set(nums)).sorted()
    }

    private var totalSteps: Int {
        max(visibleStepNumbers.count, instructions.count)
    }

    /// Maps the 1-based visible index the UI navigates to the original step number.
    private func originalStep(forVisible index: Int) -> Int? {
        let nums = visibleStepNumbers
        guard index >= 1, index <= nums.count else { return nil }
        return nums[index - 1]
    }

    private var hasSteps: Bool { totalSteps > 0 }

    private var diagramAccessibilityLabel: String {
        let players = diagram.elements.filter { $0.elementType == .player }.count
        let cones = diagram.elements.filter { $0.elementType == .cone }.count
        let goals = diagram.elements.filter { $0.elementType == .goal }.count
        return "Drill diagram: \(players) player\(players == 1 ? "" : "s"), \(cones) cone\(cones == 1 ? "" : "s"), \(goals) goal\(goals == 1 ? "" : "s") on a \(Int(diagram.field.width)) by \(Int(diagram.field.length)) meter field"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Diagram
            GeometryReader { geometry in
                let availableWidth = geometry.size.width - (fieldPadding * 2)
                let availableHeight = geometry.size.height - (fieldPadding * 2)
                let scaleX = availableWidth / CGFloat(diagram.field.width)
                let scaleY = availableHeight / CGFloat(diagram.field.length)
                let scale = min(scaleX, scaleY)
                let fieldWidth = CGFloat(diagram.field.width) * scale
                let fieldHeight = CGFloat(diagram.field.length) * scale
                let offsetX = fieldPadding + (availableWidth - fieldWidth) / 2
                let offsetY = fieldPadding + (availableHeight - fieldHeight) / 2

                ZStack {
                    // Field
                    fieldView(fieldWidth: fieldWidth, fieldHeight: fieldHeight)
                        .position(x: offsetX + fieldWidth / 2, y: offsetY + fieldHeight / 2)

                    // Penalty areas in front of edge goals — reads like a real pitch
                    penaltyAreas(scale: scale, offsetX: offsetX, offsetY: offsetY, fieldHeight: fieldHeight)

                    // Paths (behind elements)
                    if let paths = diagram.paths {
                        ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                            if path.reset != true {
                            pathView(
                                path,
                                scale: scale,
                                offsetX: offsetX,
                                offsetY: offsetY,
                                fieldHeight: fieldHeight
                            )
                            }
                        }
                    }

                    // Elements
                    ForEach(diagram.elements) { element in
                        elementView(
                            element,
                            scale: scale,
                            offsetX: offsetX,
                            offsetY: offsetY,
                            fieldHeight: fieldHeight
                        )
                    }

                    // Dimension label
                    if chrome {
                        Text("\(Int(diagram.field.width))m x \(Int(diagram.field.length))m")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .position(x: geometry.size.width / 2, y: offsetY + fieldHeight + fieldPadding / 2 + 2)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(diagramAccessibilityLabel)

            // Step controls
            if chrome && hasSteps && currentStep != nil {
                stepControls
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(chrome ? DesignSystem.Colors.pitch : Color.clear)
        .cornerRadius(chrome ? DesignSystem.CornerRadius.pitchCardCompact : 0)
        .onChange(of: currentStep) { _, newStep in
            if newStep != nil {
                restartPathAnimation()
            }
        }
        .onChange(of: isAutoPlaying) { _, playing in
            if playing {
                startAutoPlay()
            } else {
                stopAutoPlay()
            }
        }
        .onAppear {
            if isAutoPlaying {
                startAutoPlay()
            }
            if currentStep != nil {
                restartPathAnimation()
            }
        }
        .onDisappear {
            stopAutoPlay()
        }
    }

    // MARK: - Field Rendering

    private func fieldView(fieldWidth: CGFloat, fieldHeight: CGFloat) -> some View {
        return ZStack {
            // Pitch surface
            Rectangle()
                .fill(DesignSystem.Colors.pitch)
                .frame(width: fieldWidth, height: fieldHeight)

            // Halfway line
            Rectangle()
                .fill(DesignSystem.Colors.chalkWhite.opacity(0.28))
                .frame(width: fieldWidth, height: 1.5)

            // Centre circle
            Circle()
                .stroke(DesignSystem.Colors.chalkWhite.opacity(0.28), lineWidth: 1.5)
                .frame(
                    width: min(fieldWidth, fieldHeight) * 0.3,
                    height: min(fieldWidth, fieldHeight) * 0.3
                )

            // Touchline
            Rectangle()
                .stroke(DesignSystem.Colors.chalkWhite.opacity(0.28), lineWidth: 1.5)
                .frame(width: fieldWidth, height: fieldHeight)
        }
    }

    /// Draws an 18-yard box, 6-yard box and penalty spot in front of every
    /// goal that sits on a field edge, oriented into the pitch.
    private func penaltyAreas(scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat, fieldHeight: CGFloat) -> some View {
        let fieldW = Double(diagram.field.width)
        let fieldL = Double(diagram.field.length)
        let goals = diagram.elements.filter { $0.elementType == .goal }
        return Path { p in
            for g in goals {
                let dists = [g.x, fieldW - g.x, g.y, fieldL - g.y]
                guard let m = dists.min(), m <= 2.5 else { continue }
                // Box dims in meters, clamped so small fields still look sane.
                let bigD = min(16.5, fieldL * 0.4, fieldW * 0.4)     // depth into pitch
                let bigW = min(40.3, (dists[0] == m || dists[1] == m ? fieldL : fieldW) * 0.85)
                let smallD = bigD / 3, smallW = bigW * 0.45
                let spotD = min(11.0, bigD * 0.66)
                func pt(_ x: Double, _ y: Double) -> CGPoint {
                    CGPoint(x: offsetX + CGFloat(x) * scale,
                            y: offsetY + fieldHeight - CGFloat(y) * scale)
                }
                func box(cx: Double, cy: Double, depth: Double, halfW: Double, edge: Int) {
                    // edge: 0=left,1=right,2=bottom,3=top — depth extends into the pitch
                    var r: [CGPoint]
                    switch edge {
                    case 0: r = [pt(0, cy - halfW), pt(depth, cy - halfW), pt(depth, cy + halfW), pt(0, cy + halfW)]
                    case 1: r = [pt(fieldW, cy - halfW), pt(fieldW - depth, cy - halfW), pt(fieldW - depth, cy + halfW), pt(fieldW, cy + halfW)]
                    case 2: r = [pt(cx - halfW, 0), pt(cx - halfW, depth), pt(cx + halfW, depth), pt(cx + halfW, 0)]
                    default: r = [pt(cx - halfW, fieldL), pt(cx - halfW, fieldL - depth), pt(cx + halfW, fieldL - depth), pt(cx + halfW, fieldL)]
                    }
                    p.move(to: r[0]); p.addLine(to: r[1]); p.addLine(to: r[2]); p.addLine(to: r[3])
                }
                let edge = dists.firstIndex(of: m) ?? 1
                box(cx: g.x, cy: g.y, depth: bigD, halfW: bigW / 2, edge: edge)
                box(cx: g.x, cy: g.y, depth: smallD, halfW: smallW / 2, edge: edge)
                // Penalty spot
                let spot: CGPoint
                switch edge {
                case 0: spot = pt(spotD, g.y)
                case 1: spot = pt(fieldW - spotD, g.y)
                case 2: spot = pt(g.x, spotD)
                default: spot = pt(g.x, fieldL - spotD)
                }
                p.addEllipse(in: CGRect(x: spot.x - 1.5, y: spot.y - 1.5, width: 3, height: 3))
            }
        }
        .stroke(DesignSystem.Colors.chalkWhite.opacity(0.28), lineWidth: 1)
    }

    // MARK: - Element Rendering

    @ViewBuilder
    private func elementView(
        _ element: DiagramElement,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        fieldHeight: CGFloat
    ) -> some View {
        let x = offsetX + CGFloat(element.x) * scale
        let y = offsetY + fieldHeight - CGFloat(element.y) * scale
        let isActive = isElementActive(element.label)

        Group {
            switch element.elementType {
            case .player:
                playerElementView(label: element.label, isActive: isActive)
            case .defender:
                defenderElementView(label: element.label, isActive: isActive)
            case .server:
                serverElementView(label: element.label, isActive: isActive)
            case .mannequin:
                mannequinElementView(label: element.label)
            case .wall:
                wallElementView(label: element.label)
                    .rotationEffect(goalRotation(for: element))
            case .cone:
                coneElementView(label: element.label)
            case .goal:
                goalElementView(label: element.label)
                    .rotationEffect(goalRotation(for: element))
            case .gate:
                gateElementView(label: element.label)
                    .rotationEffect(goalRotation(for: element))
            case .ball:
                ballElementView()
            case .target:
                targetElementView(label: element.label)
            }
        }
        .opacity(stepOpacity(for: element.label))
        .animation(DesignSystem.Animation.smooth, value: currentStep)
        .position(x: x, y: y)
    }

    private func playerElementView(label: String, isActive: Bool) -> some View {
        let displayText = String(label.prefix(2))

        return ZStack {
            // Pulsing glow when active
            if isActive {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.3))
                    .frame(width: playerSize + 14, height: playerSize + 14)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            pulseScale = 1.25
                        }
                    }
            }

            Circle()
                .fill(DesignSystem.Colors.chalkWhite)
                .frame(width: playerSize, height: playerSize)

            Text(displayText)
                .font(Font.system(size: 12, weight: .bold).width(.condensed))
                .foregroundColor(DesignSystem.Colors.textOnAccent)
        }
    }

    private func defenderElementView(label: String, isActive: Bool) -> some View {
        let displayText = String(label.prefix(2))

        return ZStack {
            if isActive {
                Circle()
                    .fill(DesignSystem.Colors.error.opacity(0.3))
                    .frame(width: playerSize + 14, height: playerSize + 14)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            pulseScale = 1.25
                        }
                    }
            }

            Circle()
                .fill(DesignSystem.Colors.error)
                .frame(width: playerSize, height: playerSize)

            Text(displayText)
                .font(Font.system(size: 12, weight: .bold).width(.condensed))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
        }
    }

    private static let serverBlue = DesignSystem.Colors.grass

    private func serverElementView(label: String, isActive: Bool) -> some View {
        let displayText = String(label.prefix(2))

        return ZStack {
            if isActive {
                Circle()
                    .fill(Self.serverBlue.opacity(0.3))
                    .frame(width: playerSize + 14, height: playerSize + 14)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            pulseScale = 1.25
                        }
                    }
            }

            Circle()
                .fill(Self.serverBlue)
                .frame(width: playerSize, height: playerSize)

            Text(displayText)
                .font(Font.system(size: 12, weight: .bold).width(.condensed))
                .foregroundColor(DesignSystem.Colors.textOnAccent)
        }
    }

    private func mannequinElementView(label: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Self.wallGray)
                    .frame(width: playerSize, height: playerSize)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                Text("X")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textOnPitch)
        }
    }

    private static let wallGray = DesignSystem.Colors.surfaceHighlight

    private func wallElementView(label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.Colors.chalkWhite)
                .frame(width: 40, height: 10)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textOnPitch)
        }
    }

    private func coneElementView(label: String) -> some View {
        VStack(spacing: 2) {
            ConeTriangle()
                .fill(DesignSystem.Colors.cone)
                .frame(width: coneSize, height: coneSize)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textOnPitch)
        }
    }

    /// Gate: two bright posts with a dashed opening — a target to play through,
    /// visually distinct from a cone.
    private func gateElementView(label: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(DesignSystem.Colors.accentOrange)
                    .frame(width: 3, height: 10)
                Capsule()
                    .fill(DesignSystem.Colors.accentOrange)
                    .frame(width: 3, height: 10)
            }
            .overlay(
                Rectangle()
                    .fill(DesignSystem.Colors.accentOrange.opacity(0.5))
                    .frame(width: 8, height: 1)
            )
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))
        }
    }

    /// Goals render horizontally by default; a goal sitting on the left/right
    /// field edge must rotate 90° so its mouth faces the pitch — otherwise it
    /// looks impossible to score in.
    private func goalRotation(for element: DiagramElement) -> Angle {
        let distLeft = element.x
        let distRight = Double(diagram.field.width) - element.x
        let distBottom = element.y
        let distTop = Double(diagram.field.length) - element.y
        let nearest = min(distLeft, distRight, distBottom, distTop)
        return (nearest == distLeft || nearest == distRight) ? .degrees(90) : .degrees(0)
    }

    private func goalElementView(label: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                // Net: diagonal hatched lines
                Canvas { context, size in
                    let spacing: CGFloat = 5
                    var x: CGFloat = -size.height
                    while x < size.width + size.height {
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: 0))
                        line.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        context.stroke(
                            line,
                            with: .color(Color.white.opacity(0.15)),
                            lineWidth: 0.5
                        )
                        x += spacing
                    }
                }
                .frame(width: goalWidth, height: goalHeight)
                .clipShape(RoundedRectangle(cornerRadius: 1))

                // Left post
                Rectangle()
                    .fill(DesignSystem.Colors.chalkWhite)
                    .frame(width: 2, height: goalHeight)
                    .offset(x: -goalWidth / 2 + 1)

                // Right post
                Rectangle()
                    .fill(DesignSystem.Colors.chalkWhite)
                    .frame(width: 2, height: goalHeight)
                    .offset(x: goalWidth / 2 - 1)

                // Crossbar
                Rectangle()
                    .fill(DesignSystem.Colors.chalkWhite)
                    .frame(width: goalWidth, height: 2)
                    .offset(y: -goalHeight / 2 + 1)
            }
            .frame(width: goalWidth, height: goalHeight)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textOnPitch)
        }
    }

    private func ballElementView() -> some View {
        Circle()
            .fill(DesignSystem.Colors.surfaceBase)
            .frame(width: ballSize * 0.85, height: ballSize * 0.85)
            .overlay(Circle().stroke(DesignSystem.Colors.chalkWhite, lineWidth: 1.5))
    }

    private func targetElementView(label: String) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(DesignSystem.Colors.grass)
                .frame(width: targetSize, height: targetSize)
                .rotationEffect(.degrees(45))

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textOnPitch)
                .offset(y: 4)
        }
    }

    // MARK: - Path Rendering

    @ViewBuilder
    private func pathView(
        _ path: DiagramPath,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        fieldHeight: CGFloat
    ) -> some View {
        let fromElement = diagram.elements.first { $0.label == path.from }
        let toElement = diagram.elements.first { $0.label == path.to }

        if let from = fromElement, let to = toElement {
            // Prefer server-baked step coordinates (players relocate during the
            // sequence — labels alone would draw later actions from spawn points).
            let fromPt = CGPoint(
                x: offsetX + CGFloat(path.fx ?? from.x) * scale,
                y: offsetY + fieldHeight - CGFloat(path.fy ?? from.y) * scale
            )
            let toPt = CGPoint(
                x: offsetX + CGFloat(path.tx ?? to.x) * scale,
                y: offsetY + fieldHeight - CGFloat(path.ty ?? to.y) * scale
            )
            let controlPt = curveControlPoint(from: fromPt, to: toPt)
            let isStepPath = path.step != nil && currentStep != nil && path.step == originalStep(forVisible: currentStep!)
            let shouldAnimate = isStepPath
            let shouldShow = path.step == nil || path.step == currentStep

            if shouldShow {
                ZStack {
                    // The curve line
                    CurvedPathShape(from: fromPt, to: toPt, control: controlPt)
                        .stroke(
                            pathColor(path.pathStyle),
                            style: path.alt == true
                                ? StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 5])
                                : pathStrokeStyle(path.pathStyle)
                        )
                        .opacity(pathOpacity(for: path) * (path.alt == true ? 0.55 : 1.0))

    // Arrowhead for ball-travel styles
                    if path.pathStyle == .pass || path.pathStyle == .shoot || path.pathStyle == .receive {
                        arrowHeadView(from: fromPt, to: toPt, control: controlPt)
                            .fill(pathColor(path.pathStyle))
                            .opacity(pathOpacity(for: path))
                    }

                    // Animated traveling dot
                    if shouldAnimate {
                        travelingDot(from: fromPt, to: toPt, control: controlPt, style: path.pathStyle)
                    }
                }
            }
        }
    }

    private func curveControlPoint(from: CGPoint, to: CGPoint) -> CGPoint {
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return CGPoint(x: midX, y: midY) }
        // Perpendicular offset ~20pt
        let perpX = -dy / length * 20
        let perpY = dx / length * 20
        return CGPoint(x: midX + perpX, y: midY + perpY)
    }

    private func pathColor(_ style: DiagramPathStyle) -> Color {
        switch style {
        case .dribble, .pass, .shoot, .receive: return DesignSystem.Colors.grass
        case .run: return DesignSystem.Colors.chalkWhite.opacity(0.7)
        }
    }

    private func pathStrokeStyle(_ style: DiagramPathStyle) -> StrokeStyle {
        switch style {
        case .dribble:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .run:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        case .pass:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
        case .shoot:
            return StrokeStyle(lineWidth: 3, lineCap: .round)
        case .receive:
            return StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3])
        }
    }

    private func pathOpacity(for path: DiagramPath) -> Double {
        guard let idx = currentStep else { return 1.0 }
        if path.step == nil { return 0.3 }
        return path.step == originalStep(forVisible: idx) ? 1.0 : 0.2
    }

    private func arrowHeadView(from: CGPoint, to: CGPoint, control: CGPoint) -> Path {
        // Tangent at t=1 of quadratic bezier: 2*(1-t)*(control-from) + 2*t*(to-control) at t=1
        let tangentX = 2 * (to.x - control.x)
        let tangentY = 2 * (to.y - control.y)
        let angle = atan2(tangentY, tangentX)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        let tip = to
        let left = CGPoint(
            x: tip.x - arrowLength * cos(angle - arrowAngle),
            y: tip.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: tip.x - arrowLength * cos(angle + arrowAngle),
            y: tip.y - arrowLength * sin(angle + arrowAngle)
        )

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private func travelingDot(from: CGPoint, to: CGPoint, control: CGPoint, style: DiagramPathStyle) -> some View {
        let t = pathAnimationProgress
        // Quadratic bezier: B(t) = (1-t)^2 * P0 + 2*(1-t)*t * P1 + t^2 * P2
        let oneMinusT = 1.0 - t
        let dotX = oneMinusT * oneMinusT * from.x + 2 * oneMinusT * t * control.x + t * t * to.x
        let dotY = oneMinusT * oneMinusT * from.y + 2 * oneMinusT * t * control.y + t * t * to.y

        return Circle()
            .fill(pathColor(style))
            .frame(width: 8, height: 8)
            .position(x: dotX, y: dotY)
    }

    // MARK: - Step Logic

    private func activeElements(for visibleIndex: Int) -> Set<String> {
        guard let paths = diagram.paths,
              let step = originalStep(forVisible: visibleIndex) else { return [] }
        var labels = Set<String>()
        for path in paths where path.step == step && path.reset != true {
            labels.insert(path.from)
            labels.insert(path.to)
        }
        return labels
    }

    private func isElementActive(_ label: String) -> Bool {
        guard let step = currentStep else { return false }
        return activeElements(for: step).contains(label)
    }

    private func stepOpacity(for label: String) -> Double {
        guard let step = currentStep else { return 1.0 }
        let active = activeElements(for: step)
        if active.isEmpty { return 1.0 }
        return active.contains(label) ? 1.0 : 0.4
    }

    // MARK: - Path Animation

    private func restartPathAnimation() {
        pathAnimationProgress = 0
        withAnimation(.easeInOut(duration: 1.5 / playbackSpeed)) {
            pathAnimationProgress = 1
        }
    }

    // MARK: - Auto-Play

    private func startAutoPlay() {
        stopAutoPlay()
        if currentStep == nil {
            currentStep = 1
            restartPathAnimation()
        }
        let interval = 3.5 / playbackSpeed
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                advanceStep()
            }
        }
    }

    private func stopAutoPlay() {
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }

    private func advanceStep() {
        guard let step = currentStep else { return }
        if step < totalSteps {
            currentStep = step + 1
        } else {
            isAutoPlaying = false
        }
    }

    // MARK: - Step Controls

    private var stepControls: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Instruction text
            if let step = currentStep,
               step >= 1,
               step <= instructions.count {
                Text(instructions[step - 1])
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .transition(.opacity)
                    .id(step)
            }

            HStack {
                // Previous
                Button {
                    if let step = currentStep, step > 1 {
                        currentStep = step - 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(
                            currentStep ?? 0 > 1
                                ? DesignSystem.Colors.textPrimary
                                : DesignSystem.Colors.textTertiary
                        )
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Colors.surfaceOverlay)
                        .clipShape(Circle())
                }
                .a11y(label: "Previous step")
                .disabled((currentStep ?? 0) <= 1)

                Spacer()

                // Step counter
                if let step = currentStep {
                    Text("Step \(step) of \(totalSteps)")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                if isTrainingMode {
                    // Done button in training mode
                    Button {
                        if let step = currentStep {
                            onStepCompleted?(step)
                            if step < totalSteps {
                                currentStep = step + 1
                            }
                        }
                    } label: {
                        Text("Done")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textOnAccent)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.primaryGreen)
                            .clipShape(Capsule())
                    }
                } else {
                    // Next
                    Button {
                        if let step = currentStep, step < totalSteps {
                            currentStep = step + 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(
                                (currentStep ?? 0) < totalSteps
                                    ? DesignSystem.Colors.textPrimary
                                    : DesignSystem.Colors.textTertiary
                            )
                            .frame(width: 36, height: 36)
                            .background(DesignSystem.Colors.surfaceOverlay)
                            .clipShape(Circle())
                    }
                    .a11y(label: "Next step")
                    .disabled((currentStep ?? 0) >= totalSteps)
                }
            }

            // Auto-play and speed (non-training only)
            if !isTrainingMode {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button {
                        isAutoPlaying.toggle()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                                .font(DesignSystem.Typography.labelSmall)
                            Text(isAutoPlaying ? "Pause" : "Auto-play")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }

                    Spacer()

                    // Speed selector
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach([0.5, 1.0, 2.0], id: \.self) { speed in
                            speedButton(speed: speed)
                        }
                    }
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    @ViewBuilder
    private func speedButton(speed: Double) -> some View {
        let isSelected = abs(playbackSpeed - speed) < 0.01
        Text("\(speed == 0.5 ? "0.5" : speed == 1.0 ? "1" : "2")x")
            .font(DesignSystem.Typography.labelSmall)
            .foregroundColor(
                isSelected
                    ? DesignSystem.Colors.textOnAccent
                    : DesignSystem.Colors.textSecondary
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                isSelected
                    ? DesignSystem.Colors.primaryGreen
                    : DesignSystem.Colors.surfaceOverlay
            )
            .clipShape(Capsule())
    }
}

// MARK: - Supporting Shapes

struct ConeTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Small pentagon shape for ball overlay
struct PentagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<5 {
            let angle = (CGFloat(i) * 2 * .pi / 5) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
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

/// Shape that draws a quadratic bezier curve
struct CurvedPathShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let control: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        return path
    }
}

// MARK: - Preview

#Preview {
    let sampleDiagram = DrillDiagram(
        field: DiagramField(width: 20, length: 20),
        elements: [
            DiagramElement(type: "cone", x: 2, y: 2, label: "A"),
            DiagramElement(type: "cone", x: 2, y: 18, label: "B"),
            DiagramElement(type: "cone", x: 18, y: 18, label: "C"),
            DiagramElement(type: "player", x: 2, y: 2, label: "P1"),
            DiagramElement(type: "target", x: 18, y: 10, label: "Partner"),
            DiagramElement(type: "goal", x: 10, y: 20, label: "Goal"),
            DiagramElement(type: "ball", x: 3, y: 3, label: "Ball")
        ],
        paths: [
            DiagramPath(from: "A", to: "B", style: "dribble", step: 1),
            DiagramPath(from: "B", to: "C", style: "run", step: 2),
            DiagramPath(from: "C", to: "Partner", style: "pass", step: 3)
        ]
    )

    return VStack {
        Text("Drill Diagram")
            .font(DesignSystem.Typography.headlineSmall)
            .foregroundColor(DesignSystem.Colors.textPrimary)

        AnimatedDrillDiagramView(
            diagram: sampleDiagram,
            instructions: [
                "Dribble from cone A to cone B",
                "Sprint from cone B to cone C",
                "Pass the ball to your partner"
            ],
            currentStep: .constant(1),
            isAutoPlaying: .constant(false)
        )
        .frame(height: 350)
        .padding()
    }
    .background(DesignSystem.Colors.surfaceBase)
}


// MARK: - Web Animation Player (Engine v4 — phase-timeline, follow-cam)
// The same engine that renders review-page animations, embedded as a
// self-contained document. Drill JSON (diagram + animation) is injected via
// loadDrill(); no network, no remote code.

import WebKit

struct DrillWebAnimationView: UIViewRepresentable {
    /// Composed JSON: {"diagram": ..., "animation": ...}
    let drillJSON: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(Self.playerHTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingDrillJSON = drillJSON
        context.coordinator.injectIfReady(into: webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingDrillJSON: String?
        private var loaded = false
        private var lastInjected: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            injectIfReady(into: webView)
        }

        func injectIfReady(into webView: WKWebView) {
            guard loaded, let json = pendingDrillJSON, json != lastInjected else { return }
            lastInjected = json
            webView.evaluateJavaScript("window.loadDrill(\(json));", completionHandler: nil)
        }
    }
}

extension DrillWebAnimationView {
    /// Build the composed payload from persisted strings; nil if either is absent.
    static func composedJSON(diagramJSON: String?, animationJSON: String?) -> String? {
        guard let d = diagramJSON, let a = animationJSON,
              !d.isEmpty, !a.isEmpty else { return nil }
        return "{\"diagram\":\(d),\"animation\":\(a)}"
    }

    /// Overload for call sites that hold the decoded diagram.
    static func composedJSON(diagram: DrillDiagram, animationJSON: String?) -> String? {
        guard let a = animationJSON, !a.isEmpty,
              let data = try? JSONEncoder().encode(diagram),
              let d = String(data: data, encoding: .utf8) else { return nil }
        return "{\"diagram\":\(d),\"animation\":\(a)}"
    }

    static let playerHTML: String = ##"""
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
html,body{margin:0;padding:0;background:transparent;-webkit-user-select:none;user-select:none;overflow:hidden}
svg.pitchsvg{width:100vw;height:auto;display:block;border-radius:10px}
.animbar svg{width:12px;height:12px;flex:none}
.animbar{display:flex;gap:8px;justify-content:center;align-items:center;margin-top:8px;padding:0 10px}
.animbar button{font:600 12px/1 -apple-system,system-ui;letter-spacing:.06em;text-transform:uppercase;border:0;background:#5CCB5F;color:#0E1210;border-radius:7px;padding:10px 16px}
.animbar input{flex:1}
.animcap{text-align:center;font:600 13px/1.45 -apple-system,system-ui;margin:8px 10px 4px;min-height:20px;color:#D7E3DA}
body{color:#BFD3C4}
@media (prefers-color-scheme: light){body{color:#1A211B}}
</style></head><body>
<div id="stage"></div>
<script>
const COLORS = { dribble:"#5CA8E8", run:"#B9C4BB", pass:"#79D97C", shoot:"#F2A33C", receive:"#79D97C", header:"#E86FC0", toss:"#8FD8E8", throw:"#8FD8E8" };
const DASH = { run:"6 5", receive:"3 4", header:"2 6", toss:"2 6", throw:"2 6" };
function el(t,a,c){const n=document.createElementNS("http://www.w3.org/2000/svg",t);for(const k in a)n.setAttribute(k,a[k]);(c||[]).forEach(x=>n.appendChild(x));return n;}
function rot(e,W,L){const d=[e.x,W-e.x,e.y,L-e.y];const m=Math.min(...d);return (m===d[0]||m===d[1])?90:0;}
function renderPitch(drill){
  const dg=drill.diagram,f=dg.field,W=f.width,L=f.length,S=30,vw=W*S,vh=L*S;
  const svg=el("svg",{viewBox:`-14 -14 ${vw+28} ${vh+28}`,role:"img","aria-label":"drill diagram"});
  svg.appendChild(el("rect",{x:0,y:0,width:vw,height:vh,rx:8,fill:"#173A26"}));
  for(let i=0;i<Math.floor(L/3);i++){ if(i%2===0) svg.appendChild(el("rect",{x:0,y:i*3*S,width:vw,height:3*S,fill:"rgba(255,255,255,.045)"})); }
  svg.appendChild(el("circle",{cx:vw/2,cy:vh/2,r:Math.min(vw,vh)*.16,fill:"none",stroke:"rgba(255,255,255,.35)","stroke-width":1.5}));
  // Penalty areas in front of edge goals
  dg.elements.filter(e=>e.type==="goal").forEach(g0=>{
    const dists=[g0.x,W-g0.x,g0.y,L-g0.y]; const m=Math.min(...dists);
    if(m>2.5) return;
    const edge=dists.indexOf(m);
    const vert=(edge===0||edge===1);
    const bigD=Math.min(16.5,(vert?W:L)*0.4), bigW=Math.min(40.3,(vert?L:W)*0.85);
    const smallD=bigD/3, smallW=bigW*0.45, spotD=Math.min(11,bigD*0.66);
    const box=(depth,halfW)=>{
      let x0,y0,w0,h0;
      if(edge===0){x0=0;y0=vh-(g0.y+halfW)*S;w0=depth*S;h0=halfW*2*S;}
      else if(edge===1){x0=vw-depth*S;y0=vh-(g0.y+halfW)*S;w0=depth*S;h0=halfW*2*S;}
      else if(edge===2){x0=(g0.x-halfW)*S;y0=vh-depth*S;w0=halfW*2*S;h0=depth*S;}
      else {x0=(g0.x-halfW)*S;y0=0;w0=halfW*2*S;h0=depth*S;}
      svg.appendChild(el("rect",{x:x0,y:y0,width:w0,height:h0,fill:"none",stroke:"rgba(255,255,255,.35)","stroke-width":1}));
    };
    box(bigD,bigW/2); box(smallD,smallW/2);
    let sx,sy;
    if(edge===0){sx=spotD*S;sy=vh-g0.y*S;} else if(edge===1){sx=vw-spotD*S;sy=vh-g0.y*S;}
    else if(edge===2){sx=g0.x*S;sy=vh-spotD*S;} else {sx=g0.x*S;sy=spotD*S;}
    svg.appendChild(el("circle",{cx:sx,cy:sy,r:2,fill:"rgba(255,255,255,.5)"}));
  });
  const px=e=>e.x*S, py=e=>vh-e.y*S;
  const by={}; dg.elements.forEach(e=>by[e.label]=e);
  const simPos={}; dg.elements.forEach(e=>{ if(e.type==="player") simPos[e.label]={x:e.x,y:e.y}; });
  const segs=[];
  (dg.paths||[]).slice().sort((a,b)=>(a.step||0)-(b.step||0)).forEach(p=>{
    const sP=simPos[p.from], dP=simPos[p.to];
    const sEl=sP||by[p.from], tEl=dP||by[p.to];
    if(!sEl||!tEl){segs.push(null);return;}
    // Server-baked coordinates win; local sim is only a fallback for old drills.
    const seg={step:p.step,style:p.style,alt:!!p.alt,reset:!!p.reset,touches:p.touches||null,
      from:{x:(p.fx!=null?p.fx:sEl.x),y:(p.fy!=null?p.fy:sEl.y)},
      to:{x:(p.tx!=null?p.tx:tEl.x),y:(p.ty!=null?p.ty:tEl.y)}};
    segs.push(seg);
    if(!p.alt&&(p.style==="run"||p.style==="dribble")&&sP){ simPos[p.from]={x:tEl.x,y:tEl.y}; }
  });
  svg.__segs=segs;
  segs.forEach(sg=>{
    if(!sg||sg.reset)return; // resets are hidden mechanics
    const x1=sg.from.x*S,y1=vh-sg.from.y*S,x2=sg.to.x*S,y2=vh-sg.to.y*S;
    const mx=(x1+x2)/2,my=(y1+y2)/2,dx=x2-x1,dy=y2-y1,len=Math.hypot(dx,dy)||1;
    const AER=["header","toss","throw"].includes(sg.style)?34:16;
    let side=1;
    if(sg.style==="dribble"){
      // round the cone: curve to the OUTSIDE of the next turn
      const i=segs.indexOf(sg);
      for(let k=i+1;k<segs.length;k++){ const nx=segs[k];
        if(!nx||nx.reset||nx.alt)continue;
        const dx2=(nx.to.x-nx.from.x)*S,dy2=-(nx.to.y-nx.from.y)*S;
        const cross=dx*dy2-dy*dx2;
        if(Math.abs(cross)>1)side=cross>0?-1:1;
        break;
      }
    }
    const cx=mx-dy/len*AER*side,cy=my+dx/len*AER*side;
    const col=COLORS[sg.style]||"#ccc";
    const path=el("path",{d:`M ${x1} ${y1} Q ${cx} ${cy} ${x2} ${y2}`,fill:"none",stroke:col,"stroke-width":sg.style==="shoot"?3.4:(sg.alt?1.8:2.2),"stroke-linecap":"round","data-step":sg.step,class:"anim-path"});
    if(sg.alt) path.setAttribute("stroke-dasharray","5 5"), path.setAttribute("opacity","0.55");
    else if(DASH[sg.style]) path.setAttribute("stroke-dasharray",DASH[sg.style]);
    svg.appendChild(path);
    const ang=Math.atan2(y2-cy,x2-cx);
    svg.appendChild(el("path",{d:`M ${x2} ${y2} L ${x2-9*Math.cos(ang-.45)} ${y2-9*Math.sin(ang-.45)} L ${x2-9*Math.cos(ang+.45)} ${y2-9*Math.sin(ang+.45)} Z`,fill:col,"data-step":sg.step,class:"anim-path"}));
    const qx=.25*x1+.5*cx+.25*x2,qy=.25*y1+.5*cy+.25*y2;
    if(sg.touches){
      const bx=x1+(x2-x1)*0.18, by=y1+(y2-y1)*0.18;
      svg.appendChild(el("rect",{x:bx-11,y:by-8,width:22,height:14,rx:4,fill:"rgba(0,0,0,.6)"}));
      const tb=el("text",{x:bx,y:by+3,"text-anchor":"middle","font-size":8.5,"font-weight":800,fill:"#fff","font-family":"ui-monospace, monospace"});
      tb.textContent=sg.touches+"T"; svg.appendChild(tb);
    }
    if(sg.alt){ // only the semantic "or" chip survives; step order lives in the animation + caption
      svg.appendChild(el("circle",{cx:qx,cy:qy,r:9,fill:"rgba(0,0,0,.4)"}));
      const t=el("text",{x:qx,y:qy+3.4,"text-anchor":"middle","font-size":7.5,"font-weight":700,fill:"#fff","font-family":"ui-monospace, monospace"});
      t.textContent="or"; svg.appendChild(t);
    }
  });
  dg.elements.forEach(e=>{
    const x=px(e),y=py(e),g=el("g",{"data-label":e.label,"data-type":e.type});
    if(e.type==="cone"){ g.appendChild(el("path",{d:`M ${x} ${y-7} L ${x-6.5} ${y+5} L ${x+6.5} ${y+5} Z`,fill:"#F0A33A",stroke:"#7A4A12","stroke-width":.8})); }
    else if(e.type==="ball"){ g.appendChild(el("circle",{cx:x,cy:y,r:4.6,fill:"#fff",stroke:"#222","stroke-width":1})); }
    else if(e.type==="goal"||e.type==="gate"){
      const r=rot(e,W,L),wpx=((e.type==="goal"?(e.width||7.32):(e.width||1.6))*S);
      const gg=el("g",{transform:`rotate(${r} ${x} ${y})`});
      if(e.type==="goal"){ gg.appendChild(el("rect",{x:x-wpx/2,y:y-6,width:wpx,height:12,fill:"rgba(255,255,255,.16)",stroke:"#fff","stroke-width":2})); }
      else { gg.appendChild(el("rect",{x:x-wpx/2-2,y:y-6,width:4,height:12,rx:2,fill:"#F2A33C"})); gg.appendChild(el("rect",{x:x+wpx/2-2,y:y-6,width:4,height:12,rx:2,fill:"#F2A33C"})); }
      g.appendChild(gg);
    }
    else if(e.type==="wall"){ const wr=rot(e,W,L); const wg=el("g",{transform:`rotate(${wr} ${x} ${y})`}); wg.appendChild(el("rect",{x:x-26,y:y-4,width:52,height:8,rx:3,fill:"#9AA4A0",stroke:"rgba(0,0,0,.35)","stroke-width":1})); g.appendChild(wg); }
    else { const fill=e.role==="defender"?"#B23A3A":e.role==="server"?"#EEF1EC":"#5CCB5F"; g.appendChild(el("circle",{cx:x,cy:y,r:11,fill,stroke:"rgba(0,0,0,.4)","stroke-width":1.2})); }
    if(e.type==="player"){
      const inTxt=e.role==="worker"?"You":(e.role==="defender"?"D":(e.display_label?e.display_label[0]:e.label[0]));
      const inEl=el("text",{x,y:y+3.6,"text-anchor":"middle","font-size":9,"font-weight":600,fill:e.role==="server"?"#0E1210":"#0E1210","font-family":"sans-serif"});
      inEl.textContent=inTxt; g.appendChild(inEl);
      const under=e.display_label||(e.role==="server"?"Feeder":e.role==="defender"?"Defender":"");
      if(under){ const u=el("text",{x,y:y+24,"text-anchor":"middle","font-size":9.5,fill:"rgba(255,255,255,.9)","font-family":"sans-serif"});
        u.textContent=under; g.appendChild(u); }
    } else {
      const lbl=el("text",{x,y:y+16,"text-anchor":"middle","font-size":8.5,"font-weight":700,fill:"rgba(255,255,255,.92)","font-family":"ui-monospace, monospace"});
      lbl.textContent=e.label; g.appendChild(lbl);
    }
    svg.appendChild(g);
  });
  return svg;
}
function loadDrill(drill){
  const stage=document.getElementById('stage'); stage.innerHTML='';
  const pw=document.createElement('div'); stage.appendChild(pw);
  const svgEl=renderPitch(drill); svgEl.classList.add('pitchsvg'); pw.appendChild(svgEl);
  // ---- Engine v2: phase-timeline player (Fable-style: continuous clock,
  // ---- concurrent tracks, hips vectors, timed coaching captions) ----
  const BALLK="__ball__";
  const anim=drill.animation&&drill.animation.phases&&drill.animation.phases.length?drill.animation:null;
  if(anim){
    const f2=drill.diagram.field,S2=30,vh2=f2.length*S2;
    const px=(m)=>({x:m[0]*S2,y:vh2-m[1]*S2});
    const orig={}; drill.diagram.elements.forEach(e=>orig[e.label]={x:e.x*S2,y:vh2-e.y*S2,type:e.type});
    svgEl.querySelectorAll('g[data-label]').forEach(g=>{
      const lbl=g.getAttribute('data-label');
      if(orig[lbl]&&orig[lbl].type==="player"){
        const ox=orig[lbl].x, oy=orig[lbl].y;
        const wedge=el("path",{d:"M 9 0 L 15 3.4 L 15 -3.4 Z",fill:"rgba(0,0,0,.38)","data-h":lbl,opacity:0,transform:`translate(${ox} ${oy})`});
        wedge.setAttribute("data-cx",ox); wedge.setAttribute("data-cy",oy);
        g.appendChild(wedge);
      }
    });
    // follow-cam: while playing, frame the live action; pause = full field
    const VB0=svgEl.getAttribute("viewBox").split(" ").map(Number);
    const cam={cx:VB0[0]+VB0[2]/2, cy:VB0[1]+VB0[3]/2, z:1};
    function camTick(pts){
      let tz=1, tcx=VB0[0]+VB0[2]/2, tcy=VB0[1]+VB0[3]/2;
      if(playing&&pts.length){
        let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
        pts.forEach(p=>{x0=Math.min(x0,p.x);y0=Math.min(y0,p.y);x1=Math.max(x1,p.x);y1=Math.max(y1,p.y);});
        const pad=4*S2, bw=Math.max(x1-x0+2*pad, 12*S2), bh=Math.max(y1-y0+2*pad, 12*S2);
        tz=Math.max(1, Math.min(3.2, Math.min(VB0[2]/bw, VB0[3]/bh)));
        tcx=(x0+x1)/2; tcy=(y0+y1)/2;
      }
      cam.z+= (tz-cam.z)*0.10; cam.cx+=(tcx-cam.cx)*0.10; cam.cy+=(tcy-cam.cy)*0.10;
      const w=VB0[2]/cam.z, h=VB0[3]/cam.z;
      let vx=cam.cx-w/2, vy=cam.cy-h/2;
      vx=Math.max(VB0[0],Math.min(VB0[0]+VB0[2]-w,vx));
      vy=Math.max(VB0[1],Math.min(VB0[1]+VB0[3]-h,vy));
      svgEl.setAttribute("viewBox",`${vx} ${vy} ${w} ${h}`);
    }
    const trail=el("path",{d:"",fill:"none",stroke:"#FFFFFF","stroke-width":1.5,"stroke-dasharray":"4 4",opacity:.65});
    svgEl.appendChild(trail);
    const ball=el("circle",{r:6.5,fill:"#fff",stroke:"#1a1a1a","stroke-width":1.6,opacity:0});
    svgEl.appendChild(ball);
    const main0=anim.phases.filter(q=>q.kind!=="outcome");
    const outs=anim.phases.filter(q=>q.kind==="outcome");
    let loopIdx=0;
    const HOME_D=850;
    const loopPhases=()=>outs.length
      ?main0.concat([outs[loopIdx%outs.length],{kind:"homeglide",d:HOME_D,tracks:{},hips:{},label:"Reset — swap and go again",ease:"lin",step:null}])
      :main0;
    let phases=loopPhases(), total=phases.reduce((a,q)=>a+q.d,0);
    const cap=document.createElement("div"); cap.className="animcap";
    let t=0,last=null,playing=false,speed=1,raf=null;
    const lastPos={};
    const grp=(l)=>svgEl.querySelector(`g[data-label="${l}"]`);
    function snapStart(){
      for(const l in orig){const g=grp(l); if(g)g.setAttribute("transform","");}
      svgEl.querySelectorAll('g[data-type="ball"]').forEach(g=>g.setAttribute("opacity",0.15));
      ball.setAttribute("opacity",1);
      delete lastPos[BALLK];
    }
    const easef=(k,e)=>e==="out"?1-Math.pow(1-k,3):k;
    function render(){
      let acc=0,i=0;
      for(;i<phases.length;i++){ if(t<acc+phases[i].d)break; acc+=phases[i].d; }
      if(i>=phases.length){i=phases.length-1;acc=total-phases[i].d;}
      const q=phases[i], kRaw=Math.min(1,(t-acc)/q.d);
      if(q.kind==="homeglide"&&!q._built){
        q._built=true; q.tracks={}; let gmax=0;
        for(const l in orig){ if(orig[l].type!=="player")continue;
          const cur=lastPos[l]||orig[l];
          q.tracks[l]=[[ (cur.x)/S2, (vh2-cur.y)/S2 ],[ orig[l].x/S2, (vh2-orig[l].y)/S2 ]]; }
        const fb=(function(){for(const ph of main0){if(ph.tracks[BALLK])return ph.tracks[BALLK][0];}return null;})();
        if(fb&&lastPos[BALLK]) q.tracks[BALLK]=[[lastPos[BALLK].x/S2,(vh2-lastPos[BALLK].y)/S2],fb];
        for(const l in q.tracks){const tr=q.tracks[l];gmax=Math.max(gmax,Math.hypot(tr[1][0]-tr[0][0],tr[1][1]-tr[0][1]));}
        q.d=Math.max(500,Math.min(2600,Math.round(gmax*85)));
        total=phases.reduce((a,x)=>a+x.d,0);
      }
      const k=easef(kRaw,q.ease);
      svgEl.style.opacity="1";
      ball.setAttribute("r", q.kind==="tossup" ? 6.5+5*Math.sin(Math.PI*kRaw) : 6.5);
      let ballSet=false,ballStart=null,ballNow=null;const camPts=[];const camActors=[];
      for(const lbl in q.tracks){
        const tr=q.tracks[lbl],A=px(tr[0]),B=px(tr[1]);
        const X=A.x+(B.x-A.x)*k,Y=A.y+(B.y-A.y)*k;
        if(lbl===BALLK){ball.setAttribute("cx",X);ball.setAttribute("cy",Y);ballSet=true;lastPos[BALLK]={x:X,y:Y};ballStart=A;ballNow={x:X,y:Y};camPts.push({x:X,y:Y});camPts.push({x:B.x,y:B.y});}
        else{const g=grp(lbl); if(g&&orig[lbl])g.setAttribute("transform",`translate(${X-orig[lbl].x} ${Y-orig[lbl].y})`); lastPos[lbl]={x:X,y:Y};camActors.push({x:X,y:Y});}
      }
      if(!ballSet&&lastPos[BALLK]){ball.setAttribute("cx",lastPos[BALLK].x);ball.setAttribute("cy",lastPos[BALLK].y);}
      svgEl.querySelectorAll('path[data-h]').forEach(w=>{w.setAttribute("opacity",0);w.setAttribute("fill","rgba(0,0,0,.38)");});
      const face=(lbl,h,bright)=>{
        const w=svgEl.querySelector(`path[data-h="${lbl}"]`); if(!w)return;
        const ang=Math.atan2(-h[1],h[0])*180/Math.PI;
        w.setAttribute("transform",`translate(${w.getAttribute("data-cx")} ${w.getAttribute("data-cy")}) rotate(${ang})`);
        w.setAttribute("opacity",1);
        if(bright)w.setAttribute("fill","#FFFFFF");
      };
      for(const lbl in (q.hips||{})) face(lbl,q.hips[lbl],false);
      for(const lbl in (q.eye||{}))  face(lbl,q.eye[lbl],true);
      cap.textContent=q.label||"";
      // cinema mode: the stage is clean while the movie plays; arrows are for study (pause)
      const stepset=(q.steps||[q.step]).map(String);
      svgEl.querySelectorAll(".anim-path").forEach(pp=>pp.setAttribute("opacity",
        playing?0:(stepset.includes(pp.getAttribute("data-step"))?"1":"0.15")));
      const flying=ballStart&&ballNow&&q.kind!=="fade"&&q.kind!=="tossup"
        &&(Math.abs(ballNow.x-ballStart.x)+Math.abs(ballNow.y-ballStart.y)>2);
      trail.setAttribute("d",playing&&flying?`M ${ballStart.x} ${ballStart.y} L ${ballNow.x} ${ballNow.y}`:"");
      // the star of the shot is the ball and whoever is with it — always in
      // frame; other actors join only if they are near the action
      const bref=ballNow||lastPos[BALLK];
      if(bref){
        let best=null,bd=1e9;
        camActors.forEach(a=>{const dd=Math.hypot(a.x-bref.x,a.y-bref.y); if(dd<bd){bd=dd;best=a;}});
        if(best)camPts.push(best);
        camActors.forEach(a=>{ if(Math.hypot(a.x-bref.x,a.y-bref.y)<14*S2) camPts.push(a); });
      } else camActors.forEach(a=>camPts.push(a));
      camTick(camPts);
    }
    function frame(now){
      if(last===null)last=now;
      if(playing){ t+=(now-last)*speed;
        if(t>=total){ t=0; loopIdx++; phases=loopPhases(); total=phases.reduce((a,q)=>a+q.d,0); phases.forEach(q=>{if(q.kind==="homeglide")q._built=false;}); } }
      last=now; render(); raf=requestAnimationFrame(frame);
    }
    const IC={
      play:'<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" stroke="none" aria-hidden="true"><polygon points="6 3 20 12 6 21 6 3"/></svg>',
      pause:'<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" stroke="none" aria-hidden="true"><rect x="5" y="4" width="4" height="16" rx="1"/><rect x="15" y="4" width="4" height="16" rx="1"/></svg>'
    };
    const bar=document.createElement("div"); bar.className="animbar";
    const btn=document.createElement("button");
    const setBtn=()=>{btn.innerHTML=(playing?IC.pause:IC.play)+'<span style="margin-left:6px">'+(playing?"Pause":"Play")+"</span>";btn.style.display="inline-flex";btn.style.alignItems="center";};
    btn.addEventListener("click",()=>{ playing=!playing; setBtn();
      if(raf===null){ snapStart(); raf=requestAnimationFrame(frame); } });
    setBtn();
    const spd=document.createElement("input"); Object.assign(spd,{type:"range",min:"0.5",max:"2",step:"0.25",value:"1"}); spd.style.flex="1";
    const spdOut=document.createElement("span"); spdOut.textContent="1x"; spdOut.style.cssText="min-width:32px;font:600 12px ui-monospace,monospace;color:var(--muted)";
    spd.addEventListener("input",()=>{speed=parseFloat(spd.value);spdOut.textContent=speed+"x";});
    bar.appendChild(btn); bar.appendChild(spd); bar.appendChild(spdOut);
    pw.appendChild(bar); pw.appendChild(cap);
    snapStart(); render();
  }
  const playBtn=pw.querySelector('.animbar button');
  if(playBtn) playBtn.click();
}
window.loadDrill=loadDrill;
</script></body></html>
"""##
}
