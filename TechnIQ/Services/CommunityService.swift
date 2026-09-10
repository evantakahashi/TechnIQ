import Foundation
import CoreData
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
    var isHidden: Bool = false

    // Rich post metadata (optional, only present for new post types)
    var drillID: String?
    var drillTitle: String?
    var drillCategory: String?
    var drillDifficulty: Int?
    var drillSaveCount: Int?
    var achievementName: String?
    var achievementIcon: String?
    var sessionDuration: Int?
    var sessionExerciseCount: Int?
    var sessionRating: Double?
    var sessionXP: Int?
    var newLevel: Int?
    var rankName: String?

    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool {
        lhs.id == rhs.id && lhs.likesCount == rhs.likesCount && lhs.commentsCount == rhs.commentsCount && lhs.isLikedByCurrentUser == rhs.isLikedByCurrentUser
    }
}

enum CommunityPostType: String, CaseIterable {
    case general = "general"
    case sessionComplete = "session_complete"
    case achievement = "achievement"
    case milestone = "milestone"
    case sharedDrill = "shared_drill"
    case sharedAchievement = "shared_achievement"
    case sharedSession = "shared_session"
    case sharedLevelUp = "shared_levelup"

    var icon: String {
        switch self {
        case .general: return "bubble.left.fill"
        case .sessionComplete: return "checkmark.circle.fill"
        case .achievement: return "trophy.fill"
        case .milestone: return "star.fill"
        case .sharedDrill: return "square.and.arrow.up.fill"
        case .sharedAchievement: return "trophy.fill"
        case .sharedSession: return "checkmark.circle.fill"
        case .sharedLevelUp: return "arrow.up.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .general: return "Post"
        case .sessionComplete: return "Session"
        case .achievement: return "Achievement"
        case .milestone: return "Milestone"
        case .sharedDrill: return "Drill"
        case .sharedAchievement: return "Achievement"
        case .sharedSession: return "Session"
        case .sharedLevelUp: return "Level Up"
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
    var isHidden: Bool = false
}

struct SharedDrill: Identifiable {
    let id: String
    let authorID: String
    let authorName: String
    let authorLevel: Int
    let title: String
    let description: String
    let category: String
    let difficulty: Int
    let targetSkills: [String]
    let duration: Int
    let equipment: [String]
    let steps: [String]
    let sets: Int
    let reps: Int
    let timestamp: Date
    var saveCount: Int
    var isSavedByCurrentUser: Bool
    let reportCount: Int
    var isHidden: Bool = false
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let level: Int
    let xp: Int
    let position: String
    let rank: Int
}

// MARK: - Community Service

@MainActor
class CommunityService: ObservableObject, CommunityServiceProtocol {
    static let shared = CommunityService()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var blockedUsers: Set<String> = []
    @Published var sharedDrills: [SharedDrill] = []
    @Published var isLoadingDrills = false
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var currentPlayerRank: Int?
    @Published var isLoadingLeaderboard = false

    private var lastDocument: DocumentSnapshot?
    private var hasMorePosts = true
    private let pageSize = 20
    private var lastDrillDocument: DocumentSnapshot?
    private var hasMoreDrills = true
    private let drillPageSize = 20
    private var leaderboardLastFetch: Date?
    private let leaderboardCacheDuration: TimeInterval = 300

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

    // MARK: - Content Moderation

    /// Throws if any user-authored text trips the community language filter.
    /// Applied to posts, comments, and shared-drill title/description.
    private func assertCleanText(_ values: String...) throws {
        for value in values where CommunityTextFilter.containsBlocked(value) {
            throw CommunityContentError.inappropriateLanguage
        }
    }

    /// Public-facing identity: first name + last initial ("Evan Takahashi" -> "Evan T.").
    /// Full names are never broadcast to the community; local/profile screens keep the real name.
    /// `nonisolated` so SwiftUI views can call it synchronously off the main actor.
    nonisolated static func displayName(for fullName: String?) -> String {
        let trimmed = (fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Player" }
        let parts = trimmed.split(separator: " ").map(String.init)
        guard let first = parts.first else { return "Player" }
        guard parts.count > 1, let initial = parts.last?.first else { return first }
        return "\(first) \(initial)."
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

                // Auto-hidden (report threshold) content is dropped for everyone
                // except its author, who still sees it as a hidden placeholder.
                let isHidden = data["isHidden"] as? Bool ?? false
                guard !isHidden || authorID == userID else { return nil }

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
                    isReported: false,
                    isHidden: isHidden,
                    drillID: data["drillID"] as? String,
                    drillTitle: data["drillTitle"] as? String,
                    drillCategory: data["drillCategory"] as? String,
                    drillDifficulty: data["drillDifficulty"] as? Int,
                    drillSaveCount: data["drillSaveCount"] as? Int,
                    achievementName: data["achievementName"] as? String,
                    achievementIcon: data["achievementIcon"] as? String,
                    sessionDuration: data["sessionDuration"] as? Int,
                    sessionExerciseCount: data["sessionExerciseCount"] as? Int,
                    sessionRating: data["sessionRating"] as? Double,
                    sessionXP: data["sessionXP"] as? Int,
                    newLevel: data["newLevel"] as? Int,
                    rankName: data["rankName"] as? String
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
            print("CommunityService.fetchPosts error: \(error)")
            #endif
        }
    }

    // MARK: - Create Post

    func createPost(content: String, postType: CommunityPostType = .general, player: Player) async throws {
        let userID = try requireAuth()
        try assertCleanText(content)
        let authorName = Self.displayName(for: player.name)

        let postRef = db.collection("communityPosts").document()
        let postData: [String: Any] = [
            "authorID": userID,
            "authorName": authorName,
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
            authorName: authorName,
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

    // MARK: - Rich Post Creation (Opt-In Sharing)

    func createRichPost(
        content: String,
        postType: CommunityPostType,
        player: Player,
        metadata: [String: Any] = [:]
    ) async throws {
        let userID = try requireAuth()
        try assertCleanText(content)
        let authorName = Self.displayName(for: player.name)

        var postData: [String: Any] = [
            "authorID": userID,
            "authorName": authorName,
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

        for (key, value) in metadata {
            postData[key] = value
        }

        let postRef = db.collection("communityPosts").document()
        try await postRef.setData(postData)

        let newPost = CommunityPost(
            id: postRef.documentID,
            authorID: userID,
            authorName: authorName,
            authorLevel: Int(player.currentLevel),
            authorPosition: player.position ?? "",
            content: content,
            postType: postType,
            timestamp: Date(),
            likesCount: 0,
            commentsCount: 0,
            isLikedByCurrentUser: false,
            isReported: false,
            drillID: metadata["drillID"] as? String,
            drillTitle: metadata["drillTitle"] as? String,
            drillCategory: metadata["drillCategory"] as? String,
            drillDifficulty: metadata["drillDifficulty"] as? Int,
            drillSaveCount: nil,
            achievementName: metadata["achievementName"] as? String,
            achievementIcon: metadata["achievementIcon"] as? String,
            sessionDuration: metadata["sessionDuration"] as? Int,
            sessionExerciseCount: metadata["sessionExerciseCount"] as? Int,
            sessionRating: metadata["sessionRating"] as? Double,
            sessionXP: metadata["sessionXP"] as? Int,
            newLevel: metadata["newLevel"] as? Int,
            rankName: metadata["rankName"] as? String
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
        let userID = try requireAuth()

        let snapshot = try await db.collection("communityPosts").document(postID)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> CommunityComment? in
            let data = doc.data()
            let authorID = data["authorID"] as? String ?? ""
            guard !blockedUsers.contains(authorID) else { return nil }

            // Auto-hidden comments are dropped for everyone except their author.
            let isHidden = data["isHidden"] as? Bool ?? false
            guard !isHidden || authorID == userID else { return nil }

            return CommunityComment(
                id: doc.documentID,
                postID: postID,
                authorID: authorID,
                authorName: data["authorName"] as? String ?? "Player",
                authorLevel: data["authorLevel"] as? Int ?? 1,
                content: data["content"] as? String ?? "",
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                isReported: false,
                isHidden: isHidden
            )
        }
    }

    func addComment(to postID: String, content: String, player: Player) async throws {
        let userID = try requireAuth()
        try assertCleanText(content)

        let commentRef = db.collection("communityPosts").document(postID)
            .collection("comments").document()

        let commentData: [String: Any] = [
            "authorID": userID,
            "authorName": Self.displayName(for: player.name),
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

    // MARK: - Shared Drills

    func fetchSharedDrills(refresh: Bool = false, category: String? = nil, difficulty: Int? = nil) async {
        guard !isLoadingDrills else { return }
        #if DEBUG
        if TQDemoSeed.isRequested {
            sharedDrills = TQDemoSeed.sharedDrills(category: category)
            hasMoreDrills = false
            return
        }
        #endif

        if refresh {
            lastDrillDocument = nil
            hasMoreDrills = true
        }

        guard hasMoreDrills else { return }

        isLoadingDrills = true

        do {
            let userID = try requireAuth()

            var query: Query = db.collection("sharedDrills")
                .order(by: "timestamp", descending: true)
                .limit(to: drillPageSize)

            if let category = category {
                query = db.collection("sharedDrills")
                    .whereField("category", isEqualTo: category)
                    .order(by: "timestamp", descending: true)
                    .limit(to: drillPageSize)
            }

            if let lastDoc = lastDrillDocument {
                query = query.start(afterDocument: lastDoc)
            }

            let snapshot = try await query.getDocuments()

            let newDrills = snapshot.documents.compactMap { doc -> SharedDrill? in
                let data = doc.data()
                let authorID = data["authorID"] as? String ?? ""
                guard !blockedUsers.contains(authorID) else { return nil }

                // Auto-hidden drills are dropped for everyone except their author.
                let isHidden = data["isHidden"] as? Bool ?? false
                guard !isHidden || authorID == userID else { return nil }

                let savedBy = data["savedBy"] as? [String] ?? []

                return SharedDrill(
                    id: doc.documentID,
                    authorID: authorID,
                    authorName: data["authorName"] as? String ?? "Player",
                    authorLevel: data["authorLevel"] as? Int ?? 1,
                    title: data["title"] as? String ?? "Untitled Drill",
                    description: data["description"] as? String ?? "",
                    category: data["category"] as? String ?? "technical",
                    difficulty: data["difficulty"] as? Int ?? 3,
                    targetSkills: data["targetSkills"] as? [String] ?? [],
                    duration: data["duration"] as? Int ?? 15,
                    equipment: data["equipment"] as? [String] ?? [],
                    steps: data["steps"] as? [String] ?? [],
                    sets: data["sets"] as? Int ?? 3,
                    reps: data["reps"] as? Int ?? 10,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    saveCount: data["saveCount"] as? Int ?? 0,
                    isSavedByCurrentUser: savedBy.contains(userID),
                    reportCount: data["reportCount"] as? Int ?? 0,
                    isHidden: isHidden
                )
            }

            lastDrillDocument = snapshot.documents.last
            hasMoreDrills = snapshot.documents.count == drillPageSize

            if refresh {
                sharedDrills = newDrills
            } else {
                sharedDrills.append(contentsOf: newDrills)
            }

            isLoadingDrills = false
        } catch {
            isLoadingDrills = false
            #if DEBUG
            print("CommunityService.fetchSharedDrills error: \(error)")
            #endif
        }
    }

    func shareDrill(exercise: Exercise, player: Player) async throws {
        let userID = try requireAuth()
        try assertCleanText(exercise.name ?? "", exercise.exerciseDescription ?? "")
        let authorName = Self.displayName(for: player.name)

        let drillRef = db.collection("sharedDrills").document()
        let drillData: [String: Any] = [
            "authorID": userID,
            "authorName": authorName,
            "authorLevel": player.currentLevel,
            "title": exercise.name ?? "Untitled Drill",
            "description": exercise.exerciseDescription ?? "",
            "category": exercise.category ?? "technical",
            "difficulty": Int(exercise.difficulty),
            "targetSkills": exercise.targetSkills ?? [],
            "duration": 15,
            "equipment": [],
            "steps": (exercise.instructions ?? "").components(separatedBy: "\n").filter { !$0.isEmpty },
            "sets": 3,
            "reps": 10,
            "timestamp": FieldValue.serverTimestamp(),
            "saveCount": 0,
            "savedBy": [],
            "reportCount": 0,
            "reportedBy": []
        ]

        let postRef = db.collection("communityPosts").document()
        let postData: [String: Any] = [
            "authorID": userID,
            "authorName": authorName,
            "authorLevel": player.currentLevel,
            "authorPosition": player.position ?? "",
            "content": "Shared a drill: \(exercise.name ?? "Untitled")",
            "postType": CommunityPostType.sharedDrill.rawValue,
            "timestamp": FieldValue.serverTimestamp(),
            "likesCount": 0,
            "commentsCount": 0,
            "likedBy": [],
            "reportCount": 0,
            "reportedBy": [],
            "drillID": drillRef.documentID,
            "drillTitle": exercise.name ?? "Untitled Drill",
            "drillCategory": exercise.category ?? "technical",
            "drillDifficulty": Int(exercise.difficulty)
        ]

        let batch = db.batch()
        batch.setData(drillData, forDocument: drillRef)
        batch.setData(postData, forDocument: postRef)
        try await batch.commit()
    }

    func saveDrillToLibrary(drill: SharedDrill, player: Player, context: NSManagedObjectContext) async throws {
        let userID = try requireAuth()

        // Check 50 cap
        let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "communityDrillID != nil AND player == %@", player)
        let count = try context.count(for: fetchRequest)
        guard count < 50 else {
            throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Community drill library full (50 max). Remove a community drill to save new ones."])
        }

        guard !drill.isSavedByCurrentUser else { return }

        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = drill.title
        exercise.exerciseDescription = "[AI-Generated Custom Drill]\n\(drill.description)"
        exercise.category = drill.category
        exercise.difficulty = Int16(drill.difficulty)
        exercise.targetSkills = drill.targetSkills
        exercise.instructions = drill.steps.joined(separator: "\n")
        exercise.player = player
        exercise.communityAuthor = drill.authorName
        exercise.communityDrillID = drill.id

        try context.save()

        let drillRef = db.collection("sharedDrills").document(drill.id)
        try await drillRef.updateData([
            "saveCount": FieldValue.increment(Int64(1)),
            "savedBy": FieldValue.arrayUnion([userID])
        ])

        if let index = sharedDrills.firstIndex(where: { $0.id == drill.id }) {
            sharedDrills[index].saveCount += 1
            sharedDrills[index].isSavedByCurrentUser = true
        }
    }

    func reportDrill(_ drill: SharedDrill, reason: String) async throws {
        let userID = try requireAuth()

        try await db.collection("sharedDrills").document(drill.id).updateData([
            "reportCount": FieldValue.increment(Int64(1)),
            "reportedBy": FieldValue.arrayUnion([userID])
        ])

        try await db.collection("reports").document().setData([
            "drillID": drill.id,
            "reporterID": userID,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Shared Drills Count

    func fetchSharedDrillsCount(userID: String) async -> Int {
        let snapshot = try? await db.collection("sharedDrills")
            .whereField("authorID", isEqualTo: userID)
            .count
            .getAggregation(source: .server)
        return snapshot?.count.intValue ?? 0
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(forceRefresh: Bool = false) async {
        if !forceRefresh, let lastFetch = leaderboardLastFetch,
           Date().timeIntervalSince(lastFetch) < leaderboardCacheDuration,
           !leaderboard.isEmpty {
            return
        }

        guard !isLoadingLeaderboard else { return }
        isLoadingLeaderboard = true

        do {
            _ = try requireAuth()

            let snapshot = try await db.collectionGroup("playerProfiles")
                .order(by: "totalXP", descending: true)
                .limit(to: 100)
                .getDocuments()

            var entries: [LeaderboardEntry] = []
            for (index, doc) in snapshot.documents.enumerated() {
                let data = doc.data()
                entries.append(LeaderboardEntry(
                    id: doc.reference.parent.parent?.documentID ?? doc.documentID,
                    name: data["name"] as? String ?? "Player",
                    level: data["currentLevel"] as? Int ?? 1,
                    xp: (data["totalXP"] as? NSNumber)?.intValue ?? 0,
                    position: data["position"] as? String ?? "",
                    rank: index + 1
                ))
            }

            leaderboard = entries
            leaderboardLastFetch = Date()
            isLoadingLeaderboard = false
        } catch {
            isLoadingLeaderboard = false
            #if DEBUG
            print("CommunityService.fetchLeaderboard error: \(error)")
            #endif
        }
    }

    func fetchCurrentPlayerRank(playerXP: Int) async {
        do {
            _ = try requireAuth()

            let snapshot = try await db.collectionGroup("playerProfiles")
                .whereField("totalXP", isGreaterThan: playerXP)
                .count
                .getAggregation(source: .server)

            currentPlayerRank = snapshot.count.intValue + 1
        } catch {
            if let uid = currentUserID,
               let entry = leaderboard.first(where: { $0.id == uid }) {
                currentPlayerRank = entry.rank
            }
            #if DEBUG
            print("CommunityService.fetchCurrentPlayerRank error: \(error)")
            #endif
        }
    }

    // MARK: - Report User

    func reportUser(_ reportedUID: String, reason: String = "Inappropriate profile") async throws {
        let reporterID = try requireAuth()
        try await db.collection("reports").document().setData([
            "reportedUID": reportedUID,
            "reporterID": reporterID,
            "reason": reason,
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

// MARK: - Content Moderation

/// User-facing errors surfaced by the community text filter.
enum CommunityContentError: LocalizedError {
    case inappropriateLanguage

    var errorDescription: String? {
        switch self {
        case .inappropriateLanguage:
            return "Let's keep it friendly — try different words."
        }
    }
}

/// Lightweight client-side language filter for a kid-safe community.
/// Single source of truth for the blocklist; case- and leet-insensitive.
/// This is a first-pass guard, not a replacement for server-side moderation.
private enum CommunityTextFilter {
    // Fold common leetspeak / symbol substitutions so "sh1t", "f@g", "b!tch" match.
    private static let leetMap: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
        "7": "t", "8": "b", "9": "g", "@": "a", "$": "s", "!": "i"
    ]

    // Strong profanity, slurs, and sexual terms. Curated to be safe as
    // substrings of collapsed text — no ultra-short stems (e.g. "ass", "hell")
    // that hide inside ordinary soccer words like "pass" or "hello".
    private static let blockedStems: [String] = [
        "fuck", "motherfuck", "shit", "bullshit", "dipshit", "bitch", "asshole",
        "dumbass", "jackass", "bastard", "cunt", "pussy", "douche", "wanker",
        "bollocks", "cocksuck", "dickhead", "shithead", "fatass", "whore", "slut",
        "nigger", "nigga", "faggot", "retard", "kike", "chink", "wetback",
        "beaner", "gook", "tranny", "spearchuck", "towelhead",
        "porn", "blowjob", "handjob", "penis", "vagina", "boner", "jizz",
        "masturbat", "orgasm", "dildo", "creampie", "cumshot", "horny", "nudes", "nsfw",
        "idiot", "stupid", "worthless", "pathetic", "killyourself", "killurself"
    ]

    // Short/ambiguous tokens matched only as whole words (avoids "shoe"->"hoe",
    // "closer"->"loser", "snugly"->"ugly" style false positives).
    private static let blockedWords: Set<String> = [
        "loser", "losers", "moron", "morons", "ugly", "kys", "stfu", "gtfo",
        "fag", "fags", "hoe", "hoes", "twat", "twats", "slag"
    ]

    // Harassment / self-harm phrases matched against space-preserved text.
    private static let blockedPhrases: [String] = [
        "kill yourself", "kill your self", "kill urself", "hang yourself",
        "cut yourself", "go die", "you should die", "nobody likes you",
        "no one likes you", "everyone hates you", "hate you"
    ]

    static func containsBlocked(_ text: String) -> Bool {
        let folded = String(text.lowercased().map { leetMap[$0] ?? $0 })

        // Letters-only form catches spaced/punctuated evasions ("f u c k").
        let collapsed = String(folded.filter { $0.isLetter })
        if blockedStems.contains(where: { collapsed.contains($0) }) { return true }

        // Space-normalized form for whole-word and phrase checks.
        let spaced = String(folded.map { $0.isLetter ? $0 : " " })
        let words = spaced.split(separator: " ").map(String.init)
        if words.contains(where: { blockedWords.contains($0) }) { return true }

        let normalizedSpaced = words.joined(separator: " ")
        if blockedPhrases.contains(where: { normalizedSpaced.contains($0) }) { return true }

        return false
    }
}
