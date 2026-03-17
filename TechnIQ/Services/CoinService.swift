import Foundation
import CoreData
import Combine

/// Service for managing player coin economy
/// Handles awarding, deducting, and tracking coins
@MainActor
final class CoinService: ObservableObject, CoinServiceProtocol {
    static let shared = CoinService()

    // MARK: - Published Properties

    /// Current player's coin balance (for reactive UI updates)
    @Published private(set) var currentBalance: Int = 0

    /// Recent coin transaction for animation purposes
    @Published private(set) var lastTransaction: CoinTransaction?

    /// Last error encountered
    @Published private(set) var lastError: ServiceError?

    // MARK: - Private Properties

    private let coreDataManager: CoreDataManagerProtocol
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.coreDataManager = CoreDataManager.shared
        loadCurrentBalance()
    }

    /// For testing
    init(coreDataManager: CoreDataManagerProtocol) {
        self.coreDataManager = coreDataManager
        loadCurrentBalance()
    }

    // MARK: - Public Methods

    /// Award coins to the current player
    /// - Parameters:
    ///   - amount: Number of coins to award
    ///   - reason: The event that triggered the coin award
    ///   - context: Core Data context (uses main if not provided)
    /// - Returns: The new total balance
    @discardableResult
    func awardCoins(_ amount: Int, for reason: CoinEarningEvent, context: NSManagedObjectContext? = nil) -> Int {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            AppLogger.shared.error("[CoinService] No player found to award coins")
            lastError = .notFound("Player")
            return 0
        }

        let previousBalance = Int(player.coins)
        player.coins += Int64(amount)
        player.totalCoinsEarned += Int64(amount)

        do {
            try ctx.save()
            let newBalance = Int(player.coins)

            // Already on main actor — update directly
            currentBalance = newBalance
            lastTransaction = CoinTransaction(
                amount: amount,
                type: .earned,
                reason: reason.displayName,
                timestamp: Date(),
                balanceAfter: newBalance
            )

            AppLogger.shared.debug("[CoinService] Awarded \(amount) coins for: \(reason.displayName). Balance: \(previousBalance) -> \(newBalance)")

            return newBalance
        } catch {
            AppLogger.shared.error("[CoinService] Failed to save coin award: \(error)")
            lastError = .coreData(error.localizedDescription)
            ctx.rollback()
            return previousBalance
        }
    }

    /// Deduct coins from the current player (for purchases)
    /// - Parameters:
    ///   - amount: Number of coins to deduct
    ///   - reason: Description of what was purchased
    ///   - context: Core Data context (uses main if not provided)
    /// - Returns: True if successful, false if insufficient funds
    @discardableResult
    func deductCoins(_ amount: Int, for reason: String, context: NSManagedObjectContext? = nil) -> Bool {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            AppLogger.shared.error("[CoinService] No player found to deduct coins")
            lastError = .notFound("Player")
            return false
        }

        let currentCoins = Int(player.coins)
        guard currentCoins >= amount else {
            AppLogger.shared.warning("[CoinService] Insufficient funds. Have: \(currentCoins), Need: \(amount)")
            lastError = .validation("Insufficient funds")
            return false
        }

        player.coins -= Int64(amount)

        do {
            try ctx.save()
            let newBalance = Int(player.coins)

            // Already on main actor — update directly
            currentBalance = newBalance
            lastTransaction = CoinTransaction(
                amount: amount,
                type: .spent,
                reason: reason,
                timestamp: Date(),
                balanceAfter: newBalance
            )

            AppLogger.shared.debug("[CoinService] Deducted \(amount) coins for: \(reason). Balance: \(currentCoins) -> \(newBalance)")

            return true
        } catch {
            AppLogger.shared.error("[CoinService] Failed to save coin deduction: \(error)")
            lastError = .coreData(error.localizedDescription)
            ctx.rollback()
            return false
        }
    }

    /// Check if player can afford a purchase
    /// - Parameter amount: Amount to check
    /// - Returns: True if player has enough coins
    func canAfford(_ amount: Int) -> Bool {
        return currentBalance >= amount
    }

    /// Get current coin balance
    /// - Returns: Current coin balance
    func getBalance() -> Int {
        guard let player = coreDataManager.getCurrentPlayer() else {
            return 0
        }
        return Int(player.coins)
    }

    /// Get total coins ever earned
    /// - Returns: Total coins earned all-time
    func getTotalEarned() -> Int {
        guard let player = coreDataManager.getCurrentPlayer() else {
            return 0
        }
        return Int(player.totalCoinsEarned)
    }

    /// Refresh the current balance from Core Data
    func loadCurrentBalance() {
        currentBalance = getBalance()
    }

    // MARK: - Convenience Methods for Common Events

    /// Award coins for completing a training session
    /// Accumulates all bonuses and performs a single Core Data save.
    /// - Parameters:
    ///   - duration: Session duration in minutes
    ///   - isFirstOfDay: Whether this is the first session today
    ///   - rating: Optional session rating (1-5)
    ///   - streakDay: Current streak day (for bonus calculation)
    ///   - context: Core Data context
    /// - Returns: Total coins earned from this session
    @discardableResult
    func awardSessionCoins(
        duration: Int,
        isFirstOfDay: Bool,
        rating: Int?,
        streakDay: Int,
        context: NSManagedObjectContext? = nil
    ) -> Int {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            AppLogger.shared.error("[CoinService] No player found for session coins")
            lastError = .notFound("Player")
            return 0
        }

        var totalCoins = 0
        let lastReason: CoinEarningEvent

        // Base session completion
        let sessionCoins = CoinEarningEvent.sessionCompleted(duration: duration).coins
        totalCoins += sessionCoins
        lastReason = .sessionCompleted(duration: duration)

        // First session of day bonus
        if isFirstOfDay {
            totalCoins += CoinEarningEvent.firstSessionOfDay.coins
        }

        // Perfect rating bonus
        if let r = rating, r == 5 {
            totalCoins += CoinEarningEvent.fiveStarRating.coins
        }

        // Streak bonus
        if streakDay > 0 {
            totalCoins += CoinEarningEvent.dailyStreakBonus(streakDay: streakDay).coins
            if streakDay % 7 == 0 {
                totalCoins += CoinEarningEvent.weeklyStreakMilestone.coins
            }
        }

        guard totalCoins > 0 else { return 0 }

        let previousBalance = Int(player.coins)
        player.coins += Int64(totalCoins)
        player.totalCoinsEarned += Int64(totalCoins)

        do {
            try ctx.save()
            let newBalance = Int(player.coins)
            currentBalance = newBalance
            lastTransaction = CoinTransaction(
                amount: totalCoins,
                type: .earned,
                reason: lastReason.displayName,
                timestamp: Date(),
                balanceAfter: newBalance
            )
            AppLogger.shared.debug("[CoinService] Session coins: +\(totalCoins). Balance: \(previousBalance) -> \(newBalance)")
            return totalCoins
        } catch {
            AppLogger.shared.error("[CoinService] Failed to save session coins: \(error)")
            lastError = .coreData(error.localizedDescription)
            ctx.rollback()
            return 0
        }
    }

    /// Award coins for leveling up
    /// - Parameters:
    ///   - newLevel: The new level reached
    ///   - context: Core Data context
    @discardableResult
    func awardLevelUpCoins(newLevel: Int, context: NSManagedObjectContext? = nil) -> Int {
        let coins = CoinEarningEvent.levelUp(newLevel: newLevel).coins
        awardCoins(coins, for: .levelUp(newLevel: newLevel), context: context)
        return coins
    }

    /// Award coins for unlocking an achievement
    /// - Parameters:
    ///   - xpReward: The XP reward of the achievement (used to scale coins)
    ///   - context: Core Data context
    @discardableResult
    func awardAchievementCoins(xpReward: Int, context: NSManagedObjectContext? = nil) -> Int {
        let coins = CoinEarningEvent.achievementUnlocked(xpReward: xpReward).coins
        awardCoins(coins, for: .achievementUnlocked(xpReward: xpReward), context: context)
        return coins
    }
}

// MARK: - Coin Transaction Model

/// Represents a single coin transaction (for history/animation)
struct CoinTransaction: Identifiable {
    let id = UUID()
    let amount: Int
    let type: TransactionType
    let reason: String
    let timestamp: Date
    let balanceAfter: Int

    enum TransactionType {
        case earned
        case spent
    }
}

// MARK: - Coin Balance View Model

/// Observable view model for coin display components
@MainActor
final class CoinBalanceViewModel: ObservableObject {
    @Published var balance: Int = 0
    @Published var animatingAmount: Int?

    private let coinService = CoinService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to balance updates
        coinService.$currentBalance
            .sink { [weak self] newBalance in
                self?.balance = newBalance
            }
            .store(in: &cancellables)

        // Subscribe to transactions for animations
        coinService.$lastTransaction
            .compactMap { $0 }
            .sink { [weak self] transaction in
                self?.animatingAmount = transaction.type == .earned ? transaction.amount : -transaction.amount
                // Clear animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.animatingAmount = nil
                }
            }
            .store(in: &cancellables)

        // Load initial balance
        balance = coinService.currentBalance
    }

    func refresh() {
        coinService.loadCurrentBalance()
    }
}
