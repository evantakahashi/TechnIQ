import SwiftUI

struct CustomDrillGeneratorView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @StateObject private var drillService = CustomDrillService.shared
    
    @State private var request = CustomDrillRequest.empty
    @State private var showingSuccessMessage = false
    @State private var showingWarnings = false
    @State private var validationWarnings: [String] = []
    @State private var generatedExercise: Exercise?
    
    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
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
            if !validationWarnings.isEmpty {
                Button("View Warnings") {
                    showingWarnings = true
                }
            }
            Button("OK") {
                dismiss()
            }
        } message: {
            if validationWarnings.isEmpty {
                Text("Your custom drill has been added to your exercise library!")
            } else {
                Text("Your drill was created with minor quality notes. Tap 'View Warnings' for details.")
            }
        }
        .alert("Quality Notes", isPresented: $showingWarnings) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(validationWarnings.joined(separator: "\n\n"))
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
                numberOfPlayersSection
                fieldSizeSection
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
    
    // MARK: - Number of Players Section

    private var numberOfPlayersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Number of Players: \(request.numberOfPlayers)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Slider(value: Binding(
                        get: { Double(request.numberOfPlayers) },
                        set: { request.numberOfPlayers = Int($0) }
                    ), in: 1...6, step: 1)
                    .accentColor(DesignSystem.Colors.primaryGreen)

                    HStack {
                        Text("1")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("6")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Field Size Section

    private var fieldSizeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Field Size")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(FieldSize.allCases, id: \.self) { size in
                    Button {
                        request.fieldSize = size
                    } label: {
                        ModernCard(padding: DesignSystem.Spacing.sm) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: size.icon)
                                    .font(.title3)
                                    .foregroundColor(request.fieldSize == size ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.primaryGreen)

                                Text(size.displayName)
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(request.fieldSize == size ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .background(
                            request.fieldSize == size ? DesignSystem.Colors.primaryGreen : Color.clear
                        )
                        .cornerRadius(DesignSystem.CornerRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .stroke(
                                    request.fieldSize == size ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                                    lineWidth: request.fieldSize == size ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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

                // Check for validation warnings from the generation state
                if case .success(let response) = drillService.generationState {
                    validationWarnings = response.validationWarnings ?? []
                }

                showingSuccessMessage = true

            } catch {
                #if DEBUG
                print("Failed to generate drill: \(error)")
                #endif
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

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"
    
    return CustomDrillGeneratorView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}