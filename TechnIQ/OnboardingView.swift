import SwiftUI
import CoreData

struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @Binding var isOnboardingComplete: Bool
    
    @State private var currentStep = 0
    @State private var playerName = ""
    @State private var playerAge = 12
    @State private var playerHeight = 150.0
    @State private var playerWeight = 45.0
    @State private var selectedPosition = "Midfielder"
    @State private var selectedPlayingStyle = "Balanced"
    @State private var selectedDominantFoot = "Right"
    
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    
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
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Progress Indicator
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Rectangle()
                            .fill(index <= currentStep ? Color.black : Color(.systemGray4))
                            .frame(height: 3)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                
                Text("Step \(currentStep + 1) of 3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            
            Spacer()
            
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
            
            Spacer()
            
            // Continue Button
            Button(action: {
                withAnimation {
                    if currentStep < 2 {
                        currentStep += 1
                    } else {
                        createPlayer()
                    }
                }
            }) {
                Text(currentStep == 2 ? "GET STARTED" : "CONTINUE")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? Color.black : Color.gray)
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
    
    private var welcomeStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 24) {
                Image(systemName: "soccerball")
                    .font(.system(size: 80))
                    .foregroundColor(.black)
                
                VStack(spacing: 8) {
                    Text("Welcome to TechnIQ")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal soccer training companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            VStack(spacing: 24) {
                FeatureRow(
                    icon: "person.fill",
                    title: "Track Sessions",
                    description: "Log your training sessions and exercises"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Monitor Progress",
                    description: "See your improvement over time"
                )
                
                FeatureRow(
                    icon: "lightbulb.fill",
                    title: "Get Recommendations",
                    description: "Personalized training suggestions"
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var basicInfoStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Tell us about yourself")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We'll use this information to personalize your training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 24) {
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your name", text: $playerName)
                        .textFieldStyle(CustomTextFieldStyle())
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
                    ), in: 10...18, step: 1)
                    .tint(.black)
                }
                
                // Height Slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Height")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(playerHeight)) cm")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: $playerHeight, in: 120...200, step: 1)
                        .tint(.black)
                }
                
                // Weight Slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Weight")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(playerWeight)) kg")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: $playerWeight, in: 30...100, step: 1)
                        .tint(.black)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var positionStyleStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Your Playing Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This helps us recommend the right exercises for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 24) {
                // Position Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Position")
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
                    
                    Menu {
                        ForEach(dominantFeet, id: \.self) { foot in
                            Button(foot) {
                                selectedDominantFoot = foot
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedDominantFoot)
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
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func createPlayer() {
        let newPlayer = Player(context: viewContext)
        newPlayer.id = UUID()
        newPlayer.name = playerName
        newPlayer.age = Int16(playerAge)
        newPlayer.height = playerHeight
        newPlayer.weight = playerWeight
        newPlayer.position = selectedPosition
        newPlayer.playingStyle = selectedPlayingStyle
        newPlayer.dominantFoot = selectedDominantFoot
        newPlayer.createdAt = Date()
        
        let initialStats = PlayerStats(context: viewContext)
        initialStats.id = UUID()
        initialStats.player = newPlayer
        initialStats.date = Date()
        initialStats.totalSessions = 0
        initialStats.totalTrainingHours = 0.0
        initialStats.skillRatings = [
            "Ball Control": 5.0,
            "Passing": 5.0,
            "Shooting": 5.0,
            "Dribbling": 5.0,
            "Speed": 5.0,
            "Endurance": 5.0,
            "Defending": 5.0,
            "Heading": 5.0
        ]
        
        coreDataManager.save()
        isOnboardingComplete = true
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(CoreDataManager.shared)
}