import SwiftUI
import CoreData

enum SessionViewMode: String, CaseIterable {
    case list = "list"
    case calendar = "calendar"
    
    var displayName: String {
        switch self {
        case .list:
            return "List"
        case .calendar:
            return "Calendar"
        }
    }
    
    var icon: String {
        switch self {
        case .list:
            return "list.bullet"
        case .calendar:
            return "calendar"
        }
    }
}

struct SessionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var sessions: FetchedResults<TrainingSession>
    
    @State private var selectedSession: TrainingSession?
    @State private var showingSessionDetail = false
    @State private var viewMode: SessionViewMode = .list
    
    init() {
        // Initialize with empty predicate - will be updated in onAppear
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: false), // Temporary predicate
            animation: .default
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // View Mode Picker
                    viewModePickerSection
                    
                    // Content based on view mode
                    if viewMode == .list {
                        listView
                    } else {
                        calendarView
                    }
                }
            }
            .navigationTitle("Training History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleViewMode) {
                        Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
            }
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
            .onAppear {
                updateSessionsFilter()
            }
            .onChange(of: authManager.userUID) {
                updateSessionsFilter()
            }
        }
    }
    
    // MARK: - View Mode Picker
    
    private var viewModePickerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Picker("View Mode", selection: $viewMode) {
                ForEach(SessionViewMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            // Session summary for current month/week
            if !sessions.isEmpty {
                sessionSummaryView
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Training Sessions",
                    systemImage: "calendar.badge.plus",
                    description: Text("Start your first training session to see it here")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(sessions, id: \.objectID) { session in
                    SessionHistoryRow(session: session)
                        .onTapGesture {
                            selectedSession = session
                            showingSessionDetail = true
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteSessions)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
    
    // MARK: - Session Summary View
    
    private var sessionSummaryView: some View {
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
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("📅 Calendar View")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Calendar view coming soon!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            // For now, show sessions in a simple grid
            if !sessions.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                    ForEach(sessions.prefix(9), id: \.objectID) { session in
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text(session.sessionType ?? "Training")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                            
                            Text(formatDate(session.date ?? Date()))
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                        .onTapGesture {
                            selectedSession = session
                            showingSessionDetail = true
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Computed Properties
    
    private var totalDurationText: String {
        let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
        return "\(Int(totalMinutes))"
    }
    
    private var averageIntensity: Double {
        guard !sessions.isEmpty else { return 0 }
        let totalIntensity = sessions.reduce(0) { $0 + $1.intensity }
        return Double(totalIntensity) / Double(sessions.count)
    }
    
    // MARK: - Helper Methods
    
    private func toggleViewMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewMode = viewMode == .list ? .calendar : .list
        }
    }
    
    private func updateSessionsFilter() {
        guard !authManager.userUID.isEmpty else { return }
        
        // Filter sessions by player's Firebase UID
        sessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
        print("🔍 Updated SessionHistoryView filter for user: \(authManager.userUID)")
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting sessions: \(error)")
            }
        }
    }
}

struct SessionHistoryRow: View {
    let session: TrainingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionType ?? "Training")
                        .font(.headline)
                    
                    Text(formatDate(session.date ?? Date()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(session.duration)) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < session.overallRating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            if let location = session.location {
                Label(location, systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                IntensityIndicator(level: Int(session.intensity))
                
                Spacer()
                
                if let exercises = session.exercises, exercises.count > 0 {
                    Text("\(exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            return "Today"
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct IntensityIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Text("Intensity:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= level ? intensityColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var intensityColor: Color {
        switch level {
        case 1...2: return .green
        case 3: return .yellow
        case 4: return .orange
        default: return .red
        }
    }
}

#Preview {
    SessionHistoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}