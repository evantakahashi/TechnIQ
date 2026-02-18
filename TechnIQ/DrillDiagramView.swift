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

    // Element sizes
    private let coneSize: CGFloat = 16
    private let playerSize: CGFloat = 26
    private let targetSize: CGFloat = 20
    private let goalWidth: CGFloat = 32
    private let goalHeight: CGFloat = 12
    private let ballSize: CGFloat = 12
    private let fieldPadding: CGFloat = 24

    // Path animation
    @State private var pathAnimationProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var autoPlayTimer: Timer?

    private var totalSteps: Int {
        guard let paths = diagram.paths else { return 0 }
        let maxStep = paths.compactMap { $0.step }.max() ?? 0
        return max(maxStep, instructions.count)
    }

    private var hasSteps: Bool { totalSteps > 0 }

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

                    // Paths (behind elements)
                    if let paths = diagram.paths {
                        ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                            pathView(
                                path,
                                scale: scale,
                                offsetX: offsetX,
                                offsetY: offsetY,
                                fieldHeight: fieldHeight
                            )
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
                    Text("\(Int(diagram.field.width))m x \(Int(diagram.field.length))m")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .position(x: geometry.size.width / 2, y: offsetY + fieldHeight + fieldPadding / 2 + 2)
                }
            }

            // Step controls
            if hasSteps && currentStep != nil {
                stepControls
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
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
        .onDisappear {
            stopAutoPlay()
        }
    }

    // MARK: - Field Rendering

    private func fieldView(fieldWidth: CGFloat, fieldHeight: CGFloat) -> some View {
        let stripeHeight = fieldHeight / 8

        return ZStack {
            // Dark green base
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color(red: 0.18, green: 0.42, blue: 0.18))
                .frame(width: fieldWidth, height: fieldHeight)

            // Alternating grass stripes
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color.clear : Color.white.opacity(0.04))
                        .frame(width: fieldWidth, height: stripeHeight)
                }
            }
            .frame(width: fieldWidth, height: fieldHeight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))

            // Center line
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: fieldWidth * 0.85, height: 1)
                .offset(y: 0)

            // Center circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(
                    width: min(fieldWidth, fieldHeight) * 0.3,
                    height: min(fieldWidth, fieldHeight) * 0.3
                )

            // Touchline border
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                .frame(width: fieldWidth, height: fieldHeight)
        }
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
            case .cone:
                coneElementView(label: element.label)
            case .goal:
                goalElementView(label: element.label)
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
                .fill(DesignSystem.Colors.primaryGreen)
                .frame(width: playerSize, height: playerSize)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            Text(displayText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func coneElementView(label: String) -> some View {
        VStack(spacing: 2) {
            ConeTriangle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.accentOrange,
                            DesignSystem.Colors.accentOrange.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: coneSize, height: coneSize)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
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
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: goalHeight)
                    .offset(x: -goalWidth / 2 + 1)

                // Right post
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2, height: goalHeight)
                    .offset(x: goalWidth / 2 - 1)

                // Crossbar
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: goalWidth, height: 2)
                    .offset(y: -goalHeight / 2 + 1)
            }
            .frame(width: goalWidth, height: goalHeight)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private func ballElementView() -> some View {
        ZStack {
            // Shadow beneath
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: ballSize, height: ballSize * 0.4)
                .offset(y: ballSize * 0.45)

            // White ball
            Circle()
                .fill(Color.white)
                .frame(width: ballSize, height: ballSize)

            // Pentagon overlay
            PentagonShape()
                .fill(Color.black.opacity(0.15))
                .frame(width: ballSize * 0.45, height: ballSize * 0.45)
        }
    }

    private func targetElementView(label: String) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(DesignSystem.Colors.secondaryBlue)
                .frame(width: targetSize, height: targetSize)
                .rotationEffect(.degrees(45))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
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
            let fromPt = CGPoint(
                x: offsetX + CGFloat(from.x) * scale,
                y: offsetY + fieldHeight - CGFloat(from.y) * scale
            )
            let toPt = CGPoint(
                x: offsetX + CGFloat(to.x) * scale,
                y: offsetY + fieldHeight - CGFloat(to.y) * scale
            )
            let controlPt = curveControlPoint(from: fromPt, to: toPt)
            let isStepPath = path.step != nil && path.step == currentStep
            let shouldAnimate = isStepPath
            let shouldShow = path.step == nil || path.step == currentStep

            if shouldShow {
                ZStack {
                    // The curve line
                    CurvedPathShape(from: fromPt, to: toPt, control: controlPt)
                        .stroke(
                            pathColor(path.pathStyle),
                            style: pathStrokeStyle(path.pathStyle)
                        )
                        .opacity(pathOpacity(for: path))

                    // Arrowhead for pass
                    if path.pathStyle == .pass {
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
        case .dribble: return DesignSystem.Colors.secondaryBlue
        case .run: return DesignSystem.Colors.textSecondary
        case .pass: return DesignSystem.Colors.primaryGreen
        }
    }

    private func pathStrokeStyle(_ style: DiagramPathStyle) -> StrokeStyle {
        switch style {
        case .dribble:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .run:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        case .pass:
            return StrokeStyle(lineWidth: 2, lineCap: .round)
        }
    }

    private func pathOpacity(for path: DiagramPath) -> Double {
        guard currentStep != nil else { return 1.0 }
        if path.step == nil { return 0.3 }
        return path.step == currentStep ? 1.0 : 0.2
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
            .shadow(color: pathColor(style).opacity(0.6), radius: 4)
            .position(x: dotX, y: dotY)
    }

    // MARK: - Step Logic

    private func activeElements(for step: Int) -> Set<String> {
        guard let paths = diagram.paths else { return [] }
        var labels = Set<String>()
        for path in paths where path.step == step {
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
