import SwiftUI

// MARK: - New season (sheet)

struct CreateSeasonView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let onSeasonCreated: (Season) -> Void

    @State private var seasonName = ""
    @State private var teamName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TQNavBar("New season") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    TQNavAction("Create") { createSeason() }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1 : 0.4)
                        .accessibilityIdentifier("season.create")
                }
                .padding(.top, 8)

                TQDisplayTitle("Name the\nseason", size: .medium)

                VStack(spacing: 14) {
                    TQFormField("Season", text: $seasonName, placeholder: "Autumn 2026")
                    TQFormField("Team or club", text: $teamName, placeholder: "Optional")
                }

                VStack(alignment: .leading, spacing: 0) {
                    TQGroupHeader("Dates")
                    TQRule()
                    dateRow("Starts", selection: $startDate)
                    dateRow("Ends", selection: $endDate)
                    if startDate > endDate {
                        TQBody("The season can't end before it starts.", tone: .muted, size: 13)
                            .padding(.top, 10)
                    }
                }

                TQButton("Create season") { createSeason() }
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.4)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
            Spacer(minLength: 8)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .tint(DesignSystem.Colors.grass)
                .accessibilityLabel(title)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { TQRule() }
    }

    private var isFormValid: Bool {
        !seasonName.trimmingCharacters(in: .whitespaces).isEmpty && startDate <= endDate
    }

    private func createSeason() {
        guard isFormValid else { return }
        // Ensure dates are valid (defensive check)
        let validEndDate = max(startDate, endDate)

        let season = MatchService.shared.createSeason(
            for: player,
            name: seasonName.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: validEndDate,
            team: teamName.isEmpty ? nil : teamName
        )

        HapticManager.shared.success()
        onSeasonCreated(season)
        dismiss()
    }
}

#if DEBUG
#Preview {
    CreateSeasonView(player: Player()) { _ in }
}
#endif
