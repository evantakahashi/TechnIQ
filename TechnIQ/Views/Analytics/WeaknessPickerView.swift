import SwiftUI

// MARK: - Two-Tier Weakness Picker

struct WeaknessPickerView: View {
    @Binding var selectedWeaknesses: [SelectedWeakness]
    @State private var expandedCategory: WeaknessCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("What do you want to improve?")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Tier 1: Category grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                ForEach(WeaknessCategory.allCases) { category in
                    WeaknessCategoryChip(
                        category: category,
                        isExpanded: expandedCategory == category,
                        selectionCount: selectedWeaknesses.filter { $0.category == category.displayName }.count
                    )
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.smooth) {
                            if expandedCategory == category {
                                expandedCategory = nil
                            } else {
                                expandedCategory = category
                            }
                        }
                    }
                }
            }

            // Tier 2: Sub-weaknesses for expanded category
            if let expanded = expandedCategory {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(expanded.displayName)
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    FlowLayout(spacing: DesignSystem.Spacing.sm) {
                        ForEach(expanded.subWeaknesses) { sub in
                            let isSelected = selectedWeaknesses.contains {
                                $0.category == expanded.displayName && $0.specific == sub.displayName
                            }
                            SubWeaknessChip(
                                subWeakness: sub,
                                isSelected: isSelected
                            )
                            .onTapGesture {
                                toggleSubWeakness(category: expanded, sub: sub)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceOverlay)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Selected summary
            if !selectedWeaknesses.isEmpty {
                selectedSummary
            }
        }
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Selected (\(selectedWeaknesses.count))")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            FlowLayout(spacing: DesignSystem.Spacing.xs) {
                ForEach(selectedWeaknesses, id: \.specific) { weakness in
                    HStack(spacing: 4) {
                        Text(weakness.specific)
                            .font(DesignSystem.Typography.labelSmall)
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.primaryGreen.opacity(0.15))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.pill)
                    .onTapGesture {
                        selectedWeaknesses.removeAll {
                            $0.category == weakness.category && $0.specific == weakness.specific
                        }
                    }
                }
            }
        }
    }

    private func toggleSubWeakness(category: WeaknessCategory, sub: SubWeakness) {
        let weakness = SelectedWeakness(category: category.displayName, specific: sub.displayName)
        if let index = selectedWeaknesses.firstIndex(where: {
            $0.category == weakness.category && $0.specific == weakness.specific
        }) {
            selectedWeaknesses.remove(at: index)
        } else {
            selectedWeaknesses.append(weakness)
        }
    }
}

// MARK: - Category Chip

private struct WeaknessCategoryChip: View {
    let category: WeaknessCategory
    let isExpanded: Bool
    let selectionCount: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(isExpanded ? .white : DesignSystem.Colors.primaryGreen)

            Text(category.displayName)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(isExpanded ? .white : DesignSystem.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if selectionCount > 0 {
                Text("\(selectionCount)")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(DesignSystem.Colors.primaryGreen)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)
        .background(isExpanded ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    isExpanded ? Color.clear : (selectionCount > 0 ? DesignSystem.Colors.primaryGreen.opacity(0.3) : DesignSystem.Colors.textTertiary.opacity(0.3)),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Sub-Weakness Chip

private struct SubWeaknessChip: View {
    let subWeakness: SubWeakness
    let isSelected: Bool

    var body: some View {
        Text(subWeakness.displayName)
            .font(DesignSystem.Typography.labelMedium)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.surfaceRaised)
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            .cornerRadius(DesignSystem.CornerRadius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pill)
                    .stroke(
                        isSelected ? Color.clear : DesignSystem.Colors.textTertiary.opacity(0.3),
                        lineWidth: 1
                    )
            )
    }
}

// FlowLayout is defined in AITrainingPlanGeneratorView.swift
