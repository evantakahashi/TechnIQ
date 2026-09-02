import SwiftUI

// MARK: - Acceptance Store

/// One-time community-rules acceptance, persisted in UserDefaults.
/// Checked before a user's first post, comment, or drill share.
enum CommunityGuidelines {
    private static let acceptedKey = "communityGuidelinesAccepted"

    static var hasAccepted: Bool {
        UserDefaults.standard.bool(forKey: acceptedKey)
    }

    static func accept() {
        UserDefaults.standard.set(true, forKey: acceptedKey)
    }
}

// MARK: - Guidelines Sheet

/// Presented once before a user first contributes to the community.
/// Calls `onAgree` after recording acceptance so the caller can proceed.
struct CommunityGuidelinesSheet: View {
    let onAgree: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let rules: [(icon: String, text: String)] = [
        ("heart.fill", "Be kind — treat everyone the way you'd want to be treated."),
        ("soccerball", "Keep it about soccer and training."),
        ("lock.fill", "No personal info — don't share your full name, address, school, or contact details."),
        ("hand.raised.fill", "No mean words, bullying, or harassment.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Community Rules")
                            .font(DesignSystem.Typography.headlineMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("A quick agreement before you join in.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.md)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        ForEach(rules, id: \.text) { rule in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                Image(systemName: rule.icon)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                Text(rule.text)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Text("Breaking the rules removes your content and can lead to a ban.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    ModernButton("I Agree", icon: "checkmark.circle.fill", style: .primary) {
                        CommunityGuidelines.accept()
                        dismiss()
                        onAgree()
                    }
                    .accessibilityLabel("Agree to community rules")
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Before You Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
}
