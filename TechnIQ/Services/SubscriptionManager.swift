import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject, SubscriptionManagerProtocol {
    static let shared = SubscriptionManager()

    #if DEBUG
    /// DEBUG builds are Pro unless launched with `-TQFree`, which exercises the free tier end to end.
    static let debugForcesFree = ProcessInfo.processInfo.arguments.contains("-TQFree")
    @Published var isPro: Bool = !SubscriptionManager.debugForcesFree
    #else
    @Published var isPro: Bool = false
    #endif
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let productID = "com.techniq.pro.monthly"
    private var product: Product?
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await checkEntitlement() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkEntitlement()
                }
            }
        }
    }

    // MARK: - Entitlement Check

    func checkEntitlement() async {
        var hasEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                hasEntitlement = true
                break
            }
        }
        #if DEBUG
        isPro = !Self.debugForcesFree || hasEntitlement
        #else
        isPro = hasEntitlement
        #endif
    }

    // MARK: - Load Product

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            #if DEBUG
            print("Failed to load product: \(error)")
            #endif
        }
    }

    // MARK: - Purchase

    func purchase() async {
        isLoading = true
        errorMessage = nil

        await loadProduct()
        guard let product else {
            errorMessage = "Product not available. Please try again later."
            isLoading = false
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await checkEntitlement()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        try? await AppStore.sync()
        await checkEntitlement()
        if !isPro {
            errorMessage = "No active subscription found."
        }
        isLoading = false
    }

    // MARK: - Product Info

    var isProductAvailable: Bool {
        product != nil
    }

    var displayPrice: String {
        product?.displayPrice ?? "$6.99"
    }

    var subscriptionPeriod: String {
        "month"
    }

    var hasTrialOffer: Bool {
        product?.subscription?.introductoryOffer != nil
    }

    var trialDuration: String {
        guard let offer = product?.subscription?.introductoryOffer else { return "" }
        return "\(offer.period.value) \(offer.period.unit)"
    }

    // MARK: - Free AI drills (three for life, then Pro)

    /// One budget for every generator entry point (Train, Home hero, coach suggestions).
    private var freeDrills: FreeDrillAllowance {
        FreeDrillAllowance(userUID: AuthenticationManager.shared.userUID)
    }

    var freeDrillsRemaining: Int { freeDrills.remaining }

    /// Before the tap: nil when the tap is free, else "2 free left" / "Pro".
    var drillGateLabel: String? { ProGates.drillGateLabel(isPro: isPro, freeDrillsRemaining: freeDrillsRemaining) }

    /// AI plans: the first (onboarding or generator) is free.
    func canGeneratePlan(for player: Player) -> Bool {
        ProGates.canGeneratePlan(isPro: isPro, existingAIPlans: Self.aiPlanCount(for: player))
    }

    func planGateLabel(for player: Player) -> String? {
        ProGates.planGateLabel(isPro: isPro, existingAIPlans: Self.aiPlanCount(for: player))
    }

    private static func aiPlanCount(for player: Player) -> Int {
        ((player.trainingPlans as? Set<TrainingPlan>) ?? []).filter { !$0.isPrebuilt }.count
    }

    var freeDrillsLabel: String { freeDrills.label }

    func canGenerateDrill() -> Bool {
        freeDrills.canGenerate(isPro: isPro)
    }

    /// Record a drill that actually came back; a cancelled or failed generation costs nothing.
    func markDrillGenerated() {
        freeDrills.recordGeneration(isPro: isPro)
        objectWillChange.send()
    }
}
