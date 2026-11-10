import SwiftUI
import CoreData

// MARK: - Seasons (sheet from Match history)
//
// The active season on the one pitch card, every season as a flat row. Tap a season for its
// figures; "Make active" and "Delete" live on that sheet.

struct SeasonManagementView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let onUpdate: () -> Void

    @State private var seasons: [Season] = []
    @State private var showingCreateSeason = false
    @State private var selectedSeason: Season?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Seasons") {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") {
                        onUpdate()
                        dismiss()
                    }
                }
                .padding(.top, 8)

                if seasons.isEmpty {
                    emptyState
                } else {
                    if let active = seasons.first(where: { $0.isActive }) {
                        activeSeasonCard(active)
                    }
                    seasonsList
                    TQButton("New season", icon: "plus", style: .raised) { showingCreateSeason = true }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCreateSeason) {
            CreateSeasonView(player: player) { _ in
                loadSeasons()
            }
        }
        .sheet(item: $selectedSeason) { season in
            SeasonStatsView(
                season: season,
                player: player,
                onMakeActive: season.isActive ? nil : { setActiveSeason(season) },
                onDelete: { deleteSeason(season) }
            )
        }
        .onAppear(perform: loadSeasons)
    }

    // MARK: - Active season

    private func activeSeasonCard(_ season: Season) -> some View {
        let stats = MatchService.shared.calculateSeasonStats(for: season)
        return TQPitchCard(.card, markings: .centre) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow("Active season", size: 11)
                TQDisplayTitle(season.name ?? "Season", size: .card)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                TQMeta(Self.subtitle(for: season), tone: .onPitch, size: 13)
                TQFigureRow([
                    ("\(stats.matchesPlayed)", "played"),
                    ("\(stats.totalGoals)", "goals"),
                    ("\(stats.totalAssists)", "assists")
                ])
                .padding(.top, 2)
                TQTextLink("Season figures", tone: .onPitch) { selectedSeason = season }
            }
        }
    }

    // MARK: - List

    private var seasonsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("All seasons")
            TQRowList {
                ForEach(seasons, id: \.objectID) { season in
                    seasonRow(season)
                }
            }
        }
    }

    private func seasonRow(_ season: Season) -> some View {
        let played = MatchService.shared.calculateSeasonStats(for: season).matchesPlayed
        return TQRow(season.name ?? "Season",
                     subtitle: Self.dateRange(for: season),
                     meta: .init("\(played) match\(played == 1 ? "" : "es")"),
                     badge: season.isActive ? TQBadge(.status("Active")) : nil,
                     action: { selectedSeason = season })
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            TQDisplayTitle("No seasons\nyet", size: .medium)
            TQBody("A season groups your matches so the figures reset when a new one starts.")
            TQButton("New season", icon: "plus") { showingCreateSeason = true }
                .padding(.top, 8)
        }
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: - Helpers

    static func dateRange(for season: Season, format: String = "MMM yyyy") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        let start = season.startDate ?? Date()
        let end = season.endDate ?? Date()
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func subtitle(for season: Season) -> String {
        var parts: [String] = []
        if let team = season.team, !team.isEmpty { parts.append(team) }
        parts.append(dateRange(for: season))
        return parts.joined(separator: " · ")
    }

    private func loadSeasons() {
        seasons = MatchService.shared.fetchSeasons(for: player)
    }

    private func setActiveSeason(_ season: Season) {
        MatchService.shared.setActiveSeason(season, for: player)
        loadSeasons()
    }

    private func deleteSeason(_ season: Season) {
        MatchService.shared.deleteSeason(season)
        loadSeasons()
    }
}

// MARK: - Season figures (sheet)

struct SeasonStatsView: View {
    @Environment(\.dismiss) private var dismiss

    let season: Season
    let player: Player
    var onMakeActive: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var stats: SeasonStats = .empty
    @State private var matches: [Match] = []
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Season") {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") { dismiss() }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    TQEyebrow(SeasonManagementView.subtitle(for: season), tone: .muted, size: 11)
                    TQDisplayTitle(season.name ?? "Season", size: .medium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                TQStatRail(items: [
                    .init("\(stats.matchesPlayed)", label: "played"),
                    .init("\(stats.totalGoals)", label: "goals", accent: stats.totalGoals > 0),
                    .init("\(stats.totalAssists)", label: "assists"),
                    .init("\(stats.totalMinutes)", unit: "′", label: "minutes")
                ])

                if stats.matchesPlayed > 0 {
                    results
                    perGame
                }
                if !matches.isEmpty { recentMatches }
                actions
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear(perform: loadStats)
        .alert("Delete this season?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                onDelete?()
            }
        } message: {
            Text("Its matches are kept and just lose the season.")
        }
    }

    // MARK: - Sections

    private var results: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQSectionHeader("Results") {
                TQMeta(String(format: "%.0f%% won", stats.winRate), tone: .chalk, size: 14)
            }
            GeometryReader { geo in
                let total = CGFloat(max(stats.matchesPlayed, 1))
                HStack(spacing: 2) {
                    resultBar(DesignSystem.Colors.grass, width: geo.size.width * CGFloat(stats.wins) / total)
                    resultBar(DesignSystem.Colors.surfaceHighlight, width: geo.size.width * CGFloat(stats.draws) / total)
                    resultBar(DesignSystem.Colors.cone, width: geo.size.width * CGFloat(stats.losses) / total)
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityHidden(true)
            TQMeta("\(stats.wins) won · \(stats.draws) drawn · \(stats.losses) lost", tone: .muted, size: 13, weight: .regular, uppercase: false)
        }
    }

    @ViewBuilder
    private func resultBar(_ color: Color, width: CGFloat) -> some View {
        if width > 0 {
            Rectangle().fill(color).frame(width: max(0, width - 2))
        }
    }

    private var perGame: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Per game")
            TQRowList {
                TQRow("Goals", meta: .init(String(format: "%.2f", stats.goalsPerGame)), accessory: .none)
                TQRow("Assists", meta: .init(String(format: "%.2f", stats.assistsPerGame)), accessory: .none)
                TQRow("Minutes", meta: .init(String(format: "%.0f′", stats.minutesPerGame)), accessory: .none)
                TQRow("Goal contributions",
                      meta: .init("\(stats.goalContributions) · " + String(format: "%.2f", stats.goalContributionsPerGame)),
                      accessory: .none)
            }
        }
    }

    private var recentMatches: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Recent matches")
            TQRowList {
                ForEach(Array(matches.prefix(5)), id: \.objectID) { match in
                    MatchHistoryRow(match: match)
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if onMakeActive != nil || onDelete != nil {
            VStack(spacing: 10) {
                if let onMakeActive {
                    TQButton("Make active", style: .raised) {
                        onMakeActive()
                        dismiss()
                    }
                }
                if onDelete != nil {
                    TQButton("Delete season", style: .destructive) { confirmingDelete = true }
                }
            }
            .padding(.top, 8)
        }
    }

    private func loadStats() {
        stats = MatchService.shared.calculateSeasonStats(for: season)
        matches = MatchService.shared.fetchMatches(for: player, season: season)
    }
}

#if DEBUG
#Preview {
    SeasonManagementView(player: Player()) {}
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
#endif
