import SwiftUI
import StoreKit

struct OnboardingPaywallView: View {
    let planName: String
    let onContinueFree: () -> Void
    let onPurchaseComplete: () -> Void

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showFreeConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // MARK: - Header
                headerSection

                // MARK: - Benefits
                benefitsCard

                // MARK: - Trial Timeline
                if subscriptionManager.hasTrialOffer {
                    trialTimeline
                }

                // MARK: - Pricing
                pricingSection

                // MARK: - Purchase CTA
                purchaseButton

                // MARK: - Continue Free
                Button {
                    showFreeConfirmation = true
                } label: {
                    Text("Continue with Free")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // MARK: - Restore
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                // MARK: - Legal
                legalText
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .task { await subscriptionManager.loadProduct() }
        .sheet(isPresented: $showFreeConfirmation) {
            freeConfirmationSheet
                .presentationDetents([.medium])
        }
        .alert("Error", isPresented: .init(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                subscriptionManager.errorMessage = nil
            }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.accentGold, DesignSystem.Colors.accentOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock TechnIQ Pro")
                .font(DesignSystem.Typography.displaySmall)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if !planName.isEmpty {
                Text("Your \(planName) plan is ready")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: - Benefits

    private var benefitsCard: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                benefitRow(icon: "brain.head.profile", text: "Unlimited AI-generated drills")
                benefitRow(icon: "calendar.badge.plus", text: "Personalized training plans")
                benefitRow(icon: "play.circle.fill", text: "Animated drill walkthroughs")
                benefitRow(icon: "sparkles", text: "Smart weakness recommendations")
                benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Full progress analytics")
                benefitRow(icon: "person.crop.circle.badge.checkmark", text: "All avatar items & rewards")
            }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24)

            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Trial Timeline

    private var trialTimeline: some View {
        HStack(spacing: 0) {
            // Today node
            timelineNode(
                icon: "checkmark.circle.fill",
                color: DesignSystem.Colors.primaryGreen,
                label: "Today",
                sublabel: "Trial Starts"
            )

            // Connecting line
            Rectangle()
                .fill(DesignSystem.Colors.textTertiary)
                .frame(height: 2)

            // Day 7 node
            timelineNode(
                icon: "circle.fill",
                color: DesignSystem.Colors.accentGold,
                label: "Day 7",
                sublabel: "First Charge"
            )

            // Connecting line
            Rectangle()
                .fill(DesignSystem.Colors.textTertiary)
                .frame(height: 2)

            // Cancel node
            timelineNode(
                icon: "xmark.circle",
                color: DesignSystem.Colors.textSecondary,
                label: "Anytime",
                sublabel: "Cancel"
            )
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func timelineNode(icon: String, color: Color, label: String, sublabel: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(sublabel)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
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
        ZStack {
            ModernButton(
                subscriptionManager.hasTrialOffer ? "Start Your 7-Day Free Trial" : "Subscribe Now",
                icon: "crown.fill",
                style: .primary
            ) {
                Task {
                    await subscriptionManager.purchase()
                    if subscriptionManager.isPro {
                        onPurchaseComplete()
                    }
                }
            }
            .disabled(subscriptionManager.isLoading)
            .opacity(subscriptionManager.isLoading ? 0.6 : 1.0)

            if subscriptionManager.isLoading {
                ProgressView()
                    .tint(DesignSystem.Colors.textOnAccent)
            }
        }
    }

    // MARK: - Legal

    private var legalText: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignSystem.Spacing.md) {
                Link("Terms of Use", destination: URL(string: "https://techniq.app/terms")!)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Text("|")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Link("Privacy Policy", destination: URL(string: "https://techniq.app/privacy")!)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Free Confirmation Sheet

    private var freeConfirmationSheet: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Free Plan Includes")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.top, DesignSystem.Spacing.lg)

            VStack(spacing: DesignSystem.Spacing.md) {
                freeFeatureRow("1 custom AI drill")
                freeFeatureRow("1 quick AI drill")
                freeFeatureRow("Basic training sessions")
                freeFeatureRow("Progress tracking")
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            Text("Upgrade anytime in Settings")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                ModernButton("Continue with Free", style: .secondary) {
                    showFreeConfirmation = false
                    onContinueFree()
                }

                ModernButton(
                    "Start Free Trial Instead",
                    icon: "crown.fill",
                    style: .primary
                ) {
                    showFreeConfirmation = false
                    Task {
                        await subscriptionManager.purchase()
                        if subscriptionManager.isPro {
                            onPurchaseComplete()
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
    }

    private func freeFeatureRow(_ text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    OnboardingPaywallView(
        planName: "Striker Development",
        onContinueFree: {},
        onPurchaseComplete: {}
    )
}
