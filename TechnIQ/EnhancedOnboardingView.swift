import SwiftUI
import CoreData

struct EnhancedOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool
    
    @State private var currentStep = 0
    @State private var playerName = ""
    @State private var playerAge = 16
    @State private var selectedPosition = "Midfielder"
    @State private var selectedPlayingStyle = "Balanced"
    @State private var selectedDominantFoot = "Right"
    @State private var selectedExperienceLevel = "Beginner"
    @State private var yearsPlaying: Int = 2
    
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    let experienceLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]
    
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                } else {
                    Spacer()
                        .frame(width: 24)
                }
                
                Spacer()
                
                Text("Profile Setup")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Skip") {
                    createPlayer()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Progress Indicator
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentStep ? DesignSystem.Colors.primaryGreen : Color(.systemGray4))
                            .frame(height: 3)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            
            Spacer()
            
            // Step Content
            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    basicInfoStep
                case 2:
                    positionStyleStep
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            
            Spacer()
            
            // Continue Button
            Button(action: {
                withAnimation {
                    if currentStep < totalSteps - 1 {
                        currentStep += 1
                    } else {
                        createPlayer()
                    }
                }
            }) {
                Text(currentStep == totalSteps - 1 ? "CREATE PROFILE" : "CONTINUE")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? DesignSystem.Colors.primaryGreen : Color.gray)
                    .cornerRadius(28)
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(Color(.systemBackground))
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 1:
            return !playerName.isEmpty
        default:
            return true
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 24) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                
                VStack(spacing: 8) {
                    Text("AI-Powered Training")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Get personalized recommendations based on your goals and playing style")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            VStack(spacing: 24) {
                FeatureRow(
                    icon: "target",
                    title: "Smart Goals",
                    description: "Set specific skill goals and track progress"
                )
                
                FeatureRow(
                    icon: "person.3.fill",
                    title: "Player Matching",
                    description: "Learn from players with similar profiles"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "ML Recommendations",
                    description: "AI-powered exercise suggestions just for you"
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var basicInfoStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Basic Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Tell us about yourself")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 24) {
                // Player Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your name", text: $playerName)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Age Slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Age")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(playerAge)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(playerAge) },
                        set: { playerAge = Int($0) }
                    ), in: 10...75, step: 1)
                    .tint(DesignSystem.Colors.primaryGreen)
                }
                
                // Experience Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Experience Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(experienceLevels, id: \.self) { level in
                            Button(level) {
                                selectedExperienceLevel = level
                            }
                            .foregroundColor(selectedExperienceLevel == level ? .white : .primary)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedExperienceLevel == level ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Years Playing
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Years Playing")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(yearsPlaying) years")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(yearsPlaying) },
                        set: { yearsPlaying = Int($0) }
                    ), in: 0...20, step: 1)
                    .tint(DesignSystem.Colors.primaryGreen)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var positionStyleStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Playing Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Tell us about your position and style")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 24) {
                // Position Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary Position")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(positions, id: \.self) { position in
                            Button(position) {
                                selectedPosition = position
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPosition)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Playing Style Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playing Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(playingStyles, id: \.self) { style in
                            Button(style) {
                                selectedPlayingStyle = style
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPlayingStyle)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Dominant Foot Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dominant Foot")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(dominantFeet, id: \.self) { foot in
                            Button(foot) {
                                selectedDominantFoot = foot
                            }
                            .foregroundColor(selectedDominantFoot == foot ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedDominantFoot == foot ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Functions
    
    private func createPlayer() {
        print("🏗️ Starting player creation...")
        
        let userUID = authManager.userUID
        if userUID.isEmpty {
            print("❌ No Firebase UID available - cannot create player")
            return
        }
        
        print("📝 Creating player for UID: \(userUID)")
        let displayName = playerName.isEmpty ? authManager.userDisplayName : playerName
        let finalName = displayName.isEmpty ? "Player" : displayName
        print("👤 Player name: \(finalName)")
        
        let newPlayer = Player(context: viewContext)
        newPlayer.id = UUID()
        newPlayer.firebaseUID = userUID
        newPlayer.name = finalName
        newPlayer.age = Int16(playerAge)
        newPlayer.position = selectedPosition
        newPlayer.playingStyle = selectedPlayingStyle
        newPlayer.dominantFoot = selectedDominantFoot
        newPlayer.experienceLevel = selectedExperienceLevel
        newPlayer.createdAt = Date()
        
        print("✅ Player object created with ID: \(newPlayer.id?.uuidString ?? "nil")")
        
        coreDataManager.createDefaultExercises(for: newPlayer)
        print("✅ Created default exercises")
        
        do {
            coreDataManager.save()
            print("✅ Successfully saved player profile to Core Data")
            
            // Verify the save worked
            let request = Player.fetchRequest()
            request.predicate = NSPredicate(format: "firebaseUID == %@", userUID)
            let savedPlayers = try viewContext.fetch(request)
            print("🔍 Verification: Found \(savedPlayers.count) players for UID \(userUID)")
            
            if let savedPlayer = savedPlayers.first {
                print("✅ Saved player: \(savedPlayer.name ?? "Unknown") with ID: \(savedPlayer.id?.uuidString ?? "nil")")
            }
        } catch {
            print("❌ Failed to save player profile: \(error)")
            return
        }
        
        // Sync to Firebase/Cloud
        Task {
            do {
                await CloudSyncManager.shared.performFullSync()
                await CloudSyncManager.shared.trackUserEvent(.sessionStart, contextData: [
                    "onboarding_completed": true,
                    "player_name": playerName
                ])
                print("✅ Successfully synced to cloud")
            } catch {
                print("⚠️ Failed to sync new player profile: \(error)")
            }
        }
        
        print("🎯 Setting isOnboardingComplete = true")
        isOnboardingComplete = true
        print("✅ Onboarding marked as complete")
    }
}

#Preview {
    EnhancedOnboardingView(isOnboardingComplete: .constant(false))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(CoreDataManager.shared)
        .environmentObject(AuthenticationManager.shared)
}