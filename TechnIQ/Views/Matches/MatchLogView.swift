import SwiftUI
import CoreData

// MARK: - Log a match (sheet)
//
// One flat form: result first, then the match, your numbers, and what went well / needs work
// (up to three each, feeding weakness analysis). Save writes the match and closes.

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
    @State private var didDefaultDate = false
    @State private var opponent = ""
    @State private var competition = ""
    @State private var selectedSeason: Season?
    @State private var positionPlayed = ""
    @State private var isHomeGame = true
    @State private var result = "W"

    // Stats
    @State private var minutesPlayed = 90
    @State private var goals = 0
    @State private var assists = 0

    // Rating and notes
    @State private var matchRating = 3
    @State private var matchNotes = ""

    // UI State
    @State private var availableSeasons: [Season] = []
    @State private var showingCreateSeason = false

    // Strengths / weaknesses
    @State private var selectedStrengths: Set<String> = []
    @State private var selectedWeaknesses: Set<String> = []
    @State private var customStrength = ""
    @State private var customWeakness = ""

    private let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LM", "RM", "LW", "RW", "ST", "CF"]
    private let results = ["W", "D", "L"]
    private let skills = [
        "Passing", "Shooting", "Dribbling", "First Touch", "Ball Control", "Crossing",
        "Speed", "Stamina", "Strength", "Agility",
        "Positioning", "Vision", "Decision Making", "Composure", "Communication"
    ]
    private let maxPicks = 3

    var body: some View {
        VStack(spacing: 0) {
            TQNavBar("Log Match") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                TQNavAction("Save") { saveMatch() }
                    .accessibilityIdentifier("matchLog.save")
            }
            .padding(.top, 8)
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    resultSection
                    matchSection
                    numbersSection
                    positionSection
                    picksSection(title: "What went well", selected: $selectedStrengths, excluded: selectedWeaknesses, custom: $customStrength)
                    picksSection(title: "What needs work", selected: $selectedWeaknesses, excluded: selectedStrengths, custom: $customWeakness)
                    notesSection
                    TQButton("Save match") { saveMatch() }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCreateSeason) {
            CreateSeasonView(player: player) { newSeason in
                selectedSeason = newSeason
                loadSeasons()
            }
        }
        .onAppear {
            loadSeasons()
            // Logging the match just played: open on the next match's day (today or ≤ 2 days back).
            if !didDefaultDate {
                didDefaultDate = true
                matchDate = MatchScheduleLink.defaultLogDate(nextMatchDate: player.playerProfile?.nextMatchDate, now: Date(), calendar: .current)
            }
        }
    }

    // MARK: - Sections

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TQDisplayTitle("How did\nit go?", size: .medium)
            TQSegment(options: ["Win", "Draw", "Loss"], selectedIndex: resultIndex, style: .detached)
        }
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Match")
            TQRule()
            controlRow("Date") {
                DatePicker("", selection: $matchDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.grass)
                    .accessibilityLabel("Date")
            }
            controlRow("Season") { seasonMenu }
            controlRow("Venue") {
                TQSegment(options: ["Home", "Away"], selectedIndex: venueIndex)
                    .frame(width: 168)
            }
            VStack(spacing: 14) {
                TQFormField("Opponent", text: $opponent, placeholder: "Optional")
                TQFormField("Competition", text: $competition, placeholder: "Optional")
            }
            .padding(.top, 16)
        }
    }

    private var seasonMenu: some View {
        Menu {
            Button("No season") { selectedSeason = nil }
            ForEach(availableSeasons, id: \.objectID) { season in
                Button(season.name ?? "Unnamed") { selectedSeason = season }
            }
            Divider()
            Button {
                showingCreateSeason = true
            } label: {
                Label("New season", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedSeason?.name ?? "None")
                    .font(Font.system(size: 15, weight: .semibold).width(.condensed))
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .frame(minHeight: DesignSystem.Spacing.hitTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Season")
    }

    private var numbersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Your game")
            TQRule()
            TQValueStepper(label: "Minutes", value: $minutesPlayed, range: 0...120, step: 5) { "\($0)′" }
                .overlay(alignment: .bottom) { TQRule() }
            TQValueStepper(label: "Goals", value: $goals, range: 0...20)
                .overlay(alignment: .bottom) { TQRule() }
            TQValueStepper(label: "Assists", value: $assists, range: 0...20)
                .overlay(alignment: .bottom) { TQRule() }
            TQValueStepper(label: "Your rating", value: $matchRating, range: 1...5) { "\($0) / 5" }
                .overlay(alignment: .bottom) { TQRule() }
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TQGroupHeader("Position played")
            FlowLayout(spacing: 6) {
                ForEach(positions, id: \.self) { position in
                    TQChip(position, isSelected: positionPlayed == position) {
                        positionPlayed = positionPlayed == position ? "" : position
                    }
                }
            }
        }
    }

    private func picksSection(title: String, selected: Binding<Set<String>>, excluded: Set<String>, custom: Binding<String>) -> some View {
        let picks = selected.wrappedValue
        let customPicks = picks.filter { !skills.contains($0) }.sorted()
        let isFull = picks.count >= maxPicks
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                TQGroupHeader(title)
                Spacer()
                TQMeta("\(picks.count) / \(maxPicks)", tone: picks.isEmpty ? .muted : .chalk, size: 13)
            }
            FlowLayout(spacing: 6) {
                ForEach(skills + customPicks, id: \.self) { skill in
                    let isSelected = picks.contains(skill)
                    let isDisabled = !isSelected && (isFull || excluded.contains(skill))
                    TQChip(skill, isSelected: isSelected, icon: skills.contains(skill) ? nil : "xmark") {
                        if isSelected {
                            selected.wrappedValue.remove(skill)
                        } else {
                            selected.wrappedValue.insert(skill)
                        }
                    }
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.4 : 1)
                }
            }
            if !isFull {
                HStack(spacing: 10) {
                    customField(custom)
                    if !custom.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        TQButton("Add", style: .raised, size: .compact, fullWidth: false) {
                            addCustom(custom, to: selected)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func customField(_ text: Binding<String>) -> some View {
        TextField("Something else", text: text)
            .font(Font.system(size: 15, weight: .regular))
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .tint(DesignSystem.Colors.grass)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(DesignSystem.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TQGroupHeader("Notes")
            TextEditor(text: $matchNotes)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(10)
                .background(DesignSystem.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))
                .accessibilityLabel("Notes")
        }
    }

    private func controlRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { TQRule() }
    }

    // MARK: - Bindings

    private var resultIndex: Binding<Int> {
        Binding(get: { results.firstIndex(of: result) ?? 0 },
                set: { result = results[min(max($0, 0), results.count - 1)] })
    }

    private var venueIndex: Binding<Int> {
        Binding(get: { isHomeGame ? 0 : 1 }, set: { isHomeGame = $0 == 0 })
    }

    // MARK: - Actions

    private func addCustom(_ text: Binding<String>, to selected: Binding<Set<String>>) {
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, selected.wrappedValue.count < maxPicks else { return }
        selected.wrappedValue.insert(trimmed)
        text.wrappedValue = ""
    }

    private func loadSeasons() {
        availableSeasons = MatchService.shared.fetchSeasons(for: player)
        // Use preselected season, or auto-select active season if available
        if selectedSeason == nil {
            selectedSeason = preselectedSeason ?? MatchService.shared.getActiveSeason(for: player)
        }
    }

    private func saveMatch() {
        let strengthsString = selectedStrengths.isEmpty ? nil : selectedStrengths.sorted().joined(separator: ",")
        let weaknessesString = selectedWeaknesses.isEmpty ? nil : selectedWeaknesses.sorted().joined(separator: ",")

        _ = MatchService.shared.createMatch(
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
        // Played on/after the next match's day → that match is done; the plan is re-checked.
        TrainingPlanService.shared.matchLogged(on: matchDate, for: player)

        HapticManager.shared.success()
        onComplete?()
        dismiss()
    }
}

#if DEBUG
#Preview {
    MatchLogView(player: Player())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
#endif
