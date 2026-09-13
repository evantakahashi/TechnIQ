import SwiftUI
import CoreData

// MARK: - Weekly review
//
// Opens at the end of a plan week (from Home's "Week n review ready" row or the full-time screen).
// The recap comes first and needs no network: sessions done vs planned, minutes, missed days,
// effort against last week, best drill. Then the coach's summary and each proposed change with its
// reason and a toggle; Apply writes only the ticked ones. Keep as is marks the week reviewed too.

struct WeeklyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiCoachService = AICoachService.shared

    let weekNumber: Int
    let player: Player

    @State private var plan: TrainingPlanModel?
    @State private var recap: WeekRecap?
    @State private var accepted: Set<String> = []
    @State private var applied = false

    private var coachName: String { CoachIdentity.name() }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar("Week \(weekNumber) review") {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    } trailing: {
                        TQNavAction("Close") { dismiss() }
                    }
                    .padding(.top, 8)

                    if let recap {
                        recapSection(recap)
                    }

                    coachSection
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            actionBar
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
    }

    // MARK: - Recap

    private func recapSection(_ recap: WeekRecap) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow("Full week · \(plan?.name ?? "your plan")", size: 11)
                TQDisplayTitle(recap.headline, size: .medium)
                if let trend = recap.effortTrend { TQBody(trend) }
            }
            TQStatRail(items: [
                .init("\(recap.done)", unit: "/\(max(recap.planned, recap.done))", label: "sessions"),
                .init("\(recap.minutes)", unit: "min", label: "trained"),
                .init("\(recap.missed)", label: "missed", accent: recap.missed == 0),
                .init(recap.averageEffort.map { String(format: "%.1f", $0) } ?? "–", unit: "/5", label: "effort")
            ])
            if let best = recap.bestDrill {
                TQRowList {
                    TQRow("Best drill", meta: .init(best), accessory: .none, verticalPadding: DesignSystem.Spacing.rowVertical)
                }
            }
        }
    }

    // MARK: - Coach

    @ViewBuilder
    private var coachSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            TQGroupHeader("\(coachName)'s review")
            if aiCoachService.isLoadingAdaptation {
                HStack(spacing: 12) {
                    TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 2.5, size: 20)
                    TQBody("\(coachName) is reading the week.", tone: .muted, size: 14)
                }
                .padding(.vertical, 8)
            } else if let response = aiCoachService.adaptationResponse {
                TQBody(response.summary)
                if response.adaptations.isEmpty {
                    TQRowList {
                        TQRow("No changes for next week", note: "keep going").disabled(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Proposed for week \(weekNumber + 1)")
                        TQRule()
                        ForEach(response.adaptations) { adaptation in
                            adaptationRow(adaptation)
                        }
                    }
                }
            } else if let error = aiCoachService.adaptationError {
                TQBanner(.error, lead: "Couldn't reach \(coachName).", message: error, actionTitle: "Retry") { fetch() }
            }
        }
    }

    private func adaptationRow(_ adaptation: PlanAdaptation) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TQTile(symbol: symbol(for: adaptation.type))
                VStack(alignment: .leading, spacing: 4) {
                    Text(adaptation.description)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(adaptation.reason ?? "Day \(adaptation.day)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { accepted.contains(adaptation.id) },
                    set: { on in if on { accepted.insert(adaptation.id) } else { accepted.remove(adaptation.id) } }
                ))
                .labelsHidden()
                .tint(DesignSystem.Colors.grass)
                .accessibilityLabel(adaptation.description)
            }
            .padding(.vertical, DesignSystem.Spacing.rowVertical)
            TQRule()
        }
    }

    private func symbol(for type: String) -> String {
        switch type {
        case "add_session": return "plus"
        case "modify_difficulty": return "arrow.up.right"
        case "remove_session": return "minus"
        case "swap_exercise": return "arrow.triangle.2.circlepath"
        default: return "circle"
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        let changes = aiCoachService.adaptationResponse?.adaptations ?? []
        let ticked = changes.filter { accepted.contains($0.id) }
        VStack(spacing: 10) {
            if applied {
                TQButton("Done") { dismiss() }
            } else if !ticked.isEmpty {
                TQButton("Apply \(ticked.count) change\(ticked.count == 1 ? "" : "s")", icon: "checkmark") { apply(ticked) }
                    .accessibilityIdentifier("review.apply")
                TQButton("Keep the plan as it is", style: .ghost) { keep() }
            } else {
                TQButton("Keep the plan as it is", style: .raised) { keep() }
                    .accessibilityIdentifier("review.keep")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(DesignSystem.Colors.surfaceBase)
    }

    private func load() {
        guard let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else { return }
        self.plan = plan
        let calendar = Calendar.current
        let startDate = PlanSchedule.startDate(of: plan)
        recap = WeekRecap.build(
            plan: plan,
            weekNumber: weekNumber,
            sessions: Self.recapSessions(for: player, plan: plan, weekNumber: weekNumber, startDate: startDate, calendar: calendar),
            previousSessions: Self.recapSessions(for: player, plan: plan, weekNumber: weekNumber - 1, startDate: startDate, calendar: calendar),
            startDate: startDate,
            now: Date(),
            calendar: calendar
        )
        fetch()
    }

    private func fetch() {
        guard let plan else { return }
        Task { await aiCoachService.fetchPlanAdaptation(for: player, plan: plan, weekNumber: weekNumber, recap: recap) }
    }

    /// The player's sessions that fell inside the plan week's seven-day window.
    static func recapSessions(for player: Player, plan: TrainingPlanModel, weekNumber: Int, startDate: Date, calendar: Calendar) -> [WeekRecap.Session] {
        guard weekNumber >= 1 else { return [] }
        let weekStart = PlanSchedule.date(week: weekNumber, dayNumber: 1, dayOfWeek: nil, startDate: startDate, calendar: calendar)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        let sessions = ((player.sessions as? Set<TrainingSession>) ?? []).filter {
            guard let date = $0.date else { return false }
            return date >= weekStart && date < weekEnd
        }
        return sessions.map { session in
            let exercises = (session.exercises as? Set<SessionExercise>) ?? []
            var ratings: [String: Int] = [:]
            for item in exercises {
                if let name = item.exercise?.name { ratings[name] = Int(item.performanceRating) }
            }
            return WeekRecap.Session(
                date: session.date ?? weekStart,
                minutes: Int(session.duration),
                rating: Int(session.overallRating),
                drillNames: exercises.compactMap { $0.exercise?.name },
                drillRatings: ratings
            )
        }
    }

    private func apply(_ changes: [PlanAdaptation]) {
        guard let plan else { return }
        for change in changes {
            TrainingPlanService.shared.applyAdaptation(change, to: plan, targetWeek: weekNumber + 1)
        }
        aiCoachService.markWeekReviewed(planID: plan.id, weekNumber: weekNumber)
        HapticManager.shared.success()
        applied = true
    }

    private func keep() {
        if let plan { aiCoachService.markWeekReviewed(planID: plan.id, weekNumber: weekNumber) }
        HapticManager.shared.selectionChanged()
        dismiss()
    }
}
