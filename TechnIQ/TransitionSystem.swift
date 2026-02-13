import SwiftUI

// MARK: - Stagger Reveal Transition
struct StaggerRevealModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 20)
            .animation(
                reduceMotion
                    ? .none
                    : DesignSystem.Animation.staggerSpring.delay(Double(index) * 0.04),
                value: isVisible
            )
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func staggerReveal(index: Int) -> some View {
        modifier(StaggerRevealModifier(index: index))
    }
}

// MARK: - Tab Morph Transition
struct TabMorphModifier: ViewModifier {
    let selectedTab: Int
    @State private var previousTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(selectedTab: Int) {
        self.selectedTab = selectedTab
        self._previousTab = State(initialValue: selectedTab)
    }

    private var direction: CGFloat {
        selectedTab > previousTab ? 1 : -1
    }

    func body(content: Content) -> some View {
        content
            .id(selectedTab)
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .offset(x: 30 * direction).combined(with: .opacity),
                        removal: .offset(x: -30 * direction).combined(with: .opacity)
                    )
            )
            .animation(
                reduceMotion ? .none : DesignSystem.Animation.tabMorph,
                value: selectedTab
            )
            .onChange(of: selectedTab) { oldValue, _ in
                previousTab = oldValue
                if !reduceMotion {
                    HapticManager.shared.tabChanged()
                }
            }
    }
}

extension View {
    func tabMorph(selectedTab: Int) -> some View {
        modifier(TabMorphModifier(selectedTab: selectedTab))
    }
}
