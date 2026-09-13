import SwiftUI

// MARK: - Plan preview (before saving an AI plan)
//
// The plan the coach came back with: eyebrow, name, description, a stat rail, one row per week
// (tap to open its days), then Save / Regenerate / Modify. Nothing is written until Save.

struct AITrainingPlanPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let generatedPlan: GeneratedPlanStructure
    let player: Player
    let customName: String
    let onRegenerate: () -> Void
    let onModifyParameters: () -> Void
    let onSave: () -> Void

    @State private var expandedWeeks: Set<Int> = []
    @State private var isSaving = false

    private var displayName: String {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? generatedPlan.name : trimmed
    }

    private var totalSessions: Int {
        var count = 0
        for week in generatedPlan.weeks {
            for day in week.days { count += day.sessions.count }
        }
        return count
    }

    private var totalHours: Int {
        var minutes = 0
        for week in generatedPlan.weeks {
            for day in week.days {
                for session in day.sessions { minutes += session.duration }
            }
        }
        return Int((Double(minutes) / 60).rounded())
    }

    private var sessionsPerWeek: Int {
        generatedPlan.weeks.first.map { $0.days.filter { !$0.isRestDay }.count } ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar("Preview") {
                        TQNavAction("Cancel") { dismiss() }
                    } trailing: {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow([generatedPlan.parsedDifficulty.displayName, generatedPlan.targetRole ?? generatedPlan.parsedCategory.displayName].joined(separator: " · "), size: 11)
                        TQDisplayTitle(displayName, size: .medium)
                        TQBody(generatedPlan.description)
                    }

                    TQStatRail(items: [
                        .init("\(generatedPlan.weeks.count)", label: "weeks"),
                        .init("\(sessionsPerWeek)", unit: "×/wk", label: "sessions"),
                        .init("\(totalSessions)", label: "total"),
                        .init("\(totalHours)", unit: "h", label: "time")
                    ])

                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Week by week")
                        TQRowList {
                            ForEach(generatedPlan.weeks, id: \.weekNumber) { week in
                                weekRows(week)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            VStack(spacing: 10) {
                TQButton("Save plan", icon: "checkmark", isLoading: isSaving) {
                    isSaving = true
                    onSave()
                }
                .accessibilityIdentifier("planPreview.save")
                HStack(spacing: 10) {
                    TQButton("Regenerate", style: .raised, size: .compact) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onRegenerate() }
                    }
                    TQButton("Modify", style: .raised, size: .compact) {
                        dismiss()
                        onModifyParameters()
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(DesignSystem.Colors.surfaceBase)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func weekMinutes(_ week: GeneratedWeek) -> Int {
        var minutes = 0
        for day in week.days where !day.isRestDay {
            for session in day.sessions { minutes += session.duration }
        }
        return minutes
    }

    @ViewBuilder
    private func weekRows(_ week: GeneratedWeek) -> some View {
        let trainingDays = week.days.filter { !$0.isRestDay }
        let expanded = expandedWeeks.contains(week.weekNumber)
        TQRow(
            "Week \(week.weekNumber) · \(week.focusArea)",
            subtitle: "\(trainingDays.count) session\(trainingDays.count == 1 ? "" : "s") · \(weekMinutes(week)) min",
            leading: .index(String(format: "%02d", week.weekNumber), tone: .muted),
            accessory: .none,
            verticalPadding: DesignSystem.Spacing.rowVertical,
            action: {
                withAnimation(DesignSystem.Animation.quick) {
                    if expanded { expandedWeeks.remove(week.weekNumber) } else { expandedWeeks.insert(week.weekNumber) }
                }
            }
        )
        if expanded {
            ForEach(trainingDays, id: \.dayNumber) { day in
                ForEach(Array(day.sessions.enumerated()), id: \.offset) { _, session in
                    TQRow(
                        "\(day.parsedDayOfWeek?.shortName ?? "Day \(day.dayNumber)") · \(session.parsedSessionType.displayName)",
                        subtitle: "\(session.duration) min · intensity \(session.intensity)/5" + (session.suggestedExerciseNames.isEmpty ? "" : " · " + session.suggestedExerciseNames.prefix(2).joined(separator: ", ")),
                        leading: .tile(TQTile.category(session.sessionType)),
                        accessory: .none,
                        verticalPadding: 10,
                        titleFont: DesignSystem.Typography.titleSmall
                    )
                }
            }
        }
    }
}
