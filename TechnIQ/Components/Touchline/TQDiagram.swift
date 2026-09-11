import SwiftUI

// MARK: - TQDiagram
//
// Drill diagram on a pitch surface (220 pt): chalk players, cone triangles, chalk goals and walls,
// grass dashed pass lines — rendered by AnimatedDrillDiagramView with `chrome: false`. Overlays:
// legend top-left, dimensions bottom-right, Animate chip bottom-left. Same DiagramElement model.

struct TQDiagram: View {
    let diagram: DrillDiagram
    var steps: [String] = []
    var height: CGFloat = 220
    var animatable: Bool = true
    /// Phase-timeline film (server-authored). When present, the chip becomes
    /// "Watch" and swaps the pitch for the animated player inline.
    var animationJSON: String? = nil

    @State private var currentStep: Int? = nil
    @State private var isAutoPlaying = false
    @State private var showFilm = false

    private var filmJSON: String? {
        DrillWebAnimationView.composedJSON(diagram: diagram,
                                           animationJSON: animationJSON)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showFilm, let film = filmJSON {
                DrillWebAnimationView(drillJSON: film)
                    .frame(height: height + 150)
                    .accessibilityLabel("Animated drill film")
            } else {
                AnimatedDrillDiagramView(
                    diagram: diagram,
                    instructions: steps,
                    currentStep: $currentStep,
                    isAutoPlaying: $isAutoPlaying,
                    chrome: false
                )
                .frame(height: height)

                legend
                    .padding(.leading, 12)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: showFilm && filmJSON != nil ? height + 150 : height)
        .overlay(alignment: .bottomTrailing) {
            Text("\(Int(diagram.field.width)) × \(Int(diagram.field.length)) M")
                .font(Font.system(size: 11, weight: .regular).width(.condensed))
                .tracking(0.7)
                .foregroundColor(DesignSystem.Colors.textOnPitch)
                .padding(.trailing, 12)
                .padding(.bottom, 10)
                .accessibilityLabel("\(Int(diagram.field.width)) by \(Int(diagram.field.length)) metres")
        }
        .overlay(alignment: .bottomLeading) {
            if animatable, hasSteps || filmJSON != nil {
                Button {
                    HapticManager.shared.selectionChanged()
                    if filmJSON != nil {
                        withAnimation(.easeInOut(duration: 0.2)) { showFilm.toggle() }
                    } else {
                        toggleAnimation()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filmJSON != nil
                              ? (showFilm ? "stop.fill" : "play.circle.fill")
                              : (isAutoPlaying ? "stop.fill" : "play.fill"))
                            .font(.system(size: 9, weight: .bold))
                        Text(filmJSON != nil ? (showFilm ? "Close" : "Watch")
                             : (isAutoPlaying ? "Stop" : "Animate"))
                            .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                            .textCase(.uppercase)
                            .tracking(0.7)
                    }
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(DesignSystem.Colors.surfaceBase.opacity(0.5))
                    )
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.bottom, 10)
                .accessibilityLabel(isAutoPlaying ? "Stop animation" : "Animate the drill")
            }
        }
        .background(DesignSystem.Colors.pitch)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pitchCardCompact, style: .continuous))
    }

    private var hasSteps: Bool {
        let stepCount = Set((diagram.paths ?? []).filter { $0.reset != true && $0.alt != true }.compactMap { $0.step }).count
        return max(stepCount, steps.count) > 0
    }

    private func toggleAnimation() {
        if isAutoPlaying {
            isAutoPlaying = false
            currentStep = nil
        } else {
            currentStep = 1
            isAutoPlaying = true
        }
    }

    // MARK: Legend

    private var legend: some View {
        let types = Set(diagram.elements.map { $0.elementType })
        return HStack(spacing: 10) {
            if types.contains(.player) { legendItem(label: "You") { Circle().fill(DesignSystem.Colors.chalkWhite).frame(width: 8, height: 8) } }
            if types.contains(.defender) { legendItem(label: "Defender") { Circle().fill(DesignSystem.Colors.error).frame(width: 8, height: 8) } }
            if types.contains(.server) { legendItem(label: "Server") { Circle().fill(DesignSystem.Colors.grass).frame(width: 8, height: 8) } }
            if types.contains(.cone) || types.contains(.gate) { legendItem(label: "Cone") { ConeTriangle().fill(DesignSystem.Colors.cone).frame(width: 8, height: 8) } }
            if types.contains(.wall) { legendItem(label: "Wall") { Rectangle().fill(DesignSystem.Colors.chalkWhite).frame(width: 8, height: 3) } }
            if types.contains(.goal) { legendItem(label: "Goal") { Rectangle().fill(DesignSystem.Colors.chalkWhite).frame(width: 8, height: 3) } }
        }
        .accessibilityHidden(true)
    }

    private func legendItem<Swatch: View>(label: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 4) {
            swatch()
            Text(label)
                .font(Font.system(size: 11, weight: .regular).width(.condensed))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundColor(DesignSystem.Colors.textOnPitch)
        }
    }
}
