import SwiftUI
import CoreData
import Foundation

enum CalendarViewMode: String, CaseIterable {
    case monthly = "Monthly"
    case weekly = "Weekly"
}

struct SessionCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var sessions: FetchedResults<TrainingSession>
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var currentWeek = Date()
    @State private var viewMode: CalendarViewMode = .monthly
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
            // View Mode Toggle
            viewModeToggle
            
            // Calendar Header
            calendarHeader
            
            // Calendar Content
            if viewMode == .monthly {
                calendarGrid
            } else {
                weeklyCalendarView
            }
            
            // Selected Date Sessions (if any)
            if !sessionsForSelectedDate.isEmpty {
                selectedDateSessionsView
            }
        }
        .onAppear {
            updateSessionsFilter()
            updateSessionsForSelectedDate()
            currentWeek = selectedDate
        }
        .onChange(of: authManager.userUID) {
            updateSessionsFilter()
        }
        .onChange(of: selectedDate) {
            updateSessionsForSelectedDate()
        }
        .onChange(of: viewMode) {
            // Update current week when switching to weekly view
            if viewMode == .weekly {
                currentWeek = selectedDate
            }
        }
        .sheet(isPresented: $showingSessionDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session)
            }
        }
    }
    
    // MARK: - Premium View Mode Toggle
    
    private var viewModeToggle: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Premium segmented control with sliding animation
            HStack {
                Spacer()
                
                ZStack {
                    // Background with glassmorphism
                    Capsule()
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .frame(width: 188, height: 44) // 2 * 90 + 2 * 4 padding
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .customShadow(DesignSystem.Shadow.small)
                    
                    // Sliding background indicator
                    HStack(spacing: 0) {
                        if viewMode == .weekly { 
                            Color.clear.frame(width: 90, height: 36)
                        }
                        
                        Capsule()
                            .fill(DesignSystem.Colors.primaryGradient)
                            .frame(width: 90, height: 36)
                            .customShadow((DesignSystem.Colors.primaryGreen.opacity(0.3), 4, 0, 2))
                            .animation(DesignSystem.Animation.spring, value: viewMode)
                        
                        if viewMode == .monthly { 
                            Color.clear.frame(width: 90, height: 36)
                        }
                    }
                    .padding(4)
                    
                    // Toggle buttons
                    HStack(spacing: 0) {
                        ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                withAnimation(DesignSystem.Animation.spring) {
                                    viewMode = mode
                                }
                            }) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    // Add icons to make it more intuitive
                                    Image(systemName: mode == .monthly ? "calendar" : "calendar.day.timeline.leading")
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text(mode.rawValue)
                                        .font(DesignSystem.Typography.labelMedium)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(
                                    viewMode == mode 
                                        ? .white 
                                        : DesignSystem.Colors.textSecondary
                                )
                                .frame(width: 90, height: 36)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(4)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        HStack {
            Button(action: viewMode == .monthly ? previousMonth : previousWeek) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            
            Spacer()
            
            Text(headerTitle)
                .font(DesignSystem.Typography.titleLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .animation(DesignSystem.Animation.quick, value: viewMode)
            
            Spacer()
            
            Button(action: viewMode == .monthly ? nextMonth : nextWeek) {
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
    
    // MARK: - Weekly Calendar View
    
    private var weeklyCalendarView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Week days header
            HStack {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(dayOfWeekString(for: date))
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Button(action: {
                            selectedDate = date
                        }) {
                            WeeklyDayView(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDate(date, inSameDayAs: Date()),
                                sessions: sessionsForDate(date)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            // Sessions for the week (condensed view)
            if !weekSessions.isEmpty {
                weekSessionsOverview
            }
        }
    }
    
    // MARK: - Week Sessions Overview
    
    private var weekSessionsOverview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            Text("This Week's Sessions")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(weekSessions, id: \.objectID) { session in
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
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var headerTitle: String {
        if viewMode == .monthly {
            return monthYearString
        } else {
            return weekRangeString
        }
    }
    
    private var weekRangeString: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return ""
        }
        
        let formatter = DateFormatter()
        let startDate = weekInterval.start
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        
        // Check if week spans multiple months
        if calendar.component(.month, from: startDate) == calendar.component(.month, from: endDate) {
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startDate)
            formatter.dateFormat = "d, yyyy"
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        } else {
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startDate)
            let endString = formatter.string(from: endDate)
            return "\(startString) - \(endString)"
        }
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

        // Find the first day to show (might be from previous month)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth

        // Always generate exactly 42 days (6 weeks) to prevent height shifts
        var dates: [Date] = []
        var currentDate = startOfWeek

        for _ in 0..<42 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return dates
    }
    
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = weekInterval.start
        let endDate = weekInterval.end
        
        while currentDate < endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private var weekSessions: [TrainingSession] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return []
        }
        
        return sessions.filter { session in
            guard let sessionDate = session.date else { return false }
            return weekInterval.contains(sessionDate)
        }
    }
    
    private func dayOfWeekString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }
}

#Preview {
    SessionCalendarView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}