import SwiftUI
import UserNotifications

// MARK: - Reminders (You → Notifications)
//
// Two toggles and a time. Training-day reminders follow the plan's dates (or fire daily without a
// plan); the streak nudge lands at 19:30 on a day the player has not trained. Changes apply at
// once. If notifications are off at the system level the banner sends the player to Settings.

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player

    @State private var settings = ReminderSettings.load()
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var time = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Reminders") {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            } trailing: {
                TQNavAction("Done") { dismiss() }
            }
            .padding(.top, 8)

            if status == .denied {
                TQBanner(.warning, lead: "Notifications are off for TechnIQ.", message: "Turn them on in Settings to get reminders.", actionTitle: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("What")
                TQRule()
                toggleRow("Training days", subtitle: "On days your plan has a session; every day without a plan", isOn: $settings.trainingDays)
                    .accessibilityIdentifier("reminders.trainingDays")
                toggleRow("Streak at risk", subtitle: "An evening nudge on a day you haven't trained", isOn: $settings.streakAtRisk)
                    .accessibilityIdentifier("reminders.streak")
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("When")
                TQRule()
                HStack {
                    Text("Reminder time")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    Spacer()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(DesignSystem.Colors.grass)
                        .accessibilityLabel("Reminder time")
                }
                .padding(.vertical, DesignSystem.Spacing.rowVertical)
                TQRule()
                Text("Local time. The streak nudge comes at 7:30 PM.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            time = settings.fireDate(on: Date(), calendar: .current) ?? Date()
            Task { status = await NotificationManager.shared.authorizationStatus() }
        }
        .onChange(of: settings) { _, _ in apply() }
        .onChange(of: time) { _, value in
            let components = Calendar.current.dateComponents([.hour, .minute], from: value)
            settings.hour = components.hour ?? ReminderSettings.defaultHour
            settings.minute = components.minute ?? ReminderSettings.defaultMinute
        }
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    Text(subtitle)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.grass)
                    .accessibilityLabel(title)
            }
            .padding(.vertical, DesignSystem.Spacing.rowVertical)
            TQRule()
        }
    }

    private func apply() {
        settings.save()
        if settings.trainingDays || settings.streakAtRisk {
            NotificationManager.shared.requestPermissionIfNeeded {
                Task { status = await NotificationManager.shared.authorizationStatus() }
            }
        }
        NotificationManager.shared.refresh(for: player)
    }
}
