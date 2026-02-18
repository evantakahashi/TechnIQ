import SwiftUI
import UIKit

// MARK: - Drill Walkthrough View

/// Active training drill walkthrough with three phases: preview → perform → rate.
/// Used during training when a drill has a diagram.
struct DrillWalkthroughView: View {
    let exercise: Exercise
    var onComplete: ((Int, String, String) -> Void)? // (qualityRating, difficultyFeedback, notes)

    enum Phase { case preview, perform, rate }

    @State private var phase: Phase = .preview
    @State private var currentStep: Int? = 1
    @State private var isAutoPlaying: Bool = true
    @State private var playbackSpeed: Double = 1.0
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var allStepsCompleted: Bool = false

    // Rating state
    @State private var difficultyFeedback: String = "just_right"
    @State private var qualityRating: Int = 3
    @State private var feedbackNotes: String = ""

    // MARK: - Computed Properties

    private var parsedDiagram: DrillDiagram? {
        guard let json = exercise.diagramJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DrillDiagram.self, from: data)
    }

    private var parsedInstructions: [String] {
        guard let raw = exercise.instructions else { return [] }
        return raw
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil else {
                    return nil
                }
                // Strip the number prefix (e.g., "1. " or "12. ")
                if let dotRange = trimmed.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                    return String(trimmed[dotRange.upperBound...])
                }
                return trimmed
            }
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignSystem.Colors.surfaceBase
                .ignoresSafeArea()

            switch phase {
            case .preview:
                previewPhase
            case .perform:
                performPhase
            case .rate:
                ratePhase
            }
        }
        .animation(DesignSystem.Animation.smooth, value: phase)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Preview Phase

    private var previewPhase: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(exercise.name ?? "Drill")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Watch the drill play through, then tap Ready")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Diagram
            if let diagram = parsedDiagram {
                AnimatedDrillDiagramView(
                    diagram: diagram,
                    instructions: parsedInstructions,
                    currentStep: $currentStep,
                    isAutoPlaying: $isAutoPlaying,
                    playbackSpeed: playbackSpeed,
                    isTrainingMode: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DesignSystem.Spacing.md)
            } else {
                Spacer()
                Text("No diagram available")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
            }

            // Ready button
            Button {
                transitionToPerform()
            } label: {
                Text("Ready")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Perform Phase

    private var performPhase: some View {
        VStack(spacing: 0) {
            // Top bar with timer
            HStack {
                Text(exercise.name ?? "Drill")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                // Timer
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(DesignSystem.Typography.labelMedium)
                    Text(formattedTime)
                        .font(DesignSystem.Typography.numberMedium)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Diagram in training mode
            if let diagram = parsedDiagram {
                AnimatedDrillDiagramView(
                    diagram: diagram,
                    instructions: parsedInstructions,
                    currentStep: $currentStep,
                    isAutoPlaying: $isAutoPlaying,
                    playbackSpeed: playbackSpeed,
                    isTrainingMode: true,
                    onStepCompleted: { step in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if step >= parsedInstructions.count {
                            allStepsCompleted = true
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DesignSystem.Spacing.md)
            } else {
                Spacer()
            }

            // Complete button (shown when all steps done)
            if allStepsCompleted {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    transitionToRate()
                } label: {
                    Text("Complete Drill")
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundColor(DesignSystem.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Rate Phase

    private var ratePhase: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                Text("How was this drill?")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xl)

                // Elapsed time
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Time")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(formattedTime)
                        .font(DesignSystem.Typography.numberMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.surfaceRaised)
                .cornerRadius(DesignSystem.CornerRadius.md)

                // Difficulty picker
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Difficulty")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        difficultyButton(
                            label: "Too Easy",
                            icon: "chevron.down",
                            value: "too_easy"
                        )
                        difficultyButton(
                            label: "Just Right",
                            icon: "checkmark",
                            value: "just_right"
                        )
                        difficultyButton(
                            label: "Too Hard",
                            icon: "chevron.up",
                            value: "too_hard"
                        )
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceRaised)
                .cornerRadius(DesignSystem.CornerRadius.md)

                // Quality rating
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Quality")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                qualityRating = star
                            } label: {
                                Image(systemName: star <= qualityRating ? "star.fill" : "star")
                                    .font(.system(size: 28))
                                    .foregroundColor(
                                        star <= qualityRating
                                            ? DesignSystem.Colors.primaryGreen
                                            : DesignSystem.Colors.textSecondary.opacity(0.4)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceRaised)
                .cornerRadius(DesignSystem.CornerRadius.md)

                // Notes
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Notes")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Any notes?", text: $feedbackNotes, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2...4)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceBase)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceRaised)
                .cornerRadius(DesignSystem.CornerRadius.md)

                // Done button
                Button {
                    onComplete?(qualityRating, difficultyFeedback, feedbackNotes)
                } label: {
                    Text("Done")
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundColor(DesignSystem.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Subviews

    private func difficultyButton(label: String, icon: String, value: String) -> some View {
        Button {
            difficultyFeedback = value
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.labelLarge)
                Text(label)
                    .font(DesignSystem.Typography.labelMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .foregroundColor(
                difficultyFeedback == value
                    ? DesignSystem.Colors.textOnAccent
                    : DesignSystem.Colors.textSecondary
            )
            .background(
                difficultyFeedback == value
                    ? DesignSystem.Colors.primaryGreen
                    : DesignSystem.Colors.surfaceBase
            )
            .cornerRadius(DesignSystem.CornerRadius.sm)
        }
    }

    // MARK: - Phase Transitions

    private func transitionToPerform() {
        currentStep = 1
        isAutoPlaying = false
        elapsedSeconds = 0
        allStepsCompleted = false
        phase = .perform
        startTimer()
    }

    private func transitionToRate() {
        stopTimer()
        phase = .rate
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
