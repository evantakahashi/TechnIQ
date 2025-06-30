import SwiftUI
import CoreData

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.category, ascending: true),
                         NSSortDescriptor(keyPath: \Exercise.name, ascending: true)],
        animation: .default)
    private var exercises: FetchedResults<Exercise>
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedExercise: Exercise?
    @State private var showingExerciseDetail = false
    
    var categories: [String] {
        let allCategories = Set(exercises.compactMap { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    var filteredExercises: [Exercise] {
        var filtered = Array(exercises)
        
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.name?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.exerciseDescription?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                List(filteredExercises, id: \.objectID) { exercise in
                    ExerciseLibraryRow(exercise: exercise)
                        .onTapGesture {
                            selectedExercise = exercise
                            showingExerciseDetail = true
                        }
                }
                .searchable(text: $searchText, prompt: "Search exercises")
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Exercise Library")
            .sheet(isPresented: $showingExerciseDetail) {
                if let exercise = selectedExercise {
                    ExerciseDetailView(exercise: exercise)
                }
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ExerciseLibraryRow: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name ?? "Exercise")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(exercise.exerciseDescription ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                DifficultyIndicator(level: Int(exercise.difficulty))
            }
            
            HStack {
                CategoryBadge(category: exercise.category ?? "General")
                
                Spacer()
                
                if let skills = exercise.targetSkills as? [String], !skills.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(skills.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(categoryColor.opacity(0.2))
            .foregroundColor(categoryColor)
            .cornerRadius(6)
    }
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case "technical": return .blue
        case "physical": return .red
        case "tactical": return .green
        default: return .gray
        }
    }
}

struct DifficultyIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level ? difficultyColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var difficultyColor: Color {
        switch level {
        case 1: return .green
        case 2: return .orange
        default: return .red
        }
    }
}

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    exerciseHeaderCard
                    
                    if let instructions = exercise.instructions, !instructions.isEmpty {
                        instructionsCard(instructions: instructions)
                    }
                    
                    if let skills = exercise.targetSkills as? [String], !skills.isEmpty {
                        skillsCard(skills: skills)
                    }
                }
                .padding()
            }
            .navigationTitle(exercise.name ?? "Exercise")
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
    
    private var exerciseHeaderCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                CategoryBadge(category: exercise.category ?? "General")
                Spacer()
                DifficultyIndicator(level: Int(exercise.difficulty))
            }
            
            Text(exercise.exerciseDescription ?? "")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func instructionsCard(instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(instructions)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func skillsCard(skills: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Target Skills")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ExerciseLibraryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}