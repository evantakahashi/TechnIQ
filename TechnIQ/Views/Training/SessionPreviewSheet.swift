import SwiftUI

// MARK: - Before the clock starts
//
// A multi-drill plan session used to open straight on drill one. This sheet shows what the session
// holds first: drills in order with minutes and level, total time, and what to set up, then Start.

struct SessionPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let eyebrow: String
    let title: String
    let exercises: [Exercise]
    let onStart: () -> Void

    private var totalMinutes: Int {
        exercises.reduce(0) { $0 + max(1, Int($1.estimatedDurationSeconds) / 60) }
    }

    private var maxLevel: Int {
        exercises.map { Int($0.difficulty) }.max() ?? 0
    }

    /// Setup lines from drills that have one ("Two cones 8 m out, server on the byline").
    private var setupLines: [String] {
        exercises.compactMap { exercise in
            guard let setup = DrillContent.parse(exercise.instructions).setup, !setup.isEmpty else { return nil }
            return "\(exercise.name ?? "Drill"): \(setup)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar("Session") {
                        TQNavAction("Close") { dismiss() }
                    } trailing: {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow(eyebrow, size: 11)
                        TQDisplayTitle(title, size: .medium)
                    }

                    TQStatRail(items: [
                        .init("\(exercises.count)", label: "drills"),
                        .init("\(totalMinutes)", unit: "min", label: "total"),
                        .init(maxLevel > 0 ? "\(maxLevel)" : "–", label: "top level")
                    ])

                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("In order")
                        TQRowList {
                            ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                                TQRow(
                                    exercise.name ?? "Drill",
                                    subtitle: TrainLibraryModel.meta(for: exercise.trainDrill, showSkill: true),
                                    leading: .index(String(format: "%02d", index + 1)),
                                    accessory: .none,
                                    verticalPadding: DesignSystem.Spacing.rowVertical
                                )
                            }
                        }
                    }

                    if !setupLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            TQGroupHeader("Set up")
                            ForEach(setupLines, id: \.self) { line in
                                TQBody(line, tone: .base, size: 14)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            TQButton("Start session", icon: "play.fill") {
                dismiss()
                onStart()
            }
            .accessibilityIdentifier("preview.start")
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(DesignSystem.Colors.surfaceBase)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
