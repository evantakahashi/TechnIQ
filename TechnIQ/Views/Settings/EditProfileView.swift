import SwiftUI
import CoreData

// MARK: - Edit profile (You → Edit profile)
//
// Who you are on the team sheet: name, age, kit number and playing style. Position, foot, level
// and weak spots live in Training profile, so they are not repeated here.

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager

    let player: Player

    @State private var playerName: String
    @State private var playerAge: Int
    @State private var selectedPlayingStyle: String
    @State private var kitNumberText: String

    private let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]

    init(player: Player) {
        self.player = player
        _playerName = State(initialValue: player.name ?? "")
        let age = Int(player.age)
        _playerAge = State(initialValue: OnboardingMapping.ageRange.contains(age) ? age : OnboardingMapping.ageRange.lowerBound)
        _selectedPlayingStyle = State(initialValue: player.playingStyle ?? "Balanced")
        _kitNumberText = State(initialValue: player.kitNumberValue.map(String.init) ?? "")
    }

    private var canSave: Bool { !playerName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Edit profile") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    TQNavAction("Save") { saveChanges() }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                        .accessibilityIdentifier("editProfile.save")
                }
                .padding(.top, 8)

                TQDisplayTitle("On the\nteam sheet", size: .medium)

                TQFormField("Name", text: $playerName, placeholder: "Your name", contentType: .name)

                TQFormField("Kit number", text: $kitNumberText, placeholder: "Optional", keyboard: .numberPad)
                    .onChange(of: kitNumberText) { _, value in
                        kitNumberText = OnboardingMapping.digits(value, maxDigits: 2)
                    }
                    .accessibilityLabel("Kit number, optional")

                // Same range onboarding accepts (5–80).
                TQValueStepper(label: "Age", value: $playerAge, range: OnboardingMapping.ageRange)
                    .overlay(alignment: .top) { TQRule() }
                    .overlay(alignment: .bottom) { TQRule() }

                VStack(alignment: .leading, spacing: 4) {
                    TQGroupHeader("Playing style")
                    FlowLayout(spacing: 6) {
                        ForEach(playingStyles, id: \.self) { style in
                            TQChip(style, isSelected: selectedPlayingStyle == style) { selectedPlayingStyle = style }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func saveChanges() {
        guard canSave else { return }
        player.name = playerName.trimmingCharacters(in: .whitespaces)
        player.age = Int16(playerAge)
        player.playingStyle = selectedPlayingStyle
        player.kitNumberValue = OnboardingMapping.kitNumber(from: kitNumberText)

        coreDataManager.save()
        HapticManager.shared.selectionChanged()
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
