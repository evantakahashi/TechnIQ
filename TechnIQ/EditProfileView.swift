import SwiftUI
import CoreData

struct EditProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager
    
    let player: Player
    
    @State private var playerName: String
    @State private var playerAge: Int
    @State private var playerHeight: Double
    @State private var playerWeight: Double
    @State private var selectedPosition: String
    @State private var selectedPlayingStyle: String
    @State private var selectedDominantFoot: String
    
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    
    init(player: Player) {
        self.player = player
        _playerName = State(initialValue: player.name ?? "")
        _playerAge = State(initialValue: Int(player.age))
        _playerHeight = State(initialValue: player.height)
        _playerWeight = State(initialValue: player.weight)
        _selectedPosition = State(initialValue: player.position ?? "Midfielder")
        _selectedPlayingStyle = State(initialValue: player.playingStyle ?? "Balanced")
        _selectedDominantFoot = State(initialValue: player.dominantFoot ?? "Right")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $playerName)
                    
                    VStack(alignment: .leading) {
                        Text("Age: \(playerAge)")
                        Slider(value: Binding(
                            get: { Double(playerAge) },
                            set: { playerAge = Int($0) }
                        ), in: 10...16, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Height: \(Int(playerHeight)) cm")
                        Slider(value: $playerHeight, in: 120...180, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Weight: \(Int(playerWeight)) kg")
                        Slider(value: $playerWeight, in: 25...80, step: 1)
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
                
                Section("Account Actions") {
                    Button("Reset All Data", role: .destructive) {
                        // This would show a confirmation dialog
                    }
                    .foregroundColor(.red)
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
                    .disabled(playerName.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        player.name = playerName
        player.age = Int16(playerAge)
        player.height = playerHeight
        player.weight = playerWeight
        player.position = selectedPosition
        player.playingStyle = selectedPlayingStyle
        player.dominantFoot = selectedDominantFoot
        
        coreDataManager.save()
        dismiss()
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"
    samplePlayer.age = 14
    samplePlayer.height = 165
    samplePlayer.weight = 55
    samplePlayer.position = "Midfielder"
    samplePlayer.playingStyle = "Balanced"
    samplePlayer.dominantFoot = "Right"
    
    return EditProfileView(player: samplePlayer)
        .environment(\.managedObjectContext, context)
        .environmentObject(CoreDataManager.shared)
}