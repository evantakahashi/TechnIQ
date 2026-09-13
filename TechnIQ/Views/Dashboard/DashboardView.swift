import SwiftUI
import CoreData
import Foundation
import Combine

struct TrainingLaunch: Identifiable {
    let id = UUID()
    let exercises: [Exercise]
    /// Plan session this launch fulfils, so completion can be written back to the plan.
    var planSession: PlanSession? = nil
    /// Set when continuing an interrupted session.
    var resumeFrom: SessionSnapshot? = nil
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
    @State private var todayState: PlanSchedule.Today?
    @State private var planIsComplete = false
    @State private var todaysSession: PlanSession?
    @State private var todaysExercises: [Exercise] = []

    // Coach (Pro)
    @State private var coachSwapExercise: Exercise?
    @State private var pendingSession: SessionSnapshot?
    @State private var previewSession: PlanSession?
    @State private var paywallFeature: PaywallFeature?
    @State private var showingWeeklyReview = false
    @State private var showingCoachBuild = false
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
            predicate: AuthenticationManager.shared.playerPredicate,
            animation: .default
        )
        self._recentSessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: AuthenticationManager.shared.ownedByPlayerPredicate,
            animation: .default
        )
        self._recentMatches = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: false)],
            predicate: AuthenticationManager.shared.ownedByPlayerPredicate,
            animation: .default
        )
    }

    var currentPlayer: Player? { players.first }

    // MARK: Derived state

    /// `-TQHomeState offline|loading|empty` forces a state for screenshot comparison (DEBUG only).
    private var forcedState: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-TQHomeState"), index + 1 < args.count else { return nil }
        return args[index + 1]
        #else
        return nil
        #endif
    }

    private var isOffline: Bool { forcedState == "offline" || !cloudService.isNetworkAvailable }
    private var hasSessions: Bool { forcedState != "empty" && !recentSessions.isEmpty }
    private var coachEnabled: Bool { subscriptionManager.isPro && !isOffline }
    /// The hero never waits on the network: the plan's drill shows at once and the coach's note lands
    /// when it arrives. Only the `-TQHomeState loading` screenshot state shows the skeleton.
    private var coachIsLoading: Bool { forcedState == "loading" }
    private var coachName: String { CoachIdentity.name() }

    /// Today's coaching when it is today's and the player is Pro.
    private var todaysCoaching: DailyCoaching? {
        guard coachEnabled, let coaching = aiCoachService.dailyCoaching, Calendar.current.isDateInToday(coaching.fetchDate) else { return nil }
        return coaching
    }

    /// The library drill the coach picked, when it resolves.
    private func coachPick(_ coaching: DailyCoaching) -> Exercise? {
        guard coaching.recommendedDrill.isFromLibrary,
              let idString = coaching.recommendedDrill.libraryExerciseID, let id = UUID(uuidString: idString) else { return nil }
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sectionLarge) {
                if let player = currentPlayer {
                    header(player: player)
                    banners
                    resumeStrip
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
            PaywallView(feature: .customDrill)
        }
        .sheet(isPresented: $showingMatchLog) {
            if let player = currentPlayer {
                MatchLogView(player: player, preselectedSeason: nil) {}
            }
        }
        .sheet(isPresented: $showingPlanGenerator, onDismiss: { loadPlan() }) {
            if let player = currentPlayer {
                NavigationStack {
                    AITrainingPlanGeneratorView(player: player)
                }
            }
        }
        .sheet(isPresented: $showingLogPlanSession, onDismiss: { loadPlan() }) {
            if let player = currentPlayer, let session = todaysSession {
                SessionDrillPickerView(player: player, planSession: session) { exercises in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        trainingLaunch = TrainingLaunch(exercises: exercises, planSession: session)
                    }
                }
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
        }
        .sheet(item: $previewSession) { session in
            SessionPreviewSheet(
                eyebrow: weekDayMeta.map { "Today · \($0)" } ?? "Today",
                title: todaysExercises.first?.name ?? "Today's session",
                exercises: todaysExercises
            ) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trainingLaunch = TrainingLaunch(exercises: todaysExercises, planSession: session)
                }
            }
        }
        .sheet(isPresented: $showingWeeklyReview) {
            if let player = currentPlayer {
                WeeklyReviewView(weekNumber: aiCoachService.completedWeekNumber, player: player)
            }
        }
        .sheet(isPresented: $showingCoachBuild) {
            if let player = currentPlayer, let coaching = todaysCoaching {
                CustomDrillGeneratorView(player: player, prefill: .init(text: "\(coaching.recommendedDrill.name): \(coaching.recommendedDrill.description)")) { exercise in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        trainingLaunch = TrainingLaunch(exercises: [exercise])
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickDrill) {
            if let player = currentPlayer {
                CustomDrillGeneratorView(player: player, prefill: .init(weakness: quickDrillWeakness)) { exercise in
                    quickDrillWeakness = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        trainingLaunch = TrainingLaunch(exercises: [exercise])
                    }
                }
            }
        }
        .fullScreenCover(item: $trainingLaunch, onDismiss: { loadPlan() }) { launch in
            ActiveTrainingView(exercises: launch.exercises, planSession: launch.planSession, resumeFrom: launch.resumeFrom)
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
            #if DEBUG
            // `-TQRoute planDetail|matchHistory|coachDrills` pushes a destination for screenshots.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-TQRoute"), index + 1 < args.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    switch args[index + 1] {
                    case "planDetail": if let plan = activePlan { route = .planDetail(plan) }
                    case "matchHistory": route = .matchHistory
                    case "coachDrills": route = .coachDrills
                    default: break
                    }
                }
            }
            #endif
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
                // Plan progress can change from other tabs (logging a session, activating a plan).
                loadPlan()
                loadCoachDrillCount()
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
        if let plan = activePlan, let weekDay = TrainingPlanService.peekCurrentWeekAndDay(in: plan) {
            return "\(today) · Week \(weekDay.week) of \(plan.durationWeeks)"
        }
        return today
    }

    @ViewBuilder
    private func avatar(player: Player) -> some View {
        TQAvatarCircle {
            if player.avatarConfiguration != nil {
                ProgrammaticAvatarView(avatarState: avatarService.currentAvatarState, size: .small, kitNumber: player.kitNumberValue)
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

    // MARK: - Session in progress

    @ViewBuilder
    private var resumeStrip: some View {
        if let snapshot = pendingSession, let drillName = pendingDrillName(snapshot) {
            Button {
                HapticManager.shared.lightTap()
                resumeSession(snapshot)
            } label: {
                TQPitchCard(.strip, markings: .strip) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            TQEyebrow("Session in progress · \(clockLabel(snapshot.totalSeconds))", size: 11)
                            TQDisplayTitle(drillName, size: .strip)
                                .lineLimit(1)
                            Text("Drill \(snapshot.currentExerciseIndex + 1) of \(snapshot.exerciseIDs.count) · tap to continue")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textOnPitch)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        TQChevron(color: DesignSystem.Colors.textOnPitch)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.resumeSession")
            .accessibilityHint("Continues the interrupted session")
            .contextMenu {
                Button(role: .destructive) { discardPendingSession() } label: { Label("Discard session", systemImage: "trash") }
            }
        }
    }

    private func clockLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func pendingDrillName(_ snapshot: SessionSnapshot) -> String? {
        guard snapshot.currentExerciseIndex < snapshot.exerciseIDs.count,
              let id = UUID(uuidString: snapshot.exerciseIDs[snapshot.currentExerciseIndex]) else { return nil }
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request).first)?.name
    }

    private func resumeSession(_ snapshot: SessionSnapshot) {
        guard let manager = ActiveSessionManager.restore(snapshot, in: viewContext) else {
            discardPendingSession()
            return
        }
        trainingLaunch = TrainingLaunch(exercises: manager.exercises, planSession: manager.planSession, resumeFrom: snapshot)
    }

    private func discardPendingSession() {
        SessionSnapshot.clear()
        withAnimation(DesignSystem.Animation.quick) { pendingSession = nil }
    }

    private func loadPendingSession() {
        pendingSession = SessionSnapshot.load()
        if let snapshot = pendingSession, pendingDrillName(snapshot) == nil { discardPendingSession() }
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

    /// "Today's session", or "Catch-up session" when the plan's last training day went by untrained.
    private var sessionEyebrow: String {
        if case .session(_, _, _, let overdue)? = todayState, overdue { return "Catch-up session" }
        return "Today's session"
    }

    private var isRestDay: Bool {
        if case .rest? = todayState { return true }
        return false
    }

    /// " 3 free AI drills left." on the free tier, so the gate is known before the tap.
    private var freeDrillsSuffix: String {
        guard !subscriptionManager.isPro else { return "" }
        let remaining = subscriptionManager.freeDrillsRemaining
        return remaining == 0 ? " AI drills need Pro now." : " \(remaining) free AI drill\(remaining == 1 ? "" : "s") left."
    }

    private func restHero(session: PlanSession, player: Player) -> some View {
        var next = "Next session soon"
        if case .rest(let upcoming)? = todayState, let upcoming {
            let name = todaysExercises.first?.name ?? (SessionType(rawValue: session.sessionType ?? "") ?? .technical).displayName + " session"
            next = "Next: \(PlanSchedule.label(for: upcoming.date, now: Date(), calendar: Calendar.current)) · \(name)"
        }
        return TQHeroCard(
            eyebrow: "Rest day",
            trailingMeta: weekDayMeta,
            title: "Recover today",
            body: next + ". Rest is part of the plan; a light touch of the ball is fine.",
            actionTitle: "Train anyway",
            linkTitle: nil,
            markings: .heroSimple,
            action: { startPlanSession(session) }
        )
    }

    @ViewBuilder
    private func hero(player: Player) -> some View {
        if coachIsLoading {
            TQHeroCard(eyebrow: "Today's session", trailingMeta: weekDayMeta, title: "", actionTitle: "", state: .loading, markings: .heroSimple, action: {})
        } else if let session = todaysSession, isRestDay {
            restHero(session: session, player: player)
        } else if let session = todaysSession {
            planHero(session: session, player: player)
        } else if let coaching = todaysCoaching, !planIsComplete {
            coachHero(coaching: coaching, player: player)
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
                body: "No plan yet. Start with a quick drill built for your position and \(coachName) will learn from how it goes.\(freeDrillsSuffix)",
                actionTitle: "Start quick drill",
                linkTitle: "build a plan first",
                markings: .heroSimple,
                action: { startQuickDrill() },
                linkAction: { openPlanGenerator(for: player) }
            )
        } else {
            TQHeroCard(
                eyebrow: "Today's session",
                title: "Quick drill for your weakest skill",
                body: "No active plan. \(coachName) builds a ten-minute drill around what needs work most.\(freeDrillsSuffix)",
                actionTitle: "Start quick drill",
                linkTitle: "build a plan",
                markings: .heroSimple,
                action: { startQuickDrill() },
                linkAction: { openPlanGenerator(for: player) }
            )
        }
    }

    /// No plan session today: the coach's pick from the library, or an offer to build one.
    private func coachHero(coaching: DailyCoaching, player: Player) -> some View {
        let drill = coaching.recommendedDrill
        let pick = coachPick(coaching)
        var figures: [(String, String)] = [("\(max(pick.map { Int($0.estimatedDurationSeconds) / 60 } ?? drill.duration, 1))", "min")]
        let level = pick.map { Int($0.difficulty) } ?? drill.difficulty
        if level > 0 { figures.append(("\(level)", "lvl")) }
        if let foot = weakFootLabel(for: player, skills: pick?.targetSkills ?? drill.targetSkills, focus: coaching.focusArea) { figures.append((foot, "foot")) }
        return TQHeroCard(
            eyebrow: "\(coachName)'s pick · \(coaching.focusArea)",
            trailingMeta: weekDayMeta,
            title: pick?.name ?? drill.name,
            figures: figures,
            body: coachNote(coaching),
            actionTitle: pick == nil ? "Build a fresh one" : "Start session",
            markings: .hero,
            action: {
                if let pick {
                    trainingLaunch = TrainingLaunch(exercises: [pick], planSession: nil)
                } else {
                    showingCoachBuild = true
                }
            }
        )
    }

    /// "Marta: Open your hips before the second touch."
    private func coachNote(_ coaching: DailyCoaching) -> String {
        let line = (coaching.cue ?? coaching.reasoning).trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? coaching.reasoning : "\(coachName): \(line)"
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
        let coaching = todaysCoaching
        let pick = coaching.flatMap { coachPick($0) }
        let pickIsTodays = pick.map { candidate in todaysExercises.contains { $0.objectID == candidate.objectID } } ?? false
        var linkTitle: String? = nil
        if isOffline {
            bodyText = "\(coachName)'s note comes back with the connection."
            bodyTone = .italicMuted
        } else if let coaching, pick == nil || pickIsTodays || coachSwapExercise != nil {
            bodyText = coachNote(coaching)
            bodyTone = .onPitch
        } else if let coaching, let pick {
            bodyText = coachNote(coaching)
            bodyTone = .onPitch
            linkTitle = "swap in \(pick.name ?? "the coach's pick")"
        } else if let focus = currentWeekFocus {
            bodyText = "This week: \(focus)."
            bodyTone = .onPitch
        } else {
            bodyText = nil
            bodyTone = .onPitch
        }

        let swapped = coachSwapExercise
        return TQHeroCard(
            eyebrow: isOffline ? "\(sessionEyebrow) · from plan" : (swapped == nil ? sessionEyebrow : "\(coachName)'s pick"),
            trailingMeta: weekDayMeta,
            title: swapped?.name ?? title,
            figures: figures,
            body: bodyText,
            bodyTone: bodyTone,
            actionTitle: "Start session",
            linkTitle: linkTitle,
            markings: isOffline ? .heroSimple : .hero,
            action: {
                if let swapped {
                    trainingLaunch = TrainingLaunch(exercises: [swapped], planSession: session)
                } else {
                    startPlanSession(session)
                }
            },
            linkAction: { withAnimation(DesignSystem.Animation.quick) { coachSwapExercise = pick } }
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
        let calendar = Calendar.current
        var plannedDays: [HomeWeekModel.PlannedDay]? = nil
        if let plan = activePlan {
            let startDate = PlanSchedule.startDate(of: plan)
            plannedDays = PlanSchedule.trainingDays(in: plan, startDate: startDate, calendar: calendar)
                .filter { !$0.day.isSkipped }
                .map { HomeWeekModel.PlannedDay(date: $0.date, sessionCount: $0.day.sessions.count, isDone: $0.day.isDone) }
        }
        return HomeWeekModel.build(today: Date(), calendar: calendar, sessionDates: sessionDates, plannedDays: plannedDays)
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
                if let next = nextSessionMeta {
                    TQRow("Next session", meta: next, action: { route = .planDetail(plan) })
                        .accessibilityIdentifier("home.nextSession")
                }
                if aiCoachService.weeklyCheckInAvailable {
                    TQRow("Week \(aiCoachService.completedWeekNumber) review ready",
                          subtitle: subscriptionManager.isPro ? "\(coachName) read the week; see what changes" : "\(coachName)'s review of the week · Pro",
                          badge: TQBadge(.status(subscriptionManager.isPro ? "New" : "Pro")),
                          action: { if subscriptionManager.isPro { showingWeeklyReview = true } else { paywallFeature = .weeklyAdaptation } })
                        .accessibilityIdentifier("home.weeklyReview")
                }
            } else {
                TQRow("Build a training plan",
                      badge: TQBadge(.text(subscriptionManager.planGateLabel(for: player) ?? "AI")),
                      action: { openPlanGenerator(for: player) })
            }

            if forcedState != "empty", let match = recentMatches.first(where: { ($0.date ?? .distantFuture) <= Date() }) {
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
            TQRow("Drills from \(coachName)", note: "after your first session").disabled(true)
        } else if isOffline {
            TQRow("Drills from \(coachName)", note: "needs connection").disabled(true)
        } else if coachIsLoading {
            HStack(spacing: 12) {
                Text("Drills from \(coachName)")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                Spacer()
                TQSkeleton(width: 22, height: 18, cornerRadius: 3)
                TQChevron()
            }
            .padding(.vertical, DesignSystem.Spacing.rowVerticalLarge)
            .overlay(alignment: .bottom) { TQRule() }
        } else {
            TQRow("Drills from \(coachName)",
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

    private func openPlanGenerator(for player: Player) {
        if subscriptionManager.canGeneratePlan(for: player) {
            showingPlanGenerator = true
        } else {
            paywallFeature = .trainingPlan
        }
    }

    private func startQuickDrill() {
        if subscriptionManager.canGenerateDrill() {
            quickDrillWeakness = nil
            showingQuickDrill = true
        } else {
            showingQuickDrillPaywall = true
        }
    }

    private func startPlanSession(_ session: PlanSession) {
        if todaysExercises.isEmpty {
            showingLogPlanSession = true
        } else if todaysExercises.count > 1 {
            // Several drills: show what the session holds before the clock starts.
            previewSession = session
        } else {
            trainingLaunch = TrainingLaunch(exercises: todaysExercises, planSession: session)
        }
    }

    /// "Thu · First-touch directional" for the next planned session after today, or nil.
    private var nextSessionMeta: TQRow.Meta? {
        guard let plan = activePlan else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let upcoming = PlanSchedule.upcoming(in: plan, startDate: PlanSchedule.startDate(of: plan), now: now, calendar: calendar, limit: 3)
        guard let next = upcoming.first(where: { $0.date > todayStart }) else { return nil }
        let name = next.day.sessions.first.flatMap { session in
            session.exerciseIDs.first.flatMap { id in
                recentExerciseName(id)
            } ?? "\(session.sessionType.displayName) session"
        } ?? "Training"
        return .init("\(PlanSchedule.label(for: next.date, now: now, calendar: calendar)) · \(name)", size: 14, face: .text)
    }

    private func recentExerciseName(_ id: UUID) -> String? {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request).first)?.name
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
        activePlan = forcedState == "empty" ? nil : TrainingPlanService.shared.fetchActivePlan(for: player)
        loadPendingSession()
        guard let plan = activePlan else {
            currentWeekDay = nil
            planIsComplete = false
            todaysSession = nil
            todaysExercises = []
            return
        }
        currentWeekDay = TrainingPlanService.shared.getCurrentWeekAndDay(for: plan)
        todayState = PlanSchedule.today(in: plan, startDate: PlanSchedule.startDate(of: plan), now: Date(), calendar: Calendar.current)
        coachSwapExercise = nil
        NotificationManager.shared.refresh(for: player)
        aiCoachService.refreshWeeklyReview(for: player, now: Date(), calendar: Calendar.current)
        // A plan with no schedule at all (empty prebuilt shell) is not "complete"; it just has nothing to start.
        planIsComplete = currentWeekDay == nil && plan.totalDays > 0
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

    /// Fetches today's coaching for Pro players in the background. Nothing on screen waits for it.
    @MainActor
    private func fetchCoaching(for player: Player, force: Bool) async {
        guard subscriptionManager.isPro, !isOffline else { return }
        if !force, let cached = aiCoachService.dailyCoaching, Calendar.current.isDateInToday(cached.fetchDate) { return }
        await aiCoachService.fetchDailyCoachingIfNeeded(for: player)
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
