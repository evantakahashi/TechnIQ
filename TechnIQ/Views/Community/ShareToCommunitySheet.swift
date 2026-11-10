import SwiftUI

// MARK: - Share to community (drill, session, achievement, level)
//
// What is being shared as the title, an optional message, one Share button.

struct ShareToCommunitySheet: View {
    let shareType: ShareType
    let player: Player
    let onDismiss: () -> Void

    @ObservedObject private var communityService = CommunityService.shared
    @State private var additionalText = ""
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var shareSuccess = false
    @State private var showingGuidelines = false

    private let maxCharacters = 300

    enum ShareType {
        case drill(Exercise)
        case session(duration: Int, exerciseCount: Int, rating: Double, xp: Int)
        case achievement(name: String, icon: String)
        case levelUp(level: Int, rankName: String)

        var postType: CommunityPostType {
            switch self {
            case .drill: return .sharedDrill
            case .session: return .sharedSession
            case .achievement: return .sharedAchievement
            case .levelUp: return .sharedLevelUp
            }
        }

        var previewTitle: String {
            switch self {
            case .drill(let exercise): return exercise.name ?? "Untitled Drill"
            case .session: return "Training Complete"
            case .achievement(let name, _): return name
            case .levelUp(let level, let rank): return "Level \(level) — \(rank)"
            }
        }

        var defaultContent: String {
            switch self {
            case .drill(let exercise): return "Check out this drill: \(exercise.name ?? "Untitled")"
            case .session(let duration, let count, _, let xp):
                return "Just finished a \(duration) min session with \(count) exercises! +\(xp) XP"
            case .achievement(let name, _): return "Achievement unlocked: \(name)!"
            case .levelUp(let level, let rank): return "Just reached Level \(level) — \(rank)!"
            }
        }

        var metadata: [String: Any] {
            switch self {
            case .drill(let exercise):
                return [
                    "drillTitle": exercise.name ?? "Untitled",
                    "drillCategory": exercise.category ?? "technical",
                    "drillDifficulty": Int(exercise.difficulty)
                ]
            case .session(let duration, let count, let rating, let xp):
                return [
                    "sessionDuration": duration,
                    "sessionExerciseCount": count,
                    "sessionRating": rating,
                    "sessionXP": xp
                ]
            case .achievement(let name, let icon):
                return [
                    "achievementName": name,
                    "achievementIcon": icon
                ]
            case .levelUp(let level, let rank):
                return [
                    "newLevel": level,
                    "rankName": rank
                ]
            }
        }
    }

    private var isBusy: Bool { isSharing || shareSuccess }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Share") {
                TQNavAction("Cancel") { onDismiss() }
            } trailing: {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(shareType.postType.displayName, size: 11)
                TQDisplayTitle(shareType.previewTitle, size: .medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            CommunityTextArea(label: "Message (optional)", placeholder: "Say something about this…",
                              text: $additionalText, limit: maxCharacters, minHeight: 90)

            if let error = shareError {
                TQBanner(.error, message: error)
            }
            if shareSuccess {
                TQBanner(.info, lead: "Shared.", message: "It's on the community feed.")
            }

            Spacer(minLength: 0)

            TQButton("Share to Community", isLoading: isSharing) { share() }
                .disabled(isBusy)
                .opacity(shareSuccess ? 0.5 : 1)
                .padding(.bottom, DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGuidelines) {
            CommunityGuidelinesSheet { share() }
        }
    }

    // MARK: - Actions

    private func share() {
        guard CommunityGuidelines.hasAccepted else {
            showingGuidelines = true
            return
        }

        isSharing = true
        shareError = nil

        let content = additionalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? shareType.defaultContent
            : additionalText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                if case .drill(let exercise) = shareType {
                    try await communityService.shareDrill(exercise: exercise, player: player, message: content)
                } else {
                    try await communityService.createRichPost(
                        content: content,
                        postType: shareType.postType,
                        player: player,
                        metadata: shareType.metadata
                    )
                }

                HapticManager.shared.success()
                shareSuccess = true

                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onDismiss()
            } catch {
                shareError = error.localizedDescription
                isSharing = false
                HapticManager.shared.error()
            }
        }
    }
}
