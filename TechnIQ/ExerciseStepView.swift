import SwiftUI

struct ExerciseStepView: View {
    @ObservedObject var manager: ActiveSessionManager
    @State private var highlightedStep: Int? = 0

    private var exercise: Exercise? {
        manager.currentExercise
    }

    private var isAIDrill: Bool {
        exercise?.exerciseDescription?.contains("🤖 AI-Generated") == true
    }

    private var hasStructuredInstructions: Bool {
        guard let instructions = exercise?.instructions else { return false }
        return isAIDrill || instructions.contains("**Setup:**") || instructions.contains("**Instructions:**")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Exercise header
                exerciseHeader

                // Count-up timer
                timerSection

                // Drill diagram
                if let diagram = parseDiagram() {
                    diagramSection(diagram)
                }

                // Instructions
                if let instructions = exercise?.instructions, !instructions.isEmpty {
                    if hasStructuredInstructions {
                        richInstructionsSection(instructions)
                    } else {
                        simpleInstructionsSection(instructions)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        }

        // Done button pinned to bottom
        .safeAreaInset(edge: .bottom) {
            doneButton
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(exercise?.name ?? "Exercise")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                if let category = exercise?.category {
                    CategoryBadge(category: category)
                }

                if let difficulty = exercise?.difficulty, difficulty > 0 {
                    DifficultyStars(difficulty: Int(difficulty))
                }
            }
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Time")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(manager.formattedTime(manager.exerciseElapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Drill Diagram

    private func diagramSection(_ diagram: DrillDiagram) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                Text("Field Layout")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            DrillDiagramView(diagram: diagram)
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .fill(Color.gray.opacity(0.05))
                )
        }
    }

    // MARK: - Rich Instructions (AI / structured drills)

    private func richInstructionsSection(_ instructions: String) -> some View {
        DrillInstructionsView(instructions: filterMetadata(instructions))
    }

    // MARK: - Simple Instructions (plain text drills)

    private func simpleInstructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Instructions")
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            let steps = parseSteps(instructions)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(highlightedStep == index
                                  ? DesignSystem.Colors.primaryGreen
                                  : DesignSystem.Colors.neutral300)
                            .frame(width: 28, height: 28)

                        Text("\(index + 1)")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.bold)
                            .foregroundColor(highlightedStep == index ? .white : DesignSystem.Colors.textSecondary)
                    }

                    Text(step)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(highlightedStep == index
                                         ? DesignSystem.Colors.textPrimary
                                         : DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(DesignSystem.Animation.quick) {
                        highlightedStep = index
                    }
                    HapticManager.shared.lightTap()
                }
            }
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            manager.completeExercise()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Done")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignSystem.Colors.primaryGreen)
            .cornerRadius(DesignSystem.CornerRadius.button)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    // MARK: - Helpers

    private func parseDiagram() -> DrillDiagram? {
        guard let diagramJSON = exercise?.diagramJSON,
              let data = diagramJSON.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DrillDiagram.self, from: data)
    }

    /// Remove "Generated" and "Original Request" metadata sections from instructions
    private func filterMetadata(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var filtered: [String] = []
        var skipping = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect metadata section headers
            if trimmed.hasPrefix("**") && trimmed.contains(":**") {
                let header = trimmed.lowercased()
                if header.contains("generated") || header.contains("original request") {
                    skipping = true
                    continue
                } else {
                    skipping = false
                }
            }

            if !skipping {
                filtered.append(line)
            }
        }

        return filtered.joined(separator: "\n")
    }

    private func parseSteps(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var steps: [String] = []
        for line in lines {
            var cleaned = line
            if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[range.upperBound...])
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("• ") {
                cleaned = String(cleaned.dropFirst(2))
            }
            if cleaned.hasPrefix("**") && cleaned.hasSuffix("**") {
                continue
            }
            if !cleaned.isEmpty {
                steps.append(cleaned)
            }
        }

        return steps.isEmpty ? [text] : steps
    }
}
