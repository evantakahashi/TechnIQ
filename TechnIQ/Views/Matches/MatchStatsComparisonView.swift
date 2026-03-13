import SwiftUI

struct MatchStatsComparisonView: View {
    let player: Player

    @State private var comparisonMode: ComparisonMode = .seasons
    @State private var selectedPeriod1: ComparisonPeriod?
    @State private var selectedPeriod2: ComparisonPeriod?
    @State private var seasons: [Season] = []
    @State private var stats1: SeasonStats = .empty
    @State private var stats2: SeasonStats = .empty

    enum ComparisonMode: String, CaseIterable {
        case seasons = "Seasons"
        case rolling = "Rolling"
    }

    struct ComparisonPeriod: Identifiable, Hashable {
        let id: String
        let name: String
        let season: Season?
        let days: Int?

        static func == (lhs: ComparisonPeriod, rhs: ComparisonPeriod) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private var rollingPeriods: [ComparisonPeriod] {
        [
            ComparisonPeriod(id: "30", name: "Last 30 Days", season: nil, days: 30),
            ComparisonPeriod(id: "60", name: "Last 60 Days", season: nil, days: 60),
            ComparisonPeriod(id: "90", name: "Last 90 Days", season: nil, days: 90),
            ComparisonPeriod(id: "180", name: "Last 6 Months", season: nil, days: 180),
            ComparisonPeriod(id: "365", name: "Last Year", season: nil, days: 365)
        ]
    }

    private var seasonPeriods: [ComparisonPeriod] {
        seasons.map { season in
            ComparisonPeriod(
                id: season.id?.uuidString ?? UUID().uuidString,
                name: season.name ?? "Season",
                season: season,
                days: nil
            )
        }
    }

    private var availablePeriods: [ComparisonPeriod] {
        comparisonMode == .seasons ? seasonPeriods : rollingPeriods
    }

    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Mode Picker
                    modePickerCard

                    // Period Selectors
                    periodSelectorsCard

                    // Comparison Results
                    if selectedPeriod1 != nil && selectedPeriod2 != nil {
                        comparisonResultsCard
                    } else {
                        selectPeriodsPrompt
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Compare Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSeasons()
        }
        .onChange(of: selectedPeriod1) { _, _ in
            updateStats()
        }
        .onChange(of: selectedPeriod2) { _, _ in
            updateStats()
        }
        .onChange(of: comparisonMode) { _, _ in
            selectedPeriod1 = nil
            selectedPeriod2 = nil
        }
    }

    // MARK: - Mode Picker

    private var modePickerCard: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            Picker("Comparison Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    // MARK: - Period Selectors

    private var periodSelectorsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Select Periods to Compare")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if availablePeriods.isEmpty {
                    Text(comparisonMode == .seasons ? "No seasons available. Create a season first." : "No matches logged yet.")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    // Period 1 Selector
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Period 1")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        periodSelector(selection: $selectedPeriod1, excludePeriod: selectedPeriod2)
                    }

                    // Period 2 Selector
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Period 2")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        periodSelector(selection: $selectedPeriod2, excludePeriod: selectedPeriod1)
                    }
                }
            }
        }
    }

    private func periodSelector(selection: Binding<ComparisonPeriod?>, excludePeriod: ComparisonPeriod?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(availablePeriods.filter { $0.id != excludePeriod?.id }) { period in
                    Button(action: {
                        selection.wrappedValue = period
                    }) {
                        Text(period.name)
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(selection.wrappedValue?.id == period.id ? .white : DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                selection.wrappedValue?.id == period.id
                                    ? DesignSystem.Colors.primaryGreen
                                    : DesignSystem.Colors.cellBackground
                            )
                            .cornerRadius(DesignSystem.CornerRadius.pill)
                    }
                }
            }
        }
    }

    // MARK: - Select Periods Prompt

    private var selectPeriodsPrompt: some View {
        ModernCard(padding: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Select Two Periods")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Choose two time periods above to compare your match statistics and see how you've improved.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Comparison Results

    private var comparisonResultsCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            ModernCard(padding: DesignSystem.Spacing.lg) {
                HStack {
                    VStack {
                        Text(selectedPeriod1?.name ?? "")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("\(stats1.matchesPlayed) matches")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .font(.title2)

                    Spacer()

                    VStack {
                        Text(selectedPeriod2?.name ?? "")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("\(stats2.matchesPlayed) matches")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Stats Comparison
            comparisonStatCard(
                title: "Goals per Game",
                value1: stats1.goalsPerGame,
                value2: stats2.goalsPerGame,
                format: "%.2f",
                color: DesignSystem.Colors.primaryGreen
            )

            comparisonStatCard(
                title: "Assists per Game",
                value1: stats1.assistsPerGame,
                value2: stats2.assistsPerGame,
                format: "%.2f",
                color: DesignSystem.Colors.secondaryBlue
            )

            comparisonStatCard(
                title: "Minutes per Game",
                value1: stats1.minutesPerGame,
                value2: stats2.minutesPerGame,
                format: "%.0f",
                color: DesignSystem.Colors.accentOrange
            )

            comparisonStatCard(
                title: "Win Rate",
                value1: stats1.winRate,
                value2: stats2.winRate,
                format: "%.0f%%",
                color: DesignSystem.Colors.primaryGreen,
                isPercentage: true
            )

            comparisonStatCard(
                title: "Goal Contributions/Game",
                value1: stats1.goalContributionsPerGame,
                value2: stats2.goalContributionsPerGame,
                format: "%.2f",
                color: DesignSystem.Colors.accentYellow
            )
        }
    }

    private func comparisonStatCard(
        title: String,
        value1: Double,
        value2: Double,
        format: String,
        color: Color,
        isPercentage: Bool = false
    ) -> some View {
        let delta = value2 - value1
        let deltaPercent = value1 != 0 ? ((value2 - value1) / value1) * 100 : (value2 > 0 ? 100 : 0)

        return ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack {
                    // Value 1
                    VStack(alignment: .leading) {
                        Text(String(format: format, value1))
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text(selectedPeriod1?.name ?? "")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Delta indicator
                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)

                            Text(String(format: isPercentage ? "%+.0f pts" : "%+.2f", delta))
                                .font(DesignSystem.Typography.labelMedium)
                        }
                        .foregroundColor(delta >= 0 ? DesignSystem.Colors.primaryGreen : Color.red)

                        if !isPercentage && value1 != 0 {
                            Text(String(format: "%+.0f%%", deltaPercent))
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(delta >= 0 ? DesignSystem.Colors.primaryGreen.opacity(0.7) : Color.red.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        (delta >= 0 ? DesignSystem.Colors.primaryGreen : Color.red).opacity(0.1)
                    )
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                    Spacer()

                    // Value 2
                    VStack(alignment: .trailing) {
                        Text(String(format: format, value2))
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(color)

                        Text(selectedPeriod2?.name ?? "")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadSeasons() {
        seasons = MatchService.shared.fetchSeasons(for: player)
    }

    private func updateStats() {
        if let period1 = selectedPeriod1 {
            stats1 = statsForPeriod(period1)
        }

        if let period2 = selectedPeriod2 {
            stats2 = statsForPeriod(period2)
        }
    }

    private func statsForPeriod(_ period: ComparisonPeriod) -> SeasonStats {
        if let season = period.season {
            return MatchService.shared.calculateSeasonStats(for: season)
        } else if let days = period.days {
            return MatchService.shared.calculateRollingStats(for: player, days: days)
        }
        return .empty
    }
}

#Preview {
    NavigationView {
        MatchStatsComparisonView(player: Player())
    }
}
