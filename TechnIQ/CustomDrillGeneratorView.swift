import SwiftUI

struct CustomDrillGeneratorView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @StateObject private var drillService = CustomDrillService.shared
    
    @State private var request = CustomDrillRequest.empty
    @State private var showingSuccessMessage = false
    @State private var generatedExercise: Exercise?
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                if drillService.isGenerating {
                    generatingOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("Create Custom Drill")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        generateDrill()
                    }
                    .disabled(!request.isValid)
                    .foregroundColor(request.isValid ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Drill Created!", isPresented: $showingSuccessMessage) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your custom drill has been added to your exercise library!")
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                headerSection
                skillDescriptionSection
                categorySection
                difficultySection
                equipmentSection
                durationSection
                focusAreaSection
                generateButton
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("AI-Powered Drill Generator")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Describe what you want to work on, and our AI will create a personalized drill for you.")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Skill Description Section
    
    private var skillDescriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("What do you want to work on?")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("e.g., improve first touch under pressure, better crossing accuracy...", text: $request.skillDescription, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                    
                    HStack {
                        Spacer()
                        Text("\(request.skillDescription.count)/500")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(request.skillDescription.isValidSkillDescription ? 
                                           DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
            
            if !request.skillDescription.isEmpty && !request.skillDescription.isValidSkillDescription {
                Text("Please provide at least 10 characters describing what you want to work on")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Category")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                ForEach(DrillCategory.allCases, id: \.self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: request.category == category
                    ) {
                        request.category = category
                    }
                }
            }
        }
    }
    
    // MARK: - Difficulty Section
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Difficulty Level")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                    DifficultySelectionCard(
                        difficulty: difficulty,
                        isSelected: request.difficulty == difficulty
                    ) {
                        request.difficulty = difficulty
                    }
                }
            }
        }
    }
    
    // MARK: - Equipment Section
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Available Equipment")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    EquipmentSelectionCard(
                        equipment: equipment,
                        isSelected: request.equipment.contains(equipment)
                    ) {
                        if request.equipment.contains(equipment) {
                            request.equipment.remove(equipment)
                        } else {
                            request.equipment.insert(equipment)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Duration Section
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Duration: \(request.duration) minutes")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ModernCard {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Slider(value: Binding(
                        get: { Double(request.duration) },
                        set: { request.duration = Int($0) }
                    ), in: 10...120, step: 5)
                    .accentColor(DesignSystem.Colors.primaryGreen)
                    
                    HStack {
                        Text("10 min")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("120 min")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }
    
    // MARK: - Focus Area Section
    
    private var focusAreaSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Training Setup")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(FocusArea.allCases, id: \.self) { focusArea in
                    FocusAreaSelectionCard(
                        focusArea: focusArea,
                        isSelected: request.focusArea == focusArea
                    ) {
                        request.focusArea = focusArea
                    }
                }
            }
        }
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        ModernButton(
            "Generate Custom Drill",
            icon: "brain.head.profile",
            style: .primary
        ) {
            generateDrill()
        }
        .disabled(!request.isValid)
        .opacity(request.isValid ? 1.0 : 0.6)
    }
    
    // MARK: - Generating Overlay
    
    private var generatingOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView(value: drillService.generationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .scaleEffect(1.2)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Generating Your Custom Drill")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(drillService.generationMessage)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(Int(drillService.generationProgress * 100))%")
                        .font(DesignSystem.Typography.numberMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: Date())
                
                Text("AI is analyzing your requirements and creating a personalized drill...")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
    
    // MARK: - Actions
    
    private func generateDrill() {
        Task {
            do {
                let exercise = try await drillService.generateCustomDrill(
                    request: request, 
                    for: player
                )
                
                generatedExercise = exercise
                showingSuccessMessage = true
                
            } catch {
                // Handle error - could show an error alert
                print("Failed to generate drill: \(error)")
            }
        }
    }
}

// MARK: - Selection Cards

struct CategorySelectionCard: View {
    let category: DrillCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(category.displayName)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DifficultySelectionCard: View {
    let difficulty: DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                Text(difficulty.displayName)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EquipmentSelectionCard: View {
    let equipment: Equipment
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.xs) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: equipment.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.primaryGreen)
                    
                    Text(equipment.displayName.components(separatedBy: " ").dropFirst().joined(separator: " "))
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FocusAreaSelectionCard: View {
    let focusArea: FocusArea
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                HStack {
                    Text(focusArea.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primaryDark)
                    }
                }
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"
    
    return CustomDrillGeneratorView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}