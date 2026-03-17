import Foundation
import CoreData

@MainActor
protocol XPServiceProtocol: AnyObject {
    func xpRequiredForLevel(_ level: Int) -> Int64
    func levelForXP(_ xp: Int64) -> Int
    func progressToNextLevel(totalXP: Int64, currentLevel: Int) -> Double
    func tierForLevel(_ level: Int) -> LevelTier?
    func calculateSessionXP(intensity: Int16, exerciseCount: Int, allExercisesCompleted: Bool, hasRating: Bool, hasNotes: Bool, isFirstSessionOfDay: Bool, currentStreak: Int16) -> SessionXPBreakdown
    func isFirstSessionOfDay(for player: Player) -> Bool
    func updateStreak(for player: Player, sessionDate: Date)
    func calculateStreakFromHistory(for player: Player, in context: NSManagedObjectContext) -> Int16
    @discardableResult func awardXP(to player: Player, amount: Int32) -> Int?
    @discardableResult func awardMatchXP(to player: Player, xp: Int) -> Int?
    func processSessionCompletion(session: TrainingSession, player: Player, context: NSManagedObjectContext, allExercisesCompleted: Bool) -> (xp: SessionXPBreakdown, levelUp: Int?)
    func purchaseStreakFreeze(for player: Player, context: NSManagedObjectContext) -> Bool
}
