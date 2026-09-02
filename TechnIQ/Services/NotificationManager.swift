import Foundation
import UserNotifications

// MARK: - Notification Manager

/// Manages LOCAL notifications: daily training reminders, streak-at-risk nudges, and plan-day reminders.
/// No push infrastructure is used. Permission is requested lazily by the UI layer (never at launch).
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private enum Identifier {
        static let dailyReminder = "daily_training_reminder"
        static let streakAtRisk = "streak_at_risk"
        static let planDayPrefix = "plan_day_"
    }

    private let permissionAskedKey = "notif_permission_asked"

    private init() {}

    // MARK: - Permission

    /// Request notification permission once. Idempotent — records the asked-state in UserDefaults.
    /// Intended to be called by the UI layer after the player's first session, not at launch.
    func requestPermissionIfNeeded() {
        guard !defaults.bool(forKey: permissionAskedKey) else { return }
        defaults.set(true, forKey: permissionAskedKey)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                AppLogger.shared.error("Notification permission error: \(error.localizedDescription)")
            } else {
                AppLogger.shared.info("Notification permission granted: \(granted)")
            }
        }
    }

    // MARK: - Scheduling

    /// Daily reminder to train, defaulting to 5pm. Replaces any existing daily reminder.
    func scheduleDailyTrainingReminder(hour: Int = 17) {
        let content = UNMutableNotificationContent()
        content.title = "Time to train! ⚽"
        content.body = "Your streak is waiting — jump in for today's session."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        schedule(identifier: Identifier.dailyReminder, content: content, dateComponents: components, repeats: true)
    }

    /// Evening nudge (~7:30pm) warning the player their streak is at risk. Replaces any existing check.
    func scheduleStreakAtRiskCheck(currentStreak: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body = currentStreak > 0
            ? "Don't lose your \(currentStreak)-day streak! Train before the day ends."
            : "Train today to keep your streak alive!"
        content.sound = .default

        var components = DateComponents()
        components.hour = 19
        components.minute = 30

        schedule(identifier: Identifier.streakAtRisk, content: content, dateComponents: components, repeats: true)
    }

    /// Cancel the streak-at-risk nudge — call when a session is logged so the player isn't nagged today.
    func cancelStreakAtRiskForToday() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.streakAtRisk])
    }

    /// Minimal one-shot reminder for a scheduled training-plan day.
    func schedulePlanDayReminder(title: String, body: String, on date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let identifier = Identifier.planDayPrefix + ISO8601DateFormatter().string(from: date)
        schedule(identifier: identifier, content: content, dateComponents: components, repeats: false)
    }

    // MARK: - Helpers

    private func schedule(identifier: String, content: UNMutableNotificationContent, dateComponents: DateComponents, repeats: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                AppLogger.shared.error("Failed to schedule notification \(identifier): \(error.localizedDescription)")
            }
        }
    }
}
