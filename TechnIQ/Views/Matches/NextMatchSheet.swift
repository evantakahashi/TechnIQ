import SwiftUI

// MARK: - Next match sheet (Home)
//
// Set, change or clear the profile's next match from Home. Saving re-shapes the active plan
// around it (TrainingPlanService.setNextMatch → MatchDayRules).

struct NextMatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    @State private var date: Date?

    init(player: Player) {
        self.player = player
        _date = State(initialValue: MatchScheduleLink.upcoming(player.playerProfile?.nextMatchDate, now: Date(), calendar: .current)
                      ?? NextMatchDefaults.suggested())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Next match") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                TQNavAction("Save") { save() }
                    .accessibilityIdentifier("nextMatch.save")
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                TQRule()
                TQDateRow("Match day", date: $date, range: NextMatchDefaults.range()) { NextMatchDefaults.suggested() }
            }

            TQBody("Your plan rests on match day, goes light the day before and easy the day after.", tone: .muted, size: 13)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    private func save() {
        TrainingPlanService.shared.setNextMatch(date, for: player)
        HapticManager.shared.success()
        dismiss()
    }
}
