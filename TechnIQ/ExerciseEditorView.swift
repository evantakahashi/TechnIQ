import SwiftUI
import CoreData

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

    // Available categories
    private let categories = ["Technical", "Physical", "Tactical", "Recovery"]

    // Available skills
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
        exercise.exerciseDescription?.contains("AI-Generated Custom Drill") == true
    }

    var body: some View {
        NavigationView {
            Form {
                // Read-only notice for YouTube exercises
                if isReadOnly {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(DesignSystem.Colors.secondaryBlue)
                            Text("YouTube exercises cannot be edited")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                // Basic Info Section
                Section(header: Text("Basic Information")) {
                    TextField("Exercise Name", text: $name)
                        .disabled(isReadOnly)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .disabled(isReadOnly)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { level in
                                DifficultyOption(
                                    level: level,
                                    isSelected: difficulty == level,
                                    isDisabled: isReadOnly
                                ) {
                                    if !isReadOnly {
                                        difficulty = level
                                    }
                                }
                            }
                        }
                    }
                }

                // Description Section
                Section(header: Text("Description")) {
                    TextEditor(text: $exerciseDescription)
                        .frame(minHeight: 80)
                        .disabled(isReadOnly)
                }

                // Instructions Section (for non-YouTube exercises)
                if !isReadOnly || !instructions.isEmpty {
                    Section(header: Text("Instructions")) {
                        TextEditor(text: $instructions)
                            .frame(minHeight: 120)
                            .disabled(isReadOnly)

                        if isAIGenerated {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                                Text("AI-generated instructions can be customized")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                // Target Skills Section
                Section(header: Text("Target Skills")) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 100), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(availableSkills, id: \.self) { skill in
                            SkillToggleChip(
                                skill: skill,
                                isSelected: selectedSkills.contains(skill),
                                isDisabled: isReadOnly
                            ) {
                                if !isReadOnly {
                                    if selectedSkills.contains(skill) {
                                        selectedSkills.remove(skill)
                                    } else {
                                        selectedSkills.insert(skill)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Delete Section (only for non-YouTube exercises)
                if !isReadOnly && onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Exercise")
                                Spacer()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(isReadOnly ? "View Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !isReadOnly {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                loadExerciseData()
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
            .confirmationDialog(
                "Delete Exercise?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteExercise()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone. The exercise will be permanently removed.")
            }
        }
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
        // Remove AI/YouTube markers for editing
        var cleaned = description
        if cleaned.hasPrefix("🤖 AI-Generated Custom Drill") {
            if let range = cleaned.range(of: "\n\n") {
                cleaned = String(cleaned[range.upperBound...])
            }
        }
        return cleaned
    }

    private func saveChanges() {
        // Validation
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please enter an exercise name"
            showingValidationError = true
            return
        }

        guard name.count >= 3 else {
            validationMessage = "Exercise name must be at least 3 characters"
            showingValidationError = true
            return
        }

        // Update exercise
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.category = category
        exercise.difficulty = Int16(difficulty)
        exercise.targetSkills = Array(selectedSkills)

        // Preserve AI marker if present
        if isAIGenerated {
            exercise.exerciseDescription = "🤖 AI-Generated Custom Drill\n\n\(exerciseDescription)"
        } else {
            exercise.exerciseDescription = exerciseDescription
        }

        exercise.instructions = instructions

        // Save context
        do {
            try viewContext.save()
            onSave()
            dismiss()
        } catch {
            validationMessage = "Failed to save changes: \(error.localizedDescription)"
            showingValidationError = true
        }
    }

    private func deleteExercise() {
        CoreDataManager.shared.deleteExercise(exercise)
        onDelete?()
        dismiss()
    }
}

// MARK: - Difficulty Option

struct DifficultyOption: View {
    let level: Int
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    private var color: Color {
        switch level {
        case 1: return DesignSystem.Colors.primaryGreen
        case 2: return DesignSystem.Colors.accentOrange
        default: return .red
        }
    }

    private var label: String {
        switch level {
        case 1: return "Beginner"
        case 2: return "Intermediate"
        default: return "Advanced"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(1...3, id: \.self) { dot in
                        Circle()
                            .fill(dot <= level ? color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Text(label)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(isSelected ? color : DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(isSelected ? color.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Skill Toggle Chip

struct SkillToggleChip: View {
    let skill: String
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(skill)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.15) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(isSelected ? DesignSystem.Colors.primaryGreen : Color.clear, lineWidth: 1)
                )
                .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Preview

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
