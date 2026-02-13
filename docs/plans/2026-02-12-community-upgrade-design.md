# Community Section Upgrade — Design Document

**Date:** 2026-02-12
**Approach:** Unified Feed + Tabs (Feed / Drills / Leaderboard)
**Inspiration:** Train Effective community model — drill sharing + competitive motivation

---

## 1. Community Tab Structure

3 sub-tabs via `ModernSegmentControl`:

**[ Feed | Drills | Leaderboard ]**

- **Feed** — Enhanced current feed. Manual text posts + rich cards for shared drills, achievements, sessions, level-ups. All sharing opt-in. Likes/comments/block/report preserved.
- **Drills** — Marketplace. Browse/search/filter community-shared AI drills. Save to library (copy model, 50 cap).
- **Leaderboard** — Global XP ranking. Podium top 3 + ranked list. Tap → PublicProfileView.

Host: `CommunityView.swift` with segment control + 3 sub-views.

---

## 2. Drill Marketplace — Data Model & Sharing Flow

### Firestore Collection: `sharedDrills`

```
sharedDrills/{drillId}
├── id: String (doc ID)
├── authorID: String (Firebase UID)
├── authorName: String
├── authorLevel: Int
├── title: String
├── description: String
├── category: String ("technical" | "tactical" | "physical")
├── difficulty: Int (1-5)
├── targetSkills: [String]
├── duration: Int (minutes)
├── equipment: [String]
├── steps: [String]
├── sets: Int
├── reps: Int
├── timestamp: Timestamp
├── saveCount: Int
├── savedBy: [String]
├── reportCount: Int
├── reportedBy: [String]
```

### Sharing Flow

1. Player opens AI drill in ExerciseDetailView
2. "Share to Community" button (only on `isAIGenerated` drills)
3. Creates `sharedDrills` doc + `communityPosts` doc with `postType: "shared_drill"` and `drillID` reference
4. Feed shows rich drill card

### Save Flow

1. Browse Drills tab or tap drill card in feed
2. See drill detail sheet (preview, steps, stats)
3. "Save to Library" → new `Exercise` Core Data entity with all fields copied
4. `communityAuthor` field stores creator name (attribution)
5. `communityDrillID` field stores original drill ID (deduplication)
6. Increments `saveCount`, adds user to `savedBy`

### 50 Drill Cap

- Count local exercises where `communityDrillID != nil`
- If >= 50, alert: "Library full. Remove a community drill to save new ones."

### Core Data Change

Add 2 optional String attributes to `Exercise` entity:
- `communityAuthor: String?`
- `communityDrillID: String?`
- Lightweight migration (additive)

---

## 3. Enhanced Feed — New Post Types & Share Prompts

### New Post Types

| Type | Trigger | Card Content |
|------|---------|-------------|
| `shared_drill` | Player shares AI drill | Drill title, category badge, difficulty, save count, inline "Save" button |
| `shared_achievement` | Player opts to share from achievement unlock | Achievement name, icon, GlowBadge with rarity |
| `shared_session` | Player opts to share from session complete | Duration, exercise count, rating, XP earned |
| `shared_levelup` | Player opts to share from level-up | Level number, rank name, XP bar |

Existing types preserved: `general`, `sessionComplete`, `achievement`, `milestone`.

### Share Prompts (Opt-In)

- `SessionCompleteView` — "Share to Community" button below XP summary
- Achievement unlock toast — "Share" action
- Level-up celebration — "Share" button
- `ExerciseDetailView` — "Share to Community" on AI drills

All share prompts use reusable `ShareToCommunitySheet` — preview of post, optional text, "Share" button.

### Feed Card Rendering

- `shared_drill` — Emerald accent edge, drill preview, inline "Save"
- `shared_achievement` — Gold accent edge, achievement icon + GlowBadge
- `shared_session` — Emerald accent edge, stat row, XP earned
- `shared_levelup` — Gold accent edge, big level number, rank name
- `general` — No accent edge, plain text (current)

All card types support likes, comments, report/block.

### New Firestore Fields on `communityPosts`

All optional — existing posts unaffected:
- `drillID: String?` — ref to sharedDrills (shared_drill)
- `achievementName: String?` — (shared_achievement)
- `achievementIcon: String?` — SF Symbol
- `sessionDuration: Int?` — minutes (shared_session)
- `sessionExerciseCount: Int?`
- `sessionRating: Double?`
- `sessionXP: Int?`
- `newLevel: Int?` — (shared_levelup)
- `rankName: String?`

---

## 4. Leaderboard

### Data Source

`collectionGroup("playerProfiles")` ordered by XP descending, limit 100. No new collection needed — reads existing player data.

Requires Firestore composite index: `playerProfiles` collectionGroup, `xp DESC`.

### View Layout

- **Podium** — Top 3: 1st center/large, 2nd left, 3rd right. Avatar circles, names, levels, XP.
- **Ranked list** — Positions 4-100: rank number, mini avatar, name, level badge, XP.
- **Sticky "Your Rank"** bar at bottom — current player's rank (query: count where XP > currentPlayer.xp + 1).
- Pull-to-refresh.
- Tap row → `PublicProfileView`.

### Caching

5-minute local cache. Same throttle pattern as CloudSyncManager.

### New Model

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

### CommunityService Additions

```swift
@Published var leaderboard: [LeaderboardEntry] = []
@Published var currentPlayerRank: Int? = nil

func fetchLeaderboard()
func fetchCurrentPlayerRank(xp: Int)
```

---

## 5. New & Modified Files

### New Files (4)

| File | Purpose |
|------|---------|
| `DrillMarketplaceView.swift` | Drills tab — grid of shared drills, search, filters |
| `SharedDrillDetailView.swift` | Drill preview sheet — full info, "Save to Library" |
| `LeaderboardView.swift` | Leaderboard tab — podium, ranked list, "Your Rank" |
| `ShareToCommunitySheet.swift` | Reusable share sheet — preview + optional text + share button |

### Modified Files (9)

| File | Change |
|------|--------|
| `CommunityView.swift` | Segment control host (Feed / Drills / Leaderboard) |
| `CommunityFeedView.swift` | New card types, inline save on drill cards |
| `CommunityService.swift` | Drill sharing, saving, leaderboard, new post types |
| `CreatePostView.swift` | Minor — keep for manual "general" posts |
| `PostDetailView.swift` | Handle new post types in detail view |
| `ExerciseDetailView.swift` | "Share to Community" button on AI drills |
| `SessionCompleteView.swift` | "Share to Community" button |
| `PublicProfileView.swift` | "Shared Drills" count, link to drills |
| `DataModel.xcdatamodeld` | Add communityAuthor, communityDrillID to Exercise |

### Unchanged

ModernComponents, HapticManager, TransitionSystem — existing foundation sufficient.

---

## 6. Firestore Security & Indexes

### Security Rules

```
sharedDrills/{drillId}:
  read: authenticated
  create: authenticated && request.auth.uid == request.resource.data.authorID
  update: authenticated (saveCount/savedBy only — field-level validation)
  delete: authenticated && request.auth.uid == resource.data.authorID
```

Existing `communityPosts` rules unchanged — new types use same structure.

### Indexes

1. `sharedDrills` — `timestamp DESC`
2. `sharedDrills` — `category ASC, timestamp DESC`
3. `sharedDrills` — `difficulty ASC, timestamp DESC`
4. `playerProfiles` collectionGroup — `xp DESC`

### Rate Limits

- Share: max 10 drills/day/user (client + rules)
- Save: 50 cap (client-side)
- Leaderboard: 5-min cache
