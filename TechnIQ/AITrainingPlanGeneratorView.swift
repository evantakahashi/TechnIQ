import SwiftUI
import CoreData

struct AITrainingPlanGeneratorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    let player: Player

    // Form inputs
    @State private var planName: String = ""
    @State private var duration: Int = 6
    @State private var difficulty: PlanDifficulty = .intermediate
    @State private var category: PlanCategory = .technical
    @State private var targetRole: String = ""
    @State private var focusAreas: [String] = []
    @State private var newFocusArea: String = ""

    // Schedule preferences (Phase 2)
    @State private var preferredDays: Set<DayOfWeek> = []
    @State private var restDays: Set<DayOfWeek> = []
    @State private var showScheduleConflict = false

    // UI state
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var generatedPlan: TrainingPlan?

    // Preview state (Phase 1 enhancement)
    @State private var generatedStructure: GeneratedPlanStructure?
    @State private var showPreview = false
    @State private var regenerationCount = 0

    // Loading phases for better UX
    @State private var loadingPhase: LoadingPhase = .connecting

    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    headerCard

                    // Basic Info
                    basicInfoCard

                    // Focus Areas
                    focusAreasCard

                    // Schedule Preferences (Phase 2)
                    schedulePreferencesCard

                    // Generate Button
                    if !isGenerating {
                        ModernButton("Generate Training Plan", icon: "sparkles", style: .primary) {
                            generatePlan()
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                    } else {
                        loadingView
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
        .navigationTitle("AI Plan Generator")
        .navigationBarTitleDisplayMode(.large)
        .alert("Generation Failed", isPresented: $showError) {
            Button("Retry") {
                generatePlan()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPreview) {
            if let structure = generatedStructure {
                AITrainingPlanPreviewView(
                    generatedPlan: structure,
                    player: player,
                    customName: planName,
                    onRegenerate: {
                        regenerationCount += 1
                        generatePlan()
                    },
                    onModifyParameters: {
                        // Return to form - preview is dismissed, user can modify
                    },
                    onSave: {
                        savePlanFromStructure(structure)
                    }
                )
            }
        }
        .sheet(isPresented: $showSuccess) {
            if let plan = generatedPlan {
                successView(plan: plan)
            }
        }
        .onAppear {
            prefillFromPlayerProfile()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI-Powered Plan")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Personalized to your profile")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }

                Divider()

                Text("Our AI will analyze your profile and create a customized training plan with weekly schedules, daily sessions, and specific exercises tailored to your goals.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Basic Info Card

    private var basicInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Plan Details")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Plan Name (Optional)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Plan Name (Optional)")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Leave empty for AI-generated name", text: $planName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Duration
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text("Duration")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Text("\(duration) weeks")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }

                    Slider(value: Binding(
                        get: { Double(duration) },
                        set: { duration = Int($0) }
                    ), in: 2...12, step: 1)
                    .tint(DesignSystem.Colors.primaryGreen)
                }

                // Difficulty
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Difficulty Level")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(PlanDifficulty.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Category
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Focus Category")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Picker("Category", selection: $category) {
                        ForEach(PlanCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Target Role (Optional)
                if category == .position {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Target Position")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextField("e.g., Striker, Midfielder", text: $targetRole)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
        }
    }

    // MARK: - Focus Areas Card

    private var focusAreasCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Specific Focus Areas")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Add skills or areas you want to improve (e.g., Passing, Speed, Finishing)")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Add new focus area
                HStack {
                    TextField("Add focus area", text: $newFocusArea)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: addFocusArea) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                    .disabled(newFocusArea.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Focus area chips
                if !focusAreas.isEmpty {
                    FlowLayout(spacing: DesignSystem.Spacing.xs) {
                        ForEach(focusAreas, id: \.self) { area in
                            FocusAreaChip(text: area) {
                                removeFocusArea(area)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Schedule Preferences Card (Phase 2)

    private var schedulePreferencesCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    Text("Schedule Preferences")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    // Optional toggle
                    Text("Optional")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.textSecondary.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                }

                Text("Customize when you prefer to train. Leave empty to let AI optimize your schedule.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Preferred Training Days
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Preferred Training Days")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    DaySelector(
                        selectedDays: $preferredDays,
                        disabledDays: restDays,
                        accentColor: DesignSystem.Colors.primaryGreen
                    )
                }

                // Rest Days
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Required Rest Days")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    DaySelector(
                        selectedDays: $restDays,
                        disabledDays: preferredDays,
                        accentColor: DesignSystem.Colors.accentYellow
                    )
                }

                // Conflict warning
                if hasScheduleConflict {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.Colors.warning)

                        Text("A day cannot be both a training day and rest day")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.warning)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.warning.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                // Summary
                if !preferredDays.isEmpty || !restDays.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        if !preferredDays.isEmpty {
                            Text("Training: \(preferredDays.sorted(by: { $0.sortOrder < $1.sortOrder }).map { $0.shortName }.joined(separator: ", "))")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                        if !restDays.isEmpty {
                            Text("Rest: \(restDays.sorted(by: { $0.sortOrder < $1.sortOrder }).map { $0.shortName }.joined(separator: ", "))")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.accentYellow)
                        }
                    }
                }
            }
        }
    }

    private var hasScheduleConflict: Bool {
        !preferredDays.isDisjoint(with: restDays)
    }

    // MARK: - Loading View (Enhanced with phases)

    private var loadingView: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Animated soccer ball icon
                ZStack {
                    Circle()
                        .stroke(DesignSystem.Colors.primaryGreen.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(DesignSystem.Colors.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(loadingRotation))

                    Image(systemName: "soccerball")
                        .font(.title)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(loadingPhase.title)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .animation(.easeInOut, value: loadingPhase)

                    Text(loadingPhase.description)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: loadingPhase)
                }

                // Progress indicator
                ProgressView(value: loadingPhase.progress, total: 1.0)
                    .tint(DesignSystem.Colors.primaryGreen)
                    .animation(.easeInOut, value: loadingPhase)

                if regenerationCount > 0 {
                    Text("Regeneration attempt \(regenerationCount + 1)")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)
                }

                // Cancel button
                Button(action: cancelGeneration) {
                    Text("Cancel")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .onAppear {
            startLoadingAnimation()
            startPhaseProgression()
        }
    }

    @State private var loadingRotation: Double = 0

    private func startLoadingAnimation() {
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            loadingRotation = 360
        }
    }

    private func startPhaseProgression() {
        // Simulate phase progression
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if isGenerating { loadingPhase = .analyzing }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if isGenerating { loadingPhase = .generating }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if isGenerating { loadingPhase = .structuring }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            if isGenerating { loadingPhase = .finalizing }
        }
    }

    private func cancelGeneration() {
        isGenerating = false
        loadingPhase = .connecting
    }

    // MARK: - Success View

    private func successView(plan: TrainingPlan) -> some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(DesignSystem.Colors.success)

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Plan Created!")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text(plan.name ?? "Training Plan")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)

                        Text("\(plan.durationWeeks) weeks • \(plan.difficulty ?? "Intermediate")")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    ModernCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Your AI-generated plan is ready!")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text("You can view it in the Training Plans tab and activate it to start tracking your progress.")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    Spacer()

                    ModernButton("Done", icon: "checkmark", style: .primary) {
                        showSuccess = false
                        dismiss()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        // At minimum need duration and difficulty
        return duration >= 2 && duration <= 12
    }

    private func prefillFromPlayerProfile() {
        // Pre-fill target role from player position
        if let position = player.position {
            targetRole = position.capitalized
        }

        // Pre-fill focus areas from player goals
        if let goals = player.playerGoals?.allObjects as? [PlayerGoal] {
            focusAreas = goals.compactMap { $0.skillName }
        }

        // Set difficulty based on experience level
        if let experience = player.experienceLevel {
            switch experience.lowercased() {
            case "beginner":
                difficulty = .beginner
            case "intermediate":
                difficulty = .intermediate
            case "advanced", "expert":
                difficulty = .advanced
            default:
                difficulty = .intermediate
            }
        }
    }

    private func addFocusArea() {
        let trimmed = newFocusArea.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !focusAreas.contains(trimmed) else { return }

        focusAreas.append(trimmed)
        newFocusArea = ""
    }

    private func removeFocusArea(_ area: String) {
        focusAreas.removeAll { $0 == area }
    }

    private func generatePlan() {
        isGenerating = true
        loadingPhase = .connecting

        Task {
            do {
                // Convert schedule preferences to string arrays
                let preferredDayStrings = preferredDays.sorted().map { $0.rawValue }
                let restDayStrings = restDays.sorted().map { $0.rawValue }

                // Call AI generation service
                let structure = try await CloudMLService.shared.generateTrainingPlan(
                    for: player,
                    duration: duration,
                    difficulty: difficulty.rawValue,
                    category: category.rawValue,
                    targetRole: category == .position ? targetRole : nil,
                    focusAreas: focusAreas,
                    preferredDays: preferredDayStrings,
                    restDays: restDayStrings
                )

                // Show preview instead of auto-saving
                await MainActor.run {
                    generatedStructure = structure
                    isGenerating = false
                    loadingPhase = .connecting
                    showPreview = true
                }

            } catch {
                await MainActor.run {
                    isGenerating = false
                    loadingPhase = .connecting
                    errorMessage = "AI generation failed: \(error.localizedDescription)\n\nPlease check your internet connection and try again."
                    showError = true
                }
            }
        }
    }

    private func savePlanFromStructure(_ structure: GeneratedPlanStructure) {
        if let plan = TrainingPlanService.shared.createPlanFromAIGeneration(structure, for: player) {
            // Override name if user provided one
            if !planName.trimmingCharacters(in: .whitespaces).isEmpty {
                plan.name = planName
                try? viewContext.save()
            }

            generatedPlan = plan
            showPreview = false
            showSuccess = true
        } else {
            showPreview = false
            errorMessage = "Failed to save generated plan. Please try again."
            showError = true
        }
    }
}

// MARK: - Loading Phase Enum

enum LoadingPhase: Equatable {
    case connecting
    case analyzing
    case generating
    case structuring
    case finalizing

    var title: String {
        switch self {
        case .connecting: return "Connecting..."
        case .analyzing: return "Analyzing Your Profile..."
        case .generating: return "Generating Plan..."
        case .structuring: return "Structuring Weeks..."
        case .finalizing: return "Finalizing Details..."
        }
    }

    var description: String {
        switch self {
        case .connecting: return "Establishing connection to AI service"
        case .analyzing: return "Reviewing your skills, goals, and preferences"
        case .generating: return "Creating personalized training sessions"
        case .structuring: return "Organizing weekly schedules and rest days"
        case .finalizing: return "Adding exercises and final touches"
        }
    }

    var progress: Double {
        switch self {
        case .connecting: return 0.1
        case .analyzing: return 0.3
        case .generating: return 0.5
        case .structuring: return 0.7
        case .finalizing: return 0.9
        }
    }
}

// MARK: - Focus Area Chip

struct FocusAreaChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

// MARK: - Flow Layout (for chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Day Selector (Phase 2)

struct DaySelector: View {
    @Binding var selectedDays: Set<DayOfWeek>
    let disabledDays: Set<DayOfWeek>
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                DayButton(
                    day: day,
                    isSelected: selectedDays.contains(day),
                    isDisabled: disabledDays.contains(day),
                    accentColor: accentColor
                ) {
                    toggleDay(day)
                }
            }
        }
    }

    private func toggleDay(_ day: DayOfWeek) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}

struct DayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let isDisabled: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(day.shortName.prefix(1)))
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(foregroundColor)
                .frame(width: 36, height: 36)
                .background(backgroundColor)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else if isDisabled {
            return DesignSystem.Colors.textSecondary
        } else {
            return DesignSystem.Colors.textPrimary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return accentColor
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isDisabled {
            return DesignSystem.Colors.textSecondary.opacity(0.3)
        } else {
            return DesignSystem.Colors.textSecondary.opacity(0.3)
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"
    samplePlayer.position = "midfielder"
    samplePlayer.experienceLevel = "intermediate"

    return NavigationView {
        AITrainingPlanGeneratorView(player: samplePlayer)
            .environment(\.managedObjectContext, context)
            .environmentObject(AuthenticationManager.shared)
    }
}
