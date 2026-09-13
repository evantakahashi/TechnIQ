import SwiftUI

// MARK: - Name your coach (You → Your coach)
//
// One field. The name fronts every coach surface and is sent to the coach functions so the model
// speaks as that coach. Empty restores "Coach".

struct CoachNameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = CoachIdentity.name()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("Your coach") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                TQNavAction("Save") { save() }
                    .accessibilityIdentifier("coachName.save")
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                TQDisplayTitle("Who's coaching\nyou?", size: .medium)
                TQBody("The name shows on Home, Train and the weekly review. Leave it empty for plain \"Coach\".")
            }

            TQFormField("Name", text: $name, placeholder: CoachIdentity.defaultName)
                .onSubmit { save() }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func save() {
        CoachIdentity.setName(name)
        HapticManager.shared.selectionChanged()
        dismiss()
    }
}
