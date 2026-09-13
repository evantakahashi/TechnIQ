import SwiftUI
import CoreData

// MARK: - Training profile (You → Training profile)
//
// The onboarding answers, editable: goal, training days, position, stronger foot, level and up to
// three weak spots. Weak spots feed Train's ordering, the generator and the coach at once. Changing
// the training days re-binds the active plan's future weeks to the new weekdays.

struct TrainingProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let player: Player
    var onSaved: () -> Void = {}

    @State private var goal: String
    @State private var days: Set<DayOfWeek>
    @State private var positionIndex: Int
    @State private var footIndex: Int
    @State private var levelIndex: Int
    @State private var weakSpots: [WeaknessCategory]
    @State private var showingRebindNote = false

    private let goals = OnboardingMapping.goals
    private let positions = OnboardingMapping.positions
    private let feet = OnboardingMapping.feet
    private let levels = OnboardingMapping.experienceLevels
    private let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }
    private let originalDays: Set<DayOfWeek>

    init(player: Player, onSaved: @escaping () -> Void = {}) {
        self.player = player
        self.onSaved = onSaved
        let profile = player.playerProfile
        _goal = State(initialValue: profile?.trainingGoal ?? OnboardingMapping.goals[0])
        let dayList = Set(profile?.trainingDayList ?? [.monday, .wednesday, .friday])
        _days = State(initialValue: dayList)
        originalDays = dayList
        _positionIndex = State(initialValue: OnboardingMapping.positions.firstIndex(of: player.position ?? "") ?? 2)
        _footIndex = State(initialValue: OnboardingMapping.feet.firstIndex(of: player.dominantFoot ?? "") ?? 1)
        _levelIndex = State(initialValue: OnboardingMapping.experienceLevels.firstIndex(of: player.experienceLevel ?? "") ?? 0)
        _weakSpots = State(initialValue: (profile?.selfIdentifiedWeaknesses ?? []).compactMap { name in WeaknessCategory.allCases.first { $0.displayName == name } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Training profile") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    TQNavAction("Save") { save() }
                        .accessibilityIdentifier("trainingProfile.save")
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    TQEyebrow("What the coach works from", size: 11)
                    TQDisplayTitle("Your\ntraining", size: .medium)
                    TQBody("Change any of it. Weak spots reorder Train and steer the coach; training days move your plan's coming weeks.")
                }

                group("Goal") {
                    TQChipRow {
                        ForEach(goals, id: \.self) { item in
                            TQChip(item, isSelected: goal == item) { goal = item }
                        }
                    }
                }

                group("Training days") {
                    TQChipRow {
                        ForEach(weekdays, id: \.self) { day in
                            TQChip(day.shortName, isSelected: days.contains(day)) {
                                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                            }
                        }
                    }
                    if days.isEmpty {
                        TQBody("Pick at least one day.", tone: .muted, size: 13)
                    }
                }

                group("Position") {
                    TQChipRow {
                        ForEach(Array(positions.enumerated()), id: \.offset) { index, item in
                            TQChip(item, isSelected: positionIndex == index) { positionIndex = index }
                        }
                    }
                }
                group("Stronger foot") { TQSegment(options: feet, selectedIndex: $footIndex) }
                group("Level") {
                    TQChipRow {
                        ForEach(Array(levels.enumerated()), id: \.offset) { index, item in
                            TQChip(item, isSelected: levelIndex == index) { levelIndex = index }
                        }
                    }
                }

                group("Weak spots · up to \(OnboardingMapping.maxWeakSpots)") {
                    TQChipRow {
                        ForEach(WeaknessCategory.allCases, id: \.self) { skill in
                            TQChip(skill.displayName, isSelected: weakSpots.contains(skill)) { toggle(skill) }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Plan days moved", isPresented: $showingRebindNote) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your plan's coming weeks now fall on \(days.sorted { $0.sortOrder < $1.sortOrder }.map(\.shortName).joined(separator: ", ")). This week stays as it is.")
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TQGroupHeader(title)
            content()
        }
    }

    private func toggle(_ skill: WeaknessCategory) {
        if let index = weakSpots.firstIndex(of: skill) {
            weakSpots.remove(at: index)
        } else if weakSpots.count < OnboardingMapping.maxWeakSpots {
            weakSpots.append(skill)
        }
        HapticManager.shared.selectionChanged()
    }

    private func save() {
        guard !days.isEmpty else { return }
        player.position = positions[min(max(positionIndex, 0), positions.count - 1)]
        player.dominantFoot = feet[min(max(footIndex, 0), feet.count - 1)]
        player.experienceLevel = levels[min(max(levelIndex, 0), levels.count - 1)]

        let profile = player.playerProfile ?? {
            let created = PlayerProfile(context: viewContext)
            created.id = UUID()
            created.createdAt = Date()
            created.player = player
            player.playerProfile = created
            return created
        }()
        profile.trainingGoal = goal
        profile.trainingDayList = Array(days)
        profile.selfIdentifiedWeaknesses = weakSpots.isEmpty ? nil : weakSpots.map(\.displayName)
        profile.updatedAt = Date()
        CoreDataManager.shared.save()

        var rebound = false
        if days != originalDays, let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
            rebound = TrainingPlanService.shared.rebindTrainingDays(planId: plan.id, to: Array(days))
            NotificationManager.shared.refresh(for: player)
        }
        HapticManager.shared.success()
        onSaved()
        if rebound { showingRebindNote = true } else { dismiss() }
    }
}
