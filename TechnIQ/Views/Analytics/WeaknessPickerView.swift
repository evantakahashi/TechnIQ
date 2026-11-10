import SwiftUI

// MARK: - Weak-spot picker (AI drill generator)
//
// Two tiers of chips: tap an area to open it, then pick the specific weak spots inside. Picks from
// closed areas stay visible in the "Picked" row, where a tap removes them.

struct WeaknessPickerView: View {
    @Binding var selectedWeaknesses: [SelectedWeakness]
    @State private var expandedCategory: WeaknessCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.rowGap) {
            VStack(alignment: .leading, spacing: 4) {
                TQGroupHeader("Weak spot")
                FlowLayout(spacing: 6) {
                    ForEach(WeaknessCategory.allCases) { category in
                        TQChip(title(for: category), isSelected: expandedCategory == category) {
                            withAnimation(DesignSystem.Animation.quick) {
                                expandedCategory = expandedCategory == category ? nil : category
                            }
                        }
                    }
                }
            }

            if let expanded = expandedCategory {
                VStack(alignment: .leading, spacing: 8) {
                    TQEyebrow(expanded.displayName, size: 11)
                    FlowLayout(spacing: 6) {
                        ForEach(expanded.subWeaknesses) { sub in
                            TQChip(sub.displayName, isSelected: isSelected(sub, in: expanded)) {
                                toggleSubWeakness(category: expanded, sub: sub)
                            }
                        }
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(DesignSystem.Colors.grass)
                        .frame(width: 2)
                }
                .transition(.opacity)
            }

            if !selectedWeaknesses.isEmpty {
                selectedSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(for category: WeaknessCategory) -> String {
        let count = selectedWeaknesses.filter { $0.category == category.displayName }.count
        return count > 0 ? "\(category.displayName) · \(count)" : category.displayName
    }

    private func isSelected(_ sub: SubWeakness, in category: WeaknessCategory) -> Bool {
        selectedWeaknesses.contains { $0.category == category.displayName && $0.specific == sub.displayName }
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            TQGroupHeader("Picked · \(selectedWeaknesses.count)")
            FlowLayout(spacing: 6) {
                ForEach(selectedWeaknesses, id: \.specific) { weakness in
                    TQChip(weakness.specific, isSelected: true, icon: "xmark") {
                        selectedWeaknesses.removeAll {
                            $0.category == weakness.category && $0.specific == weakness.specific
                        }
                    }
                    .accessibilityLabel("Remove \(weakness.specific)")
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
