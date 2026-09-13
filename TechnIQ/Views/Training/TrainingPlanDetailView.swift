import SwiftUI
import CoreData

// MARK: - Plan detail (Touchline 5b)
//
// Pushed from the library, or the Plan tab's root for the active plan (then the nav bar's leading
// action is "All plans" instead of back). Eyebrow "ACTIVE · role · level", condensed title,
// one-line description, a stat rail (% complete, week n/8, total h, sessions done), the whole
// schedule as a grid (tap a cell → day sheet), and a pinned pitch card: "TODAY" with Start and
// "Skip today" (with undo) for the active plan, or "START THIS PLAN" for any other. The Edit menu
// also carries Stop following and Delete for stored plans.

struct TrainingPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var planService = TrainingPlanService.shared

    enum Presentation { case pushed, tabRoot }

    let initialPlan: TrainingPlanModel
    let player: Player
    var presentation: Presentation = .pushed
    /// Called after Stop following, Delete or Start when the tab root has to re-root.
    var onActivePlanChanged: (() -> Void)? = nil

    @State private var currentPlan: TrainingPlanModel?
    @State private var isStored = false
    @State private var showingAllPlans = false
    @State private var showingConfirmDelete = false
    @State private var skippedDayID: UUID?
    @State private var currentWeekDay: (week: Int, day: Int)?
    @State private var todaysExercises: [Exercise] = []
    @State private var todaysSession: PlanSession?
    @State private var showingConfirmStart = false
    @State private var showingEditor = false
    @State private var showingShareSheet = false
    @State private var showingLogSession = false
    @State private var duplicatedPlanName: String?
    @State private var selectedDay: SelectedDay?
    @State private var trainingLaunch: TrainingLaunch?

    private struct SelectedDay: Identifiable {
        let id = UUID()
        let week: PlanWeekModel
        let day: PlanDayModel
    }

    private var plan: TrainingPlanModel { currentPlan ?? initialPlan }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
                    TQNavBar("Plan") {
                        navLeading
                    } trailing: {
                        editMenu
                    }
                    .padding(.top, 8)

                    banners

                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow(eyebrow, size: 11)
                        TQDisplayTitle(plan.name, size: .medium)
                        TQBody(plan.description)
                    }

                    TQStatRail(items: statItems)

                    TQScheduleGrid(rows: gridRows, onTap: selectCell)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            pinnedCard
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, 16)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refreshPlanData() }
        .navigationDestination(isPresented: $showingAllPlans) {
            TrainingPlansListView(isPushed: true)
        }
        .confirmationDialog("Delete this plan?", isPresented: $showingConfirmDelete, titleVisibility: .visible) {
            Button("Delete plan", role: .destructive) { deletePlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(plan.name)\" and its progress are removed from My plans. Sessions you completed stay in your history.")
        }
        .sheet(isPresented: $showingEditor) {
            PlanEditorView(plan: plan, player: player) { refreshPlanData() }
        }
        .sheet(isPresented: $showingShareSheet) {
            SharePlanView(plan: plan)
        }
        .sheet(item: $selectedDay) { selection in
            PlanDaySheet(week: selection.week, day: selection.day, isToday: isToday(selection.day, in: selection.week))
        }
        .sheet(isPresented: $showingLogSession, onDismiss: { refreshPlanData() }) {
            if let session = todaysSession {
                SessionDrillPickerView(player: player, planSession: session) { exercises in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        trainingLaunch = TrainingLaunch(exercises: exercises, planSession: session)
                    }
                }
            }
        }
        .fullScreenCover(item: $trainingLaunch, onDismiss: { refreshPlanData() }) { launch in
            ActiveTrainingView(exercises: launch.exercises, planSession: launch.planSession)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
        }
        .confirmationDialog("Start this plan?", isPresented: $showingConfirmStart, titleVisibility: .visible) {
            Button("Start plan") { startPlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(plan.name)\" becomes your active plan. Any active plan is paused.")
        }
    }

    // MARK: - Banners and grid taps

    @ViewBuilder
    private var banners: some View {
        if let name = duplicatedPlanName {
            TQBanner(.info, lead: "Duplicated.", message: "\"\(name)\" is in My plans.", actionTitle: "OK") { duplicatedPlanName = nil }
        }
        if skippedDayID != nil {
            TQBanner(.info, lead: "Day skipped.", message: "Tomorrow's session is up next.", actionTitle: "Undo") { undoSkip() }
        }
    }

    private func selectCell(rowIndex: Int, dayIndex: Int) {
        guard rowIndex < plan.weeks.count else { return }
        let week = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }[rowIndex]
        if let day = week.days.first(where: { ($0.dayOfWeek.map { $0.sortOrder } ?? ($0.dayNumber - 1)) == dayIndex }) {
            selectedDay = SelectedDay(week: week, day: day)
        }
    }

    // MARK: - Nav bar

    @ViewBuilder
    private var navLeading: some View {
        if presentation == .tabRoot {
            TQNavAction("All plans") { showingAllPlans = true }
                .accessibilityIdentifier("plan.allPlans")
        } else {
            TQBackButton { dismiss() }
        }
    }

    private var editMenu: some View {
        Menu {
            if !plan.isPrebuilt {
                Button { showingEditor = true } label: { Label("Edit plan", systemImage: "pencil") }
            }
            Button { duplicatePlan() } label: { Label("Duplicate plan", systemImage: "doc.on.doc") }
            Button { showingShareSheet = true } label: { Label("Share to community", systemImage: "square.and.arrow.up") }
            if isStored {
                Divider()
                if plan.isActive {
                    Button { stopFollowing() } label: { Label("Stop following", systemImage: "pause.circle") }
                }
                Button(role: .destructive) { showingConfirmDelete = true } label: { Label("Delete plan", systemImage: "trash") }
            }
        } label: {
            Text("Edit")
                .font(Font.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .frame(minHeight: DesignSystem.Spacing.hitTarget)
        }
        .accessibilityLabel("Plan options")
    }

    // MARK: - Header bits

    private var eyebrow: String {
        var parts: [String] = [plan.isActive ? "Active" : (plan.isPrebuilt ? "Pre-built" : "My plan")]
        if let role = plan.targetRole, !role.isEmpty { parts.append(role) }
        parts.append(plan.difficulty.displayName)
        return parts.joined(separator: " · ")
    }

    private var statItems: [TQStatRail.Item] {
        let totalMinutes = plan.weeks.flatMap { $0.days }.flatMap { $0.sessions }.reduce(0) { $0 + $1.duration }
        let hours = Int((Double(totalMinutes) / 60).rounded())
        let done = plan.weeks.reduce(0) { $0 + $1.completedSessions }
        let week = currentWeekDay?.week ?? (plan.isCompleted ? plan.durationWeeks : max(plan.currentWeek, 1))
        return [
            .init("\(Int(plan.progressPercentage.rounded()))", unit: "%", label: "complete"),
            .init("\(week)", unit: "/\(plan.durationWeeks)", label: "week"),
            .init("\(hours)", unit: "h", label: "total"),
            .init("\(done)", label: "done", accent: done > 0)
        ]
    }

    // MARK: - Grid

    private var gridRows: [TQScheduleGrid.Row] {
        let weeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }
        return weeks.map { week in
            var cells = Array(repeating: TQDayCell.rest, count: 7)
            for day in week.days {
                let index = day.dayOfWeek.map { $0.sortOrder } ?? (day.dayNumber - 1)
                guard (0..<7).contains(index) else { continue }
                if day.isRestDay { continue }
                let state: TQDayCellState
                if day.isCompleted || (!day.sessions.isEmpty && day.sessions.allSatisfy { $0.isCompleted }) {
                    state = .done
                } else if isToday(day, in: week) {
                    state = .today
                } else if day.isSkipped {
                    state = .missed
                } else {
                    state = .planned
                }
                cells[index] = TQDayCell(state: state, sessions: day.sessions.count)
            }
            return TQScheduleGrid.Row(label: "WK \(week.weekNumber)", cells: cells, isCurrent: currentWeekDay?.week == week.weekNumber)
        }
    }

    private func isToday(_ day: PlanDayModel, in week: PlanWeekModel) -> Bool {
        guard plan.isActive, let current = currentWeekDay else { return false }
        return current.week == week.weekNumber && current.day == day.dayNumber
    }

    // MARK: - Pinned card

    @ViewBuilder
    private var pinnedCard: some View {
        if plan.isActive, let current = currentWeekDay {
            TQPitchCard(.pinned, markings: .pinned) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            TQEyebrow("Today · WK \(current.week) Day \(current.day)", size: 11)
                            TQDisplayTitle(todaysExercises.first?.name ?? "\(todaysSessionType) session", size: .strip)
                                .lineLimit(2)
                        }
                        TQButton("Start", icon: "play.fill", size: .compact, fullWidth: false) { startToday() }
                    }
                    TQTextLink("Skip today", arrow: false, tone: .onPitch) { skipToday() }
                        .accessibilityIdentifier("plan.skipToday")
                }
            }
        } else if plan.isActive {
            TQPitchCard(.pinned, markings: .pinned) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        TQEyebrow("Plan complete", size: 11)
                        TQDisplayTitle("Every session done", size: .strip)
                    }
                    Spacer()
                }
            }
        } else {
            TQPitchCard(.pinned, markings: .pinned) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        TQEyebrow("\(plan.durationWeeks) weeks · \(sessionsPerWeek)×/wk", size: 11)
                        TQDisplayTitle("Start this plan", size: .strip)
                    }
                    TQButton("Start", icon: "play.fill", size: .compact, fullWidth: false) { showingConfirmStart = true }
                }
            }
        }
    }

    private var sessionsPerWeek: Int {
        plan.weeks.first.map { $0.days.filter { !$0.isRestDay }.count } ?? 0
    }

    private var todaysSessionType: String {
        guard let current = currentWeekDay,
              let week = plan.weeks.first(where: { $0.weekNumber == current.week }),
              let day = week.days.first(where: { $0.dayNumber == current.day }),
              let session = day.sessions.first else { return "Training" }
        return session.sessionType.displayName
    }

    // MARK: - Actions

    private func startToday() {
        if todaysExercises.isEmpty {
            showingLogSession = true
        } else {
            trainingLaunch = TrainingLaunch(exercises: todaysExercises, planSession: todaysSession)
        }
    }

    private func duplicatePlan() {
        if let clonedPlan = TrainingPlanService.shared.clonePlan(plan, for: player) {
            duplicatedPlanName = clonedPlan.name ?? "Copy of \(plan.name)"
        }
    }

    private var todaysDayID: UUID? {
        guard let current = currentWeekDay,
              let week = plan.weeks.first(where: { $0.weekNumber == current.week }),
              let day = week.days.first(where: { $0.dayNumber == current.day }) else { return nil }
        return day.id
    }

    private func skipToday() {
        guard let dayID = todaysDayID else { return }
        planService.skipDay(dayId: dayID)
        HapticManager.shared.selectionChanged()
        withAnimation(DesignSystem.Animation.quick) { skippedDayID = dayID }
        refreshPlanData()
    }

    private func undoSkip() {
        guard let dayID = skippedDayID else { return }
        planService.unskipDay(dayId: dayID)
        withAnimation(DesignSystem.Animation.quick) { skippedDayID = nil }
        refreshPlanData()
    }

    private func stopFollowing() {
        planService.deactivatePlan(plan, for: player)
        HapticManager.shared.selectionChanged()
        refreshPlanData()
        onActivePlanChanged?()
    }

    private func deletePlan() {
        planService.deletePlan(plan)
        if planService.activePlan?.id == plan.id { planService.activePlan = nil }
        HapticManager.shared.success()
        if presentation == .tabRoot {
            onActivePlanChanged?()
        } else {
            dismiss()
        }
    }

    private func refreshPlanData() {
        if let freshPlan = TrainingPlanService.shared.fetchPlan(byId: initialPlan.id) {
            currentPlan = freshPlan
            isStored = true
        } else {
            isStored = false
        }
        guard plan.isActive else {
            currentWeekDay = nil
            todaysExercises = []
            todaysSession = nil
            return
        }
        currentWeekDay = TrainingPlanService.shared.getCurrentWeekAndDay(for: plan)
        let sessions = TrainingPlanService.shared.getTodaysSessions(for: plan)
        todaysSession = sessions.first { !$0.isCompleted } ?? sessions.first
        todaysExercises = sessions.filter { !$0.isCompleted }
            .flatMap { ($0.exercises?.allObjects as? [Exercise]) ?? [] }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func startPlan() {
        if plan.isPrebuilt {
            if let newPlan = planService.instantiatePrebuiltPlan(plan, for: player) {
                let model = newPlan.toModel()
                planService.activatePlan(model, for: player)
                currentPlan = model
            }
        } else {
            planService.activatePlan(plan, for: player)
        }
        HapticManager.shared.success()
        refreshPlanData()
        onActivePlanChanged?()
    }
}

// MARK: - Day sheet

struct PlanDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let week: PlanWeekModel
    let day: PlanDayModel
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Week \(week.weekNumber) · \(day.dayOfWeek?.displayName ?? "Day \(day.dayNumber)")") {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            } trailing: {
                TQNavAction("Done") { dismiss() }
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(isToday ? "Today" : (day.isCompleted ? "Done" : (day.isRestDay ? "Rest day" : "Planned")), size: 11)
                TQDisplayTitle(week.focusArea ?? "Week \(week.weekNumber)", size: .card)
                if let notes = week.notes, !notes.isEmpty { TQBody(notes) }
            }

            if day.isRestDay {
                TQRowList {
                    TQRow("Rest day", note: "recover").disabled(true)
                }
            } else {
                TQRowList {
                    ForEach(day.sessions) { session in
                        TQRow(
                            "\(session.sessionType.displayName) session",
                            subtitle: "\(session.duration) min · intensity \(session.intensity)/5" + (session.exerciseIDs.isEmpty ? "" : " · \(session.exerciseIDs.count) drill\(session.exerciseIDs.count == 1 ? "" : "s")"),
                            leading: .tile(TQTile.category(session.sessionType.rawValue)),
                            badge: session.isCompleted ? TQBadge(.status("Done")) : nil,
                            accessory: .none,
                            verticalPadding: DesignSystem.Spacing.rowVertical
                        )
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        TrainingPlanDetailView(
            initialPlan: TrainingPlanService.shared.availablePlans.first ?? TrainingPlanModel(
                id: UUID(), name: "Preview", description: "", durationWeeks: 4, difficulty: .beginner, category: .technical,
                targetRole: nil, isPrebuilt: true, isActive: false, currentWeek: 1, progressPercentage: 0,
                startedAt: nil, completedAt: nil, createdAt: Date(), updatedAt: Date(), weeks: []
            ),
            player: Player(context: CoreDataManager.shared.context)
        )
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(SubscriptionManager.shared)
    }
}
