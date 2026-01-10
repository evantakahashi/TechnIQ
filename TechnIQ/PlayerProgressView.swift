import SwiftUI
import Charts
import CoreData

struct PlayerProgressView: View {
    let player: Player
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedTimeRange: TimeRange = .month
    @State private var skillProgressData: [SkillProgress] = []
    @State private var overallStats: OverallStats?
    @State private var recentAchievements: [ProgressAchievement] = []
    @State private var trainingInsights: [TrainingInsight] = []
    @State private var trainingSessions: [TrainingSession] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                timeRangePicker

                // Overall Stats Cards
                overallStatsSection

                // Smart Insights Section (NEW)
                if !trainingInsights.isEmpty {
                    insightsSection
                }

                // Training Calendar Heat Map (NEW)
                if !trainingSessions.isEmpty && trainingSessions.count > 0 {
                    calendarHeatMapSection
                }

                // Skill Trend Charts (NEW)
                if !trainingSessions.isEmpty && trainingSessions.count > 0 {
                    skillTrendSection
                }

                // Skills Development Chart
                skillsDevelopmentSection

                // Recent Achievements
                achievementsSection

                // Training Consistency
                trainingConsistencySection

                // Category Breakdown
                categoryBreakdownSection
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadProgressData()
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation {
                            selectedTimeRange = range
                            loadProgressData()
                        }
                    } label: {
                        Text(range.displayName)
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                            .foregroundColor(selectedTimeRange == range ? .white : DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(minWidth: 70)
                            .background(
                                selectedTimeRange == range ? DesignSystem.Colors.primaryGreen : Color(.systemGray6)
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Overall Stats Section

    private var overallStatsSection: some View {
        VStack(spacing: 12) {
            if let stats = overallStats {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Sessions",
                        value: "\(stats.totalSessions)",
                        icon: "calendar",
                        color: DesignSystem.Colors.primaryGreen
                    )

                    StatCard(
                        title: "Hours",
                        value: String(format: "%.1f", stats.totalHours),
                        icon: "clock.fill",
                        color: DesignSystem.Colors.accentOrange
                    )
                }

                HStack(spacing: 12) {
                    StatCard(
                        title: "Avg Rating",
                        value: String(format: "%.1f", stats.averageRating),
                        subtitle: "/ 5.0",
                        icon: "star.fill",
                        color: DesignSystem.Colors.accentYellow
                    )

                    StatCard(
                        title: "Improvement",
                        value: stats.improvementPercentage > 0 ? "+\(Int(stats.improvementPercentage))%" : "\(Int(stats.improvementPercentage))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: stats.improvementPercentage > 0 ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.secondaryBlue
                    )
                }
            } else {
                ProgressView("Loading stats...")
                    .padding()
            }
        }
    }

    // MARK: - Skills Development Section

    private var skillsDevelopmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills Development")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            if !skillProgressData.isEmpty {
                VStack(spacing: 10) {
                    ForEach(skillProgressData.prefix(5)) { skill in
                        SkillProgressRow(skill: skill)
                    }
                }
            } else {
                Text("Start training to track your skill development")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            if !recentAchievements.isEmpty {
                VStack(spacing: 10) {
                    ForEach(recentAchievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
            } else {
                Text("Keep training to unlock achievements!")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Training Consistency Section

    private var trainingConsistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Consistency")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                // XP and Level Display
                xpLevelRow

                // Training streak (using stored player values)
                HStack {
                    Image(systemName: "flame.fill")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.accentOrange)
                    Text("\(player.currentStreak) day streak")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("Best: \(player.longestStreak)")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Sessions per week
                if let stats = overallStats {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.secondaryBlue)
                        Text("\(String(format: "%.1f", stats.sessionsPerWeek)) sessions/week")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - XP and Level Row

    private var xpLevelRow: some View {
        let tier = XPService.shared.tierForLevel(Int(player.currentLevel))
        let progress = XPService.shared.progressToNextLevel(totalXP: player.totalXP, currentLevel: Int(player.currentLevel))

        return VStack(spacing: 8) {
            HStack {
                // Level Badge
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.accentYellow)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Level \(player.currentLevel)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        if let tier = tier {
                            Text(tier.title)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Spacer()

                // XP Display
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(player.totalXP) XP")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    if player.currentLevel < 50 {
                        Text("\(Int(XPService.shared.xpRequiredForLevel(Int(player.currentLevel) + 1) - player.totalXP)) to next")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Progress Bar
            if player.currentLevel < 50 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.primaryGreen)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Smart Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                ForEach(Array(trainingInsights.prefix(3)), id: \.id) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }

    // MARK: - Calendar Heat Map Section

    private var calendarHeatMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Activity")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            CalendarHeatMapView(player: player, sessions: trainingSessions)
        }
    }

    // MARK: - Skill Trend Section

    private var skillTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            SkillTrendChartView(sessions: trainingSessions)
        }
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Focus")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            if let stats = overallStats {
                VStack(spacing: 10) {
                    CategoryBar(
                        category: "Technical",
                        percentage: stats.technicalPercentage,
                        color: DesignSystem.Colors.primaryGreen
                    )

                    CategoryBar(
                        category: "Physical",
                        percentage: stats.physicalPercentage,
                        color: DesignSystem.Colors.accentOrange
                    )

                    CategoryBar(
                        category: "Tactical",
                        percentage: stats.tacticalPercentage,
                        color: DesignSystem.Colors.secondaryBlue
                    )
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProgressData() {
        let sessions = fetchTrainingSessions()
        trainingSessions = sessions

        // Calculate overall stats
        overallStats = calculateOverallStats(from: sessions)

        // Calculate skill progress
        skillProgressData = calculateSkillProgress(from: sessions)

        // Generate achievements
        recentAchievements = generateAchievements(from: sessions, stats: overallStats)

        // Generate smart insights
        trainingInsights = InsightsEngine.shared.generateInsights(
            for: player,
            sessions: sessions,
            timeRange: selectedTimeRange
        )
    }

    private func fetchTrainingSessions() -> [TrainingSession] {
        let fetchRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "player == %@", player)

        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date

        switch selectedTimeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            // Get all sessions
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: true)]
            return (try? viewContext.fetch(fetchRequest)) ?? []
        }

        fetchRequest.predicate = NSPredicate(format: "player == %@ AND date >= %@ AND date <= %@", player, startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: true)]

        return (try? viewContext.fetch(fetchRequest)) ?? []
    }

    private func calculateOverallStats(from sessions: [TrainingSession]) -> OverallStats {
        guard !sessions.isEmpty else {
            return OverallStats(
                totalSessions: 0,
                totalHours: 0,
                averageRating: 0,
                improvementPercentage: 0,
                currentStreak: 0,
                longestStreak: 0,
                sessionsPerWeek: 0,
                technicalPercentage: 0,
                physicalPercentage: 0,
                tacticalPercentage: 0
            )
        }

        // Total sessions and hours
        let totalSessions = sessions.count
        let totalMinutes = sessions.compactMap { $0.duration }.reduce(0, +)
        let totalHours = Double(totalMinutes) / 60.0

        // Average rating
        let ratings = sessions.compactMap { $0.overallRating > 0 ? Double($0.overallRating) : nil }
        let averageRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)

        // Improvement calculation (compare first half vs second half)
        let halfPoint = sessions.count / 2
        if halfPoint > 0 {
            let firstHalfSessions = Array(sessions.prefix(halfPoint))
            let secondHalfSessions = Array(sessions.suffix(sessions.count - halfPoint))

            let firstHalfAvg = firstHalfSessions.compactMap { $0.overallRating > 0 ? Double($0.overallRating) : nil }.reduce(0, +) / Double(max(1, firstHalfSessions.count))
            let secondHalfAvg = secondHalfSessions.compactMap { $0.overallRating > 0 ? Double($0.overallRating) : nil }.reduce(0, +) / Double(max(1, secondHalfSessions.count))

            let improvement = firstHalfAvg > 0 ? ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100 : 0

            // Calculate streaks
            let streaks = calculateStreaks(sessions: sessions)

            // Calculate sessions per week
            let daysBetween = Calendar.current.dateComponents([.day], from: sessions.first!.date!, to: sessions.last!.date!).day ?? 1
            let weeks = max(1, Double(daysBetween) / 7.0)
            let sessionsPerWeek = Double(totalSessions) / weeks

            // Calculate category breakdown
            let categoryBreakdown = calculateCategoryBreakdown(sessions: sessions)

            return OverallStats(
                totalSessions: totalSessions,
                totalHours: totalHours,
                averageRating: averageRating,
                improvementPercentage: improvement,
                currentStreak: streaks.current,
                longestStreak: streaks.longest,
                sessionsPerWeek: sessionsPerWeek,
                technicalPercentage: categoryBreakdown.technical,
                physicalPercentage: categoryBreakdown.physical,
                tacticalPercentage: categoryBreakdown.tactical
            )
        }

        let streaks = calculateStreaks(sessions: sessions)
        let categoryBreakdown = calculateCategoryBreakdown(sessions: sessions)

        return OverallStats(
            totalSessions: totalSessions,
            totalHours: totalHours,
            averageRating: averageRating,
            improvementPercentage: 0,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            sessionsPerWeek: 0,
            technicalPercentage: categoryBreakdown.technical,
            physicalPercentage: categoryBreakdown.physical,
            tacticalPercentage: categoryBreakdown.tactical
        )
    }

    private func calculateStreaks(sessions: [TrainingSession]) -> (current: Int, longest: Int) {
        guard !sessions.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        let dates = sessions.compactMap { $0.date }.map { calendar.startOfDay(for: $0) }.sorted()

        var currentStreak = 1
        var longestStreak = 1
        var tempStreak = 1

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if current streak is active
        if let lastDate = dates.last {
            if lastDate == today || lastDate == yesterday {
                currentStreak = 1

                for i in (0..<dates.count - 1).reversed() {
                    let current = dates[i]
                    let next = dates[i + 1]

                    if let dayDiff = calendar.dateComponents([.day], from: current, to: next).day, dayDiff == 1 {
                        currentStreak += 1
                    } else {
                        break
                    }
                }
            } else {
                currentStreak = 0
            }
        }

        // Calculate longest streak
        for i in 0..<dates.count - 1 {
            let current = dates[i]
            let next = dates[i + 1]

            if let dayDiff = calendar.dateComponents([.day], from: current, to: next).day, dayDiff == 1 {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 1
            }
        }

        return (currentStreak, longestStreak)
    }

    private func calculateCategoryBreakdown(sessions: [TrainingSession]) -> (technical: Double, physical: Double, tactical: Double) {
        var technicalCount = 0
        var physicalCount = 0
        var tacticalCount = 0

        for session in sessions {
            if let sessionExercises = session.exercises as? Set<SessionExercise> {
                for sessionExercise in sessionExercises {
                    if let exercise = sessionExercise.exercise {
                        let category = exercise.category?.lowercased() ?? ""
                        if category.contains("technical") {
                            technicalCount += 1
                        } else if category.contains("physical") {
                            physicalCount += 1
                        } else if category.contains("tactical") {
                            tacticalCount += 1
                        }
                    }
                }
            }
        }

        let total = Double(technicalCount + physicalCount + tacticalCount)
        guard total > 0 else { return (0, 0, 0) }

        return (
            Double(technicalCount) / total * 100,
            Double(physicalCount) / total * 100,
            Double(tacticalCount) / total * 100
        )
    }

    private func calculateSkillProgress(from sessions: [TrainingSession]) -> [SkillProgress] {
        var skillData: [String: [Double]] = [:]

        for session in sessions {
            if let sessionExercises = session.exercises as? Set<SessionExercise> {
                for sessionExercise in sessionExercises {
                    if let exercise = sessionExercise.exercise,
                       let skills = exercise.targetSkills {
                        for skill in skills {
                            let rating = Double(sessionExercise.performanceRating)
                            skillData[skill, default: []].append(rating)
                        }
                    }
                }
            }
        }

        return skillData.map { skill, ratings in
            let average = ratings.reduce(0, +) / Double(max(1, ratings.count))
            let change = calculateSkillChange(ratings: ratings)

            return SkillProgress(
                id: UUID(),
                skillName: skill,
                currentLevel: average,
                change: change,
                sessionsCount: ratings.count
            )
        }
        .sorted { $0.currentLevel > $1.currentLevel }
    }

    private func calculateSkillChange(ratings: [Double]) -> Double {
        guard ratings.count >= 2 else { return 0 }

        let halfPoint = ratings.count / 2
        let firstHalf = Array(ratings.prefix(halfPoint))
        let secondHalf = Array(ratings.suffix(ratings.count - halfPoint))

        let firstAvg = firstHalf.reduce(0, +) / Double(max(1, firstHalf.count))
        let secondAvg = secondHalf.reduce(0, +) / Double(max(1, secondHalf.count))

        return secondAvg - firstAvg
    }

    private func generateAchievements(from sessions: [TrainingSession], stats: OverallStats?) -> [ProgressAchievement] {
        var achievements: [ProgressAchievement] = []

        guard let stats = stats else { return [] }

        // Session milestones
        if stats.totalSessions >= 10 && stats.totalSessions < 25 {
            achievements.append(ProgressAchievement(
                id: UUID(),
                icon: "star.fill",
                title: "Getting Started",
                description: "Completed 10 training sessions",
                date: Date(),
                color: DesignSystem.Colors.accentYellow
            ))
        }

        if stats.totalSessions >= 25 && stats.totalSessions < 50 {
            achievements.append(ProgressAchievement(
                id: UUID(),
                icon: "flame.fill",
                title: "Committed Player",
                description: "Completed 25 training sessions",
                date: Date(),
                color: DesignSystem.Colors.accentOrange
            ))
        }

        if stats.totalSessions >= 50 {
            achievements.append(ProgressAchievement(
                id: UUID(),
                icon: "crown.fill",
                title: "Dedicated Athlete",
                description: "Completed 50+ training sessions",
                date: Date(),
                color: DesignSystem.Colors.primaryGreen
            ))
        }

        // Streak achievements
        if stats.currentStreak >= 7 {
            achievements.append(ProgressAchievement(
                id: UUID(),
                icon: "calendar.badge.checkmark",
                title: "Week Warrior",
                description: "\(stats.currentStreak) day training streak",
                date: Date(),
                color: DesignSystem.Colors.secondaryBlue
            ))
        }

        // Improvement achievement
        if stats.improvementPercentage >= 20 {
            achievements.append(ProgressAchievement(
                id: UUID(),
                icon: "chart.line.uptrend.xyaxis",
                title: "Rising Star",
                description: "\(Int(stats.improvementPercentage))% improvement",
                date: Date(),
                color: DesignSystem.Colors.primaryGreen
            ))
        }

        return achievements
    }
}

// MARK: - Supporting Views


struct SkillProgressRow: View {
    let skill: SkillProgress

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(skill.skillName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    if skill.change > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("+\(String(format: "%.1f", skill.change))")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    } else if skill.change < 0 {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                        Text("\(String(format: "%.1f", skill.change))")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                    }

                    Text(String(format: "%.1f", skill.currentLevel))
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("/ 5.0")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(progressColor(for: skill.currentLevel))
                        .frame(width: geometry.size.width * (skill.currentLevel / 5.0), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func progressColor(for level: Double) -> Color {
        switch level {
        case 0..<2.0: return DesignSystem.Colors.accentOrange
        case 2.0..<3.5: return DesignSystem.Colors.accentYellow
        case 3.5...5.0: return DesignSystem.Colors.primaryGreen
        default: return DesignSystem.Colors.secondaryBlue
        }
    }
}

struct AchievementCard: View {
    let achievement: ProgressAchievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.system(size: 24))
                .foregroundColor(achievement.color)
                .frame(width: 40, height: 40)
                .background(achievement.color.opacity(0.1))
                .cornerRadius(20)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(achievement.description)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CategoryBar: View {
    let category: String
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(Int(percentage))%")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100.0), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Data Models

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
    case all = "All Time"

    var displayName: String { rawValue }
}

struct OverallStats {
    let totalSessions: Int
    let totalHours: Double
    let averageRating: Double
    let improvementPercentage: Double
    let currentStreak: Int
    let longestStreak: Int
    let sessionsPerWeek: Double
    let technicalPercentage: Double
    let physicalPercentage: Double
    let tacticalPercentage: Double
}

struct SkillProgress: Identifiable {
    let id: UUID
    let skillName: String
    let currentLevel: Double
    let change: Double
    let sessionsCount: Int
}

struct ProgressAchievement: Identifiable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let date: Date
    let color: Color
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: TrainingInsight

    private var cardColor: Color {
        switch insight.color {
        case "primaryGreen":
            return DesignSystem.Colors.primaryGreen
        case "secondaryBlue":
            return DesignSystem.Colors.secondaryBlue
        case "accentOrange":
            return DesignSystem.Colors.accentOrange
        case "accentYellow":
            return DesignSystem.Colors.accentYellow
        case "error":
            return DesignSystem.Colors.error
        default:
            return DesignSystem.Colors.neutral400
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: insight.icon)
                    .font(.system(size: 20))
                    .foregroundColor(cardColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    // Priority badge for high priority items
                    if insight.priority >= 8 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(cardColor)
                    }
                }

                Text(insight.description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Actionable suggestion
                if let actionable = insight.actionable {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(cardColor)

                        Text(actionable)
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(cardColor)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }
}
