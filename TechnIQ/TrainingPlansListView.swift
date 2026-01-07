import SwiftUI
import CoreData

struct TrainingPlansListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var planService = TrainingPlanService.shared

    @State private var selectedTab: PlanTab = .prebuilt
    @State private var selectedPlan: TrainingPlanModel?
    @State private var showingPlanDetail = false
    @State private var showingCustomBuilder = false
    @State private var showingAIGenerator = false
    @State private var showingShareSheet = false
    @State private var planToShare: TrainingPlanModel?
    @State private var myPlans: [TrainingPlanModel] = []

    @FetchRequest var players: FetchedResults<Player>

    init() {
        self._players = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            tabSelector

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Active Plan Card
                    if let activePlan = planService.activePlan {
                        activePlanCard(activePlan)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.top, DesignSystem.Spacing.md)
                    }

                    // Plans Grid
                    if selectedTab == .prebuilt {
                        prebuiltPlansGrid
                    } else {
                        myPlansGrid
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Training Plans")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            updatePlayersFilter()
            loadMyPlans()
        }
        .onChange(of: authManager.userUID) {
            updatePlayersFilter()
            loadMyPlans()
        }
        .sheet(isPresented: $showingPlanDetail) {
            if let plan = selectedPlan, let player = players.first {
                TrainingPlanDetailView(initialPlan: plan, player: player)
            }
        }
        .sheet(isPresented: $showingCustomBuilder) {
            if let player = players.first {
                CustomPlanBuilderView(player: player)
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            if let player = players.first {
                NavigationView {
                    AITrainingPlanGeneratorView(player: player)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let plan = planToShare {
                SharePlanView(plan: plan)
            }
        }
        .onChange(of: showingAIGenerator) { newValue in
            // Reload plans when AI generator is dismissed
            if !newValue {
                loadMyPlans()
            }
        }
        .onChange(of: showingCustomBuilder) { newValue in
            // Reload plans when custom builder is dismissed
            if !newValue {
                loadMyPlans()
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "Pre-built Programs", tab: .prebuilt, selectedTab: $selectedTab)
            TabButton(title: "My Plans", tab: .myPlans, selectedTab: $selectedTab)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Active Plan Card

    private func activePlanCard(_ plan: TrainingPlanModel) -> some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    Text("Active Plan")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    Spacer()
                }

                Text(plan.name)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                ProgressView(value: plan.progressPercentage / 100.0)
                    .tint(DesignSystem.Colors.primaryGreen)

                HStack {
                    Text("\(Int(plan.progressPercentage))% Complete")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("Week \(plan.currentWeek) of \(plan.durationWeeks)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .onTapGesture {
            selectedPlan = plan
            showingPlanDetail = true
        }
    }

    // MARK: - Pre-built Plans Grid

    private var prebuiltPlansGrid: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(planService.availablePlans) { plan in
                PlanCard(plan: plan) {
                    selectedPlan = plan
                    showingPlanDetail = true
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - My Plans Grid

    private var myPlansGrid: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // AI Generation Button
            ModernButton("Generate with AI", icon: "sparkles", style: .primary) {
                showingAIGenerator = true
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Create Custom Plan Button
            ModernButton("Create Custom Plan", icon: "plus.circle.fill", style: .secondary) {
                showingCustomBuilder = true
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            if myPlans.isEmpty {
                emptyMyPlansView
            } else {
                ForEach(myPlans) { plan in
                    PlanCard(plan: plan, showShareButton: true) {
                        selectedPlan = plan
                        showingPlanDetail = true
                    } onShare: {
                        planToShare = plan
                        showingShareSheet = true
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    private var emptyMyPlansView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.3))

            Text("No Custom Plans Yet")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Create your own training plan or choose a pre-built program")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }

    // MARK: - Helper Methods

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }

    private func loadMyPlans() {
        guard let player = players.first else { return }
        myPlans = planService.fetchAllPlans(for: player)
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: TrainingPlanModel
    var showShareButton: Bool = false
    let onTap: () -> Void
    var onShare: (() -> Void)? = nil

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: plan.category.icon)
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        if let targetRole = plan.targetRole {
                            Text(targetRole)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    if showShareButton {
                        Button {
                            onShare?()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(DesignSystem.Colors.secondaryBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    DifficultyBadge(difficulty: plan.difficulty)
                }

                // Description
                Text(plan.description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)

                Divider()

                // Stats
                HStack(spacing: DesignSystem.Spacing.md) {
                    StatItem(icon: "calendar", value: "\(plan.durationWeeks) weeks", color: DesignSystem.Colors.secondaryBlue)

                    Divider()
                        .frame(height: 20)

                    StatItem(icon: "clock", value: String(format: "%.0f hrs", plan.estimatedTotalHours), color: DesignSystem.Colors.accentOrange)

                    Spacer()
                }
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: PlanDifficulty

    var body: some View {
        Text(difficulty.displayName)
            .font(DesignSystem.Typography.labelSmall)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(DesignSystem.CornerRadius.xs)
    }

    private var badgeColor: Color {
        switch difficulty {
        case .beginner: return DesignSystem.Colors.success
        case .intermediate: return DesignSystem.Colors.secondaryBlue
        case .advanced: return DesignSystem.Colors.warning
        case .elite: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let tab: PlanTab
    @Binding var selectedTab: PlanTab

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(selectedTab == tab ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)

                Rectangle()
                    .fill(selectedTab == tab ? DesignSystem.Colors.primaryGreen : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enums

enum PlanTab: String, CaseIterable {
    case prebuilt = "Pre-built"
    case myPlans = "My Plans"
}

#Preview {
    TrainingPlansListView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
