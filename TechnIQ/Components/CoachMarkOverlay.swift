import SwiftUI

// MARK: - CoachMarkManager

final class CoachMarkManager {
    static let shared = CoachMarkManager()

    private static let allIDs = ["dashboard", "train", "plans", "progress", "avatar"]

    private init() {}

    func hasSeen(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: "hasSeenCoachMark_\(id)")
    }

    func markSeen(_ id: String) {
        UserDefaults.standard.set(true, forKey: "hasSeenCoachMark_\(id)")
    }

    func resetAll() {
        for id in Self.allIDs {
            UserDefaults.standard.removeObject(forKey: "hasSeenCoachMark_\(id)")
        }
    }
}

// MARK: - CoachMarkInfo

struct CoachMarkInfo {
    let id: String
    let text: String
}

extension CoachMarkInfo {
    static let dashboard = CoachMarkInfo(id: "dashboard", text: "Start your first session here!")
    static let train = CoachMarkInfo(id: "train", text: "Browse drills or generate a custom AI drill")
    static let plans = CoachMarkInfo(id: "plans", text: "Your AI plan lives here. Complete sessions to progress")
    static let progress = CoachMarkInfo(id: "progress", text: "Track your XP, streaks, and skill growth")
    static let avatar = CoachMarkInfo(id: "avatar", text: "Earn coins from training to unlock gear")
}

// MARK: - CoachMarkModifier

struct CoachMarkModifier: ViewModifier {
    let info: CoachMarkInfo
    @State private var showCoachMark = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if showCoachMark {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .onTapGesture { dismiss() }

                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text(info.text)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)

                            Button {
                                dismiss()
                            } label: {
                                Text("Got it")
                                    .font(DesignSystem.Typography.labelMedium)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }
                        }
                        .padding(DesignSystem.Spacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(DesignSystem.Colors.surfaceRaised)
                                .customShadow(DesignSystem.Shadow.large)
                        )
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                guard !CoachMarkManager.shared.hasSeen(info.id) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(DesignSystem.Animation.smooth) {
                        showCoachMark = true
                    }
                }
            }
    }

    private func dismiss() {
        withAnimation(DesignSystem.Animation.smooth) {
            showCoachMark = false
        }
        CoachMarkManager.shared.markSeen(info.id)
    }
}

// MARK: - View Extension

extension View {
    func coachMark(_ info: CoachMarkInfo) -> some View {
        modifier(CoachMarkModifier(info: info))
    }
}
