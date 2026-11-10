import SwiftUI
import WebKit
import CoreData
import AVKit

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
    @State private var showingHarderDrill = false
    @State private var showingHarderPaywall = false

    private var isAIGeneratedDrill: Bool {
        exercise.drillSource == .ai
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

                    if let clip = exercise.prebuiltDrill?.videoURL {
                        DrillClipCard(url: clip)
                    }

                    DrillKitSection(equipment: exercise.equipmentList, space: exercise.space)

                    stepsSection

                    levelUpSection

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
            loadExistingFeedback()
        }
        .sheet(isPresented: $showingHarderPaywall) { PaywallView(feature: .customDrill) }
        .sheet(isPresented: $showingHarderDrill, onDismiss: { onFavoriteChanged?() }) {
            if let player = exercise.player {
                CustomDrillGeneratorView(player: player, prefill: .init(text: harderDrillPrompt, difficulty: harderDifficulty))
            }
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
                if !FeatureFlags.community {
                    // No community: nothing to share to, so only the editor remains.
                    if isEditable {
                        TQIconAction("pencil", accessibilityLabel: "Edit drill") { showingEditor = true }
                    }
                } else if isEditable {
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
        let kind: String
        switch exercise.drillSource {
        case .ai: kind = "AI drill"
        case .video: kind = "Video"
        case .community: kind = "Community drill"
        case .manual: kind = "Your drill"
        case .template: kind = "Drill"
        }
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

    // MARK: - Level up (unlock criteria)

    private var levelUpSection: some View {
        let criteria = exercise.unlockCriteria
        let progress = exercise.unlockProgress
        return VStack(alignment: .leading, spacing: 10) {
            TQGroupHeader("Level up")
            TQBody(criteria.summary)
            TQProgressBar(progress: progress.fraction)
            if progress.isUnlocked {
                TQEyebrow("Mastered", tone: .grass)
            } else {
                TQMeta(progress.countLabel, tone: .muted, size: 13)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level up: \(criteria.summary). \(progress.isUnlocked ? "Mastered" : progress.countLabel)")
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
        if session.isAssessment {
            planNotice = "Today is the retest in \(plan.name); it has no drills."
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                TQGroupHeader("My notes")
                Spacer()
                if isEditingNotes {
                    TQTextLink("Save", arrow: false) { savePersonalNotes() }
                } else {
                    TQTextLink(personalNotes.isEmpty ? "Add" : "Edit", arrow: false) { isEditingNotes = true }
                }
            }
            if isEditingNotes {
                TextEditor(text: $personalNotes)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .tint(DesignSystem.Colors.grass)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField, style: .continuous).fill(DesignSystem.Colors.surfaceRaised))
            } else if personalNotes.isEmpty {
                TQBody("What worked, what to fix next time.", tone: .muted, size: 13)
            } else {
                TQBody(personalNotes)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditingNotes = true }
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
    //
    // Stars + one difficulty call, saved as soon as either changes (the same row is updated).

    private static let difficultyCalls = [("easy", "Too easy"), ("right", "Just right"), ("hard", "Too hard")]

    private var drillFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQGroupHeader("Rate this drill")
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        feedbackRating = star
                        HapticManager.shared.selectionChanged()
                        saveDrillFeedback()
                    } label: {
                        Image(systemName: star <= feedbackRating ? "star.fill" : "star")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(star <= feedbackRating ? DesignSystem.Colors.grass : DesignSystem.Colors.textTertiary)
                            .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate \(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star <= feedbackRating ? [.isSelected] : [])
                }
            }
            TQSegment(
                options: Self.difficultyCalls.map(\.1),
                selection: Binding(
                    get: { Self.difficultyCalls.firstIndex { $0.0 == difficultyFeedback } },
                    set: { index in
                        difficultyFeedback = index.map { Self.difficultyCalls[$0].0 } ?? ""
                        if feedbackRating > 0 { saveDrillFeedback() }
                    }
                ),
                style: .detached
            )
        }
    }

    private func loadExistingFeedback() {
        guard let player = exercise.player,
              let existing = CoreDataManager.shared.fetchFeedback(for: exercise, player: player) else { return }
        feedbackRating = Int(existing.rating)
        difficultyFeedback = CoreDataManager.difficultyFeedbackLabel(for: existing.difficultyRating)
        feedbackNotes = existing.notes ?? ""
        hasFeedback = true
    }

    private func saveDrillFeedback() {
        guard let player = exercise.player else { return }

        CoreDataManager.shared.saveDrillFeedback(
            for: exercise,
            player: player,
            rating: feedbackRating,
            difficultyFeedback: difficultyFeedback,
            notes: feedbackNotes
        )

        hasFeedback = true
    }

    // MARK: - Progression Section

    @ViewBuilder
    private var progressionSection: some View {
        let completionCount = CoreDataManager.shared.getCompletionCount(for: exercise)
        let avgRating = CoreDataManager.shared.getAveragePerformanceRating(for: exercise)

        if completionCount >= 3 && avgRating >= 4.0 {
            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Ready for more")
                TQBody("Done \(completionCount) times and it feels comfortable. Time to raise it.")
                TQButton("Make it harder", style: .raised, size: .compact) {
                    if SubscriptionManager.shared.canGenerateDrill() {
                        showingHarderDrill = true
                    } else {
                        showingHarderPaywall = true
                    }
                }
                .accessibilityIdentifier("drill.makeHarder")
            }
        }
    }
}

// MARK: - Harder version

private extension ExerciseDetailView {
    /// Seeds the generator so the coach builds a progression of this drill rather than a new idea.
    var harderDrillPrompt: String {
        let skills = (exercise.targetSkills ?? []).prefix(3).joined(separator: ", ")
        let focus = skills.isEmpty ? "" : " Skills: \(skills)."
        return "A harder version of \"\(exercise.name ?? "this drill")\": same setup, faster tempo, tighter space, a defender or a time limit.\(focus)"
    }

    var harderDifficulty: DifficultyLevel {
        switch exercise.difficulty {
        case ..<2: return .intermediate
        default: return .advanced
        }
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

// MARK: - Kit (equipment + space)

/// "You need": the drill's equipment and space, on drill detail and the session drill sheet.
/// Renders nothing when the drill has neither.
struct DrillKitSection: View {
    let equipment: [String]
    let space: String?

    private var spaceText: String? {
        guard let trimmed = space?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    var body: some View {
        if !equipment.isEmpty || spaceText != nil {
            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("You need")
                ForEach(Array(equipment.enumerated()), id: \.offset) { _, item in
                    TQIndexRow(index: "•", text: item, indexTone: .muted)
                }
                if let spaceText {
                    TQIndexRow(index: "•", text: "Space: \(spaceText)", indexTone: .muted)
                }
                TQRule()
            }
        }
    }
}

// MARK: - Demo clip

/// A bundled demo clip of the drill (pre-built drills, once filmed). Tap to play.
struct DrillClipCard: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pitchCardCompact, style: .continuous))
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onDisappear { player?.pause() }
            .accessibilityLabel("Demo video of the drill")
    }
}
