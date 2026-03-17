import Foundation

// MARK: - SubscriptionManager Protocol

@MainActor
protocol SubscriptionManagerProtocol: AnyObject {
    var isPro: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var displayPrice: String { get }
    var subscriptionPeriod: String { get }
    var hasTrialOffer: Bool { get }
    var trialDuration: String { get }
    var hasUsedFreeCustomDrill: Bool { get }
    var hasUsedFreeQuickDrill: Bool { get }

    func checkEntitlement() async
    func loadProduct() async
    func purchase() async
    func restorePurchases() async
    func canUseCustomDrill() -> Bool
    func canUseQuickDrill() -> Bool
    func markCustomDrillUsed()
    func markQuickDrillUsed()
}
