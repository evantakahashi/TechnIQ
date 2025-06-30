import SwiftUI
import CoreData

struct SessionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<TrainingSession>
    
    @State private var selectedSession: TrainingSession?
    @State private var showingSessionDetail = false
    
    var body: some View {
        NavigationView {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Training Sessions",
                        systemImage: "calendar.badge.plus",
                        description: Text("Start your first training session to see it here")
                    )
                } else {
                    ForEach(sessions, id: \.objectID) { session in
                        SessionHistoryRow(session: session)
                            .onTapGesture {
                                selectedSession = session
                                showingSessionDetail = true
                            }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("Training History")
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
        }
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