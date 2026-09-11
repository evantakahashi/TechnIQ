import SwiftUI

// MARK: - TQFormField
//
// Labelled text field on a raised surface: condensed eyebrow label, 16 pt input, 1 pt highlight
// border that turns grass when focused. Used by the email sign-in form and onboarding's
// name/age step.

struct TQFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>, placeholder: String = "", isSecure: Bool = false,
         contentType: UITextContentType? = nil, keyboard: UIKeyboardType = .default) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.contentType = contentType
        self.keyboard = keyboard
    }

    private var isEmailOrSecret: Bool { contentType == .emailAddress || isSecure }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                .textCase(.uppercase)
                .tracking(DesignSystem.Typography.Tracking.eyebrow)
                .foregroundColor(DesignSystem.Colors.dimIvory)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(Font.system(size: 16, weight: .regular))
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .tint(DesignSystem.Colors.grass)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(isEmailOrSecret || keyboard == .numberPad ? .never : .words)
            .autocorrectionDisabled(isEmailOrSecret)
            .focused($isFocused)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(DesignSystem.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .strokeBorder(isFocused ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight, lineWidth: 1)
            )
            .accessibilityLabel(label)
        }
    }
}

// MARK: - TQKeyboard

enum TQKeyboard {
    /// Resigns the first responder (dismisses the software keyboard) from anywhere.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - TQAppMark

/// 40 pt app mark: near-black rounded square with a lime centre-circle target on a halfway line.
struct TQAppMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(DesignSystem.Colors.surfaceBase)
            Rectangle()
                .fill(DesignSystem.Colors.grass)
                .frame(width: size * 0.7, height: 1.5)
            Circle()
                .fill(DesignSystem.Colors.surfaceBase)
                .frame(width: size * 0.42, height: size * 0.42)
            Circle()
                .strokeBorder(DesignSystem.Colors.grass, lineWidth: 2)
                .frame(width: size * 0.42, height: size * 0.42)
            Circle()
                .fill(DesignSystem.Colors.chalkWhite)
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Form field") {
    VStack(spacing: 16) {
        TQFormField("Email", text: .constant(""), placeholder: "you@example.com", contentType: .emailAddress, keyboard: .emailAddress)
        TQFormField("Password", text: .constant("secret"), isSecure: true, contentType: .password)
        HStack { TQAppMark(); Spacer() }
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
