import Foundation

/// What the player asked to be reminded about, and when. Stored in UserDefaults; the default is a
/// 17:00 nudge on training days plus a streak-at-risk nudge in the evening, all in local time.
struct ReminderSettings: Equatable {
    static let defaultHour = 17
    static let defaultMinute = 0
    static let streakHour = 19
    static let streakMinute = 30

    var trainingDays = true
    var streakAtRisk = true
    var hour = ReminderSettings.defaultHour
    var minute = ReminderSettings.defaultMinute

    private enum Key {
        static let trainingDays = "reminders.trainingDays"
        static let streakAtRisk = "reminders.streakAtRisk"
        static let hour = "reminders.hour"
        static let minute = "reminders.minute"
    }

    static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        var settings = ReminderSettings()
        if defaults.object(forKey: Key.trainingDays) != nil { settings.trainingDays = defaults.bool(forKey: Key.trainingDays) }
        if defaults.object(forKey: Key.streakAtRisk) != nil { settings.streakAtRisk = defaults.bool(forKey: Key.streakAtRisk) }
        if defaults.object(forKey: Key.hour) != nil { settings.hour = min(max(defaults.integer(forKey: Key.hour), 0), 23) }
        if defaults.object(forKey: Key.minute) != nil { settings.minute = min(max(defaults.integer(forKey: Key.minute), 0), 59) }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(trainingDays, forKey: Key.trainingDays)
        defaults.set(streakAtRisk, forKey: Key.streakAtRisk)
        defaults.set(hour, forKey: Key.hour)
        defaults.set(minute, forKey: Key.minute)
    }

    /// The reminder time on a given day, in the calendar's (local) time zone.
    func fireDate(on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: day))
    }

    /// "5:00 PM" in the player's locale.
    func timeLabel(calendar: Calendar = .current) -> String {
        guard let date = fireDate(on: Date(), calendar: calendar) else { return "\(hour):\(String(format: "%02d", minute))" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
