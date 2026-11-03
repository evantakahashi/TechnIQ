# Product pass — 10 items (2026-11-03)

Branch `feat/product-pass` off `worktree-camera-drills-spike`. Worktree `.claude/worktrees/product-pass`.
Streams run in their own worktrees off the Phase 0 commit, then merge back here one at a time (build + unit tests after each).

## Decisions (Evan, 2026-11-03)
- Plans + Train fill only from the 10 pre-built drills (+ the player's own AI/manual drills). The 84-drill
  `TemplateExerciseLibrary` no longer feeds plans or the Train "import library" row. Existing imported rows are kept.
- XP comes from training only: no XP from achievements (they stay as badges), match logs, or streak milestones.
- Evan will film himself doing the drills: each pre-built drill gets an optional video slot (empty for now).
- Camera debug readout (joints / nose / ankle) hidden behind a DEBUG launch flag.

## Phase 0 — foundation (me) ✅
- Core Data versioned: `DataModel` (v1 = main's model, what v1.0 ships) + `DataModel 2` (current). Lightweight inferred
  migration covers adds + removes. `ModelMigrationTests` opens a v1 store under the current model.
- v2 adds: Exercise `prebuiltKey, equipment, space, cue, dsl, unlockCriteriaJSON` · TrainingSession `feel,
  activeSeconds, verifiedTouches` · PlayerProfile `nextMatchDate` · PlanWeek `isRetest` · new `Benchmark`
  (id, type, value, date, cameraVerified, createdAt, updatedAt, → player; Player.benchmarks cascade).
- All new fields synced (upload + restore + incremental); `benchmarks` Firestore subcollection; CameraRun + Benchmark
  stamped by `stampSyncMetadata`.
- Shared types: `FeatureFlags` (community, soonCameraDrills, youtubeDrills), `SessionFeel`, `BenchmarkType`, `UnlockCriteria`.

## Stream A — drill content, in-session diagram, cue, unlock criteria (items 1, 2, 8)
- `TechnIQ/Resources/PrebuiltDrills.json` = the 10 drills: key, name, category, difficulty, description, skills,
  steps (3–6), coachingPoint (exactly 1), equipment, space, cue, durationMinutes, dsl (hand-written), unlockCriteria,
  videoClip (null), + compiled `diagram` / `animation` written by `scripts/compile_prebuilt_drills.py`
  (functions/ pipeline: parse_dsl → post_process → crop → annotate → compile_timeline; deterministic, no LLM).
- `PrebuiltDrillCatalog` loads it; `createDefaultExercises` seeds from it; launch backfill upgrades existing template
  rows (placeholder "Follow standard … protocol" instructions) by name → prebuiltKey. Placeholder string deleted.
- `Exercise.coachCue` = the one accessor: `cue` field, else first coaching point. Home coach line and the COACH banner
  both read it (Home no longer shows the AI's own cue text). AI drills store `cue` + `equipment` at creation.
- ActiveTrainingView: animated diagram above the clock for every drill that has one (film if animationJSON, else
  step diagram); slot hidden for drills with neither (manual drills). Tests fail if any pre-built drill lacks DSL,
  compiled diagram or film; Python test fails if the compiled JSON drifts from the DSL.
- Plans fill from pre-built drills only (TrainingPlanService name matching + random fill + template plans).
- Unlock criteria on drill detail with live progress (completions with feel ≠ too hard / benchmarks ≥ target / reps).

## Stream B — rewards, feel, effort (items 3, 4, 5)
- `XPFormula.session(verifiedTouches:activeSeconds:)` ≤ 30; one XP path. Level curve retuned. Camera sitting capped too.
- Coins + Shop removed: CoinService, ShopView, CoinDisplayView, coin UI, OwnedAvatarItem entity + Player.coins /
  totalCoinsEarned + CameraRun.coinsEarned removed from model v2, sync code, tests. All avatar items free.
- Streak counts only sessions with ≥ 300 active seconds (XPService, NotificationManager, InsightsEngine).
- Feel: Too easy / Right / Too hard, no default, Done disabled until picked, persisted to `TrainingSession.feel`.
- "Z1 effort" removed from the session screen.

## Stream C — benchmarks, assessment, retest, flags (items 6, 10)
- `BenchmarkService`: record (type, value, cameraVerified), last / best per type. Camera runs of benchmark drills write one.
- First session = 10-min assessment (warm-up, juggling best of 3 via camera or typed, wall passes 30 s, toe taps 30 s).
- Home: benchmarks rows (last vs best). Every plan (AI, custom, pre-built) ends with a retest week (`isRetest`).
- Flags: Community tab + every entry point, and "soon" camera drills, off by default.

## Stream D — match day + prefill (items 7, 9)
- `nextMatchDate` in Training Profile, AI generator, custom builder. Deterministic `MatchDayRules` on dated plan days:
  day before = technical, light; day after = recovery; intensity ≥ 4 only ≥ 2 days from a match; match day = no
  training. Also sent to the AI prompt. Re-applied on activation / profile change / adaptation.
- Match log entries link to the schedule (plan day on that date shows the match; week strip marks match days).
- Builders prefill level, position, weak spots, training days from the profile; editable.

## Camera fix (parallel)
- Countdown reaches 0 then never goes live / never counts. Debug readout behind `-TQCameraDebug`.

## Unresolved
- none blocking
