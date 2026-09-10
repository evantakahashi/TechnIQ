import SwiftUI
import CoreData
import Foundation
import Combine

struct TrainingLaunch: Identifiable {
    let id = UUID()
    let exercises: [Exercise]
    /// Plan session this launch fulfils, so completion can be written back to the plan.
    var planSession: PlanSession? = nil
}

// MARK: - Home (Touchline 4a / 9b / 9c / 9d)
//
// Home answers "what do I do today?" with one pitch card and one Start button. Everything else
// is a row. Layout never changes between states — only the hero's slot content, the banner
// above it, and the rows' enabled state.

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var recentSessions: FetchedResults<TrainingSession>
    @FetchRequest var recentMatches: FetchedResults<Match>
    @Binding var selectedTab: Int

    @ObservedObject private var aiCoachService = AICoachService.shared
    @ObservedObject private var cloudService = CloudService.shared
    @ObservedObject private var avatarService = AvatarService.shared

    // Returning-player notice
    @State private var showWelcomeBack = false
    @State private var daysInactive: Int = 0
    @AppStorage("lastAppOpenDate") private var lastAppOpenDate: Double = Date().timeIntervalSince1970

    // Plan + today's session
    @State private var activePlan: TrainingPlanModel?
    @State private var currentWeekDay: (week: Int, day: Int)?
    @State private var planIsComplete = false
    @State private var todaysSession: PlanSession?
    @State private var todaysExercises: [Exercise] = []

    // Coach (Pro)
    @State private var coachTimedOut = false
    @State private var coachAttempt = 0
    @State private var coachDrillCount = 0

    // Presentation
    @State private var showingQuickDrill = false
    @State private var quickDrillWeakness: SelectedWeakness? = nil
    @State private var showingQuickDrillPaywall = false
    @State private var showingMatchLog = false
    @State private var showingPlanGenerator = false
    @State private var showingLogPlanSession = false
    @State private var showingProfileCreation = false
    @State private var isOnboardingComplete = false
    @State private var trainingLaunch: TrainingLaunch?
    @State private var route: HomeRoute?

    private enum HomeRoute: Hashable {
        case planDetail(TrainingPlanModel)
        case matchHistory
        case coachDrills
    }

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
        self._recentSessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
        self._recentMatches = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var currentPlayer: Player? { players.first }

    // MARK: Derived state

    private var isOffline: Bool { !cloudService.isNetworkAvailable }
    private var hasSessions: Bool { !recentSessions.isEmpty }
    private var coachEnabled: Bool { subscriptionManager.isPro && !isOffline }
    private var coachIsLoading: Bool { coachEnabled && aiCoachService.dailyCoaching == nil && aiCoachService.isLoading && !coachTimedOut }
    private var coachFailed: Bool { coachEnabled && aiCoachService.dailyCoaching == nil && (coachTimedOut || (!aiCoachService.isLoading && aiCoachService.error != nil)) }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sectionLarge) {
                if let player = currentPlayer {
                    header(player: player)
                    banners
                    hero(player: player)
                        .coachMark(.dashboard)
                    weekSection
                    rows(player: player)
                    footer(player: player)
                } else {
                    noProfileState
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            updateDataFilters()
            loadPlan()
            loadCoachDrillCount()
            if let player = currentPlayer { await fetchCoaching(for: player, force: true) }
        }
        .navigationDestination(item: $route) { route in
            destination(for: route)
        }
        .sheet(isPresented: $showingQuickDrillPaywall) {
            PaywallView(feature: .quickDrill)
        }
        .sheet(isPresented: $showingMatchLog) {
            if let player = currentPlayer {
                MatchLogView(player: player, preselectedSeason: nil) {}
            }
        }
        .sheet(isPresented: $showingPlanGenerator, onDismiss: { loadPlan() }) {
            if let player = currentPlayer {
                AITrainingPlanGeneratorView(player: player)
            }
        }
        .sheet(isPresented: $showingLogPlanSession, onDismiss: { loadPlan() }) {
            if let player = currentPlayer, let session = todaysSession {
                NewSessionView(player: player, planSession: session)
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
        .sheet(isPresented: $showingQuickDrill) {
            if let player = currentPlayer {
                QuickDrillSheet(player: player, onGenerated: { exercise in
                    guard showingQuickDrill else { return }
                    showingQuickDrill = false
                    quickDrillWeakness = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        trainingLaunch = TrainingLaunch(exercises: [exercise])
                    }
                }, prefilledWeakness: quickDrillWeakness)
            }
        }
        .fullScreenCover(item: $trainingLaunch, onDismiss: { loadPlan() }) { launch in
            ActiveTrainingView(exercises: launch.exercises, planSession: launch.planSession)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
        }
        .onChange(of: isOnboardingComplete) { _, completed in
            if completed {
                showingProfileCreation = false
                isOnboardingComplete = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateDataFilters() }
            }
        }
        .onAppear {
            updateDataFilters()
            checkWelcomeBack()
            loadPlan()
            loadCoachDrillCount()
            if let player = currentPlayer { Task { await fetchCoaching(for: player, force: false) } }
        }
        .onChange(of: authManager.userUID) { updateDataFilters() }
        .onChange(of: players.count) { _, count in
            if count == 0 && !authManager.userUID.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { updateDataFilters() }
            }
        }
        .onChange(of: cloudService.isNetworkAvailable) { _, available in
            if available, let player = currentPlayer { Task { await fetchCoaching(for: player, force: false) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            DispatchQueue.main.async {
                if currentPlayer == nil && !authManager.userUID.isEmpty { updateDataFilters() }
            }
        }
    }

    // MARK: - Header

    private func header(player: Player) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerSubline)
                    .font(Font.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.dimIvory)
                nameLine(player: player)
            }
            Spacer(minLength: 8)
            avatar(player: player)
        }
    }

    private func nameLine(player: Player) -> some View {
        let name = (player.name ?? "Player").uppercased()
        let kit = player.kitNumberValue.map { "#\($0)" }
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(name)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
            if let kit {
                Text(" · ")
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                Text(kit)
                    .foregroundColor(DesignSystem.Colors.grass)
            }
        }
        .font(DesignSystem.Typography.displaySmall)
        .tracking(-0.3)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var headerSubline: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        let today = formatter.string(from: Date())
        let now = Date()
        if let next = recentMatches.compactMap({ $0.date }).filter({ $0 > now }).min() {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: Calendar.current.startOfDay(for: next)).day ?? 0
            return "\(today) · Matchday −\(days)"
        }
        let calendar = Calendar.current
        let trainedDays = Set(recentSessions.compactMap { $0.date }.map { calendar.startOfDay(for: $0) })
        let trainedToday = trainedDays.contains(calendar.startOfDay(for: now))
        return "\(today) · Day \(trainedDays.count + (trainedToday ? 0 : 1))"
    }

    @ViewBuilder
    private func avatar(player: Player) -> some View {
        TQAvatarCircle {
            if player.avatarConfiguration != nil {
                ProgrammaticAvatarView(avatarState: avatarService.currentAvatarState, size: .small)
                    .frame(width: 60, height: 90)
                    .scaleEffect(1.05, anchor: .top)
                    .offset(y: -2)
                    .frame(width: 40, height: 40, alignment: .top)
            } else {
                Text(String((player.name ?? "P").prefix(1)).uppercased())
                    .font(Font.system(size: 15, weight: .bold).width(.condensed))
                    .foregroundColor(DesignSystem.Colors.dimIvory)
            }
        }
        .accessibilityLabel("Your avatar")
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        if isOffline, activePlan != nil {
            TQBanner(.warning,
                     lead: "You're offline.",
                     message: "Today's drill comes from your plan; the coach's note will update when you're back.",
                     actionTitle: "Retry") {
                if let player = currentPlayer { Task { await fetchCoaching(for: player, force: true) } }
            }
        } else if coachFailed, activePlan != nil {
            TQBanner(.info,
                     lead: "Coach is slow to answer.",
                     message: "Today's drill comes from your plan.",
                     actionTitle: "Retry") {
                if let player = currentPlayer { Task { await fetchCoaching(for: player, force: true) } }
            }
        } else if showWelcomeBack && daysInactive >= 3 {
            TQBanner(.info,
                     lead: "Welcome back.",
                     message: "\(daysInactive) days away. Pick up with today's session.",
                     actionTitle: "Dismiss") {
                withAnimation(DesignSystem.Animation.quick) { showWelcomeBack = false }
            }
        }
    }

    // MARK: - Hero

    private var weekDayMeta: String? {
        guard activePlan != nil, let wd = currentWeekDay else { return nil }
        return "WK \(wd.week) · DAY \(wd.day)"
    }

    @ViewBuilder
    private func hero(player: Player) -> some View {
        if coachIsLoading {
            TQHeroCard(eyebrow: "Today's session", trailingMeta: weekDayMeta, title: "", actionTitle: "", state: .loading, markings: .heroSimple, action: {})
        } else if coachEnabled, let coaching = aiCoachService.dailyCoaching {
            coachHero(coaching: coaching, player: player)
        } else if let session = todaysSession {
            planHero(session: session, player: player)
        } else if planIsComplete, let plan = activePlan {
            TQHeroCard(
                eyebrow: "Plan complete",
                title: plan.name,
                body: "Every session done. Pick the next plan, or keep sharp with a quick drill.",
                actionTitle: "Start quick drill",
                linkTitle: "choose a new plan",
                markings: .heroSimple,
                action: { startQuickDrill() },
                linkAction: { selectedTab = 2 }
            )
        } else if !hasSessions {
            TQHeroCard(
                eyebrow: "Your first session",
                title: "Ten minutes, one ball, a wall",
                body: "No plan yet. Start with a quick drill built for your position and the coach will learn from how it goes.",
                actionTitle: "Start quick drill",
                linkTitle: "build a plan first",
                markings: .heroSimple,
                action: { startQuickDrill() },
                linkAction: { showingPlanGenerator = true }
            )
        } else {
            TQHeroCard(
                eyebrow: "Today's session",
                title: "Quick drill for your weakest skill",
                body: "No active plan. The coach builds a ten-minute drill around what needs work most.",
                actionTitle: "Start quick drill",
                linkTitle: "build a plan",
                markings: .heroSimple,
                action: { startQuickDrill() },
                linkAction: { showingPlanGenerator = true }
            )
        }
    }

    private func coachHero(coaching: DailyCoaching, player: Player) -> some View {
        let drill = coaching.recommendedDrill
        var figures: [(String, String)] = [("\(max(drill.duration, 1))", "min")]
        if drill.difficulty > 0 { figures.append(("\(drill.difficulty)", "lvl")) }
        if let foot = weakFootLabel(for: player, skills: drill.targetSkills, focus: coaching.focusArea) { figures.append((foot, "foot")) }
        return TQHeroCard(
            eyebrow: "Today's session",
            trailingMeta: weekDayMeta,
            title: drill.name,
            figures: figures,
            body: coaching.reasoning,
            actionTitle: "Start session",
            markings: .hero,
            action: { launchAIDrill(drill, focusArea: coaching.focusArea, for: player) }
        )
    }

    private func planHero(session: PlanSession, player: Player) -> some View {
        let exercise = todaysExercises.first
        let type = SessionType(rawValue: session.sessionType ?? "") ?? .technical
        let title = exercise?.name ?? "\(type.displayName) session"
        var figures: [(String, String)] = [("\(max(Int(session.duration), 1))", "min")]
        if let exercise, exercise.difficulty > 0 { figures.append(("\(exercise.difficulty)", "lvl")) }
        if let foot = weakFootLabel(for: player, skills: exercise?.targetSkills ?? [], focus: exercise?.weaknessCategories ?? "") { figures.append((foot, "foot")) }
        if todaysExercises.count > 1 { figures.append(("\(todaysExercises.count)", "drills")) }

        let bodyText: String?
        let bodyTone: TQBody.Tone
        if isOffline {
            bodyText = "Coach's note unavailable offline."
            bodyTone = .italicMuted
        } else if let focus = currentWeekFocus {
            bodyText = "This week: \(focus)."
            bodyTone = .onPitch
        } else {
            bodyText = nil
            bodyTone = .onPitch
        }

        return TQHeroCard(
            eyebrow: isOffline ? "Today's session · from plan" : "Today's session",
            trailingMeta: weekDayMeta,
            title: title,
            figures: figures,
            body: bodyText,
            bodyTone: bodyTone,
            actionTitle: "Start session",
            markings: isOffline ? .heroSimple : .hero,
            action: { startPlanSession(session) }
        )
    }

    private var currentWeekFocus: String? {
        guard let plan = activePlan, let wd = currentWeekDay else { return nil }
        let focus = plan.weeks.first { $0.weekNumber == wd.week }?.focusArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (focus?.isEmpty ?? true) ? nil : focus
    }

    private func weakFootLabel(for player: Player, skills: [String], focus: String) -> String? {
        let mentionsWeakFoot = (skills + [focus]).contains { $0.localizedCaseInsensitiveContains("weak foot") || $0.localizedCaseInsensitiveContains("weak-foot") }
        guard mentionsWeakFoot else { return nil }
        switch player.dominantFoot?.lowercased() {
        case "right": return "L"
        case "left": return "R"
        default: return nil
        }
    }

    // MARK: - Week

    private var week: HomeWeekModel.Week {
        let sessionDates = recentSessions.compactMap { $0.date }
        var planWeek: HomeWeekModel.PlanWeek? = nil
        if let plan = activePlan, let wd = currentWeekDay, let weekModel = plan.weeks.first(where: { $0.weekNumber == wd.week }) {
            planWeek = HomeWeekModel.PlanWeek(days: weekModel.days.map { day in
                HomeWeekModel.PlanDay(
                    weekday: day.dayOfWeek.map { $0.sortOrder + 1 },
                    isRest: day.isRestDay,
                    isCompleted: day.isCompleted || day.isSkipped,
                    sessionCount: day.sessions.count
                )
            })
        }
        return HomeWeekModel.build(today: Date(), calendar: Calendar.current, sessionDates: sessionDates, plan: planWeek)
    }

    private var weekSection: some View {
        let week = self.week
        return VStack(spacing: DesignSystem.Spacing.rowGap) {
            TQSectionHeader("This week") {
                HStack(spacing: 0) {
                    Text("\(week.done)")
                        .foregroundColor(week.done > 0 ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                    Text(week.target.map { " / \(max($0, week.done))" } ?? " / —")
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                }
                .font(Font.system(size: 16, weight: .semibold).width(.condensed).monospacedDigit())
                .accessibilityLabel("\(week.done) of \(week.target.map(String.init) ?? "no target") sessions this week")
            }
            TQWeekStrip(cells: week.cells, todayIndex: week.todayIndex)
        }
    }

    // MARK: - Rows

    private func rows(player: Player) -> some View {
        TQRowList {
            if let plan = activePlan {
                TQRow(plan.name, meta: .init(planRowMeta(plan)), action: { route = .planDetail(plan) })
            } else {
                TQRow("Build a training plan", badge: TQBadge(.text("AI")), action: { showingPlanGenerator = true })
            }

            if let match = recentMatches.first(where: { ($0.date ?? .distantFuture) <= Date() }) {
                TQRow("Last match", meta: matchMeta(match), action: { route = .matchHistory })
            } else {
                TQRow("Log a match", action: { showingMatchLog = true })
            }

            coachRow
        }
    }

    @ViewBuilder
    private var coachRow: some View {
        if !hasSessions {
            TQRow("Drills from the coach", note: "after your first session").disabled(true)
        } else if isOffline {
            TQRow("Drills from the coach", note: "needs connection").disabled(true)
        } else if coachIsLoading {
            HStack(spacing: 12) {
                Text("Drills from the coach")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                Spacer()
                TQSkeleton(width: 22, height: 18, cornerRadius: 3)
                TQChevron()
            }
            .padding(.vertical, DesignSystem.Spacing.rowVerticalLarge)
            .overlay(alignment: .bottom) { TQRule() }
        } else {
            TQRow("Drills from the coach",
                  badge: coachDrillCount > 0 ? TQBadge(.count(coachDrillCount)) : nil,
                  action: { route = .coachDrills })
        }
    }

    private func planRowMeta(_ plan: TrainingPlanModel) -> String {
        let week = currentWeekDay?.week ?? max(plan.currentWeek, 1)
        return "WK \(week)/\(plan.durationWeeks) · \(Int(plan.progressPercentage.rounded()))%"
    }

    private func matchMeta(_ match: Match) -> TQRow.Meta {
        let opponent = (match.opponent ?? "").trimmingCharacters(in: .whitespaces)
        var accent = match.result ?? ""
        var stats: [String] = []
        if match.goals > 0 { stats.append("\(match.goals)G") }
        if match.assists > 0 { stats.append("\(match.assists)A") }
        if !stats.isEmpty { accent += (accent.isEmpty ? "" : " ") + stats.joined(separator: " ") }
        let lead = opponent.isEmpty ? "" : "vs \(opponent)" + (accent.isEmpty ? "" : " · ")
        return TQRow.Meta(lead, accent: accent.isEmpty ? nil : accent)
    }

    // MARK: - Footer

    private func footer(player: Player) -> some View {
        var items: [TQFooterLine.Item] = [
            .init(value: "\(max(Int(player.currentLevel), 1))", label: "LVL", valueLeading: true),
            .init(value: player.totalXP.formatted(), label: "XP")
        ]
        if player.currentStreak > 0 {
            items.append(.init(value: "\(player.currentStreak)", label: "day streak", accent: true))
        }
        return TQFooterLine(items: items)
            .padding(.top, 2)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .planDetail(let plan):
            if let player = currentPlayer {
                TrainingPlanDetailView(initialPlan: plan, player: player)
            }
        case .matchHistory:
            if let player = currentPlayer {
                MatchHistoryView(player: player)
            }
        case .coachDrills:
            if let player = currentPlayer {
                CoachDrillsView(player: player)
            }
        }
    }

    // MARK: - No profile

    private var noProfileState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            TQHeroCard(
                eyebrow: "Welcome",
                title: "Set up your player",
                body: "Tell the coach your position and what you want to fix. It takes a minute.",
                actionTitle: "Create profile",
                actionIcon: nil,
                markings: .heroSimple,
                action: { showingProfileCreation = true }
            )
        }
        .padding(.top, DesignSystem.Spacing.xl)
    }

    // MARK: - Actions

    private func startQuickDrill() {
        if subscriptionManager.canUseQuickDrill() {
            quickDrillWeakness = nil
            showingQuickDrill = true
        } else {
            showingQuickDrillPaywall = true
        }
    }

    private func startPlanSession(_ session: PlanSession) {
        if todaysExercises.isEmpty {
            showingLogPlanSession = true
        } else {
            trainingLaunch = TrainingLaunch(exercises: todaysExercises, planSession: session)
        }
    }

    private func launchAIDrill(_ drill: RecommendedDrill, focusArea: String, for player: Player) {
        if drill.isFromLibrary, let idString = drill.libraryExerciseID, let uuid = UUID(uuidString: idString) {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            if let existing = try? viewContext.fetch(request).first {
                trainingLaunch = TrainingLaunch(exercises: [existing], planSession: todaysSession)
                return
            }
        }

        let exercise = Exercise(context: viewContext)
        exercise.id = UUID()
        exercise.name = drill.name
        exercise.exerciseDescription = "AI Coach Recommendation: \(drill.description)"
        exercise.category = drill.category
        exercise.difficulty = Int16(drill.difficulty)
        exercise.targetSkills = drill.targetSkills
        exercise.weaknessCategories = focusArea
        exercise.estimatedDurationSeconds = Int16(clamping: max(drill.duration, 1) * 60)
        exercise.instructions = drill.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        exercise.player = player

        try? viewContext.save()
        trainingLaunch = TrainingLaunch(exercises: [exercise], planSession: todaysSession)
    }

    // MARK: - Data

    private func updateDataFilters() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        recentSessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
        recentMatches.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }

    private func checkWelcomeBack() {
        let lastOpen = Date(timeIntervalSince1970: lastAppOpenDate)
        let daysSinceLastOpen = Calendar.current.dateComponents([.day], from: lastOpen, to: Date()).day ?? 0
        if daysSinceLastOpen >= 1 {
            daysInactive = daysSinceLastOpen
            showWelcomeBack = true
        }
        lastAppOpenDate = Date().timeIntervalSince1970
    }

    private func loadPlan() {
        guard let player = currentPlayer else { return }
        activePlan = TrainingPlanService.shared.fetchActivePlan(for: player)
        guard let plan = activePlan else {
            currentWeekDay = nil
            planIsComplete = false
            todaysSession = nil
            todaysExercises = []
            return
        }
        currentWeekDay = TrainingPlanService.shared.getCurrentWeekAndDay(for: plan)
        planIsComplete = currentWeekDay == nil
        let sessions = TrainingPlanService.shared.getTodaysSessions(for: plan)
        todaysSession = sessions.first { !$0.isCompleted } ?? sessions.first
        todaysExercises = sessions
            .filter { !$0.isCompleted }
            .flatMap { ($0.exercises?.allObjects as? [Exercise]) ?? [] }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func loadCoachDrillCount() {
        guard let player = currentPlayer else { coachDrillCount = 0; return }
        let profile = WeaknessAnalysisService.shared.getCachedProfile(for: player)
            ?? WeaknessAnalysisService.shared.analyzeWeaknesses(for: player)
        coachDrillCount = min(profile.suggestedWeaknesses.count, 3)
    }

    /// Fetches daily coaching for Pro players. Local data renders immediately; only the coach slots
    /// wait. After 6 s with no answer the hero falls back to the plan's drill and a banner offers Retry.
    @MainActor
    private func fetchCoaching(for player: Player, force: Bool) async {
        guard subscriptionManager.isPro, !isOffline else { return }
        if !force, let cached = aiCoachService.dailyCoaching, Calendar.current.isDateInToday(cached.fetchDate) { return }
        coachAttempt += 1
        let attempt = coachAttempt
        coachTimedOut = false

        let fetch = Task { await aiCoachService.fetchDailyCoachingIfNeeded(for: player) }
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if attempt == coachAttempt, aiCoachService.dailyCoaching == nil {
                coachTimedOut = true
            }
        }
        await fetch.value
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedTab: .constant(0))
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(SubscriptionManager.shared)
    }
}
