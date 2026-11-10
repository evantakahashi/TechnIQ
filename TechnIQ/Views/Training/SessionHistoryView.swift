import SwiftUI
import CoreData

// MARK: - Session history (You → Session history)
//
// One screen: totals, a month calendar that marks training days, then every session grouped by
// month. Tapping a calendar day narrows the list to that day; tapping a session opens its detail.

struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var sessions: FetchedResults<TrainingSession>

    @State private var month = Date()
    @State private var selectedDay: Date?
    @State private var openSession: TrainingSession?

    private let calendar = Calendar.current

    init() {
        // Derived from the signed-in user here (not only in onAppear): SwiftUI re-runs init whenever
        // the parent re-renders, so a "match nothing" initial predicate would empty the list again.
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: AuthenticationManager.shared.ownedByPlayerPredicate,
            animation: .default
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("History") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                if sessions.isEmpty {
                    emptyState
                } else {
                    TQStatRail(items: [
                        .init("\(sessions.count)", label: sessions.count == 1 ? "session" : "sessions"),
                        .init(totalTime.value, unit: totalTime.unit, label: "trained"),
                        .init("\(sessionsThisMonth)", label: "this month", accent: sessionsThisMonth > 0)
                    ])

                    SessionMonthCalendar(month: $month, selectedDay: $selectedDay, trainedDays: trainedDays)

                    sessionList
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $openSession) { session in
            SessionDetailView(session: session)
        }
        .onChange(of: authManager.userUID) {
            sessions.nsPredicate = AuthenticationManager.shared.ownedByPlayerPredicate
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            TQDisplayTitle("No sessions\nyet", size: .medium)
            TQBody("Finish a session and it lands here with its drills, time and how it felt.")
        }
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: List

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            if let selectedDay {
                HStack {
                    TQGroupHeader(Self.dayTitle(selectedDay, calendar: calendar))
                    Spacer()
                    TQTextLink("All sessions", arrow: false) { self.selectedDay = nil }
                }
                let daySessions = sessions.filter { session in
                    session.date.map { calendar.isDate($0, inSameDayAs: selectedDay) } ?? false
                }
                if daySessions.isEmpty {
                    TQBody("No session on this day.", tone: .muted)
                } else {
                    TQRowList { rows(for: daySessions) }
                }
            } else {
                ForEach(monthGroups, id: \.start) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader(group.title)
                        TQRowList { rows(for: group.sessions) }
                    }
                }
            }
        }
    }

    private func rows(for list: [TrainingSession]) -> some View {
        ForEach(list, id: \.objectID) { session in
            TQRow(session.sessionType ?? "Training",
                  subtitle: Self.subtitle(for: session),
                  leading: .tile(TQTile(number: Self.dayNumber(session.date, calendar: calendar), unit: "")),
                  meta: .init("\(Int(session.duration)) min")) {
                openSession = session
            }
        }
    }

    // MARK: Derived

    private struct MonthGroup {
        let start: Date
        let title: String
        let sessions: [TrainingSession]
    }

    private var monthGroups: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: sessions.filter { $0.date != nil }) { session -> Date in
            let date = session.date ?? Date()
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        return grouped.keys.sorted(by: >).map { start in
            MonthGroup(start: start, title: formatter.string(from: start), sessions: grouped[start] ?? [])
        }
    }

    private var trainedDays: Set<Date> {
        Set(sessions.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
    }

    private var sessionsThisMonth: Int {
        sessions.filter { session in
            session.date.map { calendar.isDate($0, equalTo: Date(), toGranularity: .month) } ?? false
        }.count
    }

    private var totalTime: (value: String, unit: String) {
        let minutes = Int(sessions.reduce(0) { $0 + $1.duration })
        if minutes < 60 { return ("\(minutes)", "min") }
        let hours = Double(minutes) / 60
        return (hours >= 10 ? "\(Int(hours.rounded()))" : String(format: "%.1f", hours), "h")
    }

    // MARK: Formatting

    static func subtitle(for session: TrainingSession) -> String {
        var parts: [String] = []
        if let date = session.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            parts.append(formatter.string(from: date))
        }
        let drills = session.exercises?.count ?? 0
        if drills > 0 { parts.append("\(drills) drill\(drills == 1 ? "" : "s")") }
        if let feel = SessionFeel(raw: session.feel) { parts.append(feel.label) }
        return parts.joined(separator: " · ")
    }

    private static func dayNumber(_ date: Date?, calendar: Calendar) -> String {
        guard let date else { return "–" }
        return "\(calendar.component(.day, from: date))"
    }

    private static func dayTitle(_ date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
}

#if DEBUG
#Preview {
    SessionHistoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
#endif
