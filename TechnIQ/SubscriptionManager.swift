import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro: Bool = false
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
        isPro = hasEntitlement
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

    // MARK: - Free Drill Tracking

    static let hasUsedFreeCustomDrillKey = "hasUsedFreeCustomDrill"
    static let hasUsedFreeQuickDrillKey = "hasUsedFreeQuickDrill"

    var hasUsedFreeCustomDrill: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasUsedFreeCustomDrillKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasUsedFreeCustomDrillKey) }
    }

    var hasUsedFreeQuickDrill: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasUsedFreeQuickDrillKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasUsedFreeQuickDrillKey) }
    }

    func canUseCustomDrill() -> Bool {
        isPro || !hasUsedFreeCustomDrill
    }

    func canUseQuickDrill() -> Bool {
        isPro || !hasUsedFreeQuickDrill
    }

    func markCustomDrillUsed() {
        if !isPro { hasUsedFreeCustomDrill = true }
    }

    func markQuickDrillUsed() {
        if !isPro { hasUsedFreeQuickDrill = true }
    }
}
