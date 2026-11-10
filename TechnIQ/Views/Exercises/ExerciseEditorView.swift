import SwiftUI
import CoreData

// MARK: - Edit drill (Drill detail → Edit)
//
// Same form language as the manual creator: name, category, level, text, skills. Video drills are
// read-only. AI drills keep their provenance marker on save.

struct ExerciseEditorView: View {
    let exercise: Exercise
    let onSave: () -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // Editable fields
    @State private var name: String = ""
    @State private var exerciseDescription: String = ""
    @State private var category: String = "Technical"
    @State private var difficulty: Int = 2
    @State private var instructions: String = ""
    @State private var selectedSkills: Set<String> = []

    // UI State
    @State private var showingDeleteConfirmation = false
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    private let categories = ["Technical", "Physical", "Tactical", "Recovery"]

    private let availableSkills = [
        "Dribbling", "Passing", "Shooting", "Ball Control", "First Touch",
        "Speed", "Agility", "Strength", "Endurance", "Flexibility",
        "Positioning", "Decision Making", "Vision", "Communication", "Teamwork"
    ]

    // Check if exercise is read-only (YouTube content)
    private var isReadOnly: Bool {
        exercise.exerciseDescription?.contains("YouTube Video") == true
    }

    // Check if exercise is AI-generated
    private var isAIGenerated: Bool {
        exercise.drillSource == .ai
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                navBar

                if isReadOnly {
                    TQBanner(.info, message: "Video drills can't be edited.")
                }

                TQFormField("Name", text: $name, placeholder: "Drill name")
                    .disabled(isReadOnly)

                categorySection
                levelSection

                DrillFormTextArea(label: "Description", text: $exerciseDescription,
                                  placeholder: "What the drill is and why it helps", lines: 3...8)
                    .disabled(isReadOnly)

                if !isReadOnly || !instructions.isEmpty {
                    DrillFormTextArea(label: "Instructions", text: $instructions,
                                      placeholder: "Set-up, steps and coaching points", lines: 5...14)
                        .disabled(isReadOnly)
                }

                skillsSection

                if !isReadOnly && onDelete != nil {
                    TQButton("Delete drill", style: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            loadExerciseData()
        }
        .alert("Can't save yet", isPresented: $showingValidationError) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
        .confirmationDialog(
            "Delete this drill?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteExercise()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("It will be removed from your library for good.")
        }
    }

    // MARK: - Sections

    private var navBar: some View {
        TQNavBar(isReadOnly ? "Drill" : "Edit drill") {
            TQNavAction(isReadOnly ? "Close" : "Cancel") { dismiss() }
        } trailing: {
            if isReadOnly {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            } else {
                TQNavAction("Save") { saveChanges() }
                    .accessibilityIdentifier("drillEditor.save")
            }
        }
        .padding(.top, 8)
    }

    private var categorySection: some View {
        DrillFormGroup("Category") {
            DrillFormChips(options: categories, isSelected: { $0 == category }) { category = $0 }
        }
        .disabled(isReadOnly)
    }

    private var levelSection: some View {
        DrillFormGroup("Level") {
            TQSegment(
                options: ["Beginner", "Intermediate", "Advanced"],
                selection: Binding<Int?>(
                    get: { (1...3).contains(difficulty) ? difficulty - 1 : nil },
                    set: { if let index = $0 { difficulty = index + 1 } }
                )
            )
        }
        .disabled(isReadOnly)
    }

    private var skillsSection: some View {
        DrillFormGroup("Skills") {
            DrillFormChips(options: availableSkills, isSelected: { selectedSkills.contains($0) }) { skill in
                if selectedSkills.contains(skill) {
                    selectedSkills.remove(skill)
                } else {
                    selectedSkills.insert(skill)
                }
            }
        }
        .disabled(isReadOnly)
    }

    // MARK: - Data Management

    private func loadExerciseData() {
        name = exercise.name ?? ""
        exerciseDescription = cleanDescription(exercise.exerciseDescription ?? "")
        category = exercise.category ?? "Technical"
        difficulty = Int(exercise.difficulty)
        instructions = exercise.instructions ?? ""
        selectedSkills = Set(exercise.targetSkills ?? [])
    }

    private func cleanDescription(_ description: String) -> String {
        // Remove AI/YouTube markers for editing (handle both new and legacy emoji markers)
        var cleaned = description
        if cleaned.hasPrefix("[AI-Generated Custom Drill]") ||
           cleaned.hasPrefix("🤖 AI-Generated Custom Drill") {
            if let range = cleaned.range(of: "\n\n") {
                cleaned = String(cleaned[range.upperBound...])
            }
        }
        return cleaned
    }

    private func saveChanges() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Give the drill a name."
            showingValidationError = true
            return
        }

        guard name.count >= 3 else {
            validationMessage = "The name needs at least 3 characters."
            showingValidationError = true
            return
        }

        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.category = category
        exercise.difficulty = Int16(difficulty)
        exercise.targetSkills = Array(selectedSkills)

        // Preserve AI marker if present
        if isAIGenerated {
            exercise.exerciseDescription = "[AI-Generated Custom Drill]\n\n\(exerciseDescription)"
        } else {
            exercise.exerciseDescription = exerciseDescription
        }

        exercise.instructions = instructions

        do {
            try viewContext.save()
            onSave()
            dismiss()
        } catch {
            validationMessage = "Couldn't save your changes: \(error.localizedDescription)"
            showingValidationError = true
        }
    }

    private func deleteExercise() {
        CoreDataManager.shared.deleteExercise(exercise)
        onDelete?()
        dismiss()
    }
}

// MARK: - Shared drill-form pieces (manual creator, editor, share plan)

/// Condensed group header over a block of form content.
struct DrillFormGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TQGroupHeader(title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wrapping chips for a single- or multi-choice field.
struct DrillFormChips: View {
    let options: [String]
    let isSelected: (String) -> Bool
    let onTap: (String) -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { option in
                TQChip(option, isSelected: isSelected(option)) { onTap(option) }
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Multi-line text field with the TQFormField look.
struct DrillFormTextArea: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var lines: ClosedRange<Int> = 3...6
    /// Shows "n / limit" under the field when set.
    var limit: Int?

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                .textCase(.uppercase)
                .tracking(DesignSystem.Typography.Tracking.eyebrow)
                .foregroundColor(DesignSystem.Colors.dimIvory)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(lines)
                .font(Font.system(size: 16, weight: .regular))
                .foregroundColor(isEnabled ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.dimIvory)
                .tint(DesignSystem.Colors.grass)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                        .strokeBorder(isFocused ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight, lineWidth: 1)
                )
                .accessibilityLabel(label)
            if let limit {
                Text("\(text.count) / \(limit)")
                    .font(Font.system(size: 12, weight: .regular).monospacedDigit())
                    .foregroundColor(text.count > limit ? DesignSystem.Colors.error : DesignSystem.Colors.dimIvory)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let context = CoreDataManager.shared.context
    let exercise = Exercise(context: context)
    exercise.name = "Sample Exercise"
    exercise.category = "Technical"
    exercise.difficulty = 2
    exercise.exerciseDescription = "A sample exercise for testing"
    exercise.instructions = "1. Do this\n2. Then that"
    exercise.targetSkills = ["Dribbling", "Ball Control"]

    return ExerciseEditorView(
        exercise: exercise,
        onSave: { },
        onDelete: { }
    )
    .environment(\.managedObjectContext, context)
}
#endif
