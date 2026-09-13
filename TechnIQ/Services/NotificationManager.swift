import Foundation
import UserNotifications

// MARK: - Notification Manager

/// Manages LOCAL notifications: training-day reminders from the plan's dates, a daily nudge when
/// there is no plan, and an evening streak-at-risk nudge. No push infrastructure is used.
/// Permission is requested by the UI layer (after onboarding's "You're all set"), never at launch.
/// `refresh` is the single entry point: it rebuilds every pending reminder from the current plan,
/// streak and settings, so callers never have to reason about what was scheduled before.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    enum Identifier {
        static let dailyReminder = "daily_training_reminder"
        static let streakAtRisk = "streak_at_risk"
        static let planDayPrefix = "plan_day_"
    }

    private let permissionAskedKey = "notif_permission_asked"

    /// How many training days ahead get their own one-shot reminder.
    static let plannedReminderHorizon = 14

    private init() {}

    // MARK: - Permission

    /// Request notification permission once. Idempotent — records the asked-state in UserDefaults.
    func requestPermissionIfNeeded(completion: (() -> Void)? = nil) {
        guard !defaults.bool(forKey: permissionAskedKey) else { completion?(); return }
        defaults.set(true, forKey: permissionAskedKey)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                AppLogger.shared.error("Notification permission error: \(error.localizedDescription)")
            } else {
                AppLogger.shared.info("Notification permission granted: \(granted)")
            }
            Task { @MainActor in completion?() }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Refresh

    /// Rebuilds all reminders. Call after onboarding, on app open, after a session, and whenever the
    /// plan or the settings change.
    func refresh(plan: TrainingPlanModel?, streak: Int, trainedToday: Bool, settings: ReminderSettings = .load(), now: Date = Date(), calendar: Calendar = .current) {
        let requests = Self.plannedRequests(plan: plan, streak: streak, trainedToday: trainedToday, settings: settings, now: now, calendar: calendar)
        center.getPendingNotificationRequests { [center] pending in
            let ours = pending.map(\.identifier).filter {
                $0 == Identifier.dailyReminder || $0 == Identifier.streakAtRisk || $0.hasPrefix(Identifier.planDayPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for request in requests {
                center.add(request) { error in
                    if let error { AppLogger.shared.error("Failed to schedule \(request.identifier): \(error.localizedDescription)") }
                }
            }
        }
    }

    /// Convenience: reads the active plan, streak and today's sessions off the player.
    func refresh(for player: Player, now: Date = Date()) {
        let plan = TrainingPlanService.shared.fetchActivePlan(for: player)
        let calendar = Calendar.current
        let trainedToday = ((player.sessions as? Set<TrainingSession>) ?? []).contains {
            guard let date = $0.date else { return false }
            return calendar.isDate(date, inSameDayAs: now)
        }
        refresh(plan: plan, streak: Int(player.currentStreak), trainedToday: trainedToday, now: now, calendar: calendar)
    }

    /// Cancel the streak-at-risk nudge — call when a session is logged so the player isn't nagged today.
    func cancelStreakAtRiskForToday() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.streakAtRisk])
    }

    // MARK: - Planning (pure)

    struct Planned: Equatable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
        let repeats: Bool
    }

    /// The reminders that should exist right now. Pure, so the schedule is unit-testable.
    nonisolated static func plan(plan: TrainingPlanModel?, streak: Int, trainedToday: Bool, settings: ReminderSettings, now: Date, calendar: Calendar) -> [Planned] {
        var planned: [Planned] = []

        if settings.trainingDays {
            if let plan {
                let upcoming = PlanSchedule.upcoming(in: plan, startDate: PlanSchedule.startDate(of: plan), now: now, calendar: calendar, limit: plannedReminderHorizon)
                for entry in upcoming {
                    guard let fireDate = settings.fireDate(on: entry.date, calendar: calendar), fireDate > now else { continue }
                    let type = entry.day.sessions.first?.sessionType.displayName ?? "Training"
                    let minutes = entry.day.totalDuration
                    let body = minutes > 0 ? "\(type) session · \(minutes) min · week \(entry.week.weekNumber)" : "\(type) session · week \(entry.week.weekNumber)"
                    planned.append(Planned(
                        identifier: Identifier.planDayPrefix + ISO8601DateFormatter().string(from: fireDate),
                        title: "Training day",
                        body: body,
                        fireDate: fireDate,
                        repeats: false
                    ))
                }
            } else if let fireDate = settings.fireDate(on: now, calendar: calendar) {
                planned.append(Planned(
                    identifier: Identifier.dailyReminder,
                    title: "Time to train",
                    body: "A quick drill keeps the streak alive.",
                    fireDate: fireDate,
                    repeats: true
                ))
            }
        }

        if settings.streakAtRisk, streak > 0, !trainedToday,
           let fireDate = calendar.date(bySettingHour: ReminderSettings.streakHour, minute: ReminderSettings.streakMinute, second: 0, of: calendar.startOfDay(for: now)),
           fireDate > now {
            planned.append(Planned(
                identifier: Identifier.streakAtRisk,
                title: "Your \(streak)-day streak is on the line",
                body: "Train before the day ends to keep it.",
                fireDate: fireDate,
                repeats: false
            ))
        }

        return planned
    }

    private nonisolated static func plannedRequests(plan: TrainingPlanModel?, streak: Int, trainedToday: Bool, settings: ReminderSettings, now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        self.plan(plan: plan, streak: streak, trainedToday: trainedToday, settings: settings, now: now, calendar: calendar).map { item in
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let components: DateComponents
            if item.repeats {
                components = calendar.dateComponents([.hour, .minute], from: item.fireDate)
            } else {
                components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: item.repeats)
            return UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
        }
    }
}
