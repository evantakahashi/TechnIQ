# UX audit follow-through — plan (2026-09-12)

Previous plan (Touchline revamp, CI, visual QA, Train sections) is done and merged: PRs #2–#5.
Audit report: https://claude.ai/code/artifact/7dbd2361-68cc-45e3-a72c-fd3e42aceb8f
Worktree: `.claude/worktrees/touchline`, one branch + PR per phase off `main`, CI green (unit + UI) before merge,
`TouchlineTourUITests` screenshots eyeballed for every screen a phase touches.

## Decisions (Evan, 2026-09-12)
Plan tab = active plan schedule with "Change plan" · coins/shop/avatar stay (items drawn on the avatar, coin glyph,
kit number on jersey) · custom plans + editor get finished (add/remove weeks/days/sessions, drills from library,
duration/difficulty, builder makes a real skeleton, one editor screen) · plan days bound to preferred weekdays,
missed sessions shift forward and show as missed · guest mode removed · Settings merged into You · community seeded
with official "TechnIQ Coach" drills, feed official-only until real posts, leaderboard real · free = onboarding plan,
templates, manual drills, community, progress; Pro = AI drills beyond 3 lifetime, daily coaching, weekly review, new
AI plans; every gate labelled, generator shows "n free drills left" · the player names their coach (default "Coach") · reminders default 17:00 local time · plan start date = creation day · daily coaching picks today's drill from library/plan
(prefetched + cached; "Build a fresh one" runs the pipeline and counts) · weekly review = recap + per-change accept +
Home re-entry row, fires at end of calendar week · one coach voice.

## Phase 0 — Trust the numbers (bugs, no design change) — PR (branch fix/audit-phase0)
- [x] Plan progress % updates on every session completion (not once a week) — `TrainingPlanService.updatePlanProgress`
- [x] Manual drills classify as manual ("Manual Custom Drill" stamp) and save their duration; land in "My drills"
- [x] Community-saved drills keep a community source (no `[AI-Generated…]` prefix) → "Community drill" eyebrow works
- [x] Coach drill launched from Home no longer attaches `planSession` (does not tick the plan day)
- [x] One quota key for AI drills; `-TQFree` launch arg to exercise the free tier in DEBUG (isPro no longer hard-coded)
- [x] Drill rating: load existing feedback on appear, update instead of insert, use the drill's owner
- [x] One streak/day source: drop the header "Day n", Progress reads `player.currentStreak`; "Next … · Mon" only once dates exist (Phase 2)
- [x] Jersey number = kit number; intensity scale /5 everywhere; progression card gets a real button
- [x] Share drill: keep the message, send real duration/sets/reps
- [x] Edit profile: age 5–80, remove dead "Reset All Data", drop height/weight (read by nothing)
- [x] Restore purchases surfaces its error
- Tests: `TechnIQTests/TrustTheNumbersTests.swift` (provenance, free allowance, live progress, share steps, rating labels) — 185 unit, 25 UI green
- Also: `Exercise.source` attribute (additive, synced) replaces description sniffing; `animationJSON` now syncs; coach pick only credits the plan day when it is the plan's drill; "Make it harder" gated on the budget

## Phase 1 — Shape (IA) — PR (branch feat/audit-phase1)
- [x] Plan tab roots on `TrainingPlanDetailView` of the active plan; nav "Change plan" → list (Pre-built / My plans / New plan); no-plan state = list
- [x] Deactivate + delete plan (detail Edit menu), Skip day with undo on the Today card; delete `TodaysTrainingView`
- [x] One session engine: `NewSessionView` becomes a drill picker feeding `ActiveTrainingView`; its save path deleted
- [x] `QuickDrillSheet` folded into `CustomDrillGeneratorView` (quick mode: skill + sentence; advanced collapsed; category/difficulty/equipment defaulted)
- [x] One coach surface: Home card + Train strip say the same thing ("2 drills the coach suggests"); `CoachDrillsView` renamed/copy fixed
- [x] Settings merged into You (Touchline): Account · Training profile (Phase 6) · Notifications (Phase 2) · Help · Legal · Sign out · Delete account
- [x] Guest mode removed: no "Train as a guest", no anonymous auth path
- [x] Dead code deleted: ConfettiView*, CoinDisplay animations, CalendarComponents.swift, legacy DrillDiagramView wrapper, ModernAlert, ProLockedCardView, `.avatar` coach mark, WeaknessSuggestionsCard, WalkthroughUITests (ProgressRing stays: StatCard uses it)
- [x] Deferred to Phase 4 and done there: the cloud `get_advanced_recommendations` client path removed
- Tests: UI tests updated (plan tab root + All plans, You account rows, no guest link), `DrillGeneratorDefaultsTests`

## Phase 2 — Dated plans + reminders — PR (branch feat/audit-phase2)
- [x] No new attributes needed: dates derive from `startedAt ?? createdAt` + week/day (`Models/PlanSchedule.swift`)
- [x] Binding: preferred days (onboarding/generator) → weekday per plan day; Home strip, plan grid and "Next: Thu" agree
- [x] Missed day → session shifts to the next training day, week strip shows the miss; rest days say "Rest day" on Home
- [x] Reminders: plan-day + streak-at-risk scheduled; permission asked after "You're all set"; Notifications row (time, toggles)
- Tests: `PlanScheduleTests` (dates, rotation, today/rest/overdue/complete, labels, reminder planning, settings), `HomeWeekModelTests` rewritten for dated days

## Phase 3 — Plan editor + custom builder — PR (branch feat/audit-phase3)
- [x] One editor: plan → tap a day → edit its sessions and drills (add/remove session, pick drills from library, duration, difficulty, rest toggle); add/remove week and day from the grid
- [x] Custom builder generates a skeleton from weeks × days/week × preferred days (no empty shells); prebuilt copies editable
- [x] Duplicate keeps drills; AI generator + preview on Touchline chrome
- Tests: `PlanEditingTests` (skeleton, append/remove week with progress guard, sessions + drills, rest toggle, details) — 204 unit; tour visits the day editor, generator and builder

## Phase 4 — Coach — PR (branch feat/audit-phase4; functions deploy pending — USER ACTION)
- [x] Daily coaching prefetched on app open / after a session, cached per day; hero never waits (6 s fallback only cold)
- [x] Function picks today's drill from the player's library/plan ids (`isFromLibrary`), returns one cue + reason; hero shows drill + one-line note
- [x] "Build a fresh one" → drill pipeline, counts as an AI drill
- [x] Weekly review: recap (done vs planned, minutes, effort trend, best drill) → changes with reasons → accept per change; fires end of calendar week; "Week n review ready" row on Home until answered
- [x] One coach voice across hero, strip, review, Progress tips (copy pass)
- Root cause found: the client decoded camelCase but the functions answer snake_case, so coaching never parsed. Fixed with explicit CodingKeys (`CoachTests`).
- Also removed the dead `get_advanced_recommendations` client path (deferred from Phase 1); coach name is player-chosen (You → Your coach)
- Tests: `CoachTests` (decoding, library payload, week recap), review trigger in `PlanEditingTests`, `functions/test_coach_prompts.py` — 210 unit

## Phase 5 — Monetization — PR
- [ ] One `TQPaywall` (replaces PaywallView + OnboardingPaywallView); benefits = real gates only
- [ ] 3 lifetime free AI drills, counter on the generator ("2 free drills left"); "Pro" tag on every gated row; AI plans Pro from Home too
- [ ] StoreKit configuration file for local purchase testing; `-TQFree` path in UI tests
- Tests: gate/counter unit tests, UI test for the free path

## Phase 6 — Retention additions — PR(s)
- [ ] Resume session: persist `ActiveSessionManager` state, `scenePhase` handling, "Session in progress" card on Home
- [ ] Training profile screen (goal, days/week, position, foot, weak spots) under You; plan re-binds on change
- [ ] Pre-session preview (drills · minutes · equipment) + next-session peek on Home
- [ ] Celebration pattern: level-up, achievement toast anywhere, plan complete summary
- [ ] Records + week-over-week on You/Progress; "Improvement %" tile removed
- [ ] Drill detail: completions + last used, persistent rating, "Make it harder" opens the generator prefilled
- [ ] Sync/offline banner on every tab, last synced under You
- [ ] Share card (`ShareLink` image) for a session and a completed week; Help row; review request after 3rd session
- [ ] Match log: position prefilled, editable match, matches count toward achievements

## Phase 7 — Community — PR (+ Firestore rules/seed script)
- [ ] Official "TechnIQ Coach" account + seed script (10–20 approved drills from `functions/eval/golden`), attributed; feed official-only until real posts
- [ ] Post a drill from the Drills segment; report-reason picker; unblock; weekly leaderboard scope; age gate (13+) for posting
- [ ] Touchline chrome: feed, create post, post detail, public profile, share sheet, guidelines

## Phase 8 — Remaining chrome — PR(s)
- [ ] Progress + history merged (one history list with calendar, one achievements list); session detail edit/delete/repeat
- [ ] Match screens; shop + avatar (items drawn on the avatar, coin glyph); cloud restore + loading screens; manual creator/editor; weakness picker; share plan

## Assumptions (unless Evan objects)
- Community posting age gate 13+; official seed account "TechnIQ Coach".
- First TestFlight build after Phase 2.
