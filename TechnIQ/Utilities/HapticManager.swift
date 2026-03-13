import UIKit
import SwiftUI

/// Centralized manager for haptic feedback throughout the app
/// Provides consistent tactile feedback for various user interactions and achievements
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    // MARK: - Preparation

    /// Pre-prepare generators for faster response
    func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - Basic Haptics

    /// Light impact - for subtle interactions
    func lightTap() {
        lightImpact.impactOccurred()
    }

    /// Medium impact - for standard interactions
    func mediumTap() {
        mediumImpact.impactOccurred()
    }

    /// Heavy impact - for important actions
    func heavyTap() {
        heavyImpact.impactOccurred()
    }

    /// Rigid impact - for firm feedback
    func rigidTap() {
        rigidImpact.impactOccurred()
    }

    /// Soft impact - for gentle feedback
    func softTap() {
        softImpact.impactOccurred()
    }

    /// Selection changed - for picker/selection changes
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }

    // MARK: - Notification Haptics

    /// Success notification - for completed actions
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning notification - for alerts
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error notification - for failures
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - Context-Specific Haptics

    /// Button tap feedback
    func buttonTap() {
        lightImpact.impactOccurred()
    }

    /// Toggle switch feedback
    func toggleSwitch() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// Slider value changed
    func sliderTick() {
        lightImpact.impactOccurred(intensity: 0.3)
    }

    /// Card swipe feedback
    func cardSwipe() {
        mediumImpact.impactOccurred()
    }

    /// Pull to refresh
    func pullToRefresh() {
        mediumImpact.impactOccurred()
    }

    // MARK: - Achievement & Celebration Haptics

    /// XP earned feedback - subtle but noticeable
    func xpEarned() {
        lightImpact.impactOccurred(intensity: 0.8)
    }

    /// Achievement unlocked - celebratory pattern
    func achievementUnlocked() {
        Task { @MainActor in
            notificationFeedback.notificationOccurred(.success)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            mediumImpact.impactOccurred()
            try? await Task.sleep(nanoseconds: 100_000_000)
            mediumImpact.impactOccurred()
        }
    }

    /// Level up - exciting pattern
    func levelUp() {
        Task { @MainActor in
            heavyImpact.impactOccurred()
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
            mediumImpact.impactOccurred()
            try? await Task.sleep(nanoseconds: 100_000_000)
            mediumImpact.impactOccurred()
            try? await Task.sleep(nanoseconds: 100_000_000)
            lightImpact.impactOccurred()
        }
    }

    /// Streak milestone - building pattern
    func streakMilestone() {
        Task { @MainActor in
            for i in 0..<3 {
                let intensity = 0.5 + (Double(i) * 0.2)
                mediumImpact.impactOccurred(intensity: intensity)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            notificationFeedback.notificationOccurred(.success)
        }
    }

    /// Session complete - satisfying finish
    func sessionComplete() {
        Task { @MainActor in
            heavyImpact.impactOccurred()
            try? await Task.sleep(nanoseconds: 200_000_000)
            notificationFeedback.notificationOccurred(.success)
        }
    }

    /// Countdown tick (for timers)
    func countdownTick() {
        lightImpact.impactOccurred(intensity: 0.4)
    }

    /// Countdown complete
    func countdownComplete() {
        heavyImpact.impactOccurred()
    }

    // MARK: - Transition Haptics

    /// Prepare generators for imminent transition
    func prepareForTransition() {
        mediumImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        lightImpact.prepare()
    }

    /// Hero transition launch
    func heroLaunch() {
        mediumImpact.impactOccurred()
    }

    /// Hero transition settle
    func heroSettle() {
        softImpact.impactOccurred()
    }

    /// Sheet presented
    func sheetPresent() {
        softImpact.impactOccurred()
    }

    /// Sheet dismissed
    func sheetDismiss() {
        lightImpact.impactOccurred()
    }

    /// Pulse expand (achievement, reveal)
    func pulseExpand() {
        rigidImpact.impactOccurred()
    }

    /// Card flip midpoint
    func cardFlipMidpoint() {
        mediumImpact.impactOccurred()
    }

    /// Tab changed
    func tabChanged() {
        lightImpact.impactOccurred()
    }

    // MARK: - Training-Specific Haptics

    /// Exercise started
    func exerciseStart() {
        mediumImpact.impactOccurred()
    }

    /// Exercise completed
    func exerciseComplete() {
        success()
    }

    /// Rep completed
    func repComplete() {
        lightImpact.impactOccurred(intensity: 0.5)
    }

    /// Set completed
    func setComplete() {
        mediumImpact.impactOccurred()
    }

    /// Rest period start
    func restStart() {
        softImpact.impactOccurred()
    }

    /// Rest period end
    func restEnd() {
        mediumImpact.impactOccurred()
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add haptic feedback to any view action
    func hapticFeedback(_ type: HapticType, trigger: Bool) -> some View {
        self.onChange(of: trigger) { newValue in
            if newValue {
                switch type {
                case .light: HapticManager.shared.lightTap()
                case .medium: HapticManager.shared.mediumTap()
                case .heavy: HapticManager.shared.heavyTap()
                case .success: HapticManager.shared.success()
                case .warning: HapticManager.shared.warning()
                case .error: HapticManager.shared.error()
                case .selection: HapticManager.shared.selectionChanged()
                case .achievement: HapticManager.shared.achievementUnlocked()
                case .levelUp: HapticManager.shared.levelUp()
                case .sessionComplete: HapticManager.shared.sessionComplete()
                }
            }
        }
    }
}

/// Types of haptic feedback available
enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    case achievement
    case levelUp
    case sessionComplete
}
