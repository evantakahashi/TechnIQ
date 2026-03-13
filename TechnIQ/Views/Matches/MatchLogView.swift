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

    // Performance categories for strengths/weaknesses
    let performanceCategories: [String: [String]] = [
        "Technical": ["Passing", "Shooting", "Dribbling", "First Touch", "Ball Control", "Crossing"],
        "Physical": ["Speed", "Stamina", "Strength", "Agility"],
        "Mental": ["Positioning", "Vision", "Decision Making", "Composure", "Communication"]
    ]

    // Strengths/Weaknesses state
    @State private var selectedStrengths: Set<String> = []
    @State private var selectedWeaknesses: Set<String> = []
    @State private var customStrength: String = ""
    @State private var customWeakness: String = ""

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
                        strengthsCard
                        weaknessesCard
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

    private var strengthsCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("What went well?")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    if !selectedStrengths.isEmpty {
                        Text("\(selectedStrengths.count)/3")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                performanceSelectionGrid(
                    selectedItems: $selectedStrengths,
                    excludedItems: selectedWeaknesses,
                    accentColor: DesignSystem.Colors.primaryGreen
                )

                // Custom strength input
                HStack {
                    TextField("Add custom...", text: $customStrength)
                        .font(DesignSystem.Typography.bodyMedium)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.cellBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)

                    if !customStrength.isEmpty && selectedStrengths.count < 3 {
                        Button {
                            let trimmed = customStrength.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !selectedStrengths.contains(trimmed) {
                                selectedStrengths.insert(trimmed)
                                customStrength = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
        }
    }

    private var weaknessesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accentOrange)
                    Text("What needs work?")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    if !selectedWeaknesses.isEmpty {
                        Text("\(selectedWeaknesses.count)/3")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                performanceSelectionGrid(
                    selectedItems: $selectedWeaknesses,
                    excludedItems: selectedStrengths,
                    accentColor: DesignSystem.Colors.accentOrange
                )

                // Custom weakness input
                HStack {
                    TextField("Add custom...", text: $customWeakness)
                        .font(DesignSystem.Typography.bodyMedium)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.cellBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)

                    if !customWeakness.isEmpty && selectedWeaknesses.count < 3 {
                        Button {
                            let trimmed = customWeakness.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !selectedWeaknesses.contains(trimmed) {
                                selectedWeaknesses.insert(trimmed)
                                customWeakness = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accentOrange)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
        }
    }

    private func performanceSelectionGrid(
        selectedItems: Binding<Set<String>>,
        excludedItems: Set<String>,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(["Technical", "Physical", "Mental"], id: \.self) { category in
                if let skills = performanceCategories[category] {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(category)
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        FlowLayout(spacing: DesignSystem.Spacing.xs) {
                            ForEach(skills, id: \.self) { skill in
                                let isSelected = selectedItems.wrappedValue.contains(skill)
                                let isExcluded = excludedItems.contains(skill)
                                let isDisabled = isExcluded || (!isSelected && selectedItems.wrappedValue.count >= 3)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isSelected {
                                            selectedItems.wrappedValue.remove(skill)
                                        } else if !isDisabled {
                                            selectedItems.wrappedValue.insert(skill)
                                        }
                                    }
                                } label: {
                                    Text(skill)
                                        .font(DesignSystem.Typography.labelSmall)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                        .background(
                                            isSelected ? accentColor : DesignSystem.Colors.cellBackground
                                        )
                                        .foregroundColor(
                                            isSelected ? .white :
                                            isDisabled ? DesignSystem.Colors.textTertiary :
                                            DesignSystem.Colors.textPrimary
                                        )
                                        .cornerRadius(DesignSystem.CornerRadius.pill)
                                        .opacity(isDisabled && !isSelected ? 0.5 : 1.0)
                                }
                                .disabled(isDisabled && !isSelected)
                            }
                        }
                    }
                }
            }

            // Show selected custom items as removable pills
            let customItems = selectedItems.wrappedValue.filter { item in
                !performanceCategories.values.flatMap { $0 }.contains(item)
            }
            if !customItems.isEmpty {
                FlowLayout(spacing: DesignSystem.Spacing.xs) {
                    ForEach(Array(customItems), id: \.self) { item in
                        Button {
                            selectedItems.wrappedValue.remove(item)
                        } label: {
                            HStack(spacing: 4) {
                                Text(item)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                            }
                            .font(DesignSystem.Typography.labelSmall)
                            .fontWeight(.medium)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.pill)
                        }
                    }
                }
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
        // Convert selected strengths/weaknesses to comma-separated strings
        let strengthsString = selectedStrengths.isEmpty ? nil : selectedStrengths.sorted().joined(separator: ",")
        let weaknessesString = selectedWeaknesses.isEmpty ? nil : selectedWeaknesses.sorted().joined(separator: ",")

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
            season: selectedSeason,
            strengths: strengthsString,
            weaknesses: weaknessesString
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
