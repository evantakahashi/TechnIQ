import SwiftUI
import CoreData

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrainingSession
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionHeaderCard
                    
                    if let exercises = session.exercises?.allObjects as? [SessionExercise], !exercises.isEmpty {
                        exercisesCard(exercises: exercises.sorted { 
                            ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "") 
                        })
                    }
                    
                    if let notes = session.notes, !notes.isEmpty {
                        notesCard(notes: notes)
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var sessionHeaderCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.sessionType ?? "Training")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formatDate(session.date ?? Date()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(Int(session.duration)) min")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < session.overallRating ? "star.fill" : "star")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            HStack(spacing: 20) {
                if let location = session.location {
                    Label(location, systemImage: "location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Label("Intensity \(session.intensity)/5", systemImage: "flame")
                    .font(.subheadline)
                    .foregroundColor(intensityColor(Int(session.intensity)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func exercisesCard(exercises: [SessionExercise]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Exercises (\(exercises.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(exercises, id: \.objectID) { sessionExercise in
                    ExerciseDetailRow(sessionExercise: sessionExercise)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 1...2: return .green
        case 3: return .yellow
        case 4: return .orange
        default: return .red
        }
    }
}

struct ExerciseDetailRow: View {
    let sessionExercise: SessionExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionExercise.exercise?.name ?? "Exercise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(sessionExercise.exercise?.category ?? "General")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(sessionExercise.duration)) min")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < sessionExercise.performanceRating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            HStack(spacing: 15) {
                if sessionExercise.sets > 0 {
                    Label("\(sessionExercise.sets) sets", systemImage: "repeat")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if sessionExercise.reps > 0 {
                    Label("\(sessionExercise.reps) reps", systemImage: "number")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if let notes = sessionExercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let sampleSession = TrainingSession(context: context)
    sampleSession.sessionType = "Technical Training"
    sampleSession.date = Date()
    sampleSession.duration = 45
    sampleSession.intensity = 3
    sampleSession.overallRating = 4
    sampleSession.location = "Local Park"
    sampleSession.notes = "Great session today, worked on ball control and passing accuracy."
    
    return SessionDetailView(session: sampleSession)
}