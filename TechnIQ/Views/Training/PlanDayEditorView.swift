import SwiftUI
import CoreData

// MARK: - Day editor (the one editing screen)
//
// Opened from a plan's day sheet. Everything about one day on one screen: the week's focus, a
// rest-day toggle, and each session's type, length, intensity and drills (add from the library,
// remove with a tap). Edits save as they happen; Done just closes. Sessions already completed are
// shown but locked, so history stays true.

struct PlanDayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var planService = TrainingPlanService.shared

    let player: Player
    let planID: UUID
    let weekID: UUID
    let dayID: UUID
    var onChange: () -> Void = {}

    @State private var week: PlanWeekModel?
    @State private var day: PlanDayModel?
    @State private var focus = ""
    @State private var isRestDay = false
    @State private var drillNames: [UUID: String] = [:]
    @State private var addingToSession: PlanSessionModel?
    @State private var refreshToken = 0

    private let sessionTypes = SessionType.allCases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar(title) {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") { onChange(); dismiss() }
                        .accessibilityIdentifier("dayEditor.done")
                }
                .padding(.top, 8)

                if let day {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        TQEyebrow(day.isCompleted ? "Done · locked" : (isRestDay ? "Rest day" : "Training day"), size: 11)
                        TQFormField("Week focus", text: $focus, placeholder: "e.g. Weak-foot finishing")
                            .onSubmit { saveFocus() }
                    }

                    if !day.isCompleted {
                        toggleRow("Rest day", subtitle: "No sessions; the plan moves on to the next training day", isOn: $isRestDay)
                            .onChange(of: isRestDay) { _, value in
                                planService.setRestDay(dayId: dayID, isRestDay: value)
                                reload()
                            }
                    }

                    if !isRestDay {
                        ForEach(Array(day.sessions.sorted { $0.orderIndex < $1.orderIndex }.enumerated()), id: \.element.id) { index, session in
                            sessionBlock(session, index: index, locked: session.isCompleted || day.isCompleted)
                        }
                        if !day.isCompleted {
                            TQButton("+ Add session", style: .raised, size: .compact) { addSession() }
                                .accessibilityIdentifier("dayEditor.addSession")
                        }
                    }
                } else {
                    TQRowList { TQRow("This day no longer exists", note: "close").disabled(true) }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear(perform: reload)
        .sheet(item: $addingToSession) { session in
            SessionDrillPickerView(player: player, planSession: nil, mode: .add, excluding: Set(session.exerciseIDs)) { picked in
                let ids = session.exerciseIDs + picked.compactMap(\.id)
                planService.setSessionExercises(sessionId: session.id, exerciseIDs: ids)
                reload()
            }
        }
    }

    private var title: String {
        guard let week, let day else { return "Day" }
        return "Week \(week.weekNumber) · \(day.dayOfWeek?.displayName ?? "Day \(day.dayNumber)")"
    }

    // MARK: - Session block

    private func sessionBlock(_ session: PlanSessionModel, index: Int, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TQSectionHeader("Session \(index + 1)\(locked ? " · done" : "")") {
                if !locked {
                    Menu {
                        ForEach(sessionTypes, id: \.self) { type in
                            Button(type.displayName) { update(session, type: type) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(session.sessionType.displayName)
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                        }
                        .font(Font.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.grass)
                        .frame(minHeight: DesignSystem.Spacing.hitTarget)
                    }
                    .accessibilityLabel("Session type \(session.sessionType.displayName)")
                } else {
                    TQMeta(session.sessionType.displayName)
                }
            }

            if locked {
                TQRowList {
                    TQRow("\(session.duration) min · intensity \(session.intensity)/5", accessory: .none, verticalPadding: DesignSystem.Spacing.rowVertical).disabled(true)
                }
            } else {
                TQRule()
                TQValueStepper(label: "Length", value: binding(for: session, keyPath: \.duration), range: 5...120, step: 5) { "\($0) min" }
                TQRule()
                TQValueStepper(label: "Intensity", value: binding(for: session, keyPath: \.intensity), range: 1...5) { "\($0) / 5" }
                TQRule()
            }

            ForEach(session.exerciseIDs, id: \.self) { exerciseID in
                HStack(spacing: 12) {
                    TQTile(symbol: "figure.soccer")
                    Text(drillNames[exerciseID] ?? "Drill")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !locked {
                        TQIconButton("xmark", style: .raised, shape: .circle, size: 30, accessibilityLabel: "Remove \(drillNames[exerciseID] ?? "drill")") {
                            remove(exerciseID, from: session)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.rowVertical)
                TQRule()
            }

            if !locked {
                HStack(spacing: 20) {
                    TQTextLink("+ Add drill", arrow: false) { addingToSession = session }
                        .accessibilityIdentifier("dayEditor.addDrill")
                    Spacer()
                    TQTextLink("Remove session", arrow: false, tone: .muted) { removeSession(session) }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            TQRule()
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    Text(subtitle)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.grass)
                    .accessibilityLabel(title)
            }
            .padding(.vertical, DesignSystem.Spacing.rowVertical)
            TQRule()
        }
    }

    // MARK: - Data

    private func reload() {
        guard let plan = planService.fetchPlan(byId: planID),
              let week = plan.weeks.first(where: { $0.id == weekID }),
              let day = week.days.first(where: { $0.id == dayID }) else {
            self.day = nil
            return
        }
        self.week = week
        self.day = day
        focus = week.focusArea ?? ""
        isRestDay = day.isRestDay
        let ids = Set(day.sessions.flatMap(\.exerciseIDs))
        drillNames = Dictionary(uniqueKeysWithValues: CoreDataManager.shared.fetchExercises(for: player)
            .compactMap { exercise -> (UUID, String)? in
                guard let id = exercise.id, ids.contains(id) else { return nil }
                return (id, exercise.name ?? "Drill")
            })
        refreshToken += 1
    }

    private func binding(for session: PlanSessionModel, keyPath: KeyPath<PlanSessionModel, Int>) -> Binding<Int> {
        Binding(
            get: { day?.sessions.first { $0.id == session.id }?[keyPath: keyPath] ?? session[keyPath: keyPath] },
            set: { value in
                let current = day?.sessions.first { $0.id == session.id } ?? session
                let duration = keyPath == \.duration ? value : current.duration
                let intensity = keyPath == \.intensity ? value : current.intensity
                _ = planService.updateSession(sessionId: session.id, sessionType: current.sessionType, duration: duration, intensity: intensity, notes: current.notes)
                reload()
            }
        )
    }

    private func saveFocus() {
        _ = planService.updateWeek(weekId: weekID, focusArea: focus.isEmpty ? nil : focus, notes: week?.notes)
        reload()
    }

    private func update(_ session: PlanSessionModel, type: SessionType) {
        _ = planService.updateSession(sessionId: session.id, sessionType: type, duration: session.duration, intensity: session.intensity, notes: session.notes)
        reload()
    }

    private func addSession() {
        let last = day?.sessions.last
        _ = planService.addSession(dayId: dayID, sessionType: last?.sessionType ?? .technical, duration: last?.duration ?? 30, intensity: last?.intensity ?? 3)
        HapticManager.shared.selectionChanged()
        reload()
    }

    private func removeSession(_ session: PlanSessionModel) {
        planService.removeSession(sessionId: session.id)
        HapticManager.shared.selectionChanged()
        reload()
    }

    private func remove(_ exerciseID: UUID, from session: PlanSessionModel) {
        planService.setSessionExercises(sessionId: session.id, exerciseIDs: session.exerciseIDs.filter { $0 != exerciseID })
        reload()
    }
}
