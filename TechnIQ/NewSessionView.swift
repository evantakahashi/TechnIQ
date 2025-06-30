import SwiftUI
import CoreData

struct NewSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager
    
    let player: Player
    
    @State private var sessionType = "Training"
    @State private var location = ""
    @State private var intensity = 3
    @State private var sessionNotes = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var exerciseDetails: [UUID: ExerciseDetail] = [:]
    @State private var showingExercisePicker = false
    @State private var overallRating = 3
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)],
        animation: .default)
    private var availableExercises: FetchedResults<Exercise>
    
    let sessionTypes = ["Training", "Match", "Fitness", "Technical", "Tactical"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Session Details") {
                    Picker("Type", selection: $sessionType) {
                        ForEach(sessionTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    TextField("Location (optional)", text: $location)
                    
                    VStack(alignment: .leading) {
                        Text("Intensity: \(intensity)/5")
                        Slider(value: Binding(
                            get: { Double(intensity) },
                            set: { intensity = Int($0) }
                        ), in: 1...5, step: 1)
                    }
                }
                
                Section("Exercises") {
                    if selectedExercises.isEmpty {
                        Button("Add Exercises") {
                            showingExercisePicker = true
                        }
                        .foregroundColor(.blue)
                    } else {
                        ForEach(selectedExercises, id: \.objectID) { exercise in
                            ExerciseRowView(
                                exercise: exercise,
                                detail: Binding(
                                    get: { exerciseDetails[exercise.id!] ?? ExerciseDetail() },
                                    set: { exerciseDetails[exercise.id!] = $0 }
                                ),
                                onRemove: {
                                    removeExercise(exercise)
                                }
                            )
                        }
                        
                        Button("Add More Exercises") {
                            showingExercisePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Session Rating") {
                    VStack(alignment: .leading) {
                        Text("Overall Rating")
                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    overallRating = rating
                                } label: {
                                    Image(systemName: rating <= overallRating ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.title2)
                                }
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Session notes (optional)", text: $sessionNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(selectedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    availableExercises: Array(availableExercises)
                )
            }
        }
    }
    
    private func removeExercise(_ exercise: Exercise) {
        selectedExercises.removeAll { $0.objectID == exercise.objectID }
        exerciseDetails.removeValue(forKey: exercise.id!)
    }
    
    private func saveSession() {
        let newSession = TrainingSession(context: viewContext)
        newSession.id = UUID()
        newSession.player = player
        newSession.date = Date()
        newSession.sessionType = sessionType
        newSession.location = location.isEmpty ? nil : location
        newSession.intensity = Int16(intensity)
        newSession.notes = sessionNotes.isEmpty ? nil : sessionNotes
        newSession.overallRating = Int16(overallRating)
        
        var totalDuration: Double = 0
        
        for exercise in selectedExercises {
            let sessionExercise = SessionExercise(context: viewContext)
            sessionExercise.id = UUID()
            sessionExercise.session = newSession
            sessionExercise.exercise = exercise
            
            if let detail = exerciseDetails[exercise.id!] {
                sessionExercise.duration = detail.duration
                sessionExercise.sets = Int16(detail.sets)
                sessionExercise.reps = Int16(detail.reps)
                sessionExercise.performanceRating = Int16(detail.rating)
                sessionExercise.notes = detail.notes.isEmpty ? nil : detail.notes
                
                totalDuration += detail.duration
            }
        }
        
        newSession.duration = totalDuration
        
        coreDataManager.save()
        dismiss()
    }
}

struct ExerciseDetail {
    var duration: Double = 10.0
    var sets: Int = 1
    var reps: Int = 10
    var rating: Int = 3
    var notes: String = ""
}

struct ExerciseRowView: View {
    let exercise: Exercise
    @Binding var detail: ExerciseDetail
    let onRemove: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name ?? "Exercise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(exercise.category ?? "General")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Remove") {
                    onRemove()
                }
                .font(.caption)
                .foregroundColor(.red)
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text("\(Int(detail.duration)) min")
                    }
                    Slider(value: $detail.duration, in: 5...60, step: 5)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Sets: \(detail.sets)")
                            Slider(value: Binding(
                                get: { Double(detail.sets) },
                                set: { detail.sets = Int($0) }
                            ), in: 1...10, step: 1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Reps: \(detail.reps)")
                            Slider(value: Binding(
                                get: { Double(detail.reps) },
                                set: { detail.reps = Int($0) }
                            ), in: 1...50, step: 1)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Performance Rating")
                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    detail.rating = rating
                                } label: {
                                    Image(systemName: rating <= detail.rating ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    
                    TextField("Exercise notes", text: $detail.notes)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.leading)
            }
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExercises: [Exercise]
    let availableExercises: [Exercise]
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    var categories: [String] {
        let allCategories = Set(availableExercises.compactMap { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    var filteredExercises: [Exercise] {
        var exercises = availableExercises
        
        if selectedCategory != "All" {
            exercises = exercises.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            exercises = exercises.filter { 
                $0.name?.localizedCaseInsensitiveContains(searchText) == true 
            }
        }
        
        return exercises
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List(filteredExercises, id: \.objectID) { exercise in
                    ExercisePickerRow(
                        exercise: exercise,
                        isSelected: selectedExercises.contains { $0.objectID == exercise.objectID }
                    ) {
                        if selectedExercises.contains(where: { $0.objectID == exercise.objectID }) {
                            selectedExercises.removeAll { $0.objectID == exercise.objectID }
                        } else {
                            selectedExercises.append(exercise)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises")
            }
            .navigationTitle("Choose Exercises")
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
}

struct ExercisePickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name ?? "Exercise")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(exercise.exerciseDescription ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(exercise.category ?? "General")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("Level \(exercise.difficulty)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"
    
    return NewSessionView(player: samplePlayer)
        .environment(\.managedObjectContext, context)
        .environmentObject(CoreDataManager.shared)
}