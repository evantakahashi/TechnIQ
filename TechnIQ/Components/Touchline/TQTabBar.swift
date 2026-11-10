import SwiftUI

// MARK: - TQTabBar
//
// Four or five icon-only items (Community is flagged), 24 pt semibold. Selected = grass + .fill symbol, idle = textTertiary
// outline, so state reads without colour. 1 px top rule, base background, no labels — the
// screen title already names the tab.

struct TQTabBar: View {
    @Binding var selectedTab: DesignSystem.Icons.Tab
    var tabs: [DesignSystem.Icons.Tab] = DesignSystem.Icons.Tab.visible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    HapticManager.shared.tabChanged()
                    if reduceMotion {
                        selectedTab = tab
                    } else {
                        withAnimation(DesignSystem.Animation.tabMorph) { selectedTab = tab }
                    }
                } label: {
                    Image(systemName: isSelected ? tab.selected : tab.idle)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? DesignSystem.Colors.grass : DesignSystem.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.Spacing.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(
            DesignSystem.Colors.surfaceBase
                .overlay(alignment: .top) { TQRule() }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#if DEBUG
#Preview("Tab bar") {
    VStack {
        Spacer()
        TQTabBar(selectedTab: .constant(.home))
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif

// MARK: - Tab content host

/// Hosts the tab roots side by side. Tabs stay alive once visited so navigation, scroll position
/// and in-flight state survive tab switches; only the first visit builds a tab.
struct AnimatedTabContent<Content: View>: View {
    @Binding var selectedTab: Int
    var tabCount: Int = 5
    let content: (Int) -> Content

    @State private var visitedTabs: Set<Int> = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<tabCount, id: \.self) { index in
                    if index == selectedTab || visitedTabs.contains(index) {
                        content(index)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: CGFloat(index - selectedTab) * geometry.size.width)
                            .opacity(index == selectedTab ? 1 : 0)
                            .allowsHitTesting(index == selectedTab)
                            .accessibilityHidden(index != selectedTab)
                    }
                }
            }
            .clipped()
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: selectedTab)
            .onAppear { visitedTabs.insert(selectedTab) }
            .onChange(of: selectedTab) { _, newValue in
                visitedTabs.insert(newValue)
            }
        }
    }
}
