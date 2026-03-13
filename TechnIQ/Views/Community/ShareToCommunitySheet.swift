import SwiftUI

struct ShareToCommunitySheet: View {
    let shareType: ShareType
    let player: Player
    let onDismiss: () -> Void

    @StateObject private var communityService = CommunityService.shared
    @State private var additionalText = ""
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var shareSuccess = false

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

        var previewIcon: String {
            switch self {
            case .drill: return "square.and.arrow.up.fill"
            case .session: return "checkmark.circle.fill"
            case .achievement(_, let icon): return icon
            case .levelUp: return "arrow.up.circle.fill"
            }
        }

        var accentColor: Color {
            switch self {
            case .drill, .session: return DesignSystem.Colors.primaryGreen
            case .achievement, .levelUp: return DesignSystem.Colors.accentGold
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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        previewCard

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Add a message (optional)")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            ZStack(alignment: .topLeading) {
                                if additionalText.isEmpty {
                                    Text("Say something about this...")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                        .padding(.top, DesignSystem.Spacing.md)
                                        .padding(.leading, DesignSystem.Spacing.md)
                                }
                                TextEditor(text: $additionalText)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(DesignSystem.Spacing.sm)
                                    .frame(minHeight: 80)
                                    .onChange(of: additionalText) {
                                        if additionalText.count > maxCharacters {
                                            additionalText = String(additionalText.prefix(maxCharacters))
                                        }
                                    }
                            }
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                            HStack {
                                Spacer()
                                Text("\(additionalText.count)/\(maxCharacters)")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }

                        if let error = shareError {
                            Text(error)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                VStack {
                    ModernButton("Share to Community", icon: "paperplane.fill", style: .primary) {
                        share()
                    }
                    .disabled(isSharing)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .overlay {
                if isSharing {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    LoadingStateView(message: "Sharing...")
                }
                if shareSuccess {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("Shared!")
                            .font(DesignSystem.Typography.headlineMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .background(DesignSystem.Colors.surfaceOverlay)
                    .cornerRadius(DesignSystem.CornerRadius.xl)
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: shareType.previewIcon)
                    .font(.title2)
                    .foregroundColor(shareType.accentColor)
                    .frame(width: 44, height: 44)
                    .background(shareType.accentColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(shareType.previewTitle)
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(shareType.postType.displayName)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(shareType.accentColor)
                }

                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func share() {
        isSharing = true
        shareError = nil

        let content = additionalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? shareType.defaultContent
            : additionalText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                if case .drill(let exercise) = shareType {
                    try await communityService.shareDrill(exercise: exercise, player: player)
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
