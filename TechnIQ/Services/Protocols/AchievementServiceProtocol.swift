import Foundation
import CoreData

@MainActor
protocol AchievementServiceProtocol: AnyObject {
    var lastError: ServiceError? { get }
    func getUnlockedAchievements(for player: Player) -> [Achievement]
    func getLockedAchievements(for player: Player) -> [Achievement]
    func isUnlocked(_ achievementId: String, for player: Player) -> Bool
    func checkAndUnlockAchievements(for player: Player, in context: NSManagedObjectContext) -> [Achievement]
    func getProgress(for achievement: Achievement, player: Player, in context: NSManagedObjectContext) -> Double
}
