import SwiftUI

struct CommunityView: View {
    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("Community")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Coming Soon")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Community")
    }
}

#Preview {
    NavigationView {
        CommunityView()
    }
}
