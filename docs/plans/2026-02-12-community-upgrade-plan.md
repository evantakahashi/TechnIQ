# Community Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add drill marketplace, global XP leaderboard, and enhanced feed with opt-in sharing to the Community tab.

**Architecture:** Extend existing CommunityService + CommunityView with 3 sub-tabs (Feed/Drills/Leaderboard). New `sharedDrills` Firestore collection for marketplace. Add 2 attributes to Exercise Core Data entity for community drill tracking. Reusable share sheet for opt-in posting from session complete, achievement unlock, level-up, and drill detail views.

**Tech Stack:** SwiftUI, Firebase Firestore, Core Data, existing DesignSystem + ModernComponents

**Design doc:** `docs/plans/2026-02-12-community-upgrade-design.md`

**Build command:** `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

---

### Task 1: Core Data — Add Community Drill Attributes to Exercise

**Files:**
- Modify: `TechnIQ/DataModel.xcdatamodeld/DataModel.xcdatamodel/contents` (add 2 attributes)
- Modify: `TechnIQ/Exercise+CoreDataProperties.swift` (add 2 properties)

**Step 1: Add attributes to Core Data model**

Open the `.xcdatamodel` XML and add to the `Exercise` entity:
- `communityAuthor` — Optional String
- `communityDrillID` — Optional String

These are additive changes so lightweight migration handles them automatically.

**Step 2: Add properties to Exercise+CoreDataProperties.swift**

After the existing `technicalComplexity` property (line 37), add:

```swift
// Community drill tracking
@NSManaged public var communityAuthor: String?
@NSManaged public var communityDrillID: String?
```

**Step 3: Add computed property for community drill detection**

In `ExerciseLibraryView.swift` where the `Exercise` extension lives (after `isAIGenerated`, around line 878), add:

```swift
var isCommunityDrill: Bool {
    communityDrillID != nil
}
```

**Step 4: Build to verify**

Run build command. Expected: BUILD SUCCEEDED. Lightweight migration auto-infers.

**Step 5: Commit**

```bash
git add TechnIQ/DataModel.xcdatamodeld TechnIQ/Exercise+CoreDataProperties.swift TechnIQ/ExerciseLibraryView.swift
git commit -m "feat: add communityAuthor and communityDrillID to Exercise entity"
```

---

### Task 2: Data Models — New Types for Drills, Leaderboard, Enhanced Posts

**Files:**
- Modify: `TechnIQ/CommunityService.swift` (lines 7-60, models section)

**Step 1: Extend CommunityPostType with new cases**

Add new cases to the enum after `milestone`:

```swift
case sharedDrill = "shared_drill"
case sharedAchievement = "shared_achievement"
case sharedSession = "shared_session"
case sharedLevelUp = "shared_levelup"
```

Update the `icon` computed property:
```swift
case .sharedDrill: return "square.and.arrow.up.fill"
case .sharedAchievement: return "trophy.fill"
case .sharedSession: return "checkmark.circle.fill"
case .sharedLevelUp: return "arrow.up.circle.fill"
```

Update `displayName`:
```swift
case .sharedDrill: return "Drill"
case .sharedAchievement: return "Achievement"
case .sharedSession: return "Session"
case .sharedLevelUp: return "Level Up"
```

**Step 2: Add optional metadata fields to CommunityPost**

Add after `isReported`:

```swift
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
```

Update the `==` function to still compare by `id`, `likesCount`, `commentsCount`, `isLikedByCurrentUser` (no change needed since new fields aren't in the equality check).

**Step 3: Add SharedDrill model**

Add after CommunityComment:

```swift
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
}
```

**Step 4: Add LeaderboardEntry model**

```swift
struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let level: Int
    let xp: Int
    let position: String
    let rank: Int
}
```

**Step 5: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

Note: Adding new cases to `CommunityPostType` may cause exhaustive switch errors in `CommunityPostCard.postTypeColor` and `CreatePostView`'s ForEach over `CommunityPostType.allCases`. Fix these:
- `postTypeColor`: add cases returning `primaryGreen` for sharedDrill/sharedSession, `accentGold` for sharedAchievement/sharedLevelUp
- `CreatePostView`: filter `allCases` to only show the original 4 manual types: `.filter { [.general, .sessionComplete, .achievement, .milestone].contains($0) }`

**Step 6: Commit**

```bash
git add TechnIQ/CommunityService.swift TechnIQ/CommunityFeedView.swift TechnIQ/CreatePostView.swift
git commit -m "feat: add SharedDrill, LeaderboardEntry models and new post types"
```

---

### Task 3: CommunityService — Drill Sharing & Saving

**Files:**
- Modify: `TechnIQ/CommunityService.swift` (add new section after block user)

**Step 1: Add published properties for drills**

After the existing `@Published var blockedUsers`:

```swift
@Published var sharedDrills: [SharedDrill] = []
@Published var isLoadingDrills = false
private var lastDrillDocument: DocumentSnapshot?
private var hasMoreDrills = true
private let drillPageSize = 20
```

**Step 2: Add fetchSharedDrills method**

```swift
// MARK: - Shared Drills

func fetchSharedDrills(refresh: Bool = false, category: String? = nil, difficulty: Int? = nil) async {
    guard !isLoadingDrills else { return }

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
                reportCount: data["reportCount"] as? Int ?? 0
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
        print("❌ CommunityService.fetchSharedDrills error: \(error)")
        #endif
    }
}
```

**Step 3: Add shareDrill method**

```swift
func shareDrill(exercise: Exercise, player: Player) async throws {
    let userID = try requireAuth()

    // Create shared drill document
    let drillRef = db.collection("sharedDrills").document()
    let drillData: [String: Any] = [
        "authorID": userID,
        "authorName": player.name ?? "Player",
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

    // Create feed post referencing the drill
    let postRef = db.collection("communityPosts").document()
    let postData: [String: Any] = [
        "authorID": userID,
        "authorName": player.name ?? "Player",
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

    // Batch write both
    let batch = db.batch()
    batch.setData(drillData, forDocument: drillRef)
    batch.setData(postData, forDocument: postRef)
    try await batch.commit()
}
```

**Step 4: Add saveDrillToLibrary method**

```swift
func saveDrillToLibrary(drill: SharedDrill, player: Player, context: NSManagedObjectContext) async throws {
    let userID = try requireAuth()

    // Check 50 cap
    let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "communityDrillID != nil AND player == %@", player)
    let count = try context.count(for: fetchRequest)
    guard count < 50 else {
        throw NSError(domain: "CommunityService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Community drill library full (50 max). Remove a community drill to save new ones."])
    }

    // Check not already saved
    guard !drill.isSavedByCurrentUser else { return }

    // Create Exercise entity
    let exercise = Exercise(context: context)
    exercise.id = UUID()
    exercise.name = drill.title
    exercise.exerciseDescription = "🤖 AI-Generated Custom Drill\n\(drill.description)"
    exercise.category = drill.category
    exercise.difficulty = Int16(drill.difficulty)
    exercise.targetSkills = drill.targetSkills
    exercise.instructions = drill.steps.joined(separator: "\n")
    exercise.player = player
    exercise.communityAuthor = drill.authorName
    exercise.communityDrillID = drill.id

    try context.save()

    // Update Firestore save count
    let drillRef = db.collection("sharedDrills").document(drill.id)
    try await drillRef.updateData([
        "saveCount": FieldValue.increment(Int64(1)),
        "savedBy": FieldValue.arrayUnion([userID])
    ])

    // Update local model
    if let index = sharedDrills.firstIndex(where: { $0.id == drill.id }) {
        sharedDrills[index].saveCount += 1
        sharedDrills[index].isSavedByCurrentUser = true
    }
}
```

**Step 5: Add reportDrill method**

```swift
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
```

**Step 6: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 7: Commit**

```bash
git add TechnIQ/CommunityService.swift
git commit -m "feat: add drill sharing, saving, and marketplace fetch to CommunityService"
```

---

### Task 4: CommunityService — Leaderboard

**Files:**
- Modify: `TechnIQ/CommunityService.swift` (append new section)

**Step 1: Add published properties for leaderboard**

After the drill properties:

```swift
@Published var leaderboard: [LeaderboardEntry] = []
@Published var currentPlayerRank: Int?
@Published var isLoadingLeaderboard = false
private var leaderboardLastFetch: Date?
private let leaderboardCacheDuration: TimeInterval = 300 // 5 min
```

**Step 2: Add fetchLeaderboard method**

```swift
// MARK: - Leaderboard

func fetchLeaderboard(forceRefresh: Bool = false) async {
    // Cache check
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
        print("❌ CommunityService.fetchLeaderboard error: \(error)")
        #endif
    }
}
```

**Step 3: Add fetchCurrentPlayerRank method**

```swift
func fetchCurrentPlayerRank(playerXP: Int) async {
    do {
        _ = try requireAuth()

        let snapshot = try await db.collectionGroup("playerProfiles")
            .whereField("totalXP", isGreaterThan: playerXP)
            .count
            .getAggregation(source: .server)

        currentPlayerRank = snapshot.count.intValue + 1
    } catch {
        // Fallback: check position in loaded leaderboard
        if let uid = currentUserID,
           let entry = leaderboard.first(where: { $0.id == uid }) {
            currentPlayerRank = entry.rank
        }
        #if DEBUG
        print("❌ CommunityService.fetchCurrentPlayerRank error: \(error)")
        #endif
    }
}
```

**Step 4: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add TechnIQ/CommunityService.swift
git commit -m "feat: add leaderboard fetch with 5-min cache and rank calculation"
```

---

### Task 5: CommunityService — Enhanced Post Creation & Parsing

**Files:**
- Modify: `TechnIQ/CommunityService.swift`

**Step 1: Add createRichPost method for opt-in sharing**

```swift
// MARK: - Rich Post Creation (Opt-In Sharing)

func createRichPost(
    content: String,
    postType: CommunityPostType,
    player: Player,
    metadata: [String: Any] = [:]
) async throws {
    let userID = try requireAuth()

    var postData: [String: Any] = [
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

    // Merge metadata (session stats, achievement info, level info)
    for (key, value) in metadata {
        postData[key] = value
    }

    let postRef = db.collection("communityPosts").document()
    try await postRef.setData(postData)

    // Build local post
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
```

**Step 2: Update fetchPosts to parse new metadata fields**

In the existing `fetchPosts` method, update the `CommunityPost` init inside the `compactMap` to include the new optional fields:

After `isReported: false` add:
```swift
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
```

Also update the existing `createPost` method's local CommunityPost init to include nil for all new fields.

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/CommunityService.swift
git commit -m "feat: add rich post creation and metadata parsing for enhanced feed"
```

---

### Task 6: ShareToCommunitySheet — Reusable Share Sheet

**Files:**
- Create: `TechnIQ/ShareToCommunitySheet.swift`

**Step 1: Create the share sheet view**

```swift
import SwiftUI

struct ShareToCommunitySheet: View {
    let shareType: ShareType
    let player: Player
    let onDismiss: () -> Void

    @StateObject private var communityService = CommunityService.shared
    @State private var additionalText = ""
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var shareSuccess = false

    private let maxCharacters = 300

    enum ShareType {
        case drill(Exercise)
        case session(duration: Int, exerciseCount: Int, rating: Double, xp: Int)
        case achievement(name: String, icon: String)
        case levelUp(level: Int, rankName: String)

        var postType: CommunityPostType {
            switch self {
            case .drill: return .sharedDrill
            case .session: return .sharedSession
            case .achievement: return .sharedAchievement
            case .levelUp: return .sharedLevelUp
            }
        }

        var previewTitle: String {
            switch self {
            case .drill(let exercise): return exercise.name ?? "Untitled Drill"
            case .session: return "Training Complete"
            case .achievement(let name, _): return name
            case .levelUp(let level, let rank): return "Level \(level) — \(rank)"
            }
        }

        var previewIcon: String {
            switch self {
            case .drill: return "square.and.arrow.up.fill"
            case .session: return "checkmark.circle.fill"
            case .achievement(_, let icon): return icon
            case .levelUp: return "arrow.up.circle.fill"
            }
        }

        var accentColor: Color {
            switch self {
            case .drill, .session: return DesignSystem.Colors.primaryGreen
            case .achievement, .levelUp: return DesignSystem.Colors.accentGold
            }
        }

        var defaultContent: String {
            switch self {
            case .drill(let exercise): return "Check out this drill: \(exercise.name ?? "Untitled")"
            case .session(let duration, let count, _, let xp):
                return "Just finished a \(duration) min session with \(count) exercises! +\(xp) XP"
            case .achievement(let name, _): return "Achievement unlocked: \(name)!"
            case .levelUp(let level, let rank): return "Just reached Level \(level) — \(rank)!"
            }
        }

        var metadata: [String: Any] {
            switch self {
            case .drill(let exercise):
                return [
                    "drillTitle": exercise.name ?? "Untitled",
                    "drillCategory": exercise.category ?? "technical",
                    "drillDifficulty": Int(exercise.difficulty)
                ]
            case .session(let duration, let count, let rating, let xp):
                return [
                    "sessionDuration": duration,
                    "sessionExerciseCount": count,
                    "sessionRating": rating,
                    "sessionXP": xp
                ]
            case .achievement(let name, let icon):
                return [
                    "achievementName": name,
                    "achievementIcon": icon
                ]
            case .levelUp(let level, let rank):
                return [
                    "newLevel": level,
                    "rankName": rank
                ]
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Preview card
                        previewCard

                        // Optional text
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Add a message (optional)")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            ZStack(alignment: .topLeading) {
                                if additionalText.isEmpty {
                                    Text("Say something about this...")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                        .padding(.top, DesignSystem.Spacing.md)
                                        .padding(.leading, DesignSystem.Spacing.md)
                                }
                                TextEditor(text: $additionalText)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(DesignSystem.Spacing.sm)
                                    .frame(minHeight: 80)
                                    .onChange(of: additionalText) {
                                        if additionalText.count > maxCharacters {
                                            additionalText = String(additionalText.prefix(maxCharacters))
                                        }
                                    }
                            }
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                            HStack {
                                Spacer()
                                Text("\(additionalText.count)/\(maxCharacters)")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }

                        if let error = shareError {
                            Text(error)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                // Share button
                VStack {
                    ModernButton("Share to Community", icon: "paperplane.fill", style: .primary) {
                        share()
                    }
                    .disabled(isSharing)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .overlay {
                if isSharing {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    LoadingStateView(message: "Sharing...")
                }
                if shareSuccess {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("Shared!")
                            .font(DesignSystem.Typography.headlineMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .background(DesignSystem.Colors.surfaceOverlay)
                    .cornerRadius(DesignSystem.CornerRadius.xl)
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: shareType.previewIcon)
                    .font(.title2)
                    .foregroundColor(shareType.accentColor)
                    .frame(width: 44, height: 44)
                    .background(shareType.accentColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(shareType.previewTitle)
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(shareType.postType.displayName)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(shareType.accentColor)
                }

                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func share() {
        isSharing = true
        shareError = nil

        let content = additionalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? shareType.defaultContent
            : additionalText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                // For drills, also create the sharedDrills doc
                if case .drill(let exercise) = shareType {
                    try await communityService.shareDrill(exercise: exercise, player: player)
                } else {
                    try await communityService.createRichPost(
                        content: content,
                        postType: shareType.postType,
                        player: player,
                        metadata: shareType.metadata
                    )
                }

                HapticManager.shared.success()
                shareSuccess = true

                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onDismiss()
            } catch {
                shareError = error.localizedDescription
                isSharing = false
                HapticManager.shared.error()
            }
        }
    }
}
```

**Step 2: Add file to Xcode project if needed**

New .swift file in TechnIQ/ directory. May need ruby script to add to pbxproj (same pattern as Task 13 from UI foundation plan).

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/ShareToCommunitySheet.swift
git commit -m "feat: add reusable ShareToCommunitySheet for opt-in sharing"
```

---

### Task 7: CommunityView — Segment Control Host

**Files:**
- Modify: `TechnIQ/CommunityView.swift` (replace entire file)

**Step 1: Replace CommunityView with tabbed layout**

```swift
import SwiftUI

struct CommunityView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Segment control
            ModernSegmentControl(
                options: ["Feed", "Drills", "Leaderboard"],
                selectedIndex: $selectedTab,
                icons: ["bubble.left.fill", "figure.run", "trophy.fill"]
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)

            // Tab content
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
```

**Step 2: Remove `.navigationTitle` from CommunityFeedView**

In `CommunityFeedView.swift`, remove line 91: `.navigationTitle("Community")` and line 92: `.navigationBarTitleDisplayMode(.large)` — the parent now owns the nav title.

**Step 3: Build to verify**

Run build command. Expected: May fail because `DrillMarketplaceView` and `LeaderboardView` don't exist yet. Create placeholder files:

`TechnIQ/DrillMarketplaceView.swift`:
```swift
import SwiftUI

struct DrillMarketplaceView: View {
    var body: some View {
        Text("Drill Marketplace — Coming Soon")
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
}
```

`TechnIQ/LeaderboardView.swift`:
```swift
import SwiftUI

struct LeaderboardView: View {
    var body: some View {
        Text("Leaderboard — Coming Soon")
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
}
```

Build again. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/CommunityView.swift TechnIQ/CommunityFeedView.swift TechnIQ/DrillMarketplaceView.swift TechnIQ/LeaderboardView.swift
git commit -m "feat: restructure Community with Feed/Drills/Leaderboard tabs"
```

---

### Task 8: DrillMarketplaceView — Full Implementation

**Files:**
- Modify: `TechnIQ/DrillMarketplaceView.swift` (replace placeholder)

**Step 1: Implement drill marketplace**

Full view with:
- Search bar at top
- Category filter chips (All, Technical, Tactical, Physical)
- Grid of drill cards showing: title, author, category badge, difficulty dots, save count
- Infinite scroll pagination
- Tap card → SharedDrillDetailView sheet
- Pull-to-refresh
- Empty state when no drills
- Loading state

Each drill card is a `ModernCard` with:
- Title in `headlineSmall`
- Author name with "by" prefix
- Category `GlowBadge`
- Difficulty as filled/empty circles
- Save count with download icon
- Accent edge (emerald for technical, gold for tactical, orange for physical)

**Step 2: Build to verify**

Run build command. Expected: May fail if SharedDrillDetailView doesn't exist. Create placeholder first.

**Step 3: Commit**

```bash
git add TechnIQ/DrillMarketplaceView.swift
git commit -m "feat: implement DrillMarketplaceView with search, filters, and grid"
```

---

### Task 9: SharedDrillDetailView — Drill Preview & Save

**Files:**
- Create: `TechnIQ/SharedDrillDetailView.swift`

**Step 1: Implement drill detail sheet**

Full view showing:
- Drill title (headlineLarge)
- Author attribution ("Created by {name}" with level badge)
- Category + difficulty badges
- Target skills as pills
- Equipment list (if any)
- Duration estimate
- Step-by-step instructions (numbered list)
- Sets × Reps info
- Save count display
- "Save to Library" button (ModernButton primary)
  - Disabled if already saved (show "Saved" state)
  - Shows error alert if at 50 cap
- Report button in toolbar

Uses `@Environment(\.managedObjectContext)` and `@EnvironmentObject` for AuthenticationManager to get player for saving.

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/SharedDrillDetailView.swift
git commit -m "feat: implement SharedDrillDetailView with save-to-library"
```

---

### Task 10: LeaderboardView — Full Implementation

**Files:**
- Modify: `TechnIQ/LeaderboardView.swift` (replace placeholder)

**Step 1: Implement leaderboard**

Full view with:
- **Podium section** (top 3):
  - 3 columns: 2nd (left), 1st (center, taller), 3rd (right)
  - Each: avatar circle with rank number overlay, name, level, XP
  - 1st gets gold ring, 2nd silver, 3rd bronze
  - Stagger reveal animation
- **Ranked list** (4-100):
  - Each row: rank number, avatar circle, name, level badge, XP (right-aligned)
  - Alternate row backgrounds for readability
  - Stagger reveal
- **Sticky "Your Rank" bar** at bottom:
  - Fixed position, surfaceOverlay background
  - Shows current player rank, name, XP
  - If player is in top 100, highlight their row in the list too
- Pull-to-refresh (forces cache bypass)
- Tap any row → PublicProfileView sheet
- Loading state with SoccerBallSpinner

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/LeaderboardView.swift
git commit -m "feat: implement LeaderboardView with podium, ranked list, and sticky rank bar"
```

---

### Task 11: Enhanced Feed Cards — Rich Post Types

**Files:**
- Modify: `TechnIQ/CommunityFeedView.swift` (CommunityPostCard)

**Step 1: Update CommunityPostCard to render rich cards**

After the existing `// Content` section (line 252), add conditional rendering based on post type:

For `sharedDrill` posts — show drill mini-card below content:
- Drill title in bold
- Category badge + difficulty dots
- Save count
- "Save" button that calls `communityService.saveDrillToLibrary`

For `sharedAchievement` posts — show achievement display:
- Achievement icon in gold glow circle
- Achievement name with GlowBadge

For `sharedSession` posts — show session stats row:
- Duration, exercise count, rating stars, XP earned in a horizontal stat bar

For `sharedLevelUp` posts — show level display:
- Big level number (displaySmall)
- Rank name with GlowBadge

For existing types (general, sessionComplete, achievement, milestone) — no change, plain text content.

**Step 2: Update postTypeColor for new types**

Add cases to the switch in `CommunityPostCard`:
```swift
case .sharedDrill: return DesignSystem.Colors.primaryGreen
case .sharedSession: return DesignSystem.Colors.primaryGreen
case .sharedAchievement: return DesignSystem.Colors.accentGold
case .sharedLevelUp: return DesignSystem.Colors.accentGold
```

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/CommunityFeedView.swift
git commit -m "feat: add rich card rendering for shared drills, achievements, sessions, level-ups"
```

---

### Task 12: Share Buttons — ExerciseDetailView + SessionCompleteView

**Files:**
- Modify: `TechnIQ/ExerciseDetailView.swift`
- Modify: `TechnIQ/SessionCompleteView.swift`

**Step 1: Add share button to ExerciseDetailView**

Add a `@State private var showingShareSheet = false` property.

After the "Start Drill" button (around line 65), add a conditional share button:

```swift
if isAIGeneratedDrill {
    Button {
        showingShareSheet = true
    } label: {
        HStack {
            Image(systemName: "square.and.arrow.up")
            Text("Share to Community")
                .fontWeight(.semibold)
        }
        .foregroundColor(DesignSystem.Colors.primaryGreen)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
        .cornerRadius(DesignSystem.CornerRadius.button)
    }
}
```

Add sheet modifier:
```swift
.sheet(isPresented: $showingShareSheet) {
    ShareToCommunitySheet(
        shareType: .drill(exercise),
        player: exercise.player!,
        onDismiss: { showingShareSheet = false }
    )
}
```

**Step 2: Add share button to SessionCompleteView**

Add `@State private var showingShareSheet = false` property.

After the dismiss button at the bottom of the view, add:

```swift
Button {
    showingShareSheet = true
} label: {
    HStack {
        Image(systemName: "square.and.arrow.up")
        Text("Share to Community")
            .fontWeight(.semibold)
    }
    .foregroundColor(DesignSystem.Colors.primaryGreen)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
    .cornerRadius(DesignSystem.CornerRadius.button)
}
```

Add sheet modifier with session data:
```swift
.sheet(isPresented: $showingShareSheet) {
    ShareToCommunitySheet(
        shareType: .session(
            duration: Int(xpBreakdown?.baseXP ?? 0) / 2,
            exerciseCount: Int(xpBreakdown?.exerciseCount ?? 0),
            rating: xpBreakdown?.averageRating ?? 0,
            xp: Int(xpBreakdown?.totalXP ?? 0)
        ),
        player: player,
        onDismiss: { showingShareSheet = false }
    )
}
```

Note: The exact session duration/exercise count fields depend on what `XPService.SessionXPBreakdown` exposes. Read that struct to get the correct field names. Adjust as needed.

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/ExerciseDetailView.swift TechnIQ/SessionCompleteView.swift
git commit -m "feat: add Share to Community buttons on drill detail and session complete"
```

---

### Task 13: PostDetailView — Handle Rich Post Types

**Files:**
- Modify: `TechnIQ/PostDetailView.swift`

**Step 1: Update postSection to render rich content**

In the `postSection` computed property, after the content Text (line 132), add conditional rich content rendering matching the same patterns from Task 11 (drill mini-card, achievement badge, session stats, level display).

This ensures when users tap into a post detail, they see the same rich card content as the feed.

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/PostDetailView.swift
git commit -m "feat: render rich post types in PostDetailView"
```

---

### Task 14: PublicProfileView — Shared Drills Count

**Files:**
- Modify: `TechnIQ/PublicProfileView.swift`

**Step 1: Add shared drills count to profile stats**

In the stats section, add a stat card for "Shared Drills" count. This requires a new query in CommunityService:

```swift
func fetchSharedDrillsCount(userID: String) async -> Int {
    let snapshot = try? await db.collection("sharedDrills")
        .whereField("authorID", isEqualTo: userID)
        .count
        .getAggregation(source: .server)
    return snapshot?.count.intValue ?? 0
}
```

Add to PublicProfileView:
- `@State private var sharedDrillsCount = 0`
- Fetch on appear alongside existing profile fetch
- Display as additional StatCard in the stats section

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/PublicProfileView.swift TechnIQ/CommunityService.swift
git commit -m "feat: show shared drills count on public profiles"
```

---

### Task 15: Add New Files to Xcode Project

**Files:**
- Modify: `TechnIQ.xcodeproj/project.pbxproj`

**Step 1: Verify new files compile**

Run build. If `ShareToCommunitySheet.swift`, `DrillMarketplaceView.swift`, `SharedDrillDetailView.swift`, `LeaderboardView.swift` aren't picked up, add via ruby script:

```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('TechnIQ.xcodeproj')
target = project.targets.find { |t| t.name == 'TechnIQ' }
group = project.main_group.find_subpath('TechnIQ', true)

['ShareToCommunitySheet.swift', 'DrillMarketplaceView.swift', 'SharedDrillDetailView.swift', 'LeaderboardView.swift'].each do |filename|
  ref = group.new_file(filename)
  target.source_build_phase.add_file_reference(ref)
end

project.save
```

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ.xcodeproj/project.pbxproj
git commit -m "chore: add new community files to Xcode project"
```

---

### Task 16: Final Build Verification

**Files:** None (verification only)

**Step 1: Clean build**

```bash
xcodebuild clean -scheme TechnIQ -sdk iphonesimulator
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build
```

Expected: BUILD SUCCEEDED with 0 errors.

**Step 2: Verify no regressions**

Confirm:
- CommunityView shows 3 tabs
- CommunityFeedView compiles with new post type handling
- All new files compile
- Exercise entity has new attributes
- No broken references

**Step 3: Commit tag**

```bash
git tag community-upgrade-v1
```

---

## Summary

| Task | File(s) | What |
|------|---------|------|
| 1 | DataModel + Exercise+CoreDataProperties | Add communityAuthor, communityDrillID |
| 2 | CommunityService (models) | SharedDrill, LeaderboardEntry, new post types |
| 3 | CommunityService | Drill sharing, saving, marketplace fetch |
| 4 | CommunityService | Leaderboard fetch + rank calculation |
| 5 | CommunityService | Rich post creation + metadata parsing |
| 6 | ShareToCommunitySheet (new) | Reusable share sheet |
| 7 | CommunityView | Segment control with 3 tabs |
| 8 | DrillMarketplaceView (new) | Drill browse/search/filter/save |
| 9 | SharedDrillDetailView (new) | Drill preview + save to library |
| 10 | LeaderboardView (new) | Podium + ranked list + sticky rank |
| 11 | CommunityFeedView | Rich card rendering for new types |
| 12 | ExerciseDetailView + SessionCompleteView | Share buttons |
| 13 | PostDetailView | Rich type rendering in detail |
| 14 | PublicProfileView + CommunityService | Shared drills count |
| 15 | project.pbxproj | Add new files to Xcode |
| 16 | — | Clean build verification |
