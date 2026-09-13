import SwiftUI
import StoreKit

// MARK: - Paywall feature context (which gate opened it)

enum PaywallFeature: String, Identifiable {
    case trainingPlan
    case customDrill
    case dailyCoaching
    case weeklyAdaptation
    case youtubeRecs

    var id: String { rawValue }

    var gate: ProGates.Feature {
        switch self {
        case .trainingPlan: return .aiPlans
        case .customDrill: return .aiDrills
        case .dailyCoaching: return .dailyCoaching
        case .weeklyAdaptation: return .weeklyReview
        case .youtubeRecs: return .aiDrills
        }
    }

    var title: String {
        switch self {
        case .trainingPlan: return "A new plan needs Pro"
        case .customDrill: return "Your free drills are used"
        case .dailyCoaching: return "The daily pick is Pro"
        case .weeklyAdaptation: return "The weekly review is Pro"
        case .youtubeRecs: return "Video picks are Pro"
        }
    }
}

// MARK: - The one paywall
//
// Used at every gate and as the last onboarding step. The benefits list is the free-tier
// contract in `ProGates` — nothing is promised that is not gated. Onboarding mode adds the
// "Continue with Free" way out and reads the plan just built.

struct PaywallView: View {
    enum Mode { case gate, onboarding(planName: String) }

    let feature: PaywallFeature
    var mode: Mode = .gate
    var onContinueFree: (() -> Void)? = nil
    var onPurchaseComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var restoreMessage: String?

    private var isOnboarding: Bool {
        if case .onboarding = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar(isOnboarding ? "Go pro" : "TechnIQ Pro", tone: .grass) {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    } trailing: {
                        if isOnboarding {
                            Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                        } else {
                            TQNavAction("Close") { dismiss() }
                        }
                    }
                    .padding(.top, 8)

                    TQHeroCard(
                        eyebrow: heroEyebrow,
                        title: heroTitle,
                        body: feature.gate.detail,
                        actionTitle: purchaseTitle,
                        actionIcon: nil,
                        markings: .heroSimple,
                        action: { Task { await subscriptionManager.purchase() } }
                    )
                    .disabled(subscriptionManager.isLoading || !subscriptionManager.isProductAvailable)
                    .opacity(subscriptionManager.isLoading ? 0.7 : 1)

                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Pro adds")
                        TQRule()
                        ForEach(ProGates.Feature.allCases, id: \.self) { item in
                            benefitRow(item.title, detail: item.detail, symbol: item == feature.gate ? "checkmark" : "plus")
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Always free")
                        TQRule()
                        benefitRow("Your first plan, templates and your own drills", detail: nil, symbol: "circle")
                        benefitRow("Three AI drills, community, progress, reminders", detail: nil, symbol: "circle")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TQBody(priceLine, tone: .base, size: 15)
                        TQBody("Cancel anytime. Payment goes to your Apple ID at confirmation; the subscription renews unless cancelled at least 24 hours before the period ends.", tone: .muted, size: 12)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            VStack(spacing: 8) {
                if isOnboarding {
                    TQButton("Continue with Free", style: .raised) { onContinueFree?() }
                        .accessibilityIdentifier("paywall.continueFree")
                }
                TQButton("Restore purchases", style: .ghost, face: .text) { restore() }
                    .disabled(subscriptionManager.isLoading)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(DesignSystem.Colors.surfaceBase)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await subscriptionManager.loadProduct() }
        .alert("Restore purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Purchase", isPresented: Binding(get: { subscriptionManager.errorMessage != nil && restoreMessage == nil }, set: { if !$0 { subscriptionManager.errorMessage = nil } })) {
            Button("OK", role: .cancel) { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            guard isPro else { return }
            if isOnboarding { onPurchaseComplete?() } else { dismiss() }
        }
    }

    private func benefitRow(_ title: String, detail: String?, symbol: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                TQTile(symbol: symbol)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    if let detail {
                        Text(detail)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignSystem.Spacing.rowVertical)
            TQRule()
        }
    }

    private var heroEyebrow: String {
        if case .onboarding(let planName) = mode { return "\(planName) is ready" }
        return "TechnIQ Pro"
    }

    private var heroTitle: String {
        if case .onboarding = mode { return "Train with\n\(CoachIdentity.name())" }
        return feature.title
    }

    private var priceLine: String {
        guard subscriptionManager.isProductAvailable else {
            return subscriptionManager.isLoading ? "Loading the price…" : "Price unavailable right now. Check your connection."
        }
        let price = "\(subscriptionManager.displayPrice) / \(subscriptionManager.subscriptionPeriod)"
        return subscriptionManager.hasTrialOffer ? "\(subscriptionManager.trialDuration) free, then \(price)." : "\(price)."
    }

    private var purchaseTitle: String {
        if subscriptionManager.isLoading { return "One moment" }
        return subscriptionManager.hasTrialOffer ? "Start free trial" : "Go pro"
    }

    private func restore() {
        Task {
            await subscriptionManager.restorePurchases()
            restoreMessage = subscriptionManager.isPro ? "Your subscription is active." : (subscriptionManager.errorMessage ?? "No active subscription found.")
            subscriptionManager.errorMessage = nil
        }
    }
}
