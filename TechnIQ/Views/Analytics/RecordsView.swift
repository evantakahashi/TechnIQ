import SwiftUI
import CoreData

// MARK: - Personal records (You → Personal records)
//
// This week against last, then the bests: longest session, best week, most drills in a day,
// longest streak. Every figure comes from `PlayerRecords` so Progress shows the same numbers.

struct RecordsView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player

    @State private var records: PlayerRecords?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Records") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                if let records {
                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow("This week", size: 11)
                        TQDisplayTitle(records.comparison.thisWeekSessions == 0 ? "Not yet" : "\(records.comparison.thisWeekSessions) session\(records.comparison.thisWeekSessions == 1 ? "" : "s")", size: .medium)
                        TQBody(records.comparison.delta)
                    }

                    TQStatRail(items: [
                        .init("\(records.comparison.thisWeekMinutes)", unit: "min", label: "this week"),
                        .init("\(records.comparison.lastWeekMinutes)", unit: "min", label: "last week"),
                        .init("\(records.totalSessions)", label: "sessions ever")
                    ])

                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Personal bests")
                        TQRowList {
                            TQRow("Longest session", subtitle: records.longestSessionDate.map { dateFormatter.string(from: $0) },
                                  meta: .init(records.longestSessionMinutes > 0 ? "\(records.longestSessionMinutes) min" : "–"), accessory: .none)
                            TQRow("Best week", subtitle: records.bestWeekStart.map { "week of \(dateFormatter.string(from: $0))" },
                                  meta: .init(records.bestWeekSessions > 0 ? "\(records.bestWeekSessions) sessions" : "–"), accessory: .none)
                            TQRow("Most drills in a day", subtitle: records.mostDrillsDate.map { dateFormatter.string(from: $0) },
                                  meta: .init(records.mostDrillsInADay > 0 ? "\(records.mostDrillsInADay)" : "–"), accessory: .none)
                            TQRow("Longest streak", subtitle: "current \(player.currentStreak)",
                                  meta: .init("\(player.longestStreak) day\(player.longestStreak == 1 ? "" : "s")"), accessory: .none)
                        }
                    }
                } else {
                    TQSkeleton(width: 200, height: 24, cornerRadius: 4)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
    }

    private func load() {
        records = PlayerRecords.build(sessions: Self.facts(for: player), now: Date(), calendar: .current)
    }

    static func facts(for player: Player) -> [PlayerRecords.SessionFact] {
        ((player.sessions as? Set<TrainingSession>) ?? []).compactMap { session in
            guard let date = session.date else { return nil }
            return PlayerRecords.SessionFact(date: date, minutes: Int(session.duration), drillCount: session.exercises?.count ?? 0)
        }
    }
}
