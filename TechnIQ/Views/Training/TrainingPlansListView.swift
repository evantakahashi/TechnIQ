import SwiftUI

// MARK: - Plans (Touchline 8a)
//
// Title row with "+ New plan" (AI / custom sheet), the active plan as a pitch card (name, WK n/8,
// progress bar, next session line), a Pre-built / My plans segment, and flat plan rows with a
// weeks tile, name, meta (category · role · frequency), level badge and chevron.

struct TrainingPlansListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var planService = TrainingPlanService.shared

    @State private var tabIndex = 0
    @State private var showingPaywall = false
    @State private var showingNewPlanMenu = false
    @State private var showingCustomBuilder = false
    @State private var showingAIGenerator = false
    @State private var showingShareSheet = false
    @State private var planToShare: TrainingPlanModel?
    @State private var myPlans: [TrainingPlanModel] = []
    @State private var activeNextLine = ""
    @State private var route: TrainingPlanModel?

    @FetchRequest var players: FetchedResults<Player>

    init() {
        self._players = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }

    private var activePlan: TrainingPlanModel? { planService.activePlan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQScreenTitle("Plans") {
                    TQButton("+ New plan", size: .compact, fullWidth: false) { showingNewPlanMenu = true }
                }

                if let plan = activePlan {
                    activePlanCard(plan)
                }

                TQSegment(options: ["Pre-built", myPlans.isEmpty ? "My plans" : "My plans · \(myPlans.count)"], selectedIndex: $tabIndex)

                if tabIndex == 0 {
                    planRows(planService.availablePlans)
                } else if myPlans.isEmpty {
                    emptyMyPlans
                } else {
                    planRows(myPlans, shareable: true)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .coachMark(.plans)
        .navigationDestination(item: $route) { plan in
            if let player = players.first {
                TrainingPlanDetailView(initialPlan: plan, player: player)
            }
        }
        .onAppear {
            updatePlayersFilter()
            loadMyPlans()
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
            loadMyPlans()
        }
        .sheet(isPresented: $showingNewPlanMenu) {
            NewPlanSheet(
                onAI: {
                    showingNewPlanMenu = false
                    if subscriptionManager.isPro { showingAIGenerator = true } else { showingPaywall = true }
                },
                onCustom: { showingNewPlanMenu = false; showingCustomBuilder = true }
            )
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingCustomBuilder, onDismiss: { loadMyPlans() }) {
            if let player = players.first {
                CustomPlanBuilderView(player: player)
            }
        }
        .sheet(isPresented: $showingAIGenerator, onDismiss: { loadMyPlans() }) {
            if let player = players.first {
                NavigationStack {
                    AITrainingPlanGeneratorView(player: player)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let plan = planToShare {
                SharePlanView(plan: plan)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: .trainingPlan)
        }
    }

    // MARK: - Active plan card

    private func activePlanCard(_ plan: TrainingPlanModel) -> some View {
        // Pure read: view bodies must not advance the plan (that happens in loadMyPlans()).
        let weekDay = TrainingPlanService.peekCurrentWeekAndDay(in: plan)
        let week = weekDay?.week ?? max(plan.currentWeek, 1)
        let progress = min(1, max(0, plan.progressPercentage / 100))
        return Button {
            HapticManager.shared.lightTap()
            route = plan
        } label: {
            TQPitchCard(.card, markings: .plan) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TQEyebrow("Active plan", size: 11)
                        Spacer()
                        TQMeta("WK \(week) / \(plan.durationWeeks)", tone: .onPitch)
                    }
                    TQDisplayTitle(plan.name, size: .card)
                    HStack(spacing: 12) {
                        TQProgressBar(progress: progress, height: 6)
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(Font.system(size: 15, weight: .semibold).width(.condensed).monospacedDigit())
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                    }
                    HStack {
                        Text(activeNextLine.isEmpty ? nextSessionLine(for: plan, weekDay: weekDay) : activeNextLine)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textOnPitch)
                            .lineLimit(1)
                        Spacer()
                        TQChevron(color: DesignSystem.Colors.textOnPitch)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the plan")
    }

    private func nextSessionLine(for plan: TrainingPlanModel, weekDay: (week: Int, day: Int)?, exerciseName: String? = nil) -> String {
        guard let weekDay,
              let week = plan.weeks.first(where: { $0.weekNumber == weekDay.week }),
              let day = week.days.first(where: { $0.dayNumber == weekDay.day }) else {
            return plan.isCompleted ? "Plan complete" : "Next: pick up where you left off"
        }
        let what = exerciseName ?? (day.sessions.first.map { "\($0.sessionType.displayName) session" } ?? "Training")
        let when = day.dayOfWeek?.shortName ?? "Day \(day.dayNumber)"
        return "Next: \(what) · \(when)"
    }

    // MARK: - Rows

    private func planRows(_ plans: [TrainingPlanModel], shareable: Bool = false) -> some View {
        TQRowList {
            ForEach(plans) { plan in
                TQRow(
                    plan.name,
                    subtitle: planMeta(plan),
                    leading: .tile(TQTile(number: "\(plan.durationWeeks)", unit: "W", accent: plan.isActive)),
                    badge: TQBadge(.level(level(for: plan.difficulty))),
                    verticalPadding: 13,
                    action: { route = plan }
                )
                .contextMenu {
                    if shareable {
                        Button {
                            planToShare = plan
                            showingShareSheet = true
                        } label: {
                            Label("Share plan", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func planMeta(_ plan: TrainingPlanModel) -> String {
        var parts: [String] = [plan.category == .position ? "Position" : plan.category.displayName]
        if let role = plan.targetRole, !role.isEmpty {
            parts.append(role)
        } else {
            parts.append(plan.category == .general ? "All ages" : "All positions")
        }
        let perWeek = plan.weeks.first.map { $0.days.filter { !$0.isRestDay }.count } ?? 0
        if perWeek > 0 { parts.append("\(perWeek)×/wk") }
        return parts.joined(separator: " · ")
    }

    private func level(for difficulty: PlanDifficulty) -> TQBadge.Level {
        switch difficulty {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        case .elite: return .elite
        }
    }

    private var emptyMyPlans: some View {
        TQRowList {
            TQRow("No plans of your own yet", note: "use + New plan").disabled(true)
        }
    }

    // MARK: - Data

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }

    private func loadMyPlans() {
        guard let player = players.first else { return }
        myPlans = planService.fetchAllPlans(for: player)
        planService.activePlan = planService.fetchActivePlan(for: player)
        // Progression (auto-completing pending rest days) happens here, once per load; the card
        // body only peeks at the model.
        if let plan = planService.activePlan {
            let weekDay = planService.getCurrentWeekAndDay(for: plan)
            let sessions = planService.getTodaysSessions(for: plan)
            let exerciseName = sessions.first?.exercises?.allObjects.compactMap { ($0 as? Exercise)?.name }.sorted().first
            activeNextLine = nextSessionLine(for: plan, weekDay: weekDay, exerciseName: exerciseName)
        } else {
            activeNextLine = ""
        }
    }
}

// MARK: - New plan sheet (AI / custom)

struct NewPlanSheet: View {
    let onAI: () -> Void
    let onCustom: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQGroupHeader("New plan")
                .padding(.top, 4)
            TQRowList {
                TQRow(
                    "Build it with the coach",
                    subtitle: "Position, weak spots, schedule · Pro",
                    leading: .tile(TQTile("AI", style: .ai)),
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: onAI
                )
                TQRow(
                    "Build it yourself",
                    subtitle: "Custom weeks and sessions",
                    leading: .tile(TQTile(symbol: "plus")),
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: onCustom
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Difficulty badge (legacy call sites)

/// Deprecated: use TQBadge(.level(_:)). Kept for out-of-scope screens.
struct DifficultyBadge: View {
    let difficulty: PlanDifficulty

    var body: some View {
        switch difficulty {
        case .beginner: TQBadge(.level(.beginner))
        case .intermediate: TQBadge(.level(.intermediate))
        case .advanced: TQBadge(.level(.advanced))
        case .elite: TQBadge(.level(.elite))
        }
    }
}

enum PlanTab: String, CaseIterable {
    case prebuilt = "Pre-built"
    case myPlans = "My Plans"
}

#Preview {
    NavigationStack {
        TrainingPlansListView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(SubscriptionManager.shared)
    }
}
