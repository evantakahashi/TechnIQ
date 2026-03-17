import Foundation
import CoreData

@MainActor
protocol TrainingPlanServiceProtocol: AnyObject {
    var activePlan: TrainingPlanModel? { get }
    var availablePlans: [TrainingPlanModel] { get }

    func fetchAllPlans(for player: Player) -> [TrainingPlanModel]
    func fetchActivePlan(for player: Player) -> TrainingPlanModel?
    func fetchPlan(byId planId: UUID) -> TrainingPlanModel?

    func createCustomPlan(name: String, description: String, durationWeeks: Int, difficulty: PlanDifficulty, category: PlanCategory, targetRole: String?, for player: Player) -> TrainingPlan?
    func createPlanFromAIGeneration(_ generated: GeneratedPlanStructure, for player: Player) -> TrainingPlan?

    func activatePlan(_ planModel: TrainingPlanModel, for player: Player)
    func deactivateAllPlans(for player: Player)

    func markSessionCompleted(_ sessionModel: PlanSessionModel, actualDuration: Int, actualIntensity: Int)

    func deletePlan(_ planModel: TrainingPlanModel)
    func clonePlan(_ planModel: TrainingPlanModel, for player: Player, newName: String?) -> TrainingPlan?

    func getCurrentDay(for planModel: TrainingPlanModel) -> (week: Int, day: PlanDayModel)?
    func getTodaysSessions(for planModel: TrainingPlanModel) -> [PlanSession]
    func getCurrentWeekAndDay(for planModel: TrainingPlanModel) -> (week: Int, day: Int)?
    func skipDay(dayId: UUID)

    @discardableResult func updatePlan(planId: UUID, name: String, description: String) -> Bool
}
