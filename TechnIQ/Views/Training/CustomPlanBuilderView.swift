import SwiftUI

// MARK: - Build it yourself
//
// A custom plan in one screen: name, weeks, training days, session type, length, intensity, level,
// position, weak spots and next match. Level, position, weak spots, days and next match start from
// the Training profile (PlanBuilderPrefill); weak spots become the weeks' focus. It creates the
// whole week × day × session skeleton, so the plan can be started and edited straight away; drills
// are attached per day from the schedule. The next match is written back to the profile.

struct CustomPlanBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    var onCreated: (TrainingPlanModel) -> Void = { _ in }

    @State private var name = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var trainingDays: Set<DayOfWeek>
    @State private var sessionTypeIndex = 0
    @State private var minutes = 30
    @State private var intensity = 3
    @State private var difficultyIndex: Int
    @State private var position: String
    @State private var weakSpots: [WeaknessCategory]
    @State private var nextMatch: Date?
    @State private var created: TrainingPlanModel?

    init(player: Player, onCreated: @escaping (TrainingPlanModel) -> Void = { _ in }) {
        self.player = player
        self.onCreated = onCreated
        let prefill = PlanBuilderPrefill.from(player: player)
        _trainingDays = State(initialValue: Set(prefill.trainingDays))
        _difficultyIndex = State(initialValue: PlanDifficulty.allCases.firstIndex(of: prefill.difficulty) ?? 1)
        _position = State(initialValue: prefill.position ?? "")
        _weakSpots = State(initialValue: prefill.weakSpots)
        _nextMatch = State(initialValue: prefill.nextMatchDate)
    }

    private let sessionTypes: [SessionType] = [.technical, .physical, .tactical]
    private let difficulties = PlanDifficulty.allCases
    private let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !trainingDays.isEmpty
    }

    private var summary: String {
        let sessions = weeks * trainingDays.count
        let hours = Double(sessions * minutes) / 60
        return "\(weeks) week\(weeks == 1 ? "" : "s") · \(trainingDays.count)×/wk · \(sessions) sessions · \(String(format: "%.1f", hours)) h"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("New plan · Custom") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                if let created {
                    createdContent(created)
                } else {
                    form
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow("Build it yourself", size: 11)
                TQDisplayTitle("Your plan,\nyour week", size: .medium)
                TQBody("Pick the shape; add drills to each day from the schedule afterwards.")
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                TQFormField("Name", text: $name, placeholder: "Pre-season sharpening")
                TQFormField("Description", text: $description, placeholder: "Optional")
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Shape")
                TQRule()
                TQValueStepper(label: "Weeks", value: $weeks, range: 1...12) { "\($0)" }
                TQRule()
                TQValueStepper(label: "Session length", value: $minutes, range: 10...120, step: 5) { "\($0) min" }
                TQRule()
                TQValueStepper(label: "Intensity", value: $intensity, range: 1...5) { "\($0) / 5" }
                TQRule()
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Training days")
                TQChipRow {
                    ForEach(weekdays, id: \.self) { day in
                        TQChip(day.shortName, isSelected: trainingDays.contains(day)) {
                            if trainingDays.contains(day) { trainingDays.remove(day) } else { trainingDays.insert(day) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Session type")
                TQSegment(options: sessionTypes.map(\.displayName), selectedIndex: $sessionTypeIndex)
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Level")
                TQSegment(options: difficulties.map(\.displayName), selectedIndex: $difficultyIndex)
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Position")
                TQChipRow {
                    ForEach(OnboardingMapping.positions, id: \.self) { item in
                        TQChip(item, isSelected: position == item) { position = item }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Weak spots · week focus")
                TQChipRow {
                    ForEach(WeaknessCategory.allCases, id: \.self) { skill in
                        TQChip(skill.displayName, isSelected: weakSpots.contains(skill)) { toggleWeakSpot(skill) }
                    }
                }
                if !weakSpots.isEmpty {
                    TQBody("Weeks rotate through \(weakSpots.map(\.displayName).joined(separator: ", ")).", tone: .muted, size: 13)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Next match")
                TQRule()
                TQDateRow("Next match", subtitle: "Light the day before, recovery the day after",
                          date: $nextMatch, range: NextMatchDefaults.range()) { NextMatchDefaults.suggested() }
                    .accessibilityIdentifier("customPlan.nextMatch")
            }

            TQBody(summary, tone: .muted, size: 13)

            TQButton("Create plan") { create() }
                .disabled(!canCreate)
                .accessibilityIdentifier("customPlan.create")
        }
    }

    private func createdContent(_ plan: TrainingPlanModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQHeroCard(
                eyebrow: "Plan ready · \(plan.durationWeeks) weeks",
                title: plan.name,
                body: "It's in My plans. Start it from its schedule, or add drills to each day first.",
                actionTitle: "Done",
                actionIcon: nil,
                markings: .heroSimple,
                action: { dismiss() }
            )
        }
    }

    private func toggleWeakSpot(_ skill: WeaknessCategory) {
        if let index = weakSpots.firstIndex(of: skill) {
            weakSpots.remove(at: index)
        } else if weakSpots.count < OnboardingMapping.maxWeakSpots {
            weakSpots.append(skill)
        }
        HapticManager.shared.selectionChanged()
    }

    private func create() {
        // The next match is the profile's; write it first so the new plan is shaped around it.
        TrainingPlanService.shared.setNextMatch(nextMatch, for: player)
        var spec = TrainingPlanService.CustomPlanSpec(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            weeks: weeks,
            trainingDays: weekdays.filter { trainingDays.contains($0) },
            sessionType: sessionTypes[min(max(sessionTypeIndex, 0), sessionTypes.count - 1)],
            minutes: minutes,
            intensity: intensity,
            difficulty: difficulties[min(max(difficultyIndex, 0), difficulties.count - 1)],
            category: sessionTypes[min(max(sessionTypeIndex, 0), sessionTypes.count - 1)] == .physical ? .physical
                : (sessionTypes[min(max(sessionTypeIndex, 0), sessionTypes.count - 1)] == .tactical ? .tactical : .technical)
        )
        spec.weakSpots = weakSpots
        spec.position = position.isEmpty ? nil : position
        guard let plan = TrainingPlanService.shared.createCustomPlan(spec, for: player) else { return }
        HapticManager.shared.success()
        let model = plan.toModel()
        created = model
        onCreated(model)
    }
}
