import SwiftUI
import CoreData

struct ActivePlanView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var planService = TrainingPlanService.shared

    @State private var activePlan: TrainingPlanModel?
    @State private var currentDayID: UUID?
    @State private var selectedSession: PlanSessionModel?
    @State private var showingSessionCompletion = false
    @State private var completionDuration: Int = 60
    @State private var completionIntensity: Int = 3

    @FetchRequest var players: FetchedResults<Player>

    init() {
        self._players = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }

    var body: some View {
        NavigationView {
            Group {
                if let plan = activePlan {
                    activePlanContent(plan)
                } else {
                    noPlanView
                }
            }
            .navigationTitle("My Training Plan")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                updatePlayersFilter()
                loadActivePlan()
            }
            .onChange(of: authManager.userUID) {
                updatePlayersFilter()
                loadActivePlan()
            }
            .sheet(isPresented: $showingSessionCompletion) {
                if let session = selectedSession {
                    sessionCompletionSheet(session)
                }
            }
        }
    }

    // MARK: - Active Plan Content

    private func activePlanContent(_ plan: TrainingPlanModel) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Progress Overview Card
                progressOverviewCard(plan)

                // Current Week Card
                if let currentWeek = plan.weeks.first(where: { $0.weekNumber == plan.currentWeek }) {
                    currentWeekCard(currentWeek)
                }

                // Weekly Calendar
                weeklyCalendar(plan)

                // Quick Stats
                quickStats(plan)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Progress Overview Card

    private func progressOverviewCard(_ plan: TrainingPlanModel) -> some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Week \(plan.currentWeek) of \(plan.durationWeeks)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    CircularProgressView(
                        progress: plan.progressPercentage / 100.0,
                        size: 60,
                        lineWidth: 6
                    )
                }

                ProgressView(value: plan.progressPercentage / 100.0)
                    .tint(DesignSystem.Colors.primaryGreen)

                Text("\(Int(plan.progressPercentage))% Complete")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Current Week Card

    private func currentWeekCard(_ week: PlanWeekModel) -> some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("This Week's Focus")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if week.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)
                    }
                }

                if let focusArea = week.focusArea {
                    Text(focusArea)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                if let notes = week.notes {
                    Text(notes)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.top, 4)
                }

                // Sessions Progress
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("\(week.completedSessions) of \(week.totalSessions) sessions completed")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Weekly Calendar

    private func weeklyCalendar(_ plan: TrainingPlanModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("This Week's Schedule")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let currentWeek = plan.weeks.first(where: { $0.weekNumber == plan.currentWeek }) {
                ForEach(currentWeek.days) { day in
                    let isCurrent = day.id == currentDayID
                    let isLocked = !day.isDone && !isCurrent
                    DayCard(day: day, isCurrent: isCurrent, isLocked: isLocked) { session in
                        selectedSession = session
                        completionDuration = session.duration
                        completionIntensity = session.intensity
                        showingSessionCompletion = true
                    }
                }
            }
        }
    }

    // MARK: - Quick Stats

    private func quickStats(_ plan: TrainingPlanModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Progress Stats")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                QuickStatCard(
                    icon: "checkmark.circle",
                    value: "\(plan.completedSessions)",
                    label: "Completed",
                    color: DesignSystem.Colors.success
                )

                QuickStatCard(
                    icon: "clock.arrow.circlepath",
                    value: "\(plan.totalSessions - plan.completedSessions)",
                    label: "Remaining",
                    color: DesignSystem.Colors.accentOrange
                )

                QuickStatCard(
                    icon: "calendar.badge.clock",
                    value: "\(plan.durationWeeks - plan.currentWeek + 1)",
                    label: "Weeks Left",
                    color: DesignSystem.Colors.secondaryBlue
                )
            }
        }
    }

    // MARK: - No Plan View

    private var noPlanView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.3))

            Text("No Active Plan")
                .font(DesignSystem.Typography.titleLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Choose a training plan to get started on your journey to improvement")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
    }

    // MARK: - Session Completion Sheet

    private func sessionCompletionSheet(_ session: PlanSessionModel) -> some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Session Info
                ModernCard(padding: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: session.sessionType.icon)
                                .font(.title2)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)

                            Text(session.sessionType.displayName)
                                .font(DesignSystem.Typography.titleMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        if let notes = session.notes {
                            Text(notes)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                // Duration Slider
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Duration: \(completionDuration) minutes")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Slider(value: Binding(
                        get: { Double(completionDuration) },
                        set: { completionDuration = Int($0) }
                    ), in: 10...180, step: 5)
                    .tint(DesignSystem.Colors.primaryGreen)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)

                // Intensity Picker
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Intensity")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(1...5, id: \.self) { level in
                            IntensityButton(level: level, selectedLevel: $completionIntensity)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)

                Spacer()

                // Complete Button
                ModernButton("Mark Complete", icon: "checkmark.circle.fill", style: .primary) {
                    completeSession()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .navigationTitle("Complete Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingSessionCompletion = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }

    private func loadActivePlan() {
        guard let player = players.first else { return }
        activePlan = planService.fetchActivePlan(for: player)
        if let plan = activePlan {
            currentDayID = planService.getCurrentDay(for: plan)?.day.id
        }
    }

    private func completeSession() {
        guard let session = selectedSession else { return }
        planService.markSessionCompleted(session, actualDuration: completionDuration, actualIntensity: completionIntensity)
        showingSessionCompletion = false
        loadActivePlan() // Refresh the view
    }
}

// MARK: - Day Card

struct DayCard: View {
    let day: PlanDayModel
    var isCurrent: Bool = false
    var isLocked: Bool = false
    let onSessionTap: (PlanSessionModel) -> Void

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    if let dayOfWeek = day.dayOfWeek {
                        Text(dayOfWeek.displayName)
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(isLocked ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    } else {
                        Text("Day \(day.dayNumber)")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(isLocked ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    }

                    if isCurrent {
                        Text("Current")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.primaryGreen)
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }

                    Spacer()

                    if day.isSkipped {
                        Text("Skipped")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.textSecondary.opacity(0.15))
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    } else if day.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))
                    }
                }

                if isLocked {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.4))

                        Text("Complete previous days to unlock")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.6))
                    }
                } else if day.isRestDay {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(DesignSystem.Colors.accentYellow)

                        Text("Rest Day")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    }
                } else {
                    ForEach(day.sessions) { session in
                        SessionRow(session: session) {
                            if !isLocked {
                                onSessionTap(session)
                            }
                        }
                    }
                }
            }
        }
        .opacity(isLocked ? 0.6 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(isCurrent ? DesignSystem.Colors.primaryGreen : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: PlanSessionModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: session.sessionType.icon)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionType.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(session.duration) min • Intensity \(session.intensity)/5")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.3))
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.sm) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(value)
                    .font(DesignSystem.Typography.numberLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(label)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.textSecondary.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(DesignSystem.Colors.primaryGreen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Intensity Button

struct IntensityButton: View {
    let level: Int
    @Binding var selectedLevel: Int

    var body: some View {
        Button {
            selectedLevel = level
        } label: {
            Text("\(level)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(selectedLevel == level ? .white : DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(selectedLevel == level ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ActivePlanView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
