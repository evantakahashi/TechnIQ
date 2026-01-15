import SwiftUI
import CoreData

struct ManualDrillCreatorView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var drillName = ""
    @State private var drillDescription = ""
    @State private var selectedCategory: DrillCategory = .technical
    @State private var selectedDifficulty: DifficultyLevel = .beginner
    @State private var duration = 30
    @State private var selectedSkills: Set<String> = []
    @State private var showingSuccessMessage = false

    // Phase 6: Structured sections
    @State private var useStructuredMode = false
    @State private var setupRequirements = ""
    @State private var instructionSteps: [String] = [""]
    @State private var coachingPoints: [String] = [""]
    @State private var progressions: [String] = [""]
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var showingPreview = false

    // Available skills for selection
    private let availableSkills = [
        "Ball Control", "Dribbling", "Passing", "Shooting", "First Touch",
        "Speed", "Agility", "Endurance", "Strength", "Coordination",
        "Positioning", "Vision", "Decision Making", "Game Awareness", "Teamwork"
    ]

    private var isValid: Bool {
        if useStructuredMode {
            return !drillName.isEmpty && drillName.count >= 3 &&
                   !setupRequirements.isEmpty &&
                   instructionSteps.contains(where: { !$0.isEmpty })
        } else {
            return !drillName.isEmpty && drillName.count >= 3 &&
                   !drillDescription.isEmpty && drillDescription.count >= 10
        }
    }

    // Generate formatted instructions from structured sections
    private var formattedInstructions: String {
        var output = ""

        // Setup section
        if !setupRequirements.isEmpty {
            output += "**Setup:**\n\(setupRequirements)\n"
            if !selectedEquipment.isEmpty {
                let equipmentNames = selectedEquipment.map { $0.displayName.components(separatedBy: " ").dropFirst().joined(separator: " ") }.sorted()
                output += "Equipment: \(equipmentNames.joined(separator: ", "))\n"
            }
            output += "\n"
        }

        // Instructions section
        let validSteps = instructionSteps.filter { !$0.isEmpty }
        if !validSteps.isEmpty {
            output += "**Instructions:**\n"
            for (index, step) in validSteps.enumerated() {
                output += "\(index + 1). \(step)\n"
            }
            output += "\n"
        }

        // Coaching points section
        let validPoints = coachingPoints.filter { !$0.isEmpty }
        if !validPoints.isEmpty {
            output += "**Coaching Points:**\n"
            for point in validPoints {
                output += "• \(point)\n"
            }
            output += "\n"
        }

        // Progressions section
        let validProgressions = progressions.filter { !$0.isEmpty }
        if !validProgressions.isEmpty {
            output += "**Progressions:**\n"
            for progression in validProgressions {
                output += "• \(progression)\n"
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        headerSection
                        modeToggleSection
                        nameSection

                        if useStructuredMode {
                            setupSection
                            equipmentSection
                            instructionsSection
                            coachingPointsSection
                            progressionsSection
                            previewButton
                        } else {
                            descriptionSection
                        }

                        categorySection
                        difficultySection
                        durationSection
                        skillsSection
                        createButton
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .navigationTitle("Manual Drill")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDrill()
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Drill Created!", isPresented: $showingSuccessMessage) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your drill has been added to your exercise library!")
        }
        .sheet(isPresented: $showingPreview) {
            DrillPreviewSheet(
                drillName: drillName,
                instructions: formattedInstructions,
                onDismiss: { showingPreview = false }
            )
        }
    }

    // MARK: - Mode Toggle Section

    private var modeToggleSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Structured Mode")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Create drills with organized sections like AI-generated drills")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $useStructuredMode)
                        .labelsHidden()
                        .tint(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                Text("Setup Requirements")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("Describe the setup area, cone placements, etc.", text: $setupRequirements, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Equipment Section

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sportscourt")
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)
                Text("Equipment (Optional)")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                ForEach(Equipment.allCases.filter { $0 != .none }, id: \.self) { equipment in
                    EquipmentSelectionCard(
                        equipment: equipment,
                        isSelected: selectedEquipment.contains(equipment)
                    ) {
                        if selectedEquipment.contains(equipment) {
                            selectedEquipment.remove(equipment)
                        } else {
                            selectedEquipment.insert(equipment)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundColor(DesignSystem.Colors.accentOrange)
                Text("Step-by-Step Instructions")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(instructionSteps.indices, id: \.self) { index in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accentOrange.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.accentOrange)
                        }

                        ModernCard {
                            TextField("Enter step \(index + 1)...", text: $instructionSteps[index])
                                .font(DesignSystem.Typography.bodyMedium)
                                .textFieldStyle(.plain)
                                .padding(DesignSystem.Spacing.sm)
                        }

                        if instructionSteps.count > 1 {
                            Button {
                                instructionSteps.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                    }
                }

                Button {
                    instructionSteps.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Step")
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Coaching Points Section

    private var coachingPointsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Coaching Points (Optional)")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(coachingPoints.indices, id: \.self) { index in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)

                        ModernCard {
                            TextField("Enter coaching tip...", text: $coachingPoints[index])
                                .font(DesignSystem.Typography.bodyMedium)
                                .textFieldStyle(.plain)
                                .padding(DesignSystem.Spacing.sm)
                        }

                        if coachingPoints.count > 1 {
                            Button {
                                coachingPoints.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                    }
                }

                Button {
                    coachingPoints.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Coaching Point")
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Progressions Section

    private var progressionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.purple)
                Text("Progressions/Variations (Optional)")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(progressions.indices, id: \.self) { index in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 8, height: 8)

                        ModernCard {
                            TextField("e.g., Harder: Add defender pressure", text: $progressions[index])
                                .font(DesignSystem.Typography.bodyMedium)
                                .textFieldStyle(.plain)
                                .padding(DesignSystem.Spacing.sm)
                        }

                        if progressions.count > 1 {
                            Button {
                                progressions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                    }
                }

                Button {
                    progressions.append("")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Progression")
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Preview Button

    private var previewButton: some View {
        Button {
            showingPreview = true
        } label: {
            HStack {
                Image(systemName: "eye")
                Text("Preview Formatted Drill")
            }
            .font(DesignSystem.Typography.bodyMedium)
            .fontWeight(.medium)
            .foregroundColor(DesignSystem.Colors.secondaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.secondaryBlue, lineWidth: 1.5)
            )
        }
        .disabled(!isValid)
        .opacity(isValid ? 1.0 : 0.5)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Create Your Own Drill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Manually design a custom drill with your own specifications.")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Drill Name")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("e.g., Cone Dribbling Circuit", text: $drillName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .textFieldStyle(.plain)

                    HStack {
                        Spacer()
                        Text("\(drillName.count)/50")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(drillName.count >= 3 ?
                                           DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }

            if !drillName.isEmpty && drillName.count < 3 {
                Text("Name must be at least 3 characters")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Description")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("Describe the drill, setup, and execution...", text: $drillDescription, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .lineLimit(4...8)
                        .textFieldStyle(.plain)

                    HStack {
                        Spacer()
                        Text("\(drillDescription.count)/500")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(drillDescription.count >= 10 ?
                                           DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }

            if !drillDescription.isEmpty && drillDescription.count < 10 {
                Text("Description must be at least 10 characters")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Category")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                ForEach(DrillCategory.allCases, id: \.self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - Difficulty Section

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Difficulty Level")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                    DifficultySelectionCard(
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty
                    ) {
                        selectedDifficulty = difficulty
                    }
                }
            }
        }
    }

    // MARK: - Duration Section

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Duration: \(duration) minutes")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Slider(value: Binding(
                        get: { Double(duration) },
                        set: { duration = Int($0) }
                    ), in: 10...120, step: 5)
                    .accentColor(DesignSystem.Colors.primaryGreen)

                    HStack {
                        Text("10 min")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("120 min")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Target Skills (Optional)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                ForEach(availableSkills, id: \.self) { skill in
                    SkillSelectionCard(
                        skill: skill,
                        isSelected: selectedSkills.contains(skill)
                    ) {
                        if selectedSkills.contains(skill) {
                            selectedSkills.remove(skill)
                        } else {
                            selectedSkills.insert(skill)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        ModernButton(
            "Create Drill",
            icon: "checkmark.circle.fill",
            style: .primary
        ) {
            saveDrill()
        }
        .disabled(!isValid)
        .opacity(isValid ? 1.0 : 0.6)
    }

    // MARK: - Actions

    private func saveDrill() {
        let exercise = Exercise(context: viewContext)
        exercise.id = UUID()
        exercise.name = drillName
        exercise.category = selectedCategory.rawValue
        exercise.difficulty = Int16(selectedDifficulty.numericValue)
        exercise.targetSkills = Array(selectedSkills)
        exercise.isYouTubeContent = false

        if useStructuredMode {
            // Use formatted instructions for structured mode
            exercise.exerciseDescription = "Manual Drill"
            exercise.instructions = formattedInstructions
        } else {
            // Simple mode - use description directly
            exercise.exerciseDescription = drillDescription
            exercise.instructions = nil
        }

        // Link to player
        exercise.player = player

        do {
            try viewContext.save()
            showingSuccessMessage = true
        } catch {
            #if DEBUG
            print("Failed to save drill: \(error)")
            #endif
        }
    }
}

// MARK: - Drill Preview Sheet

struct DrillPreviewSheet: View {
    let drillName: String
    let instructions: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(drillName)
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Preview how your drill will appear")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)

                    // Formatted Instructions
                    DrillInstructionsView(instructions: instructions)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .adaptiveBackground()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }
}

// MARK: - Skill Selection Card

struct SkillSelectionCard: View {
    let skill: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.xs) {
                Text(skill)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return ManualDrillCreatorView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}
