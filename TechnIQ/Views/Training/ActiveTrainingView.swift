import SwiftUI
import CoreData

// MARK: - Active session (Touchline 5c)
//
// The pitch goes full screen. Top: close, "DRILL n OF m", menu; 3 pt progress segments. Eyebrow +
// drill name; 128 pt clock centred; reps and effort as numberLarge at the bottom; coach tip strip on
// a 35 % base overlay; controls row: pause 64, "+10 reps" grass, next. No per-drill rating step —
// Session Complete asks once how it felt.

struct ActiveTrainingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    @StateObject private var manager: ActiveSessionManager

    // Session complete state
    @State private var xpBreakdown: SessionXPBreakdown?
    @State private var newLevel: Int?
    @State private var unlockedAchievements: [Achievement] = []
    @State private var xpBeforeSession: Int64 = 0
    @State private var levelBeforeSession: Int = 1

    @State private var showingEndConfirm = false
    @State private var showingDrillSheet = false

    init(exercises: [Exercise], planSession: PlanSession? = nil) {
        _manager = StateObject(wrappedValue: ActiveSessionManager(exercises: exercises, planSession: planSession))
    }

    private var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        return try? viewContext.fetch(request).first
    }

    var body: some View {
        if manager.exercises.isEmpty {
            emptySessionFallback
        } else {
            sessionBody
        }
    }

    // MARK: - Empty fallback

    private var emptySessionFallback: some View {
        TQScreen {
            VStack(spacing: DesignSystem.Spacing.section) {
                Spacer()
                TQHeroCard(
                    eyebrow: "No drill loaded",
                    title: "Nothing to start",
                    body: "Head back and pick a drill to start training.",
                    actionTitle: "Close",
                    actionIcon: nil,
                    markings: .heroSimple,
                    action: { dismiss() }
                )
                Spacer()
            }
        }
    }

    // MARK: - Session body

    @ViewBuilder
    private var sessionBody: some View {
        Group {
            switch manager.phase {
            case .exercise, .rating:
                pitchScreen
            case .sessionComplete:
                sessionCompleteContent
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            if let player = currentPlayer {
                xpBeforeSession = player.totalXP
                levelBeforeSession = Int(player.currentLevel)
            }
            manager.start()
        }
        .onDisappear { manager.pauseClock() }
        .alert("End session early?", isPresented: $showingEndConfirm) {
            Button("End Session", role: .destructive) { manager.endSessionEarly() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Drills you finished are saved with pro-rated XP.")
        }
        .sheet(isPresented: $showingDrillSheet, onDismiss: { manager.startClock() }) {
            if let exercise = manager.currentExercise {
                TQDrillSheet(exercise: exercise)
            }
        }
    }

    private var pitchScreen: some View {
        ZStack {
            DesignSystem.Colors.pitch.ignoresSafeArea()
            TQPitchMarkings(preset: .fullscreen).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressSegments
                    .padding(.top, 16)

                if let exercise = manager.currentExercise {
                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow(drillEyebrow(exercise))
                        TQDisplayTitle(exercise.name ?? "Drill", size: .medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 34)
                }

                Spacer(minLength: 12)

                TQClock(seconds: manager.clockSeconds, subtitle: clockSubtitle, isRunning: manager.isRunning)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                figures
                    .padding(.bottom, 18)

                coachStrip

                controls
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            TQIconButton("xmark", style: .translucent, shape: .circle, size: 36, iconSize: 13, accessibilityLabel: "End session") {
                manager.pauseClock()
                showingEndConfirm = true
            }
            Spacer()
            Text("Drill \(manager.currentExerciseIndex + 1) of \(manager.exercises.count)")
                .font(Font.system(size: 14, weight: .semibold).width(.condensed).monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundColor(DesignSystem.Colors.textOnPitch)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            TQIconButton("line.3.horizontal", style: .translucent, shape: .circle, size: 36, iconSize: 14, accessibilityLabel: "Drill steps") {
                manager.pauseClock()
                showingDrillSheet = true
            }
        }
        .padding(.top, 4)
    }

    private var progressSegments: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(manager.exercises.count, 1), id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index <= manager.currentExerciseIndex ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite.opacity(0.25))
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Drill \(manager.currentExerciseIndex + 1) of \(manager.exercises.count)")
    }

    private func drillEyebrow(_ exercise: Exercise) -> String {
        let skills = (exercise.targetSkills ?? []).prefix(2)
        if !skills.isEmpty { return skills.joined(separator: " · ") }
        return exercise.category ?? "Drill"
    }

    private var clockSubtitle: String {
        if manager.isTimeUp { return "Time · tap next" }
        if let target = manager.targetSeconds { return "of \(TQClock.format(target))" }
        return "elapsed"
    }

    // MARK: Figures

    private var figures: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(manager.currentReps)")
                        .font(Font.system(size: 44, weight: .semibold).width(.condensed).monospacedDigit().leading(.tight))
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .contentTransition(.numericText())
                        .animation(DesignSystem.Animation.microBounce, value: manager.currentReps)
                }
                TQEyebrow("reps", tone: .onPitch)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Z\(manager.currentEffortZone)")
                    .font(Font.system(size: 44, weight: .semibold).width(.condensed).monospacedDigit().leading(.tight))
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                TQEyebrow("effort", tone: .onPitch)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Effort zone \(manager.currentEffortZone)")
        }
    }

    // MARK: Coach strip

    @ViewBuilder
    private var coachStrip: some View {
        if let cue = DrillContent.parse(manager.currentExercise?.instructions).coachCue(forStep: manager.currentExerciseIndex)
            ?? manager.currentExercise?.exerciseDescription?.components(separatedBy: "\n").last(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 10) {
                Text("COACH")
                    .font(Font.system(size: 12, weight: .bold).width(.condensed))
                    .tracking(1.2)
                    .foregroundColor(DesignSystem.Colors.grass)
                    .padding(.top, 2)
                Text(cue)
                    .font(DesignSystem.Typography.bodyMedium)
                    .lineSpacing(14 * 0.45)
                    .foregroundColor(DesignSystem.Colors.bodyOnPitch)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceBase.opacity(0.35))
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            TQIconButton(manager.isRunning ? "pause.fill" : "play.fill",
                         style: .translucent, shape: .square, size: 64, iconSize: 20,
                         accessibilityLabel: manager.isRunning ? "Pause" : "Resume") {
                manager.toggleClock()
            }
            TQButton("+ 10 reps", size: .regular) {
                manager.addReps(10)
            }
            .frame(height: 64)
            TQIconButton("chevron.right", style: .translucent, shape: .square, size: 64, iconSize: 18,
                         accessibilityLabel: manager.isLastExercise ? "Finish session" : "Next drill") {
                manager.advance()
            }
        }
    }

    // MARK: - Session Complete

    @ViewBuilder
    private var sessionCompleteContent: some View {
        if let player = currentPlayer {
            if xpBreakdown != nil {
                SessionCompleteView(
                    xpBreakdown: xpBreakdown,
                    newLevel: newLevel,
                    achievements: unlockedAchievements,
                    player: player,
                    onDismiss: { dismiss() },
                    exercises: manager.exercises,
                    sessionDurationMinutes: manager.totalMinutes,
                    sessionRating: SessionEffort.good.rating,
                    recap: recapItems,
                    xpBefore: xpBeforeSession,
                    levelBefore: levelBeforeSession,
                    weekSummary: weekSummary(for: player),
                    onEffort: { effort in
                        manager.applyEffort(effort, to: manager.completedSession, player: player, context: viewContext)
                    }
                )
            } else {
                Color.clear
                    .onAppear {
                        let result = manager.finishSession(player: player, context: viewContext)
                        xpBreakdown = result.xpBreakdown
                        newLevel = result.newLevel
                        unlockedAchievements = result.achievements
                    }
            }
        } else {
            TQScreen {
                VStack(spacing: DesignSystem.Spacing.section) {
                    Spacer()
                    TQHeroCard(eyebrow: "Full time", title: "Session complete", actionTitle: "Done", actionIcon: nil, markings: .heroSimple, action: { dismiss() })
                    Spacer()
                }
            }
        }
    }

    private var recapItems: [SessionRecapItem] {
        manager.exercises.enumerated().compactMap { index, exercise in
            guard index < manager.exerciseRatings.count, manager.exerciseRatings[index] > 0 else { return nil }
            let reps = index < manager.reps.count ? manager.reps[index] : 0
            let seconds = index < manager.exerciseDurations.count ? manager.exerciseDurations[index] : 0
            return SessionRecapItem(name: exercise.name ?? "Drill", reps: reps, minutes: max(1, Int((Double(seconds) / 60).rounded())))
        }
    }

    /// "That's 4 of 4 this week." from this week's sessions (including the one just saved) and the plan target.
    private func weekSummary(for player: Player) -> String? {
        let sessions = ((player.sessions as? Set<TrainingSession>) ?? []).compactMap { $0.date }
        var planWeek: HomeWeekModel.PlanWeek? = nil
        if let plan = TrainingPlanService.shared.fetchActivePlan(for: player),
           let wd = TrainingPlanService.shared.getCurrentWeekAndDay(for: plan),
           let week = plan.weeks.first(where: { $0.weekNumber == wd.week }) {
            planWeek = HomeWeekModel.PlanWeek(days: week.days.map {
                HomeWeekModel.PlanDay(weekday: $0.dayOfWeek.map { $0.sortOrder + 1 }, isRest: $0.isRestDay, isCompleted: $0.isCompleted || $0.isSkipped, sessionCount: $0.sessions.count)
            })
        }
        let week = HomeWeekModel.build(today: Date(), calendar: Calendar.current, sessionDates: sessions, plan: planWeek)
        guard let target = week.target else { return nil }
        return "That's \(week.done) of \(max(target, week.done)) this week."
    }
}

// MARK: - Drill sheet (steps + diagram behind the menu button)

struct TQDrillSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var currentStep: Int? = nil
    @State private var isAutoPlaying = false

    private var content: DrillContent { DrillContent.parse(exercise.instructions) }

    private var diagram: DrillDiagram? {
        guard let json = exercise.diagramJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DrillDiagram.self, from: data)
    }

    var body: some View {
        TQScreen {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar(exercise.category ?? "Drill", tone: .grass) {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") { dismiss() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                        TQDisplayTitle(exercise.name ?? "Drill", size: .medium)

                        if let diagram {
                            AnimatedDrillDiagramView(diagram: diagram, instructions: content.steps, currentStep: $currentStep, isAutoPlaying: $isAutoPlaying)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pitchCardCompact, style: .continuous))
                        }

                        if !content.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                TQGroupHeader("Steps")
                                ForEach(Array(content.steps.enumerated()), id: \.offset) { index, step in
                                    TQIndexRow(index: String(format: "%02d", index + 1), text: step)
                                }
                                TQRule()
                            }
                        }

                        if !content.coachingPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                TQGroupHeader("Coaching points")
                                ForEach(Array(content.coachingPoints.enumerated()), id: \.offset) { _, point in
                                    TQIndexRow(index: "•", text: point, indexTone: .muted)
                                }
                                TQRule()
                            }
                        } else if let description = exercise.exerciseDescription, !description.isEmpty, content.steps.isEmpty {
                            TQBody(description.replacingOccurrences(of: "[AI-Generated Custom Drill]\n\n", with: ""))
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}
