import SwiftUI
import CoreData

struct MatchHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let player: Player

    @State private var matches: [Match] = []
    @State private var seasons: [Season] = []
    @State private var selectedSeason: Season?
    @State private var selectedMatch: Match?
    @State private var showingMatchDetail = false
    @State private var showingLogMatch = false
    @State private var showingSeasonManagement = false

    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Summary Stats Card
                if !matches.isEmpty {
                    matchSummaryCard
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.md)
                }

                // Season Filter Pills
                if !seasons.isEmpty {
                    seasonFilterSection
                }

                // Match List
                matchListView
            }
        }
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingLogMatch = true }) {
                        Label("Log Match", systemImage: "plus.circle")
                    }

                    Button(action: { showingSeasonManagement = true }) {
                        Label("Manage Seasons", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
        .sheet(isPresented: $showingMatchDetail) {
            if let match = selectedMatch {
                MatchDetailView(match: match)
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
        }
    }

    // MARK: - Summary Card

    private var matchSummaryCard: some View {
        let stats = MatchService.shared.calculateStats(for: filteredMatches)

        return HStack(spacing: DesignSystem.Spacing.md) {
            // Total Matches
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(stats.matchesPlayed)")
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                Text("Matches")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Divider()
                .frame(height: 30)

            // Total Goals
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(stats.totalGoals)")
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                Text("Goals")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Divider()
                .frame(height: 30)

            // Total Assists
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(stats.totalAssists)")
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)

                Text("Assists")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Divider()
                .frame(height: 30)

            // Win Rate
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(String(format: "%.0f%%", stats.winRate))
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.accentOrange)

                Text("Win Rate")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }

    // MARK: - Season Filter

    private var seasonFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // All Seasons Pill
                seasonPill(name: "All", isSelected: selectedSeason == nil) {
                    selectedSeason = nil
                }

                // Season Pills
                ForEach(seasons, id: \.objectID) { season in
                    seasonPill(
                        name: season.name ?? "Season",
                        isSelected: selectedSeason == season
                    ) {
                        selectedSeason = season
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func seasonPill(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.cellBackground
                )
                .cornerRadius(DesignSystem.CornerRadius.pill)
        }
    }

    // MARK: - Match List

    private var matchListView: some View {
        List {
            if filteredMatches.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "sportscourt",
                    description: Text("Log your first match to see it here")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredMatches, id: \.objectID) { match in
                    MatchHistoryRow(match: match)
                        .onTapGesture {
                            selectedMatch = match
                            showingMatchDetail = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteMatches)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
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
    }

    private func deleteMatches(offsets: IndexSet) {
        withAnimation {
            let matchesToDelete = offsets.map { filteredMatches[$0] }
            for match in matchesToDelete {
                MatchService.shared.deleteMatch(match)
            }
            loadData()
        }
    }
}

// MARK: - Match History Row

struct MatchHistoryRow: View {
    let match: Match

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header: Opponent & Date
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if let opponent = match.opponent, !opponent.isEmpty {
                                Text("vs \(opponent)")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            } else {
                                Text("Match")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }

                            // Home/Away indicator
                            Text(match.isHomeGame ? "H" : "A")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(match.isHomeGame ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                                .cornerRadius(4)
                        }

                        Text(formatDate(match.date ?? Date()))
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Result Badge
                    if let result = match.result {
                        resultBadge(result: result)
                    }
                }

                Divider()
                    .background(DesignSystem.Colors.textSecondary.opacity(0.3))

                // Stats Row
                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Minutes
                    statItem(
                        value: "\(match.minutesPlayed)'",
                        label: "Minutes",
                        color: DesignSystem.Colors.textPrimary
                    )

                    // Goals
                    statItem(
                        value: "\(match.goals)",
                        label: "Goals",
                        color: DesignSystem.Colors.primaryGreen
                    )

                    // Assists
                    statItem(
                        value: "\(match.assists)",
                        label: "Assists",
                        color: DesignSystem.Colors.secondaryBlue
                    )

                    Spacer()

                    // Rating
                    if match.rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= match.rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.accentYellow)
                            }
                        }
                    }
                }

                // Position & Competition (if available)
                if match.positionPlayed != nil || match.competition != nil {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        if let position = match.positionPlayed, !position.isEmpty {
                            Label(position, systemImage: "person.fill")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        if let competition = match.competition, !competition.isEmpty {
                            Label(competition, systemImage: "trophy")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.numberSmall)
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private func resultBadge(result: String) -> some View {
        let (color, text) = resultInfo(result)

        return Text(text)
            .font(DesignSystem.Typography.labelMedium)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(color)
            .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private func resultInfo(_ result: String) -> (Color, String) {
        switch result.uppercased() {
        case "W":
            return (DesignSystem.Colors.primaryGreen, "WIN")
        case "D":
            return (DesignSystem.Colors.accentOrange, "DRAW")
        case "L":
            return (Color.red.opacity(0.8), "LOSS")
        default:
            return (DesignSystem.Colors.textSecondary, result)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            return "Today"
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Match Detail View

struct MatchDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let match: Match

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header Card
                        headerCard

                        // Stats Card
                        statsCard

                        // Details Card
                        if hasDetails {
                            detailsCard
                        }

                        // Notes Card
                        if let notes = match.notes, !notes.isEmpty {
                            notesCard(notes: notes)
                        }

                        // XP Card
                        xpCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Match Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }

    private var headerCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Opponent
                if let opponent = match.opponent, !opponent.isEmpty {
                    Text("vs \(opponent)")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Date & Result
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Date
                    VStack {
                        Text(formatDate(match.date ?? Date()))
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Result
                    if let result = match.result {
                        resultBadge(result: result)
                    }

                    Spacer()

                    // Home/Away
                    Text(match.isHomeGame ? "Home" : "Away")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Rating
                if match.rating > 0 {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= match.rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(DesignSystem.Colors.accentYellow)
                        }
                    }
                }
            }
        }
    }

    private var statsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Performance")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Minutes
                    statBlock(
                        value: "\(match.minutesPlayed)",
                        label: "Minutes",
                        icon: "clock",
                        color: DesignSystem.Colors.textPrimary
                    )

                    Spacer()

                    // Goals
                    statBlock(
                        value: "\(match.goals)",
                        label: "Goals",
                        icon: "soccerball",
                        color: DesignSystem.Colors.primaryGreen
                    )

                    Spacer()

                    // Assists
                    statBlock(
                        value: "\(match.assists)",
                        label: "Assists",
                        icon: "arrow.right.circle",
                        color: DesignSystem.Colors.secondaryBlue
                    )
                }
            }
        }
    }

    private var hasDetails: Bool {
        if let position = match.positionPlayed, !position.isEmpty { return true }
        if let competition = match.competition, !competition.isEmpty { return true }
        return match.season != nil
    }

    private var detailsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Details")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    if let position = match.positionPlayed, !position.isEmpty {
                        detailRow(icon: "person.fill", label: "Position", value: position)
                    }

                    if let competition = match.competition, !competition.isEmpty {
                        detailRow(icon: "trophy", label: "Competition", value: competition)
                    }

                    if let season = match.season, let name = season.name {
                        detailRow(icon: "calendar", label: "Season", value: name)
                    }
                }
            }
        }
    }

    private func notesCard(notes: String) -> some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Notes")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(notes)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var xpCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.accentYellow)

                Text("+\(match.xpEarned) XP Earned")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }
        }
    }

    private func statBlock(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(DesignSystem.Typography.numberLarge)
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .frame(width: 24)

            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    private func resultBadge(result: String) -> some View {
        let (color, text) = resultInfo(result)

        return Text(text)
            .font(DesignSystem.Typography.titleMedium)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(color)
            .cornerRadius(DesignSystem.CornerRadius.md)
    }

    private func resultInfo(_ result: String) -> (Color, String) {
        switch result.uppercased() {
        case "W":
            return (DesignSystem.Colors.primaryGreen, "WIN")
        case "D":
            return (DesignSystem.Colors.accentOrange, "DRAW")
        case "L":
            return (Color.red.opacity(0.8), "LOSS")
        default:
            return (DesignSystem.Colors.textSecondary, result)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

#Preview {
    MatchHistoryView(player: Player())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
