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

// MARK: - Hero Transition Namespace
private struct HeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var heroNamespace: Namespace.ID? {
        get { self[HeroNamespaceKey.self] }
        set { self[HeroNamespaceKey.self] = newValue }
    }
}

extension View {
    func heroNamespace(_ namespace: Namespace.ID) -> some View {
        environment(\.heroNamespace, namespace)
    }
}

// MARK: - Hero Source Modifier
struct HeroSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: true
            )
    }
}

// MARK: - Hero Destination Modifier
struct HeroDestinationModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: false
            )
    }
}

extension View {
    func heroSource(id: String, namespace: Namespace.ID) -> some View {
        modifier(HeroSourceModifier(id: id, namespace: namespace))
    }

    func heroDestination(id: String, namespace: Namespace.ID) -> some View {
        modifier(HeroDestinationModifier(id: id, namespace: namespace))
    }
}

// MARK: - Pulse Expand Transition
struct PulseExpandModifier: ViewModifier {
    @Binding var trigger: Bool
    @State private var isExpanded = false
    @State private var glowOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isExpanded ? 1.0 : 0.8)
            .opacity(isExpanded ? 1.0 : 0.0)
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
                    .scaleEffect(isExpanded ? 1.5 : 0.8)
                    .opacity(glowOpacity)
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    HapticManager.shared.pulseExpand()
                    if reduceMotion {
                        isExpanded = true
                    } else {
                        withAnimation(DesignSystem.Animation.springBouncy) {
                            isExpanded = true
                        }
                        withAnimation(DesignSystem.Animation.smooth) {
                            glowOpacity = 0.6
                        }
                        withAnimation(DesignSystem.Animation.slow.delay(0.2)) {
                            glowOpacity = 0
                        }
                    }
                }
            }
    }
}

extension View {
    func pulseExpand(trigger: Binding<Bool>) -> some View {
        modifier(PulseExpandModifier(trigger: trigger))
    }
}

// MARK: - Card Flip Transition
struct CardFlipModifier<Back: View>: ViewModifier {
    @Binding var isFlipped: Bool
    let back: Back
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(rotation < 90 ? 1 : 0)
                .accessibilityHidden(isFlipped)

            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation >= 90 ? 1 : 0)
                .accessibilityHidden(!isFlipped)
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onChange(of: isFlipped) { _, newValue in
            if reduceMotion {
                rotation = newValue ? 180 : 0
            } else {
                withAnimation(DesignSystem.Animation.smooth) {
                    rotation = newValue ? 180 : 0
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    HapticManager.shared.cardFlipMidpoint()
                }
            }
        }
    }
}

extension View {
    func cardFlip<Back: View>(isFlipped: Binding<Bool>, @ViewBuilder back: () -> Back) -> some View {
        modifier(CardFlipModifier(isFlipped: isFlipped, back: back()))
    }
}

// MARK: - Countdown Burst Transition
struct CountdownBurstModifier: ViewModifier {
    let value: Int
    let isFinal: Bool
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: value) { _, _ in
                if reduceMotion { return }

                scale = 0.7
                opacity = 0
                withAnimation(DesignSystem.Animation.springBouncy) {
                    scale = 1.0
                    opacity = 1.0
                }

                if isFinal {
                    HapticManager.shared.countdownComplete()
                } else {
                    HapticManager.shared.countdownTick()
                }
            }
    }
}

extension View {
    func countdownBurst(value: Int, isFinal: Bool = false) -> some View {
        modifier(CountdownBurstModifier(value: value, isFinal: isFinal))
    }
}

// MARK: - Sheet Rise Modifier
struct SheetRiseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surfaceOverlay)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: DesignSystem.CornerRadius.xl,
                    topTrailingRadius: DesignSystem.CornerRadius.xl
                )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
            )
            .onAppear {
                HapticManager.shared.sheetPresent()
            }
            .onDisappear {
                HapticManager.shared.sheetDismiss()
            }
    }
}

extension View {
    func sheetRise() -> some View {
        modifier(SheetRiseModifier())
    }
}
