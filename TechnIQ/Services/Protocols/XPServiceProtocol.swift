import Foundation
import CoreData

@MainActor
protocol XPServiceProtocol: AnyObject {
    var lastError: ServiceError? { get }
    func xpRequiredForLevel(_ level: Int) -> Int64
    func levelForXP(_ xp: Int64) -> Int
    func progressToNextLevel(totalXP: Int64, currentLevel: Int) -> Double
    func tierForLevel(_ level: Int) -> LevelTier?
    func updateStreak(for player: Player, sessionDate: Date)
    func calculateStreakFromHistory(for player: Player, in context: NSManagedObjectContext) -> Int16
    @discardableResult func awardXP(to player: Player, amount: Int32) -> Int?
    func processSessionCompletion(session: TrainingSession, player: Player, context: NSManagedObjectContext, allExercisesCompleted: Bool) -> (xp: SessionXPBreakdown, levelUp: Int?)
}
