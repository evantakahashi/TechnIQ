import SwiftUI
import CoreData

struct SeasonManagementView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let onUpdate: () -> Void

    @State private var seasons: [Season] = []
    @State private var showingCreateSeason = false
    @State private var selectedSeason: Season?
    @State private var showingSeasonStats = false
    @State private var showingDeleteAlert = false
    @State private var seasonToDelete: Season?

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Active Season Card
                        if let activeSeason = seasons.first(where: { $0.isActive }) {
                            activeSeasonCard(season: activeSeason)
                        }

                        // All Seasons
                        if seasons.isEmpty {
                            emptyStateCard
                        } else {
                            seasonsListCard
                        }

                        // Create New Season Button
                        ModernButton("Create New Season", icon: "plus.circle.fill", style: .primary) {
                            showingCreateSeason = true
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Seasons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onUpdate()
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .sheet(isPresented: $showingCreateSeason) {
                CreateSeasonView(player: player) { newSeason in
                    loadSeasons()
                }
            }
            .sheet(isPresented: $showingSeasonStats) {
                if let season = selectedSeason {
                    SeasonStatsView(season: season, player: player)
                }
            }
            .alert("Delete Season", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let season = seasonToDelete {
                        deleteSeason(season)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this season? All matches in this season will be unlinked (not deleted).")
            }
            .onAppear {
                loadSeasons()
            }
        }
    }

    // MARK: - Active Season Card

    private func activeSeasonCard(season: Season) -> some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    Text("Active Season")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    Spacer()
                }

                Text(season.name ?? "Season")
                    .font(DesignSystem.Typography.titleLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let team = season.team, !team.isEmpty {
                    Text(team)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Date Range
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(seasonDateRange(season))
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Quick Stats
                let stats = MatchService.shared.calculateSeasonStats(for: season)
                if stats.matchesPlayed > 0 {
                    Divider()

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        quickStat(value: "\(stats.matchesPlayed)", label: "Matches")
                        quickStat(value: "\(stats.totalGoals)", label: "Goals")
                        quickStat(value: "\(stats.totalAssists)", label: "Assists")
                    }
                }

                ModernButton("View Stats", icon: "chart.bar.fill", style: .secondary) {
                    selectedSeason = season
                    showingSeasonStats = true
                }
            }
        }
    }

    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.numberMedium)
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        ModernCard(padding: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("No Seasons Yet")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Create a season to organize your matches and track your progress over time.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Seasons List

    private var seasonsListCard: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("All Seasons")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)

                ForEach(seasons, id: \.objectID) { season in
                    seasonRow(season: season)

                    if season != seasons.last {
                        Divider()
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
            }
        }
    }

    private func seasonRow(season: Season) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(season.name ?? "Season")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if season.isActive {
                        Text("ACTIVE")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primaryGreen)
                            .cornerRadius(4)
                    }
                }

                Text(seasonDateRange(season))
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Match count
            let stats = MatchService.shared.calculateSeasonStats(for: season)
            Text("\(stats.matchesPlayed) matches")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            // Actions Menu
            Menu {
                if !season.isActive {
                    Button(action: { setActiveSeason(season) }) {
                        Label("Set as Active", systemImage: "star")
                    }
                }

                Button(action: {
                    selectedSeason = season
                    showingSeasonStats = true
                }) {
                    Label("View Stats", systemImage: "chart.bar")
                }

                Divider()

                Button(role: .destructive, action: {
                    seasonToDelete = season
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(season.isActive ? DesignSystem.Colors.primaryGreen.opacity(0.1) : Color.clear)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    // MARK: - Helpers

    private func seasonDateRange(_ season: Season) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        let start = season.startDate ?? Date()
        let end = season.endDate ?? Date()

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
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

// MARK: - Season Stats View

struct SeasonStatsView: View {
    @Environment(\.dismiss) private var dismiss

    let season: Season
    let player: Player

    @State private var stats: SeasonStats = .empty
    @State private var matches: [Match] = []

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        headerCard

                        // Overview Stats
                        overviewCard

                        // Per Game Averages
                        averagesCard

                        // Results Breakdown
                        resultsCard

                        // Recent Matches
                        if !matches.isEmpty {
                            recentMatchesCard
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Season Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .onAppear {
                loadStats()
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(season.name ?? "Season")
                    .font(DesignSystem.Typography.titleLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let team = season.team, !team.isEmpty {
                    Text(team)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(seasonDateRange)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Overview")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.md) {
                    overviewStat(value: "\(stats.matchesPlayed)", label: "Matches", color: DesignSystem.Colors.textPrimary)
                    overviewStat(value: "\(stats.totalGoals)", label: "Goals", color: DesignSystem.Colors.primaryGreen)
                    overviewStat(value: "\(stats.totalAssists)", label: "Assists", color: DesignSystem.Colors.secondaryBlue)
                    overviewStat(value: "\(stats.totalMinutes)", label: "Minutes", color: DesignSystem.Colors.accentOrange)
                }
            }
        }
    }

    private func overviewStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.numberLarge)
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Averages Card

    private var averagesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Per Game Averages")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    averageStat(
                        value: String(format: "%.2f", stats.goalsPerGame),
                        label: "Goals/Game",
                        color: DesignSystem.Colors.primaryGreen
                    )

                    Spacer()

                    averageStat(
                        value: String(format: "%.2f", stats.assistsPerGame),
                        label: "Assists/Game",
                        color: DesignSystem.Colors.secondaryBlue
                    )

                    Spacer()

                    averageStat(
                        value: String(format: "%.0f", stats.minutesPerGame),
                        label: "Mins/Game",
                        color: DesignSystem.Colors.accentOrange
                    )
                }

                // Goal Contributions
                Divider()

                HStack {
                    Text("Goal Contributions")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("\(stats.goalContributions)")
                        .font(DesignSystem.Typography.numberMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("(\(String(format: "%.2f", stats.goalContributionsPerGame))/game)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    private func averageStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.numberMedium)
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Results")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text(String(format: "%.0f%% Win Rate", stats.winRate))
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                // Results Bar
                if stats.matchesPlayed > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            // Wins
                            Rectangle()
                                .fill(DesignSystem.Colors.primaryGreen)
                                .frame(width: geo.size.width * CGFloat(stats.wins) / CGFloat(stats.matchesPlayed))

                            // Draws
                            Rectangle()
                                .fill(DesignSystem.Colors.accentOrange)
                                .frame(width: geo.size.width * CGFloat(stats.draws) / CGFloat(stats.matchesPlayed))

                            // Losses
                            Rectangle()
                                .fill(Color.red.opacity(0.8))
                                .frame(width: geo.size.width * CGFloat(stats.losses) / CGFloat(stats.matchesPlayed))
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 12)
                }

                // Legend
                HStack(spacing: DesignSystem.Spacing.lg) {
                    resultLegend(color: DesignSystem.Colors.primaryGreen, label: "W", count: stats.wins)
                    resultLegend(color: DesignSystem.Colors.accentOrange, label: "D", count: stats.draws)
                    resultLegend(color: Color.red.opacity(0.8), label: "L", count: stats.losses)
                }
            }
        }
    }

    private func resultLegend(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text("\(count) \(label)")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Recent Matches Card

    private var recentMatchesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Recent Matches")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                ForEach(matches.prefix(5), id: \.objectID) { match in
                    recentMatchRow(match: match)

                    if match != matches.prefix(5).last {
                        Divider()
                    }
                }
            }
        }
    }

    private func recentMatchRow(match: Match) -> some View {
        HStack {
            // Result
            if let result = match.result {
                Text(result)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(resultColor(result))
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(match.opponent ?? "Match")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(formatDate(match.date ?? Date()))
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Stats
            HStack(spacing: DesignSystem.Spacing.sm) {
                if match.goals > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "soccerball")
                            .font(.caption2)
                        Text("\(match.goals)")
                            .font(DesignSystem.Typography.bodySmall)
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                if match.assists > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption2)
                        Text("\(match.assists)")
                            .font(DesignSystem.Typography.bodySmall)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)
                }
            }
        }
    }

    // MARK: - Helpers

    private var seasonDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        let start = season.startDate ?? Date()
        let end = season.endDate ?? Date()

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func loadStats() {
        stats = MatchService.shared.calculateSeasonStats(for: season)
        matches = MatchService.shared.fetchMatches(for: player, season: season)
    }

    private func resultColor(_ result: String) -> Color {
        switch result.uppercased() {
        case "W": return DesignSystem.Colors.primaryGreen
        case "D": return DesignSystem.Colors.accentOrange
        case "L": return Color.red.opacity(0.8)
        default: return DesignSystem.Colors.textSecondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    SeasonManagementView(player: Player()) {}
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
