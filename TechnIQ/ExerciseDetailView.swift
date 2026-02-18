import SwiftUI
import WebKit

struct ExerciseDetailView: View {
    let exercise: Exercise
    var onFavoriteChanged: (() -> Void)? = nil
    var onExerciseDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingWebView = false
    @State private var isFavorite: Bool = false
    @State private var showingEditor = false
    @State private var personalNotes: String = ""
    @State private var isEditingNotes = false
    @State private var showingActiveTraining = false

    // Drill feedback state (for AI-generated drills)
    @State private var feedbackRating: Int = 0
    @State private var difficultyFeedback: String = ""
    @State private var feedbackNotes: String = ""
    @State private var hasFeedback: Bool = false
    @State private var showingFeedbackSuccess: Bool = false
    @State private var showingShareSheet = false

    // Check if this is an AI-generated drill
    private var isAIGeneratedDrill: Bool {
        exercise.exerciseDescription?.contains("🤖 AI-Generated") == true
    }

    // Check if exercise is editable (not YouTube content)
    private var isEditable: Bool {
        exercise.exerciseDescription?.contains("YouTube Video") != true
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Exercise Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name ?? "Unknown Exercise")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryDark)
                        
                        HStack {
                            CategoryBadge(category: exercise.category ?? "General")
                            DifficultyStars(difficulty: Int(exercise.difficulty))
                        }
                    }

                    // Start Drill Button
                    Button {
                        showingActiveTraining = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Drill")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.button)
                    }

                    // Share to Community (AI drills only)
                    if isAIGeneratedDrill {
                        Button {
                            showingShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share to Community")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
                            .cornerRadius(DesignSystem.CornerRadius.button)
                        }
                    }

                    // YouTube Video Section
                    if let youtubeVideoId = extractYouTubeVideoId() {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Video Tutorial")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryDark)
                            
                            // YouTube Thumbnail with Play Button
                            Button(action: {
                                showingWebView = true
                            }) {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(youtubeVideoId)/hqdefault.jpg")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .cornerRadius(12)
                                        .overlay(
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 60, height: 60)
                                                .overlay(
                                                    Image(systemName: "play.fill")
                                                        .foregroundColor(.white)
                                                        .font(.title2)
                                                )
                                        )
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .cornerRadius(12)
                                        .overlay(
                                            VStack {
                                                ProgressView()
                                                Text("Loading video...")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // YouTube Link
                            Link("Open in YouTube", destination: URL(string: "https://youtube.com/watch?v=\(youtubeVideoId)")!)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    
                    // Description Section
                    if let description = exercise.exerciseDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryDark)
                            
                            Text(cleanDescription(description))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Drill Diagram Section (for AI-generated drills)
                    if let diagram = parseDiagram() {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "map")
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                                Text("Field Layout")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryDark)
                            }

                            DrillDiagramView(diagram: diagram)
                                .frame(height: 220)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }

                    // Instructions Section
                    if let instructions = exercise.instructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryDark)

                            // Use rich markdown display for AI-generated drills and structured manual drills
                            if exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true ||
                               instructions.contains("**Setup:**") || instructions.contains("**Instructions:**") {
                                DrillInstructionsView(instructions: instructions)
                            } else {
                                Text(instructions)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Target Skills Section
                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Skills")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryDark)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100))
                            ], spacing: 8) {
                                ForEach(skills, id: \.self) { skill in
                                    Text(skill)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(DesignSystem.Colors.primaryGreen.opacity(0.2))
                                        )
                                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                                }
                            }
                        }
                    }

                    // Personal Notes Section
                    personalNotesSection

                    // Drill Feedback Section (AI-generated drills only)
                    if isAIGeneratedDrill {
                        drillFeedbackSection
                        progressionSection
                    }
                }
                .padding()
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : DesignSystem.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Edit button (only for editable exercises)
                        if isEditable {
                            Button {
                                showingEditor = true
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }
                        }

                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                isFavorite = exercise.isFavorite
                personalNotes = exercise.personalNotes ?? ""
            }
            .sheet(isPresented: $showingEditor) {
                ExerciseEditorView(
                    exercise: exercise,
                    onSave: {
                        // Refresh the detail view after save
                        isFavorite = exercise.isFavorite
                        onFavoriteChanged?()
                    },
                    onDelete: {
                        onExerciseDeleted?()
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let youtubeVideoId = extractYouTubeVideoId() {
                YouTubeWebView(videoId: youtubeVideoId)
            }
        }
        .fullScreenCover(isPresented: $showingActiveTraining) {
            ActiveTrainingView(exercises: [exercise])
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
                .environmentObject(SubscriptionManager.shared)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let player = exercise.player {
                ShareToCommunitySheet(
                    shareType: .drill(exercise),
                    player: player,
                    onDismiss: { showingShareSheet = false }
                )
            }
        }
    }
    
    private func extractYouTubeVideoId() -> String? {
        guard let instructions = exercise.instructions else { return nil }
        
        // Look for YouTube URL patterns in instructions
        let patterns = [
            "youtube\\.com/watch\\?v=([a-zA-Z0-9_-]{11})",
            "youtu\\.be/([a-zA-Z0-9_-]{11})",
            "Video ID: ([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: instructions.utf16.count)
                if let match = regex.firstMatch(in: instructions, options: [], range: range) {
                    if let videoIdRange = Range(match.range(at: 1), in: instructions) {
                        return String(instructions[videoIdRange])
                    }
                }
            }
        }
        
        return nil
    }

    private func parseDiagram() -> DrillDiagram? {
        guard let diagramJSON = exercise.diagramJSON,
              let data = diagramJSON.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(DrillDiagram.self, from: data)
    }

    private func cleanDescription(_ description: String) -> String {
        // Remove YouTube-specific metadata from description
        let lines = description.components(separatedBy: .newlines)
        var cleanLines: [String] = []

        var skipNextLines = false
        for line in lines {
            if line.contains("🎥 YouTube Video") {
                skipNextLines = true
                continue
            }
            if skipNextLines && (line.contains("Channel:") || line.contains("Video ID:")) {
                continue
            }
            skipNextLines = false
            cleanLines.append(line)
        }

        return cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleFavorite() {
        CoreDataManager.shared.toggleFavorite(exercise: exercise)
        isFavorite = exercise.isFavorite
        onFavoriteChanged?()
    }

    // MARK: - Personal Notes Section

    private var personalNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Notes")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryDark)

                Spacer()

                if !isEditingNotes && !personalNotes.isEmpty {
                    Button {
                        isEditingNotes = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
            }

            if isEditingNotes {
                // Editable text area
                VStack(spacing: 8) {
                    TextEditor(text: $personalNotes)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignSystem.Colors.primaryGreen.opacity(0.5), lineWidth: 1)
                        )

                    HStack {
                        Button("Cancel") {
                            personalNotes = exercise.personalNotes ?? ""
                            isEditingNotes = false
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Button("Save") {
                            savePersonalNotes()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
            } else if personalNotes.isEmpty {
                // Empty state - tap to add
                Button {
                    isEditingNotes = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add personal notes...")
                    }
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryGreen.opacity(0.7))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.primaryGreen.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DesignSystem.Colors.primaryGreen.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Display notes
                Text(personalNotes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .onTapGesture {
                        isEditingNotes = true
                    }
            }
        }
    }

    private func savePersonalNotes() {
        exercise.personalNotes = personalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        CoreDataManager.shared.save()
        isEditingNotes = false
        onFavoriteChanged?() // Refresh parent view
    }

    // MARK: - Drill Feedback Section

    @ViewBuilder
    private var drillFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.thumbsup")
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                Text("Was this drill helpful?")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryDark)
            }

            if hasFeedback {
                // Show existing feedback
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= feedbackRating ? "star.fill" : "star")
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                            .font(.title3)
                    }
                    Text("- Thanks for your feedback!")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                // Star rating
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= feedbackRating ? "star.fill" : "star")
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                            .font(.title2)
                            .onTapGesture {
                                feedbackRating = star
                            }
                    }
                }

                // Difficulty feedback chips
                HStack(spacing: 8) {
                    FeedbackChip(label: "Too Easy", selected: difficultyFeedback == "easy") {
                        difficultyFeedback = difficultyFeedback == "easy" ? "" : "easy"
                    }
                    FeedbackChip(label: "Just Right", selected: difficultyFeedback == "right") {
                        difficultyFeedback = difficultyFeedback == "right" ? "" : "right"
                    }
                    FeedbackChip(label: "Too Hard", selected: difficultyFeedback == "hard") {
                        difficultyFeedback = difficultyFeedback == "hard" ? "" : "hard"
                    }
                }

                // Optional notes
                TextField("Any comments? (optional)", text: $feedbackNotes)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.subheadline)

                // Submit button
                if feedbackRating > 0 {
                    Button(action: saveDrillFeedback) {
                        Text("Submit Feedback")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(DesignSystem.Colors.primaryGreen)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .alert("Feedback Saved", isPresented: $showingFeedbackSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Thank you! Your feedback helps improve future drill recommendations.")
        }
    }

    private func saveDrillFeedback() {
        // Need to get player - for now use a simple approach
        let players = try? CoreDataManager.shared.context.fetch(Player.fetchRequest())
        guard let player = players?.first else { return }

        CoreDataManager.shared.saveDrillFeedback(
            for: exercise,
            player: player,
            rating: feedbackRating,
            difficultyFeedback: difficultyFeedback,
            notes: feedbackNotes
        )

        hasFeedback = true
        showingFeedbackSuccess = true
    }

    // MARK: - Progression Section

    @ViewBuilder
    private var progressionSection: some View {
        let completionCount = CoreDataManager.shared.getCompletionCount(for: exercise)
        let avgRating = CoreDataManager.shared.getAveragePerformanceRating(for: exercise)

        if completionCount >= 3 && avgRating >= 4.0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("Ready for a Challenge?")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryDark)
                }

                Text("You've mastered this drill! Completed \(completionCount) times with \(String(format: "%.1f", avgRating))/5 avg rating.")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Go to Exercises → AI Drill Generator to create a harder version.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.secondaryBlue.opacity(0.1))
            )
        }
    }
}

// MARK: - Feedback Chip

struct FeedbackChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(selected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selected ? DesignSystem.Colors.primaryGreen : Color.gray.opacity(0.2))
                )
                .foregroundColor(selected ? .white : DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct YouTubeWebView: UIViewRepresentable {
    let videoId: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load YouTube embed URL
        let embedURL = "https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1"
        if let url = URL(string: embedURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YouTubeWebView
        
        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ WebView failed to load: \(error.localizedDescription)")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ WebView failed provisional navigation: \(error.localizedDescription)")
            #endif
        }
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.2))
            )
            .foregroundColor(DesignSystem.Colors.primaryGreen)
    }
}

struct DifficultyStars: View {
    let difficulty: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= difficulty ? "star.fill" : "star")
                    .foregroundColor(star <= difficulty ? .orange : .gray)
                    .font(.caption)
            }
        }
    }
}

struct ExerciseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.context
        let exercise = Exercise(context: context)
        exercise.name = "Sample Exercise"
        exercise.category = "Technical"
        exercise.difficulty = 3
        exercise.exerciseDescription = "This is a sample exercise description."
        exercise.instructions = "1. Watch the YouTube video at: https://youtube.com/watch?v=dQw4w9WgXcQ\n2. Practice the technique shown"
        
        return ExerciseDetailView(exercise: exercise)
    }
}