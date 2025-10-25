import SwiftUI
import CoreData
import Foundation

// MARK: - Calendar Mini Summary

struct CalendarMiniSummary: View {
    let sessions: [TrainingSession]
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Total Sessions
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(sessions.count)")
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                
                Text("Sessions")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Divider()
                .frame(height: 30)
            
            // Total Training Time
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(totalDurationText)
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)
                
                Text("Minutes")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Divider()
                .frame(height: 30)
            
            // Average Intensity
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(String(format: "%.1f", averageIntensity))
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.accentOrange)
                
                Text("Avg Intensity")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }
    
    private var totalDurationText: String {
        let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
        return "\(Int(totalMinutes))"
    }
    
    private var averageIntensity: Double {
        guard !sessions.isEmpty else { return 0 }
        let totalIntensity = sessions.reduce(0) { $0 + $1.intensity }
        return Double(totalIntensity) / Double(sessions.count)
    }
}

// MARK: - Calendar Week View

struct CalendarWeekView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var sessions: FetchedResults<TrainingSession>
    
    @State private var selectedDate = Date()
    @State private var currentWeek = Date()
    @State private var selectedSession: TrainingSession?
    @State private var showingSessionDetail = false
    
    private let calendar = Calendar.current
    
    init() {
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Week Navigation
            weekNavigationHeader
            
            // Week Days
            weekDaysView
            
            // Selected Day Sessions
            if !sessionsForSelectedDate.isEmpty {
                selectedDaySessionsList
            }
        }
        .onAppear {
            updateSessionsFilter()
        }
        .onChange(of: authManager.userUID) {
            updateSessionsFilter()
        }
        .sheet(isPresented: $showingSessionDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session)
            }
        }
    }
    
    private var weekNavigationHeader: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            
            Spacer()
            
            Text(weekRangeString)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button(action: nextWeek) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private var weekDaysView: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(weekDates, id: \.self) { date in
                WeekDayView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDate(date, inSameDayAs: Date()),
                    sessions: sessionsForDate(date)
                ) {
                    selectedDate = date
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private var selectedDaySessionsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(selectedDateString)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(sessionsForSelectedDate, id: \.objectID) { session in
                WeekSessionRow(session: session) {
                    selectedSession = session
                    showingSessionDetail = true
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSessionsFilter() {
        guard !authManager.userUID.isEmpty else { return }
        sessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }
    
    private func sessionsForDate(_ date: Date) -> [TrainingSession] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return sessions.filter { session in
            guard let sessionDate = session.date else { return false }
            return sessionDate >= startOfDay && sessionDate < endOfDay
        }
    }
    
    private var sessionsForSelectedDate: [TrainingSession] {
        return sessionsForDate(selectedDate)
    }
    
    private func previousWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
        }
    }
    
    private func nextWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
        }
    }
    
    // MARK: - Computed Properties
    
    private var weekRangeString: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekInterval.start)
        let endString = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end)
        
        return "\(startString) - \(endString)"
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        
        if calendar.isDate(selectedDate, inSameDayAs: Date()) {
            return "Today's Sessions"
        } else if calendar.isDate(selectedDate, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "Yesterday's Sessions"
        } else {
            formatter.dateStyle = .full
            return formatter.string(from: selectedDate)
        }
    }
    
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = weekInterval.start
        
        for _ in 0..<7 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
}

// MARK: - Week Day View

struct WeekDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let sessions: [TrainingSession]
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Day of week
                Text(dayOfWeekString)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                // Session indicator bar
                Rectangle()
                    .fill(sessionBarColor)
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private var textColor: Color {
        if isToday {
            return isSelected ? .white : DesignSystem.Colors.primaryGreen
        } else {
            return isSelected ? .white : DesignSystem.Colors.textPrimary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.primaryGreen
        } else if isToday {
            return DesignSystem.Colors.primaryGreen.opacity(0.1)
        } else {
            return DesignSystem.Colors.cardBackground
        }
    }
    
    private var borderColor: Color {
        return isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
    }
    
    private var sessionBarColor: Color {
        if sessions.isEmpty {
            return Color.clear
        }
        
        let avgIntensity = sessions.reduce(0) { $0 + $1.intensity } / Int16(sessions.count)
        
        switch avgIntensity {
        case 1...2:
            return DesignSystem.Colors.success
        case 3:
            return DesignSystem.Colors.accentYellow
        case 4:
            return DesignSystem.Colors.warning
        default:
            return DesignSystem.Colors.error
        }
    }
}

// MARK: - Week Session Row

struct WeekSessionRow: View {
    let session: TrainingSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Session type icon
                    Image(systemName: iconForSessionType(session.sessionType))
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .frame(width: 24)
                    
                    // Session details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.sessionType ?? "Training")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(timeString)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Duration and intensity
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(session.duration)) min")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        IntensityIndicator(level: Int(session.intensity))
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var timeString: String {
        guard let date = session.date else { return "Unknown time" }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func iconForSessionType(_ sessionType: String?) -> String {
        switch sessionType?.lowercased() {
        case "technical":
            return "soccerball"
        case "physical":
            return "figure.run"
        case "tactical":
            return "brain.head.profile"
        case "match":
            return "sportscourt"
        default:
            return "figure.soccer"
        }
    }
}

#Preview {
    VStack {
        CalendarMiniSummary(sessions: [])
    }
    .padding()
}