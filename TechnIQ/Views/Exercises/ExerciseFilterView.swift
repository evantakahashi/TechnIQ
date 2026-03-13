import SwiftUI

// MARK: - Filter Models

enum ExerciseDifficulty: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var difficultyValue: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }
}

enum ExerciseType: String, CaseIterable, Identifiable {
    case all = "All"
    case youtube = "YouTube"
    case aiGenerated = "AI-Generated"
    case manual = "Manual"
    case template = "Template"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .youtube: return "play.rectangle.fill"
        case .aiGenerated: return "brain.head.profile"
        case .manual: return "pencil.circle.fill"
        case .template: return "doc.text"
        }
    }
}

enum ExerciseSortOption: String, CaseIterable, Identifiable {
    case nameAZ = "Name (A-Z)"
    case nameZA = "Name (Z-A)"
    case difficultyLowHigh = "Difficulty (Low→High)"
    case difficultyHighLow = "Difficulty (High→Low)"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case mostUsed = "Most Used"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nameAZ: return "textformat.abc"
        case .nameZA: return "textformat.abc"
        case .difficultyLowHigh: return "arrow.up.right"
        case .difficultyHighLow: return "arrow.down.right"
        case .newestFirst: return "clock.fill"
        case .oldestFirst: return "clock"
        case .mostUsed: return "star.fill"
        }
    }
}

struct ExerciseFilterState: Equatable {
    var selectedDifficulties: Set<ExerciseDifficulty> = []
    var selectedType: ExerciseType = .all
    var selectedSkills: Set<String> = []
    var favoritesOnly: Bool = false
    var sortOption: ExerciseSortOption = .nameAZ

    var activeFilterCount: Int {
        var count = 0
        if !selectedDifficulties.isEmpty { count += 1 }
        if selectedType != .all { count += 1 }
        if !selectedSkills.isEmpty { count += 1 }
        if favoritesOnly { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        activeFilterCount > 0
    }

    mutating func reset() {
        selectedDifficulties = []
        selectedType = .all
        selectedSkills = []
        favoritesOnly = false
        sortOption = .nameAZ
    }
}

// MARK: - Filter View

struct ExerciseFilterView: View {
    @Binding var filterState: ExerciseFilterState
    let availableSkills: [String]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Difficulty Section
                    difficultySection

                    Divider()
                        .padding(.horizontal, DesignSystem.Spacing.md)

                    // Exercise Type Section
                    exerciseTypeSection

                    Divider()
                        .padding(.horizontal, DesignSystem.Spacing.md)

                    // Target Skills Section
                    if !availableSkills.isEmpty {
                        skillsSection

                        Divider()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                    }

                    // Favorites Toggle
                    favoritesSection

                    Divider()
                        .padding(.horizontal, DesignSystem.Spacing.md)

                    // Sort Options
                    sortSection

                    // Bottom padding
                    Spacer()
                        .frame(height: DesignSystem.Spacing.xl)
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
            .navigationTitle("Filter Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        withAnimation {
                            filterState.reset()
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .disabled(!filterState.hasActiveFilters)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Difficulty Section

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Difficulty")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(ExerciseDifficulty.allCases) { difficulty in
                    DifficultyChip(
                        difficulty: difficulty,
                        isSelected: filterState.selectedDifficulties.contains(difficulty)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if filterState.selectedDifficulties.contains(difficulty) {
                                filterState.selectedDifficulties.remove(difficulty)
                            } else {
                                filterState.selectedDifficulties.insert(difficulty)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Exercise Type Section

    private var exerciseTypeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Type")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(ExerciseType.allCases) { type in
                        TypeChip(
                            type: type,
                            isSelected: filterState.selectedType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filterState.selectedType = type
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Target Skills")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if !filterState.selectedSkills.isEmpty {
                    Text("(\(filterState.selectedSkills.count))")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 100), spacing: DesignSystem.Spacing.sm)
                ],
                spacing: DesignSystem.Spacing.sm
            ) {
                ForEach(availableSkills, id: \.self) { skill in
                    SkillChip(
                        skill: skill,
                        isSelected: filterState.selectedSkills.contains(skill)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if filterState.selectedSkills.contains(skill) {
                                filterState.selectedSkills.remove(skill)
                            } else {
                                filterState.selectedSkills.insert(skill)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Favorites Only")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Show only favorited exercises")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $filterState.favoritesOnly)
                .labelsHidden()
                .tint(DesignSystem.Colors.primaryGreen)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Sort By")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(ExerciseSortOption.allCases) { option in
                    SortOptionRow(
                        option: option,
                        isSelected: filterState.sortOption == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterState.sortOption = option
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Chip Components

struct DifficultyChip: View {
    let difficulty: ExerciseDifficulty
    let isSelected: Bool
    let onTap: () -> Void

    private var color: Color {
        switch difficulty {
        case .beginner: return DesignSystem.Colors.primaryGreen
        case .intermediate: return DesignSystem.Colors.accentOrange
        case .advanced: return .red
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(difficulty.rawValue)
                    .font(DesignSystem.Typography.bodySmall)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? color.opacity(0.15) : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? color : DesignSystem.Colors.textPrimary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TypeChip: View {
    let type: ExerciseType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)

                Text(type.rawValue)
                    .font(DesignSystem.Typography.bodySmall)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.15) : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primaryGreen : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textPrimary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SkillChip: View {
    let skill: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(skill)
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.15) : DesignSystem.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(isSelected ? DesignSystem.Colors.primaryGreen : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textPrimary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SortOptionRow: View {
    let option: ExerciseSortOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: option.icon)
                    .font(.body)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .frame(width: 24)

                Text(option.rawValue)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ExerciseFilterView(
        filterState: .constant(ExerciseFilterState()),
        availableSkills: ["Dribbling", "Passing", "Shooting", "Ball Control", "Speed", "Agility"],
        onApply: { }
    )
}
