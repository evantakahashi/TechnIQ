import SwiftUI

struct CommunityView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            ModernSegmentControl(
                options: ["Feed", "Drills", "Leaderboard"],
                selectedIndex: $selectedTab,
                icons: ["bubble.left.fill", "figure.run", "trophy.fill"]
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)

            TabView(selection: $selectedTab) {
                CommunityFeedView()
                    .tag(0)

                DrillMarketplaceView()
                    .tag(1)

                LeaderboardView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(DesignSystem.Animation.tabMorph, value: selectedTab)
        }
        .background(AdaptiveBackground().ignoresSafeArea())
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        CommunityView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
