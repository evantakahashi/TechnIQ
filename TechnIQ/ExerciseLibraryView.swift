import SwiftUI
import CoreData
import Foundation

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
    @State private var isLoadingYouTubeContent = false
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadYouTubeContent) {
                        HStack {
                            if isLoadingYouTubeContent {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.rectangle")
                            }
                            Text("YouTube")
                                .font(.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                    .disabled(isLoadingYouTubeContent)
                }
            }
            .sheet(isPresented: $showingExerciseDetail) {
                if let exercise = selectedExercise {
                    ExerciseDetailView(exercise: exercise)
                }
            }
        }
    }
    
    private func loadYouTubeContent() {
        isLoadingYouTubeContent = true
        
        Task {
            await CoreDataManager.shared.loadYouTubeDrillsFromAPI(
                category: selectedCategory == "All" ? nil : selectedCategory,
                maxResults: 10
            )
            
            await MainActor.run {
                isLoadingYouTubeContent = false
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
        HStack(spacing: 12) {
            if let description = exercise.exerciseDescription, description.contains("🎥 YouTube Video") {
                if let videoIdRange = description.range(of: "Video ID: "),
                   let endRange = description[videoIdRange.upperBound...].range(of: "\n") ?? description[videoIdRange.upperBound...].range(of: "$") {
                    let videoId = String(description[videoIdRange.upperBound..<endRange.lowerBound])
                    let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/medium.jpg"
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 45)
                            .clipped()
                            .cornerRadius(8)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 60, height: 45)
                    }
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 60, height: 45)
                        .background(DesignSystem.Colors.neutral200)
                        .cornerRadius(8)
                }
            } else {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .frame(width: 60, height: 45)
                    .background(DesignSystem.Colors.neutral200)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.name ?? "Exercise")
                                .font(.headline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            
                            if let description = exercise.exerciseDescription, description.contains("🎥 YouTube Video") {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
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
                    
                    if let skills = exercise.targetSkills, !skills.isEmpty {
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
                    
                    if let skills = exercise.targetSkills, !skills.isEmpty {
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