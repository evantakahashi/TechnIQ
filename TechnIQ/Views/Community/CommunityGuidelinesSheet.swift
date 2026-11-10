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

    private let rules: [String] = [
        "Be kind — treat everyone the way you'd want to be treated.",
        "Keep it about soccer and training.",
        "No personal info — don't share your full name, address, school, or contact details.",
        "No mean words, bullying, or harassment."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Before you post") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                TQDisplayTitle("Community rules", size: .medium)
                TQBody("A quick agreement before you join in.")
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                    TQIndexRow(index: String(format: "%02d", index + 1), text: rule)
                }
                TQRule()
            }

            TQBody("Breaking the rules removes your content and can lead to a ban.", tone: .muted, size: 13)

            Spacer(minLength: 0)

            TQButton("I agree") {
                CommunityGuidelines.accept()
                dismiss()
                onAgree()
            }
            .accessibilityLabel("Agree to community rules")
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
