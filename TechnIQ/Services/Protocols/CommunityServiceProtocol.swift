import Foundation
import CoreData

// MARK: - CommunityService Protocol

@MainActor
protocol CommunityServiceProtocol: AnyObject {
    var posts: [CommunityPost] { get }
    var isLoading: Bool { get }
    var error: String? { get }
    var blockedUsers: Set<String> { get }
    var sharedDrills: [SharedDrill] { get }
    var isLoadingDrills: Bool { get }
    var leaderboard: [LeaderboardEntry] { get }
    var currentPlayerRank: Int? { get }
    var isLoadingLeaderboard: Bool { get }

    func fetchPosts(refresh: Bool) async
    func createPost(content: String, postType: CommunityPostType, player: Player) async throws
    func deletePost(_ post: CommunityPost) async throws
    func toggleLike(for post: CommunityPost) async throws
    func fetchComments(for postID: String) async throws -> [CommunityComment]
    func addComment(to postID: String, content: String, player: Player) async throws
    func reportPost(_ post: CommunityPost, reason: String) async throws
    func fetchSharedDrills(refresh: Bool, category: String?, difficulty: Int?) async
    func shareDrill(exercise: Exercise, player: Player) async throws
    func saveDrillToLibrary(drill: SharedDrill, player: Player, context: NSManagedObjectContext) async throws
    func fetchLeaderboard(forceRefresh: Bool) async
    func fetchCurrentPlayerRank(playerXP: Int) async
    func blockUser(_ userID: String) async throws
}
