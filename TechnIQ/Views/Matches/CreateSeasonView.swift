import SwiftUI

struct CreateSeasonView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let onSeasonCreated: (Season) -> Void

    @State private var seasonName = ""
    @State private var teamName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Season Name
                        ModernCard(padding: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Season Name")
                                    .font(DesignSystem.Typography.titleMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                TextField("e.g., Fall 2024", text: $seasonName)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.cellBackground)
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                            }
                        }

                        // Team Name
                        ModernCard(padding: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Team/Club (Optional)")
                                    .font(DesignSystem.Typography.titleMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                TextField("e.g., FC Barcelona", text: $teamName)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.cellBackground)
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                            }
                        }

                        // Date Range
                        ModernCard(padding: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Season Dates")
                                    .font(DesignSystem.Typography.titleMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .tint(DesignSystem.Colors.primaryGreen)

                                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .tint(DesignSystem.Colors.primaryGreen)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("New Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSeason()
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !seasonName.isEmpty && startDate <= endDate
    }

    private func createSeason() {
        // Ensure dates are valid (defensive check)
        let validEndDate = max(startDate, endDate)

        let season = MatchService.shared.createSeason(
            for: player,
            name: seasonName,
            startDate: startDate,
            endDate: validEndDate,
            team: teamName.isEmpty ? nil : teamName
        )

        onSeasonCreated(season)
        dismiss()
    }
}

#Preview {
    CreateSeasonView(player: Player()) { _ in }
}
