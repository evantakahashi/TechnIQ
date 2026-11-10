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

    // MARK: - Achievement & Celebration Haptics

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

    // MARK: - Transition Haptics

    /// Tab changed
    func tabChanged() {
        lightImpact.impactOccurred()
    }

    // MARK: - Training-Specific Haptics

    /// Exercise completed
    func exerciseComplete() {
        success()
    }

}

// MARK: - SwiftUI View Extension

extension View {
}

