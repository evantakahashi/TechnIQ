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

    // UI state
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var generatedPlan: TrainingPlan?

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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

    // MARK: - Loading View

    private var loadingView: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(DesignSystem.Colors.primaryGreen)

                Text("Generating Your Plan...")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Our AI is creating a personalized training plan based on your profile. This may take 30-60 seconds.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
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

        Task {
            do {
                // Call AI generation service
                let generatedStructure = try await CloudMLService.shared.generateTrainingPlan(
                    for: player,
                    duration: duration,
                    difficulty: difficulty.rawValue,
                    category: category.rawValue,
                    targetRole: category == .position ? targetRole : nil,
                    focusAreas: focusAreas
                )

                // Convert to Core Data
                await MainActor.run {
                    if let plan = TrainingPlanService.shared.createPlanFromAIGeneration(generatedStructure, for: player) {
                        // Override name if user provided one
                        if !planName.trimmingCharacters(in: .whitespaces).isEmpty {
                            plan.name = planName
                            try? viewContext.save()
                        }

                        generatedPlan = plan
                        isGenerating = false
                        showSuccess = true
                    } else {
                        isGenerating = false
                        errorMessage = "Failed to save generated plan. Please try again."
                        showError = true
                    }
                }

            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "AI generation failed: \(error.localizedDescription)\n\nPlease check your internet connection and try again."
                    showError = true
                }
            }
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
