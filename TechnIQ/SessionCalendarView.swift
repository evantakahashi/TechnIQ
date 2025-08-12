import SwiftUI
import CoreData
import Foundation

struct SessionCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var sessions: FetchedResults<TrainingSession>
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var sessionsForSelectedDate: [TrainingSession] = []
    @State private var showingDayDetail = false
    @State private var selectedSession: TrainingSession?
    @State private var showingSessionDetail = false
    
    // Callback for session selection - will be used by parent view
    var onSessionSelected: ((TrainingSession) -> Void)?
    
    private let calendar = Calendar.current
    
    init(onSessionSelected: ((TrainingSession) -> Void)? = nil) {
        self.onSessionSelected = onSessionSelected
        
        // Initialize with empty predicate - will be updated in onAppear
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar Header
            calendarHeader
            
            // Calendar Grid
            calendarGrid
            
            // Selected Date Sessions (if any)
            if !sessionsForSelectedDate.isEmpty {
                selectedDateSessionsView
            }
        }
        .onAppear {
            updateSessionsFilter()
            updateSessionsForSelectedDate()
        }
        .onChange(of: authManager.userUID) {
            updateSessionsFilter()
        }
        .onChange(of: selectedDate) {
            updateSessionsForSelectedDate()
        }
        .sheet(isPresented: $showingSessionDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session)
            }
        }
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(DesignSystem.Typography.titleLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Days of week header
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.uppercased())
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: DesignSystem.Spacing.xs) {
                ForEach(calendarDates, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDate(date, inSameDayAs: Date()),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        sessions: sessionsForDate(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
    
    // MARK: - Selected Date Sessions View
    
    private var selectedDateSessionsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            Text(selectedDateString)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(sessionsForSelectedDate, id: \.objectID) { session in
                        SessionCalendarCard(session: session) {
                            selectedSession = session
                            if let callback = onSessionSelected {
                                callback(session)
                            } else {
                                showingSessionDetail = true
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    // MARK: - Helper Methods
    
    private func updateSessionsFilter() {
        guard !authManager.userUID.isEmpty else { return }
        sessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }
    
    private func updateSessionsForSelectedDate() {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        sessionsForSelectedDate = sessions.filter { session in
            guard let sessionDate = session.date else { return false }
            return sessionDate >= startOfDay && sessionDate < endOfDay
        }
    }
    
    private func sessionsForDate(_ date: Date) -> [TrainingSession] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return sessions.filter { session in
            guard let sessionDate = session.date else { return false }
            return sessionDate >= startOfDay && sessionDate < endOfDay
        }
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
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
    
    private var calendarDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let startOfMonth = monthInterval.start
        let endOfMonth = monthInterval.end
        
        // Find the first day to show (might be from previous month)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        // Find the last day to show (might be from next month)
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -1, to: endOfMonth) ?? endOfMonth)?.end ?? endOfMonth
        
        var dates: [Date] = []
        var currentDate = startOfWeek
        
        while currentDate < endOfWeek {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let sessions: [TrainingSession]
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)
                
                // Session indicators
                sessionIndicators
            }
            .frame(width: 40, height: 50)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var sessionIndicators: some View {
        HStack(spacing: 2) {
            ForEach(Array(sessions.prefix(3).enumerated()), id: \.offset) { index, session in
                Circle()
                    .fill(colorForSession(session))
                    .frame(width: 4, height: 4)
            }
            
            if sessions.count > 3 {
                Text("+")
                    .font(.system(size: 8))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(height: 6)
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return DesignSystem.Colors.textTertiary
        } else if isToday {
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
        } else if !sessions.isEmpty {
            return DesignSystem.Colors.neutral200
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        return isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
    }
    
    private func colorForSession(_ session: TrainingSession) -> Color {
        switch session.intensity {
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

// MARK: - Session Calendar Card

struct SessionCalendarCard: View {
    let session: TrainingSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(session.sessionType ?? "Training")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        IntensityIndicator(level: Int(session.intensity))
                    }
                    
                    HStack {
                        Label("\(Int(session.duration)) min", systemImage: "clock")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        if let exercises = session.exercises, exercises.count > 0 {
                            Text("\(exercises.count) exercises")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 160)
    }
}

#Preview {
    SessionCalendarView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}