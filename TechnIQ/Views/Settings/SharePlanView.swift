import SwiftUI

// MARK: - Share a plan with the community (plan Edit menu, behind FeatureFlags.community)
//
// The plan as others will see it, an optional message, one action.

struct SharePlanView: View {
    let plan: TrainingPlanModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareMessage = ""
    @State private var isSharing = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?

    private let messageLimit = 200

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TQNavBar("Share plan") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                planSummary

                TQStatRail(items: [
                    .init("\(plan.durationWeeks)", unit: "wk", label: "length"),
                    .init(String(format: "%.0f", plan.estimatedTotalHours), unit: "h", label: "total")
                ])

                DrillFormTextArea(label: "Message (optional)", text: $shareMessage,
                                  placeholder: "This plan helped me improve my finishing…", lines: 3...6, limit: messageLimit)

                TQBody("Other players see the plan's structure, drills, length and level, plus your message. Your own progress and personal data stay private.", tone: .muted, size: 13)

                TQButton("Share with community", isLoading: isSharing) { sharePlan() }
                    .disabled(isSharing)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Plan shared", isPresented: $showSuccessMessage) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Thanks for contributing. Your plan will help other players train.")
        }
        .alert("Couldn't share", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Plan summary

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQEyebrow([plan.targetRole, plan.difficulty.displayName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            TQDisplayTitle(plan.name, size: .medium)
            if !plan.description.isEmpty {
                TQBody(plan.description)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func sharePlan() {
        guard shareMessage.count <= messageLimit else {
            errorMessage = "Message must be \(messageLimit) characters or less"
            return
        }

        isSharing = true

        Task {
            do {
                try await CloudService.shared.shareTrainingPlan(plan, message: shareMessage)

                await MainActor.run {
                    isSharing = false
                    showSuccessMessage = true
                }
            } catch CloudDataError.notAuthenticated {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Please sign in to share plans"
                }
            } catch CloudDataError.networkError {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "No internet connection. Please try again later."
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Failed to share plan. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let mockPlan = TrainingPlanModel(
        id: UUID(),
        name: "Striker Development",
        description: "8-week program focused on finishing, positioning, and movement in the attacking third",
        durationWeeks: 8,
        difficulty: .intermediate,
        category: .position,
        targetRole: "Striker",
        isPrebuilt: false,
        isActive: false,
        currentWeek: 1,
        progressPercentage: 0,
        startedAt: nil,
        completedAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        weeks: []
    )

    return SharePlanView(plan: mockPlan)
}
#endif
