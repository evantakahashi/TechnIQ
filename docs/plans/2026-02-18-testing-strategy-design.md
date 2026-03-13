# Testing Strategy Design

## Goal
Full testing culture via Protocol + Init Injection (Approach A). Unit tests for 6 core services + UI smoke tests for 5 key flows.

## Approach
Define protocols for each service's public API. Keep `static let shared` for production. Tests use mocks or direct instantiation with in-memory Core Data.

## Phase 1 Services (6)

| Service | Key Test Areas | Est. Tests |
|---------|---------------|------------|
| XPService | XP math, level thresholds, streak, session completion | ~15 |
| CoinService | Balance ops, insufficient funds, session/level coin awards | ~10 |
| AchievementService | Unlock logic, progress calc, idempotency, all requirement types | ~15 |
| TrainingPlanService | Plan CRUD, activation, completion-based progression, cascade delete | ~10 |
| MatchService | Season stats math, comparisons, rolling stats | ~8 |
| ActiveSessionManager | State machine transitions, early end, finishSession integration | ~10 |

**Total: ~60-70 unit tests**

## Protocol Layer
Each service gets a protocol covering testable methods (calculations, state changes, CRUD). Protocol defined at top of the service file. Services conform to their protocol. `init()` made internal (no longer private).

### Protocol Scope

**XPServiceProtocol:** `calculateSessionXP`, `xpRequiredForLevel`, `levelForXP`, `progressToNextLevel`, `awardXP`, `processSessionCompletion`, `purchaseStreakFreeze`

**CoinServiceProtocol:** `awardCoins`, `deductCoins`, `canAfford`, `getBalance`, `awardSessionCoins`, `awardLevelUpCoins`

**AchievementServiceProtocol:** `checkAndUnlockAchievements`, `getProgress`, `isUnlocked`, `getUnlockedAchievements`

**TrainingPlanServiceProtocol:** `createCustomPlan`, `activatePlan`, `markSessionCompleted`, `getCurrentDay`, `deletePlan`, `fetchAllPlans`

**MatchServiceProtocol:** `createMatch`, `fetchMatches`, `calculateSeasonStats`, `compareSeasons`

**ActiveSessionManagerProtocol:** `start`, `completeExercise`, `nextExercise`, `finishSession`, `skipRest`

## Core Data Test Strategy
In-memory `NSPersistentContainer` via `TestCoreDataStack`. Factory helpers for Player, TrainingSession, Match, Exercise. Real Core Data stack, zero disk I/O, isolated per test.

## UI Tests (5 smoke tests)

| Flow | Asserts |
|------|---------|
| App launch | Main UI appears |
| Auth -> Dashboard | Anonymous sign-in, dashboard visible |
| Start training session | Start, complete exercise, end early, complete screen |
| Exercise library browse | Navigate, tap drill, detail loads |
| Settings navigation | Profile -> settings -> items visible |

`UI_TESTING` launch argument bypasses auth if Firebase flakes on simulator.

## File Structure

```
TechnIQTests/
  TestHelpers/
    TestCoreDataStack.swift
    MockServices.swift
  XPServiceTests.swift
  CoinServiceTests.swift
  AchievementServiceTests.swift
  TrainingPlanServiceTests.swift
  MatchServiceTests.swift
  ActiveSessionManagerTests.swift

TechnIQUITests/
  TechnIQUITests.swift          (5 smoke tests)
  TechnIQUITestsLaunchTests.swift (keep existing)
```

## Conventions
- Test naming: `test_methodName_condition_expectedResult`
- One XCTestCase per service
- Fresh TestCoreDataStack in setUp()
- No shared mutable state across tests
- Protocols live in same file as service
