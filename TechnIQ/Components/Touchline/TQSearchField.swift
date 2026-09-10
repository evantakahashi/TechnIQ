import SwiftUI

// MARK: - TQSearchField
//
// Raised field (r8, 12×14 padding) with a magnifier and 15 pt placeholder. Focused: 1.5 pt grass
// border and a Cancel affordance. Disabled: 50 % opacity.

struct TQSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(_ placeholder: String, text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .accessibilityHidden(true)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(DesignSystem.Colors.dimIvory))
                .font(Font.system(size: 15, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { onSubmit?() }
                .accessibilityLabel(placeholder)

            if isFocused || !text.isEmpty {
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Text("Cancel")
                        .font(Font.system(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                        .frame(minHeight: DesignSystem.Spacing.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(minHeight: DesignSystem.Spacing.hitTarget)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField, style: .continuous)
                .fill(DesignSystem.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField, style: .continuous)
                .strokeBorder(isFocused ? DesignSystem.Colors.grass : Color.clear, lineWidth: 1.5)
        )
        .opacity(isEnabled ? 1 : 0.5)
        .animation(DesignSystem.Animation.quick, value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isFocused = true } }
    }
}

#if DEBUG
#Preview("Search") {
    VStack(spacing: 12) {
        TQSearchField("Search 47 drills", text: .constant(""))
        TQSearchField("Search 47 drills", text: .constant("wall"))
        TQSearchField("Search drills", text: .constant("")).disabled(true)
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
