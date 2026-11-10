import SwiftUI
import CoreData

// MARK: - Match history (You → Matches & seasons, Home → Last match)
//
// Figures rail for the filtered matches, a season filter, then one flat row per match
// (result letter leading). Tap a row for the detail sheet; delete lives there.

struct MatchHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let player: Player

    @State private var matches: [Match] = []
    @State private var seasons: [Season] = []
    @State private var selectedSeason: Season?
    @State private var selectedMatch: Match?
    @State private var showingLogMatch = false
    @State private var showingSeasonManagement = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Match History") {
                    TQBackButton { dismiss() }
                } trailing: {
                    TQNavAction("Seasons") { showingSeasonManagement = true }
                }
                .padding(.top, 8)

                if matches.isEmpty {
                    emptyState
                } else {
                    summaryRail
                    if !seasons.isEmpty { seasonFilter }
                    matchList
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            if !matches.isEmpty {
                TQButton("Log a match", icon: "plus") { showingLogMatch = true }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.surfaceBase)
            }
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedMatch) { match in
            MatchDetailView(match: match) {
                MatchService.shared.deleteMatch(match)
                loadData()
            }
        }
        .sheet(isPresented: $showingLogMatch) {
            MatchLogView(player: player, preselectedSeason: selectedSeason) {
                loadData()
            }
        }
        .sheet(isPresented: $showingSeasonManagement) {
            SeasonManagementView(player: player) {
                loadData()
            }
        }
        .onAppear {
            loadData()
            #if DEBUG
            // `-TQSheet matchLog|seasons|matchDetail` opens a Matches sheet for screenshots.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-TQSheet"), index + 1 < args.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    switch args[index + 1] {
                    case "matchLog": showingLogMatch = true
                    case "seasons": showingSeasonManagement = true
                    case "matchDetail": selectedMatch = matches.first
                    default: break
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Sections

    private var summaryRail: some View {
        let stats = MatchService.shared.calculateStats(for: filteredMatches)
        return TQStatRail(items: [
            .init("\(stats.matchesPlayed)", label: "played"),
            .init("\(stats.totalGoals)", label: "goals", accent: stats.totalGoals > 0),
            .init("\(stats.totalAssists)", label: "assists"),
            .init(String(format: "%.0f", stats.winRate), unit: "%", label: "won")
        ])
    }

    private var seasonFilter: some View {
        TQChipRow {
            TQChip("All", isSelected: selectedSeason == nil) { selectedSeason = nil }
            ForEach(seasons, id: \.objectID) { season in
                TQChip(season.name ?? "Season", isSelected: selectedSeason == season) { selectedSeason = season }
            }
        }
    }

    @ViewBuilder
    private var matchList: some View {
        if filteredMatches.isEmpty {
            TQBody("No matches in this season yet.", tone: .muted)
                .padding(.top, 8)
        } else {
            TQRowList {
                ForEach(filteredMatches, id: \.objectID) { match in
                    MatchHistoryRow(match: match) { selectedMatch = match }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            TQEyebrow("Matches", tone: .muted, size: 11)
            TQDisplayTitle("No matches\nyet", size: .medium)
            TQBody("Log a match after the final whistle. Goals, minutes and what needs work shape what you train next.")
            TQButton("Log a match", icon: "plus") { showingLogMatch = true }
                .padding(.top, 8)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Helpers

    private var filteredMatches: [Match] {
        if let season = selectedSeason {
            return matches.filter { $0.season == season }
        }
        return matches
    }

    private func loadData() {
        matches = MatchService.shared.fetchMatches(for: player)
        seasons = MatchService.shared.fetchSeasons(for: player)
        if let season = selectedSeason, !seasons.contains(season) { selectedSeason = nil }
    }
}

// MARK: - Result style

/// W / D / L wording and tone, shared by the match and season screens.
enum MatchResultStyle {
    static func word(_ result: String?) -> String {
        switch (result ?? "").uppercased() {
        case "W": return "Win"
        case "D": return "Draw"
        case "L": return "Loss"
        default: return result ?? ""
        }
    }

    static func color(_ result: String?) -> Color {
        switch (result ?? "").uppercased() {
        case "W": return DesignSystem.Colors.grass
        case "L": return DesignSystem.Colors.cone
        default: return DesignSystem.Colors.dimIvory
        }
    }

    static func statLine(goals: Int, assists: Int, minutes: Int) -> String {
        "\(goals)G \(assists)A · \(minutes)′"
    }

    static func day(_ date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return "" }
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "EEE d MMM" : "d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Match row

struct MatchHistoryRow: View {
    let match: Match
    var action: (() -> Void)?

    var body: some View {
        let letter = (match.result ?? "–").uppercased()
        let tone: TQRow.IndexTone = letter == "W" ? .grass : .muted
        return TQRow(title,
              subtitle: subtitle,
              leading: .index(letter, tone: tone),
              meta: .init(MatchResultStyle.statLine(goals: Int(match.goals), assists: Int(match.assists), minutes: Int(match.minutesPlayed))),
              accessory: action == nil ? .none : .chevron,
              action: action)
    }

    private var title: String {
        if let opponent = match.opponent, !opponent.isEmpty { return "vs \(opponent)" }
        return "Match"
    }

    private var subtitle: String {
        var parts = [MatchResultStyle.day(match.date), match.isHomeGame ? "Home" : "Away"]
        if let competition = match.competition, !competition.isEmpty { parts.append(competition) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

// MARK: - Match detail (sheet)

struct MatchDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let match: Match
    var onDelete: (() -> Void)?

    @State private var confirmingDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Match") {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") { dismiss() }
                }
                .padding(.top, 8)

                header
                figures
                if hasDetails { details }
                picks(title: "Went well", raw: match.strengths)
                picks(title: "Needs work", raw: match.weaknesses)
                if let notes = match.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        TQGroupHeader("Notes")
                        TQBody(notes)
                    }
                }
                if onDelete != nil {
                    TQButton("Delete match", style: .destructive) { confirmingDelete = true }
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Delete this match?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                onDelete?()
            }
        } message: {
            Text("It comes out of your season figures. This can't be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TQEyebrow([dateText, match.isHomeGame ? "Home" : "Away"].joined(separator: " · "), tone: .muted, size: 11)
            TQDisplayTitle(opponentTitle, size: .medium)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let result = match.result, !result.isEmpty {
                Text(MatchResultStyle.word(result))
                    .font(DesignSystem.Typography.labelMedium)
                    .textCase(.uppercase)
                    .tracking(DesignSystem.Typography.Tracking.label)
                    .foregroundColor(MatchResultStyle.color(result))
            }
        }
    }

    private var figures: some View {
        var items: [TQStatRail.Item] = [
            .init("\(match.minutesPlayed)", unit: "′", label: "minutes"),
            .init("\(match.goals)", label: "goals", accent: match.goals > 0),
            .init("\(match.assists)", label: "assists")
        ]
        if match.rating > 0 {
            items.append(.init("\(match.rating)", unit: "/5", label: "rating"))
        }
        return TQStatRail(items: items)
    }

    private var hasDetails: Bool {
        if let position = match.positionPlayed, !position.isEmpty { return true }
        if let competition = match.competition, !competition.isEmpty { return true }
        return match.season?.name != nil
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Details")
            TQRowList {
                if let position = match.positionPlayed, !position.isEmpty {
                    TQRow("Position", meta: .init(position), accessory: .none)
                }
                if let competition = match.competition, !competition.isEmpty {
                    TQRow("Competition", meta: .init(competition), accessory: .none)
                }
                if let name = match.season?.name {
                    TQRow("Season", meta: .init(name), accessory: .none)
                }
            }
        }
    }

    @ViewBuilder
    private func picks(title: String, raw: String?) -> some View {
        let items = (raw ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                TQGroupHeader(title)
                TQBody(items.joined(separator: " · "))
            }
        }
    }

    private var opponentTitle: String {
        if let opponent = match.opponent, !opponent.isEmpty { return "vs \(opponent)" }
        return "Match"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: match.date ?? Date())
    }
}

#if DEBUG
#Preview {
    MatchHistoryView(player: Player())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
#endif
