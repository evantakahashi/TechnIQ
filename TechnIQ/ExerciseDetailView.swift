import SwiftUI
import WebKit

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var showingWebView = false
    
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
                    
                    // Instructions Section
                    if let instructions = exercise.instructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryDark)

                            // Use rich markdown display for AI-generated drills
                            if exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true {
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
                }
                .padding()
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let youtubeVideoId = extractYouTubeVideoId() {
                YouTubeWebView(videoId: youtubeVideoId)
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
            print("❌ WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed provisional navigation: \(error.localizedDescription)")
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