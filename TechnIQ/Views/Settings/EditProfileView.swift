import SwiftUI
import CoreData

struct EditProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager

    let player: Player

    @State private var playerName: String
    @State private var playerAge: Int
    @State private var selectedPosition: String
    @State private var selectedPlayingStyle: String
    @State private var selectedDominantFoot: String
    @State private var kitNumberText: String

    let positions = OnboardingMapping.positions
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = OnboardingMapping.feet

    init(player: Player) {
        self.player = player
        _playerName = State(initialValue: player.name ?? "")
        let age = Int(player.age)
        _playerAge = State(initialValue: OnboardingMapping.ageRange.contains(age) ? age : OnboardingMapping.ageRange.lowerBound)
        _selectedPosition = State(initialValue: player.position ?? "Midfielder")
        _selectedPlayingStyle = State(initialValue: player.playingStyle ?? "Balanced")
        _selectedDominantFoot = State(initialValue: player.dominantFoot ?? "Right")
        _kitNumberText = State(initialValue: player.kitNumberValue.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $playerName)

                    // Same range onboarding accepts (5–80); the old slider clamped to 10–16.
                    Stepper(value: $playerAge, in: OnboardingMapping.ageRange) {
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(playerAge)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityValue("\(playerAge)")

                    HStack {
                        Text("Kit number")
                        Spacer()
                        TextField("None", text: $kitNumberText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: kitNumberText) { _, value in
                                kitNumberText = OnboardingMapping.digits(value, maxDigits: 2)
                            }
                            .accessibilityLabel("Kit number, optional")
                    }
                }

                Section("Playing Profile") {
                    Picker("Position", selection: $selectedPosition) {
                        ForEach(positions, id: \.self) { position in
                            Text(position).tag(position)
                        }
                    }

                    Picker("Playing Style", selection: $selectedPlayingStyle) {
                        ForEach(playingStyles, id: \.self) { style in
                            Text(style).tag(style)
                        }
                    }

                    Picker("Dominant Foot", selection: $selectedDominantFoot) {
                        ForEach(dominantFeet, id: \.self) { foot in
                            Text(foot).tag(foot)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        player.name = playerName.trimmingCharacters(in: .whitespaces)
        player.age = Int16(playerAge)
        player.position = selectedPosition
        player.playingStyle = selectedPlayingStyle
        player.dominantFoot = selectedDominantFoot
        player.kitNumberValue = OnboardingMapping.kitNumber(from: kitNumberText)

        coreDataManager.save()
        dismiss()
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"
    samplePlayer.age = 14
    samplePlayer.position = "Midfielder"
    samplePlayer.playingStyle = "Balanced"
    samplePlayer.dominantFoot = "Right"

    return EditProfileView(player: samplePlayer)
        .environment(\.managedObjectContext, context)
        .environmentObject(CoreDataManager.shared)
}
