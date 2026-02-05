import SwiftUI
import CoreData

struct TodaysTrainingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let activePlan: TrainingPlanModel

    @State private var todaysSessions: [PlanSession] = []
    @State private var currentDay: PlanDayModel?
    @State private var currentWeek: Int = 1
    @State private var planComplete = false
    @State private var showingNewSession = false
    @State private var showingActiveTraining = false
    @State private var selectedPlanSession: PlanSession?
    @State private var activeTrainingExercises: [Exercise] = []

    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header Card
                    headerCard

                    // Progress Card
                    progressCard

                    if planComplete {
                        planCompleteCard
                    } else if todaysSessions.isEmpty {
                        emptyStateCard
                    } else {
                        sessionsListCard
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
        .navigationTitle("Today's Training")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadTodaysSessions()
        }
        .sheet(isPresented: $showingNewSession) {
            if let planSession = selectedPlanSession {
                NewSessionView(
                    player: player,
                    planSession: planSession
                )
            }
        }
        .fullScreenCover(isPresented: $showingActiveTraining) {
            ActiveTrainingView(exercises: activeTrainingExercises)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: activePlan.category.icon)
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activePlan.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        if let day = currentDay {
                            Text("Week \(currentWeek), Day \(day.dayNumber)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    DifficultyBadge(difficulty: activePlan.difficulty)
                }

                // Skip Day button
                if currentDay != nil && !planComplete {
                    Button {
                        skipCurrentDay()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "forward.fill")
                                .font(.caption)
                            Text("Skip Day")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.textSecondary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Overall Progress")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(Int(activePlan.progressPercentage))%")
                        .font(DesignSystem.Typography.titleSmall)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                ProgressView(value: activePlan.progressPercentage / 100.0)
                    .tint(DesignSystem.Colors.primaryGreen)

                HStack {
                    Text("\(activePlan.completedSessions) of \(activePlan.totalSessions) sessions complete")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Sessions List Card

    private var sessionsListCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Today's Sessions (\(todaysSessions.count))")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ForEach(todaysSessions, id: \.id) { session in
                PlanSessionCard(
                    session: session,
                    onStartSession: {
                        let exercises = (session.exercises?.allObjects as? [Exercise]) ?? []
                        if !exercises.isEmpty {
                            activeTrainingExercises = exercises
                            showingActiveTraining = true
                        } else {
                            selectedPlanSession = session
                            showingNewSession = true
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundColor(DesignSystem.Colors.neutral400)

                Text("No Sessions Today")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Enjoy your rest day! Come back tomorrow for your next training session.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Plan Complete

    private var planCompleteCard: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(DesignSystem.Colors.accentYellow)

                Text("Plan Complete!")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("You've finished all training days in this plan. Great work!")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Helper Functions

    private func loadTodaysSessions() {
        if let (week, day) = TrainingPlanService.shared.getCurrentDay(for: activePlan) {
            currentWeek = week
            currentDay = day
            planComplete = false
            todaysSessions = TrainingPlanService.shared.getTodaysSessions(for: activePlan)
        } else {
            currentDay = nil
            planComplete = true
            todaysSessions = []
        }
    }

    private func skipCurrentDay() {
        guard let day = currentDay else { return }
        TrainingPlanService.shared.skipDay(dayId: day.id)
        loadTodaysSessions()
    }
}

// MARK: - Plan Session Card

struct PlanSessionCard: View {
    @Environment(\.managedObjectContext) private var viewContext

    let session: PlanSession
    let onStartSession: () -> Void

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    // Session Type Icon
                    ZStack {
                        Circle()
                            .fill(sessionColor.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: sessionIcon)
                            .font(.title3)
                            .foregroundColor(sessionColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.sessionType ?? "Training")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("\(session.duration) min")
                                    .font(DesignSystem.Typography.labelSmall)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                            Text("•")
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                Text("Intensity \(session.intensity)")
                                    .font(DesignSystem.Typography.labelSmall)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Completion Status
                    if session.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.success)
                    }
                }

                // Exercises
                if let exercises = session.exercises?.allObjects as? [Exercise], !exercises.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Exercises (\(exercises.count))")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ForEach(exercises.prefix(3), id: \.id) { exercise in
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "soccerball")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                                Text(exercise.name ?? "Exercise")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }

                        if exercises.count > 3 {
                            Text("+\(exercises.count - 3) more")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                // Notes
                if let notes = session.notes, !notes.isEmpty {
                    Divider()

                    Text(notes)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                // Action Button
                if !session.isCompleted {
                    ModernButton("Start Session", icon: "play.circle.fill", style: .primary) {
                        onStartSession()
                    }
                }
            }
        }
    }

    private var sessionIcon: String {
        let type = session.sessionType?.lowercased() ?? ""
        switch type {
        case "technical": return "target"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        case "recovery": return "bed.double.fill"
        case "match": return "sportscourt"
        case "warmup": return "flame.fill"
        case "cooldown": return "snowflake"
        default: return "soccerball"
        }
    }

    private var sessionColor: Color {
        let type = session.sessionType?.lowercased() ?? ""
        switch type {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.error
        case "tactical": return DesignSystem.Colors.secondaryBlue
        case "recovery": return DesignSystem.Colors.warning
        case "match": return DesignSystem.Colors.accentOrange
        case "warmup": return DesignSystem.Colors.accentOrange
        case "cooldown": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.primaryGreen
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"

    let mockPlan = TrainingPlanModel(
        id: UUID(),
        name: "Midfielder Mastery",
        description: "6-week program",
        durationWeeks: 6,
        difficulty: .intermediate,
        category: .position,
        targetRole: "Midfielder",
        isPrebuilt: true,
        isActive: true,
        currentWeek: 1,
        progressPercentage: 15.0,
        startedAt: Date(),
        completedAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        weeks: []
    )

    return NavigationView {
        TodaysTrainingView(player: samplePlayer, activePlan: mockPlan)
            .environment(\.managedObjectContext, context)
    }
}
