import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Community Data Models

struct CommunityPost: Identifiable, Equatable {
    let id: String
    let authorID: String
    let authorName: String
    let authorLevel: Int
    let authorPosition: String
    let content: String
    let postType: CommunityPostType
    let timestamp: Date
    var likesCount: Int
    var commentsCount: Int
    var isLikedByCurrentUser: Bool
    var isReported: Bool

    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool {
        lhs.id == rhs.id && lhs.likesCount == rhs.likesCount && lhs.commentsCount == rhs.commentsCount && lhs.isLikedByCurrentUser == rhs.isLikedByCurrentUser
    }
}

enum CommunityPostType: String, CaseIterable {
    case general = "general"
    case sessionComplete = "session_complete"
    case achievement = "achievement"
    case milestone = "milestone"

    var icon: String {
        switch self {
        case .general: return "bubble.left.fill"
        case .sessionComplete: return "checkmark.circle.fill"
        case .achievement: return "trophy.fill"
        case .milestone: return "star.fill"
        }
    }

    var displayName: String {
        switch self {
        case .general: return "Post"
        case .sessionComplete: return "Session"
        case .achievement: return "Achievement"
        case .milestone: return "Milestone"
        }
    }
}

struct CommunityComment: Identifiable {
    let id: String
    let postID: String
    let authorID: String
    let authorName: String
    let authorLevel: Int
    let content: String
    let timestamp: Date
    var isReported: Bool
}

// MARK: - Community Service

@MainActor
class CommunityService: ObservableObject {
    static let shared = CommunityService()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var blockedUsers: Set<String> = []

    private var lastDocument: DocumentSnapshot?
    private var hasMorePosts = true
    private let pageSize = 20

    private init() {
        loadBlockedUsers()
    }

    // MARK: - Auth Helper

    private var currentUserID: String? {
        auth.currentUser?.uid
    }

    private func requireAuth() throws -> String {
        guard let uid = currentUserID else {
            throw CloudDataError.notAuthenticated
        }
        return uid
    }

    // MARK: - Fetch Posts (Paginated)

    func fetchPosts(refresh: Bool = false) async {
        guard !isLoading else { return }

        if refresh {
            lastDocument = nil
            hasMorePosts = true
        }

        guard hasMorePosts else { return }

        isLoading = true
        error = nil

        do {
            let userID = try requireAuth()

            var query = db.collection("communityPosts")
                .order(by: "timestamp", descending: true)
                .limit(to: pageSize)

            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            let newPosts = snapshot.documents.compactMap { doc -> CommunityPost? in
                let data = doc.data()
                let authorID = data["authorID"] as? String ?? ""
                guard !blockedUsers.contains(authorID) else { return nil }

                let likedBy = data["likedBy"] as? [String] ?? []

                return CommunityPost(
                    id: doc.documentID,
                    authorID: authorID,
                    authorName: data["authorName"] as? String ?? "Player",
                    authorLevel: data["authorLevel"] as? Int ?? 1,
                    authorPosition: data["authorPosition"] as? String ?? "",
                    content: data["content"] as? String ?? "",
                    postType: CommunityPostType(rawValue: data["postType"] as? String ?? "general") ?? .general,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    likesCount: data["likesCount"] as? Int ?? 0,
                    commentsCount: data["commentsCount"] as? Int ?? 0,
                    isLikedByCurrentUser: likedBy.contains(userID),
                    isReported: false
                )
            }

            lastDocument = snapshot.documents.last
            hasMorePosts = snapshot.documents.count == pageSize

            if refresh {
                posts = newPosts
            } else {
                posts.append(contentsOf: newPosts)
            }

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            #if DEBUG
            print("❌ CommunityService.fetchPosts error: \(error)")
            #endif
        }
    }

    // MARK: - Create Post

    func createPost(content: String, postType: CommunityPostType = .general, player: Player) async throws {
        let userID = try requireAuth()

        let postRef = db.collection("communityPosts").document()
        let postData: [String: Any] = [
            "authorID": userID,
            "authorName": player.name ?? "Player",
            "authorLevel": player.currentLevel,
            "authorPosition": player.position ?? "",
            "content": content,
            "postType": postType.rawValue,
            "timestamp": FieldValue.serverTimestamp(),
            "likesCount": 0,
            "commentsCount": 0,
            "likedBy": [],
            "reportCount": 0,
            "reportedBy": []
        ]

        try await postRef.setData(postData)

        // Insert at top of local feed
        let newPost = CommunityPost(
            id: postRef.documentID,
            authorID: userID,
            authorName: player.name ?? "Player",
            authorLevel: Int(player.currentLevel),
            authorPosition: player.position ?? "",
            content: content,
            postType: postType,
            timestamp: Date(),
            likesCount: 0,
            commentsCount: 0,
            isLikedByCurrentUser: false,
            isReported: false
        )
        posts.insert(newPost, at: 0)
    }

    // MARK: - Delete Post

    func deletePost(_ post: CommunityPost) async throws {
        let userID = try requireAuth()
        guard post.authorID == userID else { return }

        try await db.collection("communityPosts").document(post.id).delete()
        posts.removeAll { $0.id == post.id }
    }

    // MARK: - Toggle Like

    func toggleLike(for post: CommunityPost) async throws {
        let userID = try requireAuth()
        let postRef = db.collection("communityPosts").document(post.id)

        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        if posts[index].isLikedByCurrentUser {
            // Unlike
            try await postRef.updateData([
                "likesCount": FieldValue.increment(Int64(-1)),
                "likedBy": FieldValue.arrayRemove([userID])
            ])
            posts[index].likesCount -= 1
            posts[index].isLikedByCurrentUser = false
        } else {
            // Like
            try await postRef.updateData([
                "likesCount": FieldValue.increment(Int64(1)),
                "likedBy": FieldValue.arrayUnion([userID])
            ])
            posts[index].likesCount += 1
            posts[index].isLikedByCurrentUser = true
        }
    }

    // MARK: - Comments

    func fetchComments(for postID: String) async throws -> [CommunityComment] {
        _ = try requireAuth()

        let snapshot = try await db.collection("communityPosts").document(postID)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> CommunityComment? in
            let data = doc.data()
            let authorID = data["authorID"] as? String ?? ""
            guard !blockedUsers.contains(authorID) else { return nil }

            return CommunityComment(
                id: doc.documentID,
                postID: postID,
                authorID: authorID,
                authorName: data["authorName"] as? String ?? "Player",
                authorLevel: data["authorLevel"] as? Int ?? 1,
                content: data["content"] as? String ?? "",
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                isReported: false
            )
        }
    }

    func addComment(to postID: String, content: String, player: Player) async throws {
        let userID = try requireAuth()

        let commentRef = db.collection("communityPosts").document(postID)
            .collection("comments").document()

        let commentData: [String: Any] = [
            "authorID": userID,
            "authorName": player.name ?? "Player",
            "authorLevel": player.currentLevel,
            "content": content,
            "timestamp": FieldValue.serverTimestamp(),
            "reportCount": 0,
            "reportedBy": []
        ]

        // Batch: add comment + increment counter
        let batch = db.batch()
        batch.setData(commentData, forDocument: commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(1))],
                         forDocument: db.collection("communityPosts").document(postID))
        try await batch.commit()

        // Update local count
        if let index = posts.firstIndex(where: { $0.id == postID }) {
            posts[index].commentsCount += 1
        }
    }

    // MARK: - Report Post

    func reportPost(_ post: CommunityPost, reason: String) async throws {
        let userID = try requireAuth()

        try await db.collection("communityPosts").document(post.id).updateData([
            "reportCount": FieldValue.increment(Int64(1)),
            "reportedBy": FieldValue.arrayUnion([userID])
        ])

        // Also write to a moderation queue
        try await db.collection("reports").document().setData([
            "postID": post.id,
            "reporterID": userID,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    func reportComment(_ comment: CommunityComment) async throws {
        let userID = try requireAuth()

        try await db.collection("communityPosts").document(comment.postID)
            .collection("comments").document(comment.id).updateData([
                "reportCount": FieldValue.increment(Int64(1)),
                "reportedBy": FieldValue.arrayUnion([userID])
            ])

        try await db.collection("reports").document().setData([
            "commentID": comment.id,
            "postID": comment.postID,
            "reporterID": userID,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Block User

    func blockUser(_ userID: String) async throws {
        let currentUID = try requireAuth()

        blockedUsers.insert(userID)
        saveBlockedUsers()

        // Remove their posts from local feed
        posts.removeAll { $0.authorID == userID }

        // Persist block in Firestore
        try await db.collection("users").document(currentUID)
            .collection("blockedUsers").document(userID)
            .setData(["blockedAt": FieldValue.serverTimestamp()])
    }

    // MARK: - Blocked Users Persistence

    private func loadBlockedUsers() {
        if let saved = UserDefaults.standard.stringArray(forKey: "blockedCommunityUsers") {
            blockedUsers = Set(saved)
        }

        // Also load from Firestore in background
        Task {
            guard let uid = currentUserID else { return }
            let snapshot = try? await db.collection("users").document(uid)
                .collection("blockedUsers").getDocuments()
            if let docs = snapshot?.documents {
                let ids = docs.map { $0.documentID }
                blockedUsers.formUnion(ids)
                saveBlockedUsers()
            }
        }
    }

    private func saveBlockedUsers() {
        UserDefaults.standard.set(Array(blockedUsers), forKey: "blockedCommunityUsers")
    }

    // MARK: - Fetch Public Profile

    func fetchPublicProfile(userID: String) async throws -> (name: String, level: Int, position: String, totalXP: Int64, sessionsCount: Int) {
        let snapshot = try await db.collection("users").document(userID)
            .collection("playerProfiles").limit(to: 1).getDocuments()

        guard let doc = snapshot.documents.first else {
            return ("Player", 1, "", 0, 0)
        }

        let data = doc.data()
        return (
            name: data["name"] as? String ?? "Player",
            level: data["currentLevel"] as? Int ?? 1,
            position: data["position"] as? String ?? "",
            totalXP: data["totalXP"] as? Int64 ?? 0,
            sessionsCount: data["totalSessions"] as? Int ?? 0
        )
    }
}
