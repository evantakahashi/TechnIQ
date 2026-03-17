import SwiftUI
import CoreData

struct ExerciseDetail {
    var duration: Double = 10.0
    var sets: Int = 1
    var reps: Int = 10
    var rating: Int = 3
    var notes: String = ""
}

struct ModernExerciseRowView: View {
    let exercise: Exercise
    @Binding var detail: ExerciseDetail
    let onRemove: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Exercise Header
            HStack(spacing: DesignSystem.Spacing.md) {
                // Exercise Icon and Info
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: exerciseIcon)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(exercise.name ?? "Exercise")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(exercise.category ?? "General")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.primaryGreen.opacity(0.8))
                                .cornerRadius(DesignSystem.CornerRadius.xs)

                            Text("Level \(exercise.difficulty)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.warning.opacity(0.8))
                                .cornerRadius(DesignSystem.CornerRadius.xs)
                        }
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Button(action: onRemove) {
                        Image(systemName: "trash.circle.fill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.error.opacity(0.7))
                    }
                    .pressAnimation()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen.opacity(0.7))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .pressAnimation()
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.background)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .customShadow(DesignSystem.Shadow.small)

            // Expanded Details Section
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Duration Control
                    modernControlSection(
                        title: "Duration",
                        value: "\(Int(detail.duration)) min",
                        content: {
                            Slider(value: $detail.duration, in: 5...60, step: 5)
                                .tint(DesignSystem.Colors.primaryGreen)
                        }
                    )

                    // Sets and Reps Controls
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        // Sets Control
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Sets")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Spacer()

                                Text("\(detail.sets)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }

                            Slider(value: Binding(
                                get: { Double(detail.sets) },
                                set: { detail.sets = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(DesignSystem.Colors.primaryGreen)
                        }

                        // Reps Control
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Reps")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Spacer()

                                Text("\(detail.reps)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }

                            Slider(value: Binding(
                                get: { Double(detail.reps) },
                                set: { detail.reps = Int($0) }
                            ), in: 1...50, step: 1)
                            .tint(DesignSystem.Colors.primaryGreen)
                        }
                    }

                    // Performance Rating
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Performance")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Spacer()

                            Text(performanceDescription(for: detail.rating))
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        detail.rating = rating
                                    }
                                }) {
                                    Image(systemName: rating <= detail.rating ? "star.fill" : "star")
                                        .font(DesignSystem.Typography.titleMedium)
                                        .foregroundColor(
                                            rating <= detail.rating
                                                ? DesignSystem.Colors.warning
                                                : DesignSystem.Colors.neutral300
                                        )
                                        .scaleEffect(rating <= detail.rating ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: detail.rating)
                                }
                                .pressAnimation()
                            }
                            Spacer()
                        }
                    }

                    // Notes Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Exercise Notes")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        ModernTextField(
                            "Notes",
                            text: $detail.notes,
                            placeholder: "Add notes about this exercise...",
                            icon: "note.text"
                        )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.primaryGreen.opacity(0.05))
                .cornerRadius(DesignSystem.CornerRadius.md)
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }

    private var exerciseIcon: String {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return "target"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        default: return "soccerball"
        }
    }

    private func performanceDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "Good"
        }
    }

    @ViewBuilder
    private func modernControlSection<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(value)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }

            content()
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExercises: [Exercise]
    let availableExercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategory = "All"

    var categories: [String] {
        let allCategories = Set(availableExercises.compactMap { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }

    var filteredExercises: [Exercise] {
        var exercises = availableExercises

        if selectedCategory != "All" {
            exercises = exercises.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter {
                $0.name?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return exercises
    }

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.md) {
                    // Modern Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }) {
                                    Text(category)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                        .background(
                                            selectedCategory == category
                                                ? DesignSystem.Colors.primaryGreen
                                                : DesignSystem.Colors.background
                                        )
                                        .cornerRadius(DesignSystem.CornerRadius.lg)
                                        .customShadow(selectedCategory == category ? DesignSystem.Shadow.medium : DesignSystem.Shadow.small)
                                }
                                .pressAnimation()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    }

                    // Search Bar
                    HStack {
                        ModernTextField(
                            "Search",
                            text: $searchText,
                            placeholder: "Search exercises...",
                            icon: "magnifyingglass"
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)

                    // Exercise List
                    if filteredExercises.isEmpty {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(DesignSystem.Colors.neutral400)

                            Text("No exercises found")
                                .font(DesignSystem.Typography.titleMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            if !searchText.isEmpty {
                                Text("Try adjusting your search")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(filteredExercises, id: \.objectID) { exercise in
                                    ModernExercisePickerRow(
                                        exercise: exercise,
                                        isSelected: selectedExercises.contains { $0.objectID == exercise.objectID }
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedExercises.contains(where: { $0.objectID == exercise.objectID }) {
                                                selectedExercises.removeAll { $0.objectID == exercise.objectID }
                                            } else {
                                                selectedExercises.append(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                            .padding(.bottom, DesignSystem.Spacing.xl)
                        }
                    }
                }
            }
            .navigationTitle("Choose Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }
}

struct ModernExercisePickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Exercise Icon
            ZStack {
                Circle()
                    .fill(exerciseColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: exerciseIcon)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(exerciseColor)
            }

            // Exercise Details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(exercise.name ?? "Exercise")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                if let description = exercise.exerciseDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                // Tags
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(exercise.category ?? "General")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(exerciseColor.opacity(0.8))
                        .cornerRadius(DesignSystem.CornerRadius.xs)

                    Text("Level \(exercise.difficulty)")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.8))
                        .cornerRadius(DesignSystem.CornerRadius.xs)

                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        Text("\(skills.count) skills")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.neutral200)
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }
                }
            }

            Spacer()

            // Selection Button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? DesignSystem.Colors.primaryGreen
                                : DesignSystem.Colors.background
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                        ? DesignSystem.Colors.primaryGreen
                                        : DesignSystem.Colors.neutral300,
                                    lineWidth: 2
                                )
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .pressAnimation()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .customShadow(isSelected ? DesignSystem.Shadow.medium : DesignSystem.Shadow.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(
                    isSelected
                        ? DesignSystem.Colors.primaryGreen.opacity(0.3)
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private var exerciseIcon: String {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return "target"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        default: return "soccerball"
        }
    }

    private var exerciseColor: Color {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.error
        case "tactical": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.primaryGreen
        }
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case 1...2: return DesignSystem.Colors.success
        case 3...4: return DesignSystem.Colors.warning
        case 5: return DesignSystem.Colors.error
        default: return DesignSystem.Colors.neutral400
        }
    }
}
