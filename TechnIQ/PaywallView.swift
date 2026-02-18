import SwiftUI
import StoreKit

// MARK: - Paywall Feature Context
enum PaywallFeature {
    case trainingPlan
    case customDrill
    case quickDrill
    case dailyCoaching
    case mlRecommendations
    case youtubeRecs
    case weeklyAdaptation

    var title: String {
        switch self {
        case .trainingPlan: return "AI Training Plans"
        case .customDrill: return "Custom AI Drills"
        case .quickDrill: return "Quick AI Drills"
        case .dailyCoaching: return "Daily AI Coaching"
        case .mlRecommendations: return "Smart Recommendations"
        case .youtubeRecs: return "YouTube AI Picks"
        case .weeklyAdaptation: return "Plan Adaptation"
        }
    }

    var icon: String {
        switch self {
        case .trainingPlan: return "calendar.badge.plus"
        case .customDrill: return "brain.head.profile"
        case .quickDrill: return "bolt.fill"
        case .dailyCoaching: return "message.badge.waveform"
        case .mlRecommendations: return "sparkles"
        case .youtubeRecs: return "play.rectangle.fill"
        case .weeklyAdaptation: return "arrow.triangle.2.circlepath"
        }
    }

    var description: String {
        switch self {
        case .trainingPlan: return "Generate unlimited personalized training plans with AI"
        case .customDrill: return "Create custom drills tailored to your skill level"
        case .quickDrill: return "Instantly generate drills from a quick description"
        case .dailyCoaching: return "Get daily AI-powered coaching tips and focus areas"
        case .mlRecommendations: return "Receive smart drill recommendations based on your training"
        case .youtubeRecs: return "Discover curated YouTube drills matched to your needs"
        case .weeklyAdaptation: return "Automatically adapt your plan based on weekly progress"
        }
    }
}

// MARK: - PaywallView
struct PaywallView: View {
    let feature: PaywallFeature
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    featureHeader
                    proBenefits
                    pricingSection
                    purchaseButton
                    restoreButton
                    termsText
                }
                .padding(DesignSystem.Spacing.screenPadding)
            }
            .adaptiveBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Button("OK") { subscriptionManager.errorMessage = nil }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
            .onChange(of: subscriptionManager.isPro) { isPro in
                if isPro { dismiss() }
            }
        }
        .task {
            await subscriptionManager.loadProduct()
        }
    }

    // MARK: - Feature Header
    private var featureHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: feature.icon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primaryGreen, DesignSystem.Colors.accentGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(DesignSystem.Spacing.lg)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                )

            Text("Unlock \(feature.title)")
                .font(DesignSystem.Typography.headlineLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(feature.description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Pro Benefits
    private var proBenefits: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("TechnIQ Pro includes:")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                benefitRow("Unlimited AI training plans", icon: "calendar.badge.plus")
                benefitRow("Custom & quick drill generator", icon: "brain.head.profile")
                benefitRow("Daily AI coaching", icon: "message.badge.waveform")
                benefitRow("Smart drill recommendations", icon: "sparkles")
                benefitRow("YouTube AI drill picks", icon: "play.rectangle.fill")
                benefitRow("Weekly plan adaptation", icon: "arrow.triangle.2.circlepath")
            }
        }
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .frame(width: 24)
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Pricing
    private var pricingSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if subscriptionManager.hasTrialOffer {
                Text("7 days free, then \(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            } else {
                Text("\(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Text("Cancel anytime")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Purchase Button
    private var purchaseButton: some View {
        ModernButton(
            subscriptionManager.hasTrialOffer ? "Start Free Trial" : "Subscribe Now",
            icon: "crown.fill",
            style: .primary
        ) {
            Task { await subscriptionManager.purchase() }
        }
        .disabled(subscriptionManager.isLoading)
        .overlay {
            if subscriptionManager.isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    // MARK: - Restore
    private var restoreButton: some View {
        Button {
            Task { await subscriptionManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Terms
    private var termsText: some View {
        Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is cancelled at least 24 hours before the end of the current period.")
            .font(DesignSystem.Typography.bodySmall)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .multilineTextAlignment(.center)
    }
}
