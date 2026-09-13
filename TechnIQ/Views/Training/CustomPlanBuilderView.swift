import SwiftUI

// MARK: - Build it yourself
//
// A custom plan in one screen: name, weeks, training days, session type, length, intensity, level.
// It creates the whole week × day × session skeleton, so the plan can be started and edited
// straight away; drills are attached per day from the schedule.

struct CustomPlanBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    var onCreated: (TrainingPlanModel) -> Void = { _ in }

    @State private var name = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var trainingDays: Set<DayOfWeek> = [.monday, .wednesday, .friday]
    @State private var sessionTypeIndex = 0
    @State private var minutes = 30
    @State private var intensity = 3
    @State private var difficultyIndex = 1
    @State private var created: TrainingPlanModel?

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

    private func create() {
        let spec = TrainingPlanService.CustomPlanSpec(
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
        guard let plan = TrainingPlanService.shared.createCustomPlan(spec, for: player) else { return }
        HapticManager.shared.success()
        let model = plan.toModel()
        created = model
        onCreated(model)
    }
}
