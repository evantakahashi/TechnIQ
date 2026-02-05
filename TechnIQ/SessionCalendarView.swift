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

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let sessions: [TrainingSession]
    let onTap: () -> Void
    
    @State private var isPressed = false
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: {
            // Add haptic feedback for premium feel
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Day number with enhanced typography
                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? DesignSystem.Typography.titleMedium : DesignSystem.Typography.bodyMedium)
                    .fontWeight(isToday ? .bold : .semibold)
                    .foregroundColor(textColor)
                
                // Enhanced session indicators
                premiumSessionIndicators
            }
            .frame(width: 52, height: 64) // Larger touch targets
            .background(premiumBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(premiumOverlay)
            .customShadow(shadowStyle)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isPressed)
            .animation(DesignSystem.Animation.quick, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    @ViewBuilder
    private var premiumSessionIndicators: some View {
        VStack(spacing: 2) {
            if sessions.isEmpty {
                // Empty state with subtle indicator
                Circle()
                    .fill(DesignSystem.Colors.neutral300)
                    .frame(width: 6, height: 6)
                    .opacity(0.3)
            } else if sessions.count == 1, let first = sessions.first {
                // Single session with icon
                sessionTypeIcon(for: first)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(colorForSession(first))
                    .cornerRadius(8)
            } else {
                // Multiple sessions - show count with heat intensity
                Text("\(sessions.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(sessionIntensityGradient)
                    )
                    .customShadow(DesignSystem.Shadow.small)
            }
        }
    }
    
    private var sessionIntensityGradient: LinearGradient {
        let avgIntensity = sessions.reduce(0.0) { $0 + Double($1.intensity) } / Double(sessions.count)
        
        switch avgIntensity {
        case 0..<2:
            return LinearGradient(colors: [DesignSystem.Colors.success, DesignSystem.Colors.primaryGreenLight], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2..<3:
            return LinearGradient(colors: [DesignSystem.Colors.accentYellow, DesignSystem.Colors.warning], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3..<4:
            return LinearGradient(colors: [DesignSystem.Colors.warning, DesignSystem.Colors.accentOrange], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [DesignSystem.Colors.error, Color.red], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func sessionTypeIcon(for session: TrainingSession) -> Image {
        // Determine icon based on session type or default to soccer ball
        if let sessionType = session.sessionType?.lowercased() {
            switch sessionType {
            case "technical", "skill", "ball work":
                return Image(systemName: "soccerball")
            case "physical", "fitness", "conditioning":
                return Image(systemName: "figure.run")
            case "tactical", "strategy", "formation":
                return Image(systemName: "brain.head.profile")
            default:
                return Image(systemName: "soccerball")
            }
        }
        return Image(systemName: "soccerball")
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
    
    @ViewBuilder
    private var premiumBackground: some View {
        Group {
            if isSelected {
                // Selected state with premium gradient
                DesignSystem.Colors.primaryGradient
            } else if isToday {
                // Today with subtle gradient
                LinearGradient(
                    colors: [DesignSystem.Colors.primaryGreen.opacity(0.15), DesignSystem.Colors.primaryGreenLight.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if !sessions.isEmpty {
                // Has sessions - subtle background with glassmorphism
                DesignSystem.Colors.neutral100
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                // Empty day
                DesignSystem.Colors.backgroundSecondary
            }
        }
    }
    
    @ViewBuilder
    private var premiumOverlay: some View {
        Group {
            if isSelected {
                // Bright selection border
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2.5)
                    .opacity(0.8)
            } else if isToday {
                // Today border with subtle glow
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 1.5)
                    .opacity(0.6)
            } else if !sessions.isEmpty {
                // Sessions border
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1)
                    .opacity(0.5)
            }
        }
    }
    
    private var shadowStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        if isSelected {
            return (DesignSystem.Colors.primaryGreen.opacity(0.3), 8, 0, 4)
        } else if isToday || !sessions.isEmpty {
            return DesignSystem.Shadow.small
        } else {
            return (Color.clear, 0, 0, 0)
        }
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

// MARK: - Weekly Day View Component

struct WeeklyDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let sessions: [TrainingSession]
    
    @State private var isPressed = false
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("\(calendar.component(.day, from: date))")
                .font(isToday ? DesignSystem.Typography.titleMedium : DesignSystem.Typography.titleSmall)
                .fontWeight(isToday ? .bold : .semibold)
                .foregroundColor(textColor)
            
            // Enhanced session indicator for weekly view
            weeklySessionIndicator
        }
        .frame(width: 48, height: 72) // Larger for weekly view
        .background(premiumBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .overlay(premiumOverlay)
        .customShadow(shadowStyle)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.spring, value: isPressed)
    }
    
    @ViewBuilder
    private var weeklySessionIndicator: some View {
        if sessions.isEmpty {
            Circle()
                .fill(DesignSystem.Colors.neutral300)
                .frame(width: 8, height: 8)
                .opacity(0.4)
        } else if sessions.count == 1, let first = sessions.first {
            // Single session with larger icon for weekly view
            sessionTypeIcon(for: first)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(colorForSession(first))
                .cornerRadius(10)
                .customShadow(DesignSystem.Shadow.small)
        } else {
            // Multiple sessions with enhanced styling
            VStack(spacing: 2) {
                Text("\(sessions.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(sessionIntensityGradient)
                    )
                    .customShadow(DesignSystem.Shadow.small)
                
                // Progress bar showing total duration
                sessionDurationBar
            }
        }
    }
    
    @ViewBuilder
    private var sessionDurationBar: some View {
        let totalMinutes = sessions.reduce(0) { $0 + Int($1.duration) }
        let barWidth: CGFloat = min(CGFloat(totalMinutes) / 120.0 * 32, 32) // Max 120min = full width
        
        Capsule()
            .fill(sessionIntensityGradient)
            .frame(width: barWidth, height: 3)
            .opacity(0.8)
    }
    
    private var textColor: Color {
        if isToday {
            return isSelected ? .white : DesignSystem.Colors.primaryGreen
        } else {
            return isSelected ? .white : DesignSystem.Colors.textPrimary
        }
    }
    
    @ViewBuilder
    private var premiumBackground: some View {
        Group {
            if isSelected {
                DesignSystem.Colors.primaryGradient
            } else if isToday {
                LinearGradient(
                    colors: [DesignSystem.Colors.primaryGreen.opacity(0.2), DesignSystem.Colors.primaryGreenLight.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if !sessions.isEmpty {
                DesignSystem.Colors.neutral100
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                DesignSystem.Colors.backgroundSecondary
            }
        }
    }
    
    @ViewBuilder
    private var premiumOverlay: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 3)
                    .opacity(0.8)
            } else if isToday {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
                    .opacity(0.7)
            } else if !sessions.isEmpty {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1.5)
                    .opacity(0.6)
            }
        }
    }
    
    private var shadowStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        if isSelected {
            return (DesignSystem.Colors.primaryGreen.opacity(0.4), 10, 0, 5)
        } else if isToday || !sessions.isEmpty {
            return DesignSystem.Shadow.medium
        } else {
            return (Color.clear, 0, 0, 0)
        }
    }
    
    private var sessionIntensityGradient: LinearGradient {
        let avgIntensity = sessions.reduce(0.0) { $0 + Double($1.intensity) } / Double(sessions.count)
        
        switch avgIntensity {
        case 0..<2:
            return LinearGradient(colors: [DesignSystem.Colors.success, DesignSystem.Colors.primaryGreenLight], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2..<3:
            return LinearGradient(colors: [DesignSystem.Colors.accentYellow, DesignSystem.Colors.warning], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3..<4:
            return LinearGradient(colors: [DesignSystem.Colors.warning, DesignSystem.Colors.accentOrange], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [DesignSystem.Colors.error, Color.red], 
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func sessionTypeIcon(for session: TrainingSession) -> Image {
        if let sessionType = session.sessionType?.lowercased() {
            switch sessionType {
            case "technical", "skill", "ball work":
                return Image(systemName: "soccerball")
            case "physical", "fitness", "conditioning":
                return Image(systemName: "figure.run")
            case "tactical", "strategy", "formation":
                return Image(systemName: "brain.head.profile")
            default:
                return Image(systemName: "soccerball")
            }
        }
        return Image(systemName: "soccerball")
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

// MARK: - Enhanced Session Calendar Card

struct SessionCalendarCard: View {
    let session: TrainingSession
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with session type and intensity
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Session type with icon
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            sessionTypeIcon
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(sessionColor)
                            
                            Text(session.sessionType ?? "Training")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        
                        // Session date/time
                        if let date = session.date {
                            Text(timeString(from: date))
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Intensity indicator with premium styling
                    intensityBadge
                }
                
                // Metrics row
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Duration with progress bar
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(sessionColor)
                            
                            Text("\(Int(session.duration)) min")
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        
                        // Duration progress bar (relative to 2 hours max)
                        let progress = min(session.duration / 120.0, 1.0)
                        
                        Capsule()
                            .fill(sessionColor.opacity(0.3))
                            .frame(height: 3)
                            .overlay(
                                HStack {
                                    Capsule()
                                        .fill(sessionColor)
                                        .frame(width: 40 * progress)
                                    
                                    Spacer()
                                }
                            )
                            .frame(width: 40)
                    }
                    
                    Spacer()
                    
                    // Exercise count
                    if let exercises = session.exercises, exercises.count > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(exercises.count)")
                                    .font(DesignSystem.Typography.labelMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            Text("exercises")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(width: 180, height: 100)
            .background(premiumCardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .overlay(premiumCardOverlay)
            .customShadow(cardShadow)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var sessionTypeIcon: Image {
        if let sessionType = session.sessionType?.lowercased() {
            switch sessionType {
            case "technical", "skill", "ball work":
                return Image(systemName: "soccerball")
            case "physical", "fitness", "conditioning":
                return Image(systemName: "figure.run")
            case "tactical", "strategy", "formation":
                return Image(systemName: "brain.head.profile")
            default:
                return Image(systemName: "soccerball")
            }
        }
        return Image(systemName: "soccerball")
    }
    
    private var sessionColor: Color {
        switch session.intensity {
        case 1...2: return DesignSystem.Colors.success
        case 3: return DesignSystem.Colors.accentYellow
        case 4: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }
    
    @ViewBuilder
    private var intensityBadge: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= Int(session.intensity) ? sessionColor : DesignSystem.Colors.neutral300)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.backgroundSecondary)
                .overlay(
                    Capsule()
                        .stroke(sessionColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var premiumCardBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
            .fill(DesignSystem.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
    
    @ViewBuilder
    private var premiumCardOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
            .stroke(
                LinearGradient(
                    colors: [sessionColor.opacity(0.3), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
    
    private var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        return (sessionColor.opacity(0.15), 6, 0, 3)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SessionCalendarView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}