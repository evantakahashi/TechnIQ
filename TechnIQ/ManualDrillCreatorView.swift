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

    // Available skills for selection
    private let availableSkills = [
        "Ball Control", "Dribbling", "Passing", "Shooting", "First Touch",
        "Speed", "Agility", "Endurance", "Strength", "Coordination",
        "Positioning", "Vision", "Decision Making", "Game Awareness", "Teamwork"
    ]

    private var isValid: Bool {
        !drillName.isEmpty && drillName.count >= 3 &&
        !drillDescription.isEmpty && drillDescription.count >= 10
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        headerSection
                        nameSection
                        descriptionSection
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
        exercise.exerciseDescription = drillDescription
        exercise.category = selectedCategory.rawValue
        exercise.difficulty = Int16(selectedDifficulty.numericValue)
        exercise.targetSkills = Array(selectedSkills)
        exercise.isYouTubeContent = false

        // Link to player
        exercise.player = player

        do {
            try viewContext.save()
            showingSuccessMessage = true
        } catch {
            print("Failed to save drill: \(error)")
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
