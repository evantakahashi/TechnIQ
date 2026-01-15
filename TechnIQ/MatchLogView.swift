import SwiftUI
import CoreData

struct MatchLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    let player: Player
    let preselectedSeason: Season?
    let onComplete: (() -> Void)?

    init(player: Player, preselectedSeason: Season? = nil, onComplete: (() -> Void)? = nil) {
        self.player = player
        self.preselectedSeason = preselectedSeason
        self.onComplete = onComplete
    }

    // Match details
    @State private var matchDate = Date()
    @State private var opponent = ""
    @State private var competition = ""
    @State private var selectedSeason: Season?
    @State private var positionPlayed = ""
    @State private var isHomeGame = true
    @State private var result = "W"

    // Stats
    @State private var minutesPlayed: Double = 90
    @State private var goals: Int = 0
    @State private var assists: Int = 0

    // Rating and notes
    @State private var matchRating = 3
    @State private var matchNotes = ""

    // UI State
    @State private var availableSeasons: [Season] = []
    @State private var showingCreateSeason = false
    @State private var showMatchComplete = false
    @State private var earnedXP: Int32 = 0

    let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LM", "RM", "LW", "RW", "ST", "CF"]
    let results = ["W", "D", "L"]

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        dateAndSeasonCard
                        opponentCard
                        positionCard
                        matchStatsCard
                        resultCard
                        ratingCard
                        notesCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Log Match")
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
                    Button("Save") {
                        saveMatch()
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .sheet(isPresented: $showingCreateSeason) {
                CreateSeasonView(player: player) { newSeason in
                    selectedSeason = newSeason
                    loadSeasons()
                }
            }
            .sheet(isPresented: $showMatchComplete) {
                MatchCompleteView(xpEarned: earnedXP, goals: goals, assists: assists) {
                    showMatchComplete = false
                    onComplete?()
                    dismiss()
                }
            }
            .onAppear {
                loadSeasons()
            }
        }
    }

    // MARK: - Card Components

    private var dateAndSeasonCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Match Details")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Date picker
                DatePicker("Date", selection: $matchDate, displayedComponents: .date)
                    .font(DesignSystem.Typography.bodyMedium)
                    .tint(DesignSystem.Colors.primaryGreen)

                Divider()

                // Season selector
                HStack {
                    Text("Season")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Menu {
                        Button("No Season") {
                            selectedSeason = nil
                        }

                        ForEach(availableSeasons, id: \.id) { season in
                            Button(season.name ?? "Unnamed") {
                                selectedSeason = season
                            }
                        }

                        Divider()

                        Button {
                            showingCreateSeason = true
                        } label: {
                            Label("Create Season", systemImage: "plus.circle")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedSeason?.name ?? "None")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                    }
                }
            }
        }
    }

    private var opponentCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Opponent & Competition")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                TextField("Opponent (optional)", text: $opponent)
                    .font(DesignSystem.Typography.bodyMedium)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.cellBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                TextField("Competition (optional)", text: $competition)
                    .font(DesignSystem.Typography.bodyMedium)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.cellBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                // Home/Away toggle
                HStack {
                    Text("Location")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Picker("", selection: $isHomeGame) {
                        Text("Home").tag(true)
                        Text("Away").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
        }
    }

    private var positionCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Position Played")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(positions, id: \.self) { position in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                positionPlayed = position
                            }
                        } label: {
                            Text(position)
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(
                                    positionPlayed == position
                                        ? DesignSystem.Colors.primaryGreen
                                        : DesignSystem.Colors.cellBackground
                                )
                                .foregroundColor(
                                    positionPlayed == position
                                        ? .white
                                        : DesignSystem.Colors.textPrimary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                        }
                    }
                }
            }
        }
    }

    private var matchStatsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Match Stats")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Minutes played
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                        Text("Minutes Played")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(minutesPlayed))")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                    }
                    Slider(value: $minutesPlayed, in: 0...120, step: 1)
                        .tint(DesignSystem.Colors.accentOrange)
                }

                Divider()

                // Goals
                HStack {
                    Image(systemName: "soccerball")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("Goals")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Stepper(value: $goals, in: 0...20) {
                        Text("\(goals)")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                // Assists
                HStack {
                    Image(systemName: "hand.point.up.fill")
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)
                    Text("Assists")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Stepper(value: $assists, in: 0...20) {
                        Text("\(assists)")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.secondaryBlue)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var resultCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Match Result")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(results, id: \.self) { resultOption in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                result = resultOption
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: iconForResult(resultOption))
                                    .font(.system(size: 24))
                                Text(labelForResult(resultOption))
                                    .font(DesignSystem.Typography.labelMedium)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                result == resultOption
                                    ? colorForResult(resultOption)
                                    : DesignSystem.Colors.cellBackground
                            )
                            .foregroundColor(
                                result == resultOption
                                    ? .white
                                    : DesignSystem.Colors.textPrimary
                            )
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                    }
                }
            }
        }
    }

    private var ratingCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Your Performance")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                matchRating = rating
                            }
                        } label: {
                            Image(systemName: rating <= matchRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(rating <= matchRating ? DesignSystem.Colors.xpGold : DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var notesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Notes")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                TextEditor(text: $matchNotes)
                    .font(DesignSystem.Typography.bodyMedium)
                    .frame(minHeight: 100)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.cellBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Helper Functions

    private func loadSeasons() {
        availableSeasons = MatchService.shared.fetchSeasons(for: player)
        // Use preselected season, or auto-select active season if available
        if selectedSeason == nil {
            selectedSeason = preselectedSeason ?? MatchService.shared.getActiveSeason(for: player)
        }
    }

    private func saveMatch() {
        let match = MatchService.shared.createMatch(
            for: player,
            date: matchDate,
            opponent: opponent.isEmpty ? nil : opponent,
            competition: competition.isEmpty ? nil : competition,
            minutesPlayed: Int16(minutesPlayed),
            goals: Int16(goals),
            assists: Int16(assists),
            positionPlayed: positionPlayed.isEmpty ? nil : positionPlayed,
            isHomeGame: isHomeGame,
            result: result,
            notes: matchNotes.isEmpty ? nil : matchNotes,
            rating: Int16(matchRating),
            season: selectedSeason
        )

        earnedXP = match.xpEarned

        // Award XP to player
        XPService.shared.awardMatchXP(to: player, xp: Int(earnedXP))

        HapticManager.shared.success()
        showMatchComplete = true
    }

    private func iconForResult(_ result: String) -> String {
        switch result {
        case "W": return "trophy.fill"
        case "D": return "equal.circle.fill"
        case "L": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private func labelForResult(_ result: String) -> String {
        switch result {
        case "W": return "Win"
        case "D": return "Draw"
        case "L": return "Loss"
        default: return result
        }
    }

    private func colorForResult(_ result: String) -> Color {
        switch result {
        case "W": return DesignSystem.Colors.primaryGreen
        case "D": return DesignSystem.Colors.accentOrange
        case "L": return .red.opacity(0.8)
        default: return .gray
        }
    }
}

// MARK: - Match Complete View

struct MatchCompleteView: View {
    let xpEarned: Int32
    let goals: Int
    let assists: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.Colors.darkModeBackground
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Celebration icon
                Image(systemName: "soccerball")
                    .font(.system(size: 80))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .padding()
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.primaryGreen.opacity(0.2))
                    )

                Text("Match Logged!")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Stats summary
                HStack(spacing: DesignSystem.Spacing.xl) {
                    VStack {
                        Text("\(goals)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("Goals")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    VStack {
                        Text("\(assists)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryBlue)
                        Text("Assists")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // XP earned
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DesignSystem.Colors.xpGold)
                    Text("+\(xpEarned) XP")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.xpGold)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.xpGold.opacity(0.2))
                .cornerRadius(DesignSystem.CornerRadius.pill)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(DesignSystem.Typography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    MatchLogView(player: Player())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
