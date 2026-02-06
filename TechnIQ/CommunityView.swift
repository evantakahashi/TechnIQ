import SwiftUI

struct CommunityView: View {
    var body: some View {
        CommunityFeedView()
    }
}

#Preview {
    NavigationView {
        CommunityView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
