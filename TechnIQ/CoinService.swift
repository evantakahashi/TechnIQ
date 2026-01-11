import Foundation
import CoreData
import Combine

/// Service for managing player coin economy
/// Handles awarding, deducting, and tracking coins
final class CoinService: ObservableObject {
    static let shared = CoinService()

    // MARK: - Published Properties

    /// Current player's coin balance (for reactive UI updates)
    @Published private(set) var currentBalance: Int = 0

    /// Recent coin transaction for animation purposes
    @Published private(set) var lastTransaction: CoinTransaction?

    // MARK: - Private Properties

    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load initial balance on startup
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
            #if DEBUG
            print("[CoinService] No player found to award coins")
            #endif
            return 0
        }

        let previousBalance = Int(player.coins)
        player.coins += Int64(amount)
        player.totalCoinsEarned += Int64(amount)

        do {
            try ctx.save()
            let newBalance = Int(player.coins)

            // Update published properties on main thread
            DispatchQueue.main.async { [weak self] in
                self?.currentBalance = newBalance
                self?.lastTransaction = CoinTransaction(
                    amount: amount,
                    type: .earned,
                    reason: reason.displayName,
                    timestamp: Date(),
                    balanceAfter: newBalance
                )
            }

            #if DEBUG
            print("[CoinService] Awarded \(amount) coins for: \(reason.displayName). Balance: \(previousBalance) -> \(newBalance)")
            #endif

            return newBalance
        } catch {
            #if DEBUG
            print("[CoinService] Failed to save coin award: \(error)")
            #endif
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
            #if DEBUG
            print("[CoinService] No player found to deduct coins")
            #endif
            return false
        }

        let currentCoins = Int(player.coins)
        guard currentCoins >= amount else {
            #if DEBUG
            print("[CoinService] Insufficient funds. Have: \(currentCoins), Need: \(amount)")
            #endif
            return false
        }

        player.coins -= Int64(amount)

        do {
            try ctx.save()
            let newBalance = Int(player.coins)

            // Update published properties on main thread
            DispatchQueue.main.async { [weak self] in
                self?.currentBalance = newBalance
                self?.lastTransaction = CoinTransaction(
                    amount: amount,
                    type: .spent,
                    reason: reason,
                    timestamp: Date(),
                    balanceAfter: newBalance
                )
            }

            #if DEBUG
            print("[CoinService] Deducted \(amount) coins for: \(reason). Balance: \(currentCoins) -> \(newBalance)")
            #endif

            return true
        } catch {
            #if DEBUG
            print("[CoinService] Failed to save coin deduction: \(error)")
            #endif
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
    /// - Parameter context: Core Data context (uses main if not provided)
    /// - Returns: Current coin balance
    func getBalance(context: NSManagedObjectContext? = nil) -> Int {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            return 0
        }
        return Int(player.coins)
    }

    /// Get total coins ever earned
    /// - Parameter context: Core Data context (uses main if not provided)
    /// - Returns: Total coins earned all-time
    func getTotalEarned(context: NSManagedObjectContext? = nil) -> Int {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            return 0
        }
        return Int(player.totalCoinsEarned)
    }

    /// Refresh the current balance from Core Data
    func loadCurrentBalance() {
        let balance = getBalance()
        DispatchQueue.main.async { [weak self] in
            self?.currentBalance = balance
        }
    }

    // MARK: - Convenience Methods for Common Events

    /// Award coins for completing a training session
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
        var totalCoins = 0

        // Base session completion coins
        let sessionCoins = CoinEarningEvent.sessionCompleted(duration: duration).coins
        awardCoins(sessionCoins, for: .sessionCompleted(duration: duration), context: context)
        totalCoins += sessionCoins

        // First session of day bonus
        if isFirstOfDay {
            let bonus = CoinEarningEvent.firstSessionOfDay.coins
            awardCoins(bonus, for: .firstSessionOfDay, context: context)
            totalCoins += bonus
        }

        // Perfect rating bonus
        if let rating = rating, rating == 5 {
            let bonus = CoinEarningEvent.fiveStarRating.coins
            awardCoins(bonus, for: .fiveStarRating, context: context)
            totalCoins += bonus
        }

        // Streak bonus
        if streakDay > 0 {
            let streakBonus = CoinEarningEvent.dailyStreakBonus(streakDay: streakDay).coins
            awardCoins(streakBonus, for: .dailyStreakBonus(streakDay: streakDay), context: context)
            totalCoins += streakBonus

            // Weekly milestone (every 7 days)
            if streakDay % 7 == 0 {
                let weeklyBonus = CoinEarningEvent.weeklyStreakMilestone.coins
                awardCoins(weeklyBonus, for: .weeklyStreakMilestone, context: context)
                totalCoins += weeklyBonus
            }
        }

        return totalCoins
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
final class CoinBalanceViewModel: ObservableObject {
    @Published var balance: Int = 0
    @Published var animatingAmount: Int?

    private let coinService = CoinService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to balance updates
        coinService.$currentBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                self?.balance = newBalance
            }
            .store(in: &cancellables)

        // Subscribe to transactions for animations
        coinService.$lastTransaction
            .receive(on: DispatchQueue.main)
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
        balance = coinService.getBalance()
    }

    func refresh() {
        coinService.loadCurrentBalance()
    }
}
