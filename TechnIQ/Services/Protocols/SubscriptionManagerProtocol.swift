import Foundation

// MARK: - SubscriptionManager Protocol

@MainActor
protocol SubscriptionManagerProtocol: AnyObject {
    var isPro: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var isProductAvailable: Bool { get }
    var displayPrice: String { get }
    var subscriptionPeriod: String { get }
    var hasTrialOffer: Bool { get }
    var trialDuration: String { get }
    var freeDrillsRemaining: Int { get }
    var freeDrillsLabel: String { get }

    func checkEntitlement() async
    func loadProduct() async
    func purchase() async
    func restorePurchases() async
    func canGenerateDrill() -> Bool
    func markDrillGenerated()
}
