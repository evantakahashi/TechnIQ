import SwiftUI

/// Renders an overhead view of a drill field layout
struct DrillDiagramView: View {
    let diagram: DrillDiagram

    // Visual constants
    private let padding: CGFloat = 20
    private let coneSize: CGFloat = 16
    private let playerSize: CGFloat = 24
    private let targetSize: CGFloat = 20
    private let goalWidth: CGFloat = 30
    private let goalHeight: CGFloat = 10
    private let labelOffset: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (padding * 2)
            let availableHeight = geometry.size.height - (padding * 2)

            // Calculate scale to fit the field
            let scaleX = availableWidth / CGFloat(diagram.field.width)
            let scaleY = availableHeight / CGFloat(diagram.field.length)
            let scale = min(scaleX, scaleY)

            // Calculate offset to center the field
            let fieldWidth = CGFloat(diagram.field.width) * scale
            let fieldHeight = CGFloat(diagram.field.length) * scale
            let offsetX = padding + (availableWidth - fieldWidth) / 2
            let offsetY = padding + (availableHeight - fieldHeight) / 2

            ZStack {
                // Field background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.2, green: 0.5, blue: 0.2).opacity(0.3))
                    .frame(width: fieldWidth, height: fieldHeight)
                    .position(x: offsetX + fieldWidth / 2, y: offsetY + fieldHeight / 2)

                // Field border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignSystem.Colors.primaryGreen.opacity(0.5), lineWidth: 2)
                    .frame(width: fieldWidth, height: fieldHeight)
                    .position(x: offsetX + fieldWidth / 2, y: offsetY + fieldHeight / 2)

                // Draw paths first (so they appear behind elements)
                if let paths = diagram.paths {
                    ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                        drawPath(path, scale: scale, offsetX: offsetX, offsetY: offsetY, fieldHeight: fieldHeight)
                    }
                }

                // Draw elements
                ForEach(diagram.elements) { element in
                    drawElement(element, scale: scale, offsetX: offsetX, offsetY: offsetY, fieldHeight: fieldHeight)
                }

                // Dimensions label
                Text("\(Int(diagram.field.width))m x \(Int(diagram.field.length))m")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 8)
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    // MARK: - Element Drawing

    @ViewBuilder
    private func drawElement(_ element: DiagramElement, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat, fieldHeight: CGFloat) -> some View {
        let x = offsetX + CGFloat(element.x) * scale
        // Flip Y axis (0,0 at bottom-left in data, but top-left in SwiftUI)
        let y = offsetY + fieldHeight - CGFloat(element.y) * scale

        switch element.elementType {
        case .cone:
            coneView(label: element.label)
                .position(x: x, y: y)

        case .player:
            playerView(label: element.label)
                .position(x: x, y: y)

        case .target:
            targetView(label: element.label)
                .position(x: x, y: y)

        case .goal:
            goalView(label: element.label)
                .position(x: x, y: y)

        case .ball:
            ballView()
                .position(x: x, y: y)
        }
    }

    private func coneView(label: String) -> some View {
        VStack(spacing: 2) {
            // Triangle cone
            ConeTriangle()
                .fill(DesignSystem.Colors.accentOrange)
                .frame(width: coneSize, height: coneSize)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    private func playerView(label: String) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(DesignSystem.Colors.secondaryBlue)
                .frame(width: playerSize, height: playerSize)
                .overlay(
                    Image(systemName: "figure.run")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private func targetView(label: String) -> some View {
        VStack(spacing: 2) {
            // Diamond shape for target/partner
            Rectangle()
                .fill(DesignSystem.Colors.primaryGreen)
                .frame(width: targetSize, height: targetSize)
                .rotationEffect(.degrees(45))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .offset(y: 4)
        }
    }

    private func goalView(label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(DesignSystem.Colors.textPrimary, lineWidth: 3)
                .frame(width: goalWidth, height: goalHeight)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.3))
                )

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private func ballView() -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }

    // MARK: - Path Drawing

    @ViewBuilder
    private func drawPath(_ path: DiagramPath, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat, fieldHeight: CGFloat) -> some View {
        let fromElement = diagram.elements.first { $0.label == path.from }
        let toElement = diagram.elements.first { $0.label == path.to }

        if let from = fromElement, let to = toElement {
            let fromX = offsetX + CGFloat(from.x) * scale
            let fromY = offsetY + fieldHeight - CGFloat(from.y) * scale
            let toX = offsetX + CGFloat(to.x) * scale
            let toY = offsetY + fieldHeight - CGFloat(to.y) * scale

            PathLine(from: CGPoint(x: fromX, y: fromY), to: CGPoint(x: toX, y: toY), style: path.pathStyle)
        }
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

struct PathLine: View {
    let from: CGPoint
    let to: CGPoint
    let style: DiagramPathStyle

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            // Draw the main line
            context.stroke(
                path,
                with: .color(lineColor),
                style: strokeStyle
            )

            // Draw arrowhead for passes
            if style == .pass {
                let arrowPath = arrowHead(from: from, to: to)
                context.fill(arrowPath, with: .color(lineColor))
            }
        }
    }

    private var lineColor: Color {
        switch style {
        case .dribble:
            return DesignSystem.Colors.secondaryBlue
        case .run:
            return DesignSystem.Colors.textSecondary
        case .pass:
            return DesignSystem.Colors.primaryGreen
        }
    }

    private var strokeStyle: StrokeStyle {
        switch style {
        case .dribble:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .run:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        case .pass:
            return StrokeStyle(lineWidth: 2, lineCap: .round)
        }
    }

    private func arrowHead(from: CGPoint, to: CGPoint) -> Path {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6  // 30 degrees

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
}

// MARK: - Preview

#Preview {
    let sampleDiagram = DrillDiagram(
        field: DiagramField(width: 20, length: 20),
        elements: [
            DiagramElement(type: "cone", x: 0, y: 0, label: "A"),
            DiagramElement(type: "cone", x: 0, y: 20, label: "B"),
            DiagramElement(type: "cone", x: 20, y: 20, label: "C"),
            DiagramElement(type: "player", x: 0, y: 0, label: "Start"),
            DiagramElement(type: "target", x: 20, y: 10, label: "Partner"),
            DiagramElement(type: "goal", x: 10, y: 20, label: "Goal")
        ],
        paths: [
            DiagramPath(from: "A", to: "B", style: "dribble"),
            DiagramPath(from: "B", to: "C", style: "run"),
            DiagramPath(from: "C", to: "Partner", style: "pass")
        ]
    )

    return VStack {
        Text("Drill Diagram")
            .font(.headline)

        DrillDiagramView(diagram: sampleDiagram)
            .frame(height: 250)
            .padding()
    }
    .background(Color.black)
}
