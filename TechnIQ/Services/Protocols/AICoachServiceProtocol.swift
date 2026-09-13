import Foundation

// MARK: - AICoachService Protocol

@MainActor
protocol AICoachServiceProtocol: AnyObject {
    var dailyCoaching: DailyCoaching? { get }
    var aiInsights: [TrainingInsight] { get }
    var isLoading: Bool { get }
    var error: String? { get }

    var weeklyCheckInAvailable: Bool { get }
    var completedWeekNumber: Int { get }
    var adaptationResponse: PlanAdaptationResponse? { get }
    var isLoadingAdaptation: Bool { get }
    var adaptationError: String? { get }

    func fetchDailyCoachingIfNeeded(for player: Player) async
    func setWeeklyCheckInAvailable(weekNumber: Int)
    func fetchPlanAdaptation(for player: Player, plan: TrainingPlanModel, weekNumber: Int, recap: WeekRecap?) async
    func refreshWeeklyReview(for player: Player, now: Date, calendar: Calendar)
    func markWeekReviewed(planID: UUID, weekNumber: Int)
    func dismissWeeklyCheckIn()
}
