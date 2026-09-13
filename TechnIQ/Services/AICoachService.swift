import Foundation
import FirebaseAuth
import CoreData

@MainActor
class AICoachService: ObservableObject, AICoachServiceProtocol {
    static let shared = AICoachService()

    @Published var dailyCoaching: DailyCoaching?
    @Published var aiInsights: [TrainingInsight] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let auth = Auth.auth()
    private let cacheKey = "cachedDailyCoaching"
    private let cacheDateKey = "dailyCoachingFetchDate"

    private init() {
        loadCachedCoaching()
    }

    // MARK: - Public API

    func fetchDailyCoachingIfNeeded(for player: Player) async {
        // Check if we already have today's coaching
        if let cached = dailyCoaching, Calendar.current.isDateInToday(cached.fetchDate) {
            return
        }

        isLoading = true
        error = nil

        do {
            let coaching = try await callDailyCoachingFunction(for: player)
            dailyCoaching = coaching
            aiInsights = coaching.insights.map { mapToTrainingInsight($0) }
            cacheCoaching(coaching)
        } catch {
            #if DEBUG
            print("AICoachService: Failed to fetch coaching: \(error)")
            #endif
            self.error = error.localizedDescription
            // Keep showing yesterday's cached coaching if available
        }

        isLoading = false
    }

    // MARK: - Cache

    private func loadCachedCoaching() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        do {
            let coaching = try JSONDecoder().decode(DailyCoaching.self, from: data)
            dailyCoaching = coaching
            aiInsights = coaching.insights.map { mapToTrainingInsight($0) }
        } catch {
            #if DEBUG
            print("AICoachService: Failed to decode cached coaching: \(error)")
            #endif
        }
    }

    private func cacheCoaching(_ coaching: DailyCoaching) {
        do {
            let data = try JSONEncoder().encode(coaching)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            #if DEBUG
            print("AICoachService: Failed to cache coaching: \(error)")
            #endif
        }
    }

    var isCacheStale: Bool {
        guard let coaching = dailyCoaching else { return true }
        return !Calendar.current.isDateInToday(coaching.fetchDate)
    }

    // MARK: - Plan Adaptation

    @Published var weeklyCheckInAvailable: Bool = false
    @Published var completedWeekNumber: Int = 0
    @Published var adaptationResponse: PlanAdaptationResponse?
    @Published var isLoadingAdaptation: Bool = false
    @Published var adaptationError: String?

    func setWeeklyCheckInAvailable(weekNumber: Int) {
        completedWeekNumber = weekNumber
        weeklyCheckInAvailable = true
    }

    // MARK: - Weekly review (calendar-driven)

    private func reviewedWeeksKey(_ planID: UUID) -> String { "weeklyReview.reviewed.\(planID.uuidString)" }

    /// Weeks of the active plan whose seven-day window has ended and that have not been reviewed yet.
    /// Called on app open and after sessions; the first pending week becomes the check-in.
    func refreshWeeklyReview(for player: Player, now: Date = Date(), calendar: Calendar = .current) {
        guard let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else {
            weeklyCheckInAvailable = false
            return
        }
        let reviewed = Set(UserDefaults.standard.array(forKey: reviewedWeeksKey(plan.id)) as? [Int] ?? [])
        let startDate = PlanSchedule.startDate(of: plan)
        let todayStart = calendar.startOfDay(for: now)
        let pending = plan.weeks
            .filter { week in
                guard !reviewed.contains(week.weekNumber) else { return false }
                let weekStart = PlanSchedule.date(week: week.weekNumber, dayNumber: 1, dayOfWeek: nil, startDate: startDate, calendar: calendar)
                guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return false }
                let hasSessions = week.days.contains { !$0.isRestDay }
                return hasSessions && weekEnd <= todayStart
            }
            .map(\.weekNumber)
            .sorted()
        if let week = pending.first {
            setWeeklyCheckInAvailable(weekNumber: week)
        } else if weeklyCheckInAvailable == false {
            weeklyCheckInAvailable = false
        }
    }

    /// Marks a week reviewed (applied or kept) so the row on Home goes away.
    func markWeekReviewed(planID: UUID, weekNumber: Int) {
        var reviewed = UserDefaults.standard.array(forKey: reviewedWeeksKey(planID)) as? [Int] ?? []
        if !reviewed.contains(weekNumber) { reviewed.append(weekNumber) }
        UserDefaults.standard.set(reviewed, forKey: reviewedWeeksKey(planID))
        dismissWeeklyCheckIn()
    }

    func fetchPlanAdaptation(for player: Player, plan: TrainingPlanModel, weekNumber: Int, recap: WeekRecap? = nil) async {
        isLoadingAdaptation = true
        adaptationError = nil

        do {
            adaptationResponse = try await callPlanAdaptationFunction(for: player, plan: plan, weekNumber: weekNumber, recap: recap)
        } catch {
            #if DEBUG
            print("AICoachService: Failed to fetch plan adaptation: \(error)")
            #endif
            adaptationError = error.localizedDescription
        }

        isLoadingAdaptation = false
    }

    func dismissWeeklyCheckIn() {
        weeklyCheckInAvailable = false
        adaptationResponse = nil
    }

    private func callPlanAdaptationFunction(for player: Player, plan: TrainingPlanModel, weekNumber: Int, recap: WeekRecap? = nil) async throws -> PlanAdaptationResponse {
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_plan_adaptation"

        guard let url = URL(string: functionsURL) else {
            throw URLError(.badURL)
        }

        let userUID = auth.currentUser?.uid ?? "anonymous_user"
        let playerContext = buildPlayerContext(for: player)

        // Build completed week data
        var completedWeekData: [String: Any] = ["days": []]
        var nextWeekData: [String: Any] = [:]

        if let completedWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber }) {
            var daysData: [[String: Any]] = []
            for day in completedWeek.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
                var sessionsData: [[String: Any]] = []
                for session in day.sessions {
                    var sessionDict: [String: Any] = [
                        "type": session.sessionType.rawValue,
                        "completed": session.isCompleted,
                        "duration": session.duration,
                        "intensity": session.intensity
                    ]
                    if session.isCompleted {
                        sessionDict["rating"] = session.actualIntensity
                    }
                    sessionsData.append(sessionDict)
                }
                daysData.append([
                    "day_number": day.dayNumber,
                    "is_rest_day": day.isRestDay,
                    "sessions": sessionsData
                ])
            }
            completedWeekData["days"] = daysData
        }

        // Next week structure
        if let nextWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber + 1 }) {
            var daysData: [[String: Any]] = []
            for day in nextWeek.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
                var sessionsData: [[String: Any]] = []
                for session in day.sessions {
                    sessionsData.append([
                        "type": session.sessionType.rawValue,
                        "duration": session.duration,
                        "intensity": session.intensity
                    ])
                }
                daysData.append([
                    "day_number": day.dayNumber,
                    "is_rest_day": day.isRestDay,
                    "sessions": sessionsData
                ])
            }
            nextWeekData = ["days": daysData]
        }

        var requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerContext.profile,
            "plan_structure": [
                "name": plan.name,
                "next_week": nextWeekData
            ],
            "completed_week": completedWeekData,
            "week_number": weekNumber,
            "coach_name": CoachIdentity.name()
        ]
        if let recap { requestBody["recap"] = recap.payload }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let user = auth.currentUser {
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Single retry with 2s backoff
        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                return try JSONDecoder().decode(PlanAdaptationResponse.self, from: data)
            } catch {
                lastError = error
                if attempt == 0 {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Insight Mapping

    private func mapToTrainingInsight(_ ai: AIInsight) -> TrainingInsight {
        let insightType: InsightType
        switch ai.type {
        case "celebration": insightType = .celebration
        case "warning": insightType = .warning
        case "recommendation": insightType = .recommendation
        case "pattern": insightType = .pattern
        default: insightType = .recommendation
        }

        return TrainingInsight(
            type: insightType,
            title: ai.title,
            description: ai.description,
            icon: iconForType(insightType),
            color: colorForType(insightType),
            priority: ai.priority,
            actionable: ai.actionable
        )
    }

    private func iconForType(_ type: InsightType) -> String {
        switch type {
        case .celebration: return "star.fill"
        case .warning: return "exclamationmark.triangle"
        case .recommendation: return "lightbulb.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .achievement: return "trophy.fill"
        }
    }

    private func colorForType(_ type: InsightType) -> String {
        switch type {
        case .celebration: return "primaryGreen"
        case .warning: return "error"
        case .recommendation: return "secondaryBlue"
        case .pattern: return "accentOrange"
        case .achievement: return "accentYellow"
        }
    }

    // MARK: - Firebase Function Call

    private func callDailyCoachingFunction(for player: Player) async throws -> DailyCoaching {
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_daily_coaching"

        guard let url = URL(string: functionsURL) else {
            throw URLError(.badURL)
        }

        let userUID = auth.currentUser?.uid ?? "anonymous_user"
        let playerContext = buildPlayerContext(for: player)

        var requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerContext.profile,
            "recent_sessions": playerContext.sessions,
            "category_balance": playerContext.categoryBalance,
            "active_plan": playerContext.activePlan,
            "streak_days": Int(player.currentStreak),
            "days_since_last_session": playerContext.daysSinceLastSession,
            "total_sessions": player.sessions?.count ?? 0,
            "library": Self.libraryPayload(for: player),
            "coach_name": CoachIdentity.name()
        ]
        if let today = Self.todayPayload(for: player) { requestBody["today"] = today }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Add auth token
        if let user = auth.currentUser {
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Single retry with 2s backoff
        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server returned \(statusCode)"])
                }

                // Snake-case contract with explicit keys; the decoder stamps today's fetch date.
                return try JSONDecoder().decode(DailyCoaching.self, from: data)
            } catch {
                lastError = error
                if attempt == 0 {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Library and today's session (what the coach may pick from)

    /// Up to 40 library drills, most recently used first, with the ids the model must echo back.
    nonisolated static func libraryPayload(for player: Player, now: Date = Date(), calendar: Calendar = .current) -> [[String: Any]] {
        let exercises = ((player.exercises as? Set<Exercise>) ?? []).filter { $0.id != nil }
        let ordered = exercises.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?): return l > r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return (lhs.name ?? "") < (rhs.name ?? "")
            }
        }
        return ordered.prefix(40).map { exercise in
            var dict: [String: Any] = [
                "id": exercise.id!.uuidString,
                "name": exercise.name ?? "Drill",
                "category": exercise.category ?? "Technical",
                "difficulty": Int(exercise.difficulty),
                "minutes": exercise.estimatedDurationSeconds > 0 ? Int(exercise.estimatedDurationSeconds) / 60 : 15,
                "skills": Array((exercise.targetSkills ?? []).prefix(4)),
                "source": exercise.drillSource.rawValue
            ]
            if let used = exercise.lastUsedAt {
                dict["last_used_days_ago"] = calendar.dateComponents([.day], from: calendar.startOfDay(for: used), to: calendar.startOfDay(for: now)).day ?? 0
            }
            return dict
        }
    }

    /// Today's plan session as the model sees it (drills with ids), or nil without a plan.
    static func todayPayload(for player: Player, now: Date = Date(), calendar: Calendar = .current) -> [String: Any]? {
        guard let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else { return nil }
        switch PlanSchedule.today(in: plan, startDate: PlanSchedule.startDate(of: plan), now: now, calendar: calendar) {
        case .rest, .complete:
            return ["is_rest": true]
        case .session(let week, let dayNumber, _, _):
            guard let weekModel = plan.weeks.first(where: { $0.weekNumber == week }),
                  let day = weekModel.days.first(where: { $0.dayNumber == dayNumber }) else { return ["is_rest": true] }
            let session = day.sessions.sorted { $0.orderIndex < $1.orderIndex }.first { !$0.isCompleted } ?? day.sessions.first
            let ids = Set(session?.exerciseIDs ?? [])
            let drills = ((player.exercises as? Set<Exercise>) ?? [])
                .filter { $0.id.map(ids.contains) ?? false }
                .map { ["id": $0.id!.uuidString, "name": $0.name ?? "Drill"] }
            return [
                "is_rest": false,
                "session_type": session?.sessionType.displayName ?? "Training",
                "minutes": session?.duration ?? day.totalDuration,
                "week": week,
                "drills": drills
            ]
        }
    }

    // MARK: - Player Context Builder

    private struct PlayerContext {
        let profile: [String: Any]
        let sessions: [[String: Any]]
        let categoryBalance: [String: Int]
        let activePlan: [String: Any]
        let daysSinceLastSession: Int
    }

    private func buildPlayerContext(for player: Player) -> PlayerContext {
        // Profile (reuse pattern from CustomDrillService.buildPlayerProfile)
        var profile: [String: Any] = [
            "age": Int(player.age),
            "position": player.position ?? "Unknown",
            "experience": player.experienceLevel ?? "intermediate",
            "style": player.playingStyle ?? "",
            "dominant_foot": player.dominantFoot ?? ""
        ]

        if let pp = player.playerProfile {
            if let goals = pp.skillGoals, !goals.isEmpty {
                profile["goals"] = goals
            }
            if let weaknesses = pp.selfIdentifiedWeaknesses, !weaknesses.isEmpty {
                profile["weaknesses"] = weaknesses
            }
        }

        // Recent sessions (last 10)
        let allSessions = (player.sessions as? Set<TrainingSession>)?.sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        } ?? []
        let recentSessions = Array(allSessions.prefix(10))

        var sessionsData: [[String: Any]] = []
        for session in recentSessions {
            var sessionDict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: session.date ?? Date()),
                "duration_minutes": Int(session.duration),
                "overall_rating": Int(session.overallRating)
            ]

            var exercisesData: [[String: Any]] = []
            if let exercises = session.exercises as? Set<SessionExercise> {
                for se in exercises {
                    if let ex = se.exercise {
                        exercisesData.append([
                            "name": ex.name ?? "",
                            "category": ex.category ?? "",
                            "skills": ex.targetSkills ?? [],
                            "rating": Int(se.performanceRating),
                            "duration": Int(se.duration)
                        ])
                    }
                }
            }
            sessionDict["exercises"] = exercisesData
            sessionsData.append(sessionDict)
        }

        // Category balance
        var technical = 0, physical = 0, tactical = 0
        for session in recentSessions {
            if let exercises = session.exercises as? Set<SessionExercise> {
                for se in exercises {
                    let cat = se.exercise?.category?.lowercased() ?? ""
                    if cat.contains("technical") { technical += 1 }
                    else if cat.contains("physical") { physical += 1 }
                    else if cat.contains("tactical") { tactical += 1 }
                }
            }
        }
        let total = max(technical + physical + tactical, 1)
        let categoryBalance: [String: Int] = [
            "technical": (technical * 100) / total,
            "physical": (physical * 100) / total,
            "tactical": (tactical * 100) / total
        ]

        // Active plan
        var activePlanDict: [String: Any] = [:]
        if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
            activePlanDict = [
                "name": plan.name,
                "week": plan.currentWeek,
                "progress": plan.progressPercentage / 100.0
            ]
        }

        // Days since last session
        let daysSince: Int
        if let lastDate = allSessions.first?.date {
            daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        } else {
            daysSince = 999
        }

        return PlayerContext(
            profile: profile,
            sessions: sessionsData,
            categoryBalance: categoryBalance,
            activePlan: activePlanDict,
            daysSinceLastSession: daysSince
        )
    }
}
