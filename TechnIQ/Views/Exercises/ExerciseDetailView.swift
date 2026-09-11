import SwiftUI
import WebKit
import CoreData

// MARK: - Drill detail (Touchline 7c)
//
// Header: back, eyebrow "AI DRILL · category", heart + share. Condensed title + figures
// (min, lvl, foot). Diagram on a pitch surface (legend, dimensions, Animate). Steps as numbered
// rows with a collapsed "+n" for coaching points. Pinned Start drill + "+PLAN". Notes and
// feedback sit below the fold; the video card only appears for video drills.

struct ExerciseDetailView: View {
    let exercise: Exercise
    var onFavoriteChanged: (() -> Void)? = nil
    var onExerciseDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingWebView = false
    @State private var isFavorite: Bool = false
    @State private var showingEditor = false
    @State private var personalNotes: String = ""
    @State private var isEditingNotes = false
    @State private var showingActiveTraining = false
    @State private var showingExtras = false
    @State private var planNotice: String?

    // Drill feedback state (for AI-generated drills)
    @State private var feedbackRating: Int = 0
    @State private var difficultyFeedback: String = ""
    @State private var feedbackNotes: String = ""
    @State private var hasFeedback: Bool = false
    @State private var showingFeedbackSuccess: Bool = false
    @State private var showingShareSheet = false

    private var isAIGeneratedDrill: Bool {
        exercise.exerciseDescription?.contains("AI-Generated") == true
    }

    private var isVideoDrill: Bool {
        exercise.isYouTubeExercise || extractYouTubeVideoId() != nil
    }

    /// Editable = not YouTube content.
    private var isEditable: Bool {
        !isVideoDrill
    }

    private var content: DrillContent { DrillContent.parse(exercise.instructions) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    navBar
                        .padding(.top, 8)

                    if let planNotice {
                        TQBanner(.info, message: planNotice, actionTitle: "OK") { self.planNotice = nil }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TQDisplayTitle(exercise.name ?? "Drill", size: .medium)
                        TQFigureRow(figures, onPitch: false, valueSize: 18)
                        if let skills = exercise.targetSkills, !skills.isEmpty {
                            TQMeta(skills.joined(separator: " · "), tone: .muted, size: 13, weight: .regular)
                        }
                    }

                    if let diagram = parseDiagram() {
                        TQDiagram(diagram: diagram, steps: content.steps, animationJSON: exercise.animationJSON)
                    } else if let videoId = extractYouTubeVideoId() {
                        videoCard(videoId)
                    }

                    stepsSection

                    if content.steps.isEmpty, let description = exercise.exerciseDescription, !cleanDescription(description).isEmpty {
                        TQBody(cleanDescription(description))
                    }

                    personalNotesSection

                    if isAIGeneratedDrill {
                        drillFeedbackSection
                        progressionSection
                    }

                    DrillSafetyDisclaimer()
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            HStack(spacing: 10) {
                TQButton("Start drill", icon: "play.fill") { showingActiveTraining = true }
                TQLabelSquare(label: "+PLAN") { addToTodaysPlan() }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(DesignSystem.Colors.surfaceBase)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            isFavorite = exercise.isFavorite
            personalNotes = exercise.personalNotes ?? ""
        }
        .sheet(isPresented: $showingEditor) {
            ExerciseEditorView(
                exercise: exercise,
                onSave: {
                    isFavorite = exercise.isFavorite
                    onFavoriteChanged?()
                },
                onDelete: {
                    onExerciseDeleted?()
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingWebView) {
            if let youtubeVideoId = extractYouTubeVideoId() {
                YouTubeWebView(videoId: youtubeVideoId)
            }
        }
        .fullScreenCover(isPresented: $showingActiveTraining) {
            ActiveTrainingView(exercises: [exercise])
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
                .environmentObject(AuthenticationManager.shared)
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

    // MARK: - Nav bar

    private var navBar: some View {
        TQNavBar(eyebrow, tone: .grass) {
            TQBackButton { dismiss() }
        } trailing: {
            HStack(spacing: 2) {
                TQIconAction(
                    isFavorite ? "heart.fill" : "heart",
                    tone: isFavorite ? .grass : .muted,
                    accessibilityLabel: isFavorite ? "Remove from saved" : "Save drill"
                ) {
                    toggleFavorite()
                }
                if isEditable {
                    Menu {
                        Button { showingShareSheet = true } label: { Label("Share to community", systemImage: "square.and.arrow.up") }
                        Button { showingEditor = true } label: { Label("Edit drill", systemImage: "pencil") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.dimIvory)
                            .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .accessibilityLabel("Share or edit")
                } else {
                    TQIconAction("square.and.arrow.up", accessibilityLabel: "Share") { showingShareSheet = true }
                }
            }
        }
    }

    private var eyebrow: String {
        let kind = isAIGeneratedDrill ? "AI drill" : (isVideoDrill ? "Video" : (exercise.isCommunityDrill ? "Community drill" : "Drill"))
        return "\(kind) · \(exercise.category ?? "Technical")"
    }

    private var figures: [(String, String)] {
        var items: [(String, String)] = []
        if exercise.estimatedDurationSeconds > 0 {
            items.append(("\(max(1, Int(exercise.estimatedDurationSeconds) / 60))", "min"))
        } else if exercise.videoDuration > 0 {
            items.append(("\(max(1, Int(exercise.videoDuration) / 60))", "min"))
        }
        if exercise.difficulty > 0 { items.append(("\(exercise.difficulty)", "lvl")) }
        let mentionsWeakFoot = (exercise.targetSkills ?? []).contains { $0.localizedCaseInsensitiveContains("weak foot") }
            || (exercise.weaknessCategories ?? "").localizedCaseInsensitiveContains("weak foot")
        if mentionsWeakFoot {
            switch exercise.player?.dominantFoot?.lowercased() {
            case "right": items.append(("L", "foot"))
            case "left": items.append(("R", "foot"))
            default: break
            }
        }
        return items
    }

    // MARK: - Video

    private func videoCard(_ videoId: String) -> some View {
        Button { showingWebView = true } label: {
            AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")) { image in
                image.resizable().aspectRatio(16 / 9, contentMode: .fill)
            } placeholder: {
                DesignSystem.Colors.surfaceRaised
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .overlay(
                TQIconButton("play.fill", style: .primary, shape: .circle, size: 56, iconSize: 20, accessibilityLabel: "Play video") { showingWebView = true }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pitchCardCompact, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play video tutorial")
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepsSection: some View {
        let steps = content.steps
        let extras = content.extras
        if !steps.isEmpty || !extras.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Steps")
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    TQIndexRow(index: String(format: "%02d", index + 1), text: step)
                }
                if !extras.isEmpty {
                    Button {
                        HapticManager.shared.selectionChanged()
                        withAnimation(DesignSystem.Animation.quick) { showingExtras.toggle() }
                    } label: {
                        TQIndexRow(index: showingExtras ? "–" : "+\(extras.count)",
                                   text: showingExtras ? "Hide coaching points" : extrasSummary,
                                   indexTone: .muted,
                                   textColor: DesignSystem.Colors.dimIvory)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showingExtras ? "Hides coaching points" : "Shows coaching points")
                    if showingExtras {
                        ForEach(Array(extras.enumerated()), id: \.offset) { _, point in
                            TQIndexRow(index: "•", text: point, indexTone: .muted)
                        }
                    }
                }
                TQRule()
            }
        }
    }

    private var extrasSummary: String {
        var parts: [String] = []
        if !content.coachingPoints.isEmpty { parts.append("coaching points") }
        if !content.variations.isEmpty { parts.append("variations") }
        if !content.progressions.isEmpty { parts.append("progressions") }
        if content.safetyNotes != nil { parts.append("safety") }
        if let skills = exercise.targetSkills, !skills.isEmpty, parts.count < 2 { parts.append("target skills") }
        return parts.prefix(2).joined(separator: ", ").capitalizingFirstLetter
    }

    // MARK: - +PLAN

    private func addToTodaysPlan() {
        guard let player = exercise.player,
              let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else {
            planNotice = "Start a plan first to add drills to it."
            return
        }
        let sessions = TrainingPlanService.shared.getTodaysSessions(for: plan)
        guard let session = sessions.first(where: { !$0.isCompleted }) ?? sessions.first else {
            planNotice = "Nothing scheduled today in \(plan.name)."
            return
        }
        if (session.exercises as? Set<Exercise>)?.contains(exercise) == true {
            planNotice = "Already in today's session."
            return
        }
        session.addToExercises(exercise)
        CoreDataManager.shared.save()
        HapticManager.shared.success()
        planNotice = "Added to today's session in \(plan.name)."
    }

    // MARK: - Helpers

    private func extractYouTubeVideoId() -> String? {
        guard let instructions = exercise.instructions else { return nil }
        let patterns = [
            "youtube\\.com/watch\\?v=([a-zA-Z0-9_-]{11})",
            "youtu\\.be/([a-zA-Z0-9_-]{11})",
            "Video ID: ([a-zA-Z0-9_-]{11})"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: instructions.utf16.count)
                if let match = regex.firstMatch(in: instructions, options: [], range: range),
                   let videoIdRange = Range(match.range(at: 1), in: instructions) {
                    return String(instructions[videoIdRange])
                }
            }
        }
        return nil
    }

    private func parseDiagram() -> DrillDiagram? {
        guard let diagramJSON = exercise.diagramJSON,
              let data = diagramJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DrillDiagram.self, from: data)
    }

    private func cleanDescription(_ description: String) -> String {
        let lines = description.components(separatedBy: .newlines)
        var cleanLines: [String] = []
        var skipNextLines = false
        for line in lines {
            if line.contains("YouTube Video") || line.contains("AI-Generated Custom Drill") {
                skipNextLines = true
                continue
            }
            if skipNextLines && (line.contains("Channel:") || line.contains("Video ID:")) { continue }
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
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                feedbackRating = star
                            }
                            .accessibilityLabel("Rate \(star) star\(star == 1 ? "" : "s")")
                            .accessibilityAddTraits(star <= feedbackRating ? [.isButton, .isSelected] : .isButton)
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
        guard context.coordinator.loadedVideoId != videoId else { return }
        context.coordinator.loadedVideoId = videoId

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
        var loadedVideoId: String?

        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("WebView failed to load: \(error.localizedDescription)")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("WebView failed provisional navigation: \(error.localizedDescription)")
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

private extension String {
    var capitalizingFirstLetter: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
