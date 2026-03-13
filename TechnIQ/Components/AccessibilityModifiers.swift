import SwiftUI

// MARK: - Accessibility Modifier
struct A11yModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let isHidden: Bool

    func body(content: Content) -> some View {
        if isHidden {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityLabel(label)
                .accessibilityHint(hint ?? "")
                .accessibilityAddTraits(traits)
        }
    }
}

extension View {
    func a11y(
        label: String,
        hint: String? = nil,
        trait: AccessibilityTraits = .isButton
    ) -> some View {
        modifier(A11yModifier(label: label, hint: hint, traits: trait, isHidden: false))
    }

    func a11yHidden() -> some View {
        modifier(A11yModifier(label: "", hint: nil, traits: [], isHidden: true))
    }

    func a11yValue(_ value: String, label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}

// MARK: - Reduce Motion Helper
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animated: AnyTransition
    let reduced: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? reduced : animated)
    }
}

extension View {
    func adaptiveTransition(
        animated: AnyTransition,
        reduced: AnyTransition = .opacity
    ) -> some View {
        modifier(ReduceMotionModifier(animated: animated, reduced: reduced))
    }
}
