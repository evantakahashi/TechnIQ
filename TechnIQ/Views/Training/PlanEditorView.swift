import SwiftUI

// MARK: - Plan details editor
//
// Name, description and level for a stored plan. Days and sessions are edited from the schedule
// (tap a day → Edit day); weeks are added or removed from the plan's Edit menu.

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: TrainingPlanModel
    let player: Player
    var onSave: () -> Void = {}

    @State private var name: String
    @State private var description: String
    @State private var difficultyIndex: Int

    private let difficulties = PlanDifficulty.allCases

    init(plan: TrainingPlanModel, player: Player, onSave: @escaping () -> Void = {}) {
        self.plan = plan
        self.player = player
        self.onSave = onSave
        _name = State(initialValue: plan.name)
        _description = State(initialValue: plan.description)
        _difficultyIndex = State(initialValue: PlanDifficulty.allCases.firstIndex(of: plan.difficulty) ?? 0)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Edit plan") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    TQNavAction("Save") { save() }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                        .accessibilityIdentifier("planEditor.save")
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    TQFormField("Name", text: $name, placeholder: "Striker development")
                    TQFormField("Description", text: $description, placeholder: "What this plan is for")
                }

                VStack(alignment: .leading, spacing: 10) {
                    TQGroupHeader("Level")
                    TQSegment(options: difficulties.map(\.displayName), selectedIndex: $difficultyIndex)
                }

                TQRowList {
                    TQRow("Days and drills", subtitle: "Tap a day on the schedule, then Edit day", accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical).disabled(true)
                    TQRow("Weeks", subtitle: "Add a week or remove the last one from the Edit menu", accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical).disabled(true)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func save() {
        let difficulty = difficulties[min(max(difficultyIndex, 0), difficulties.count - 1)]
        TrainingPlanService.shared.updatePlanDetails(planId: plan.id, name: name, description: description, difficulty: difficulty)
        HapticManager.shared.success()
        onSave()
        dismiss()
    }
}
