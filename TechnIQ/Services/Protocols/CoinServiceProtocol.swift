import Foundation
import CoreData

@MainActor
protocol CoinServiceProtocol: AnyObject {
    var currentBalance: Int { get }
    var lastTransaction: CoinTransaction? { get }
    var lastError: ServiceError? { get }
    @discardableResult func awardCoins(_ amount: Int, for reason: CoinEarningEvent, context: NSManagedObjectContext?) -> Int
    @discardableResult func deductCoins(_ amount: Int, for reason: String, context: NSManagedObjectContext?) -> Bool
    func canAfford(_ amount: Int) -> Bool
    func getBalance() -> Int
    func getTotalEarned() -> Int
    func loadCurrentBalance()
    @discardableResult func awardSessionCoins(duration: Int, isFirstOfDay: Bool, rating: Int?, streakDay: Int, context: NSManagedObjectContext?) -> Int
    @discardableResult func awardLevelUpCoins(newLevel: Int, context: NSManagedObjectContext?) -> Int
    @discardableResult func awardAchievementCoins(xpReward: Int, context: NSManagedObjectContext?) -> Int
}
