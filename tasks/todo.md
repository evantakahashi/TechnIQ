# Touchline UI revamp — plan (2026-09-09)

Worktree: `/Users/evantakahashi/TechnIQ/.claude/worktrees/touchline` (branch feat/touchline-ui; the main checkout is shared with another session working on drill gen — never build or edit there).
Source: `~/Downloads/Mobile app UI revamp help.zip` → unpacked at
`/private/tmp/claude-501/-Users-evantakahashi-TechnIQ/491bf823-711f-4f9a-b06f-6dfdcf375c9f/scratchpad/handoff/design_handoff_touchline/`
(re-unzip if the scratchpad is gone). Read order: README.md → `TechnIQ Handoff.dc.html` (spec) →
`TechnIQ Final Screens.dc.html` (17 final screens, easiest to read) → `TechnIQ Revamp.dc.html` #9a (component
inventory, lines 17–73) and #8b (tab symbols, lines 263–280). PNGs in `screens/` are 2× at 402×874 pt.
Only anchors 4a 5a 5b 5c 6a 6b 6c 7a 7b 7c 8a 8b 9a 9b–9g are final; ignore turns 0–3, 4b, 4c.
Values come from the HTML inline styles, never estimated from PNGs.

## Status (2026-09-10)
- [x] 01 Tokens — commit 42652d8
- [x] 02 Components — 8b3adb5, 618f5ef (+ `TQGallery` debug view; `scripts/add_to_pbxproj.py` registers files)
- [x] 03 Home — 54e563d + review commit; all four states verified on the simulator with `-TQSeedDemo` / `-TQHomeState`
- [x] REVIEW STOP — Evan reviewed Home ("great, commit and move on")
- [x] 04 Active session + Session complete — bf75abe
- [x] 05 Train, AI drill states, Plans, Plan detail, Drill detail, Community — e7a409f; You, Sign-in, Onboarding — 361b38f
- [x] 06 Cleanup — dead views/components deleted, lint 0 errors, unit + UI suites green, CLAUDE.md updated

## Rules of the build
- Token NAMES in DesignSystem.swift stay; VALUES change (spec §2–4). Shadows → clear. Gradients → removed.
- Screens are composed only from `Components/Touchline/TQ*.swift`. Need something new → add a variant, not ad-hoc styling.
- Layout never changes between states; only slot content does. Skeleton = same height as loaded. Errors = TQBanner
  above the hero (never a modal unless destructive). Every TQButton renders disabled + loading; every tappable row has pressed.
- Display face = SF Pro `.width(.condensed)` semibold/bold uppercase (NOT compressed). Text = SF Pro regular width.
  Numbers `.monospacedDigit()`, never the monospaced design.
- One pitch-green surface + one grass button per screen.
- pbxproj is NOT a synchronized folder → every new file must be added to project.pbxproj (script in scratchpad: `add_to_pbxproj.py`).
- Build after every step, FOREGROUND (background xcodebuild gets killed on this box):
  `xcodebuild -scheme TechnIQ -destination 'platform=iOS Simulator,name=iPhone 15 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO CLANG_ENABLE_EXPLICIT_MODULES=NO build`
- Out of scope (inherit tokens + rows only): avatar redesign, Shop, Settings, Match log, Analytics detail, Paywall.

## Token values (spec §2–4)
Surfaces: base #0E1210 · raised #161C18 · overlay (rules/borders) #1F2722 · highlight (disabled, tracks) #2A342D ·
pitch #173A26 (new) · pitchLine rgba(238,241,236,.24) (new)
Accents: accentLime→grass #5CCB5F · accentLimeDim (pressed) #3E9A48 · bloodOrange→cone #F0A33A · error #B23A3A
Text: chalkWhite #EEF1EC · mutedIvory #B9C1BB (on pitch #BFD3C4, coach copy on pitch #D7E3DA) · dimIvory #8E968F ·
textTertiary #4E5651 (own value now). Rarity colours unchanged. Streak = grass (cone no longer used for streak).
Type: displayLarge 56 bold cond upper tracking −1 · displayMedium 40 semibold cond upper (46 on some heroes) ·
displaySmall 30 semibold cond upper · numberLarge 40 bold cond monoDigit · numberMedium 26 semibold cond monoDigit ·
labelLarge 19 bold cond upper +1 · labelMedium 14 semibold cond upper +.6 · labelSmall/eyebrow 11–12 bold upper +1.2 grass ·
titleMedium 15 semibold · bodyMedium 14 regular line 1.5 · bodySmall 13. Sign-in headline 60 → heroDisplay.
Radii: button 8 · pitch card 12–14 · tile/chip 6 · segment inner 4 · pill unused.
Spacing: screenPadding 20 · section 16–18 · row 12–14 v · hero padding 16–18 · hit target ≥ 44.
Motion: keep heroSpring/staggerSpring/microBounce; drop pulseAnimation + 1.1× tab scale; level bar 0.8 s ease-out.
Tab symbols (#8b): house/house.fill · figure.soccer · calendar/calendar.fill · person.2/person.2.fill ·
person.crop.circle/.fill. 24 pt semibold; grass selected, #4E5651 idle. Elsewhere: sparkles=AI, flame.fill=streak,
soccerball=technical, bolt.fill=physical, brain=tactical, play.rectangle.fill=video. Retire wand.and.stars,
checkmark.seal.fill hero, coloured icon-in-circle.

## Component inventory (README table + #9a) → `Components/Touchline/`
| File | Contents |
|---|---|
| TQPitchMarkings.swift | Shape drawing touchline rect / halfway line / centre circle+spot / boxes at pitchLine; presets .full .centre .half .box .none (geometry read from each mock's SVG) |
| TQPitchCard.swift | variants .hero .strip .pinned .fullscreen; slots eyebrow/title/meta/body/action; states default/loading(skeleton, same height)/empty |
| TQButton.swift | .primary(grass) .inverse(chalk) .raised .ghost; size .regular 54 / .compact 40–44; ButtonStyle-based pressed (0.97 + darker); disabled #2A342D/#8E968F; loading spinner keeps label |
| TQRow.swift | leading .none/.tile/.index; trailing .meta/.badge/.chevron/.heart/.none; subtitle; pressed = raised fill bleed −8 r6; disabled = secondary text no chevron; 1 px overlay rule; TQRowList (top rule) |
| TQStatRail.swift | 2–4 items value(numberMedium)+unit+label, 1 px rules between, optional grass accent on one value |
| TQWeekStrip.swift | TQDayCellState enum {done, planned, today, rest, missed, locked, sessions(n)}; TQWeekStrip (7 cells + day letters) + TQScheduleGrid (rows×7, "WK n" column, today row bold) |
| TQControls.swift | TQSegment (raised track r6, 3 pt inset, selected chalk fill r4, h36) · TQChip (labelMedium r4/6, chalk when selected) · TQBadge (.level beginner=grass/intermediate=highlight/advanced=cone/elite=error, .count, .status) · TQTile (42 pt r6, TEC/PHY/TAC/VID; .ai = pitch fill + grass text; number+unit) · TQEyebrow · TQStepper (01 ── ── ── 04, 2 pt bars) |
| TQSearchField.swift | raised r8; idle / focused (grass 1.5 pt border + Cancel) / disabled 50 % |
| TQBanner.swift | .warning cone / .error red / .info grass; 3 pt left bar, r6, message (bold lead) + action |
| TQSkeleton.swift | #1F2722 blocks, 1 s pulse 0.5→1, height/width params |
| TQTabBar.swift | 5 icon-only items per #8b, 1 px top rule, surfaceBase |
| TQClock.swift | 128 pt cond bold monoDigit m:ss + 15 pt uppercase sub-line; running/paused |
| TQLevelBar.swift | 8 pt track raised, previous fill highlight, current grass, 0.8 s ease-out |
| TQDiagram.swift | pitch surface 220 pt; DrillDiagramView restyled (player chalk circle 26, cone #F0A33A triangle 16, goal/wall chalk bar, pass grass 2 pt dashed 5/5); legend TL, dimensions BR, Animate chip BL; same DiagramElement model |

Old → new mapping (delete when in-scope screens no longer use them; out-of-scope users keep a flat, token-compliant
version marked `// Deprecated: use TQ…`):
ModernButton→TQButton (keep ModernButton as thin wrapper: primary→.primary, secondary→.raised, ghost→.ghost, danger→.raised+error text, accent→.primary) ·
ModernSegmentControl→TQSegment (wrapper) · ModernCard→keep, flat (raised, r8–12, no border/shadow) · ModernTextField→raised r8, 1 px highlight border, grass on focus, eyebrow label ·
AnimatedTabBar/ModernTabBar/TabBarItem→TQTabBar (delete) · TurfBackground/TurfGrainCanvas→surfaceBase (delete) · heroCard()/CornerBracketShape/PitchDivider/ProgressRing/GlowBadge/ActionChip/FloatingActionButton/CompactActionButton/StatCard/SoccerBallSpinner/PillSelector/MultiSelectPillSelector→delete once unused (StatCard/GlowBadge/SoccerBallSpinner/DifficultyBadge still used by out-of-scope views → keep flat+deprecated) ·
TodaysFocusCard/DailyGoalCard/aiDrillHeroBanner/continuePlanCard/activePlanCard→TQPitchCard · ModernSessionRow/MatchHistoryRow/SmartRecommendationRow/ProfileMenuItem/DayRow/ListExerciseCard/PlanCard→TQRow ·
FilterChip/ActionChip/PhysicalIndicatorChip/FrequencyChip→TQChip · DifficultyBadge/CategoryBadge→TQBadge · ExerciseIconPreview→TQTile · gradients→removed (11 call sites replaced with flat grass/surface) · pulseAnimation→removed (5 call sites).

## Order of work (spec §7) — build green after each numbered step
### 01 Tokens — DesignSystem.swift
- [x] Colors: new values; add `pitch`, `pitchLine`, `grass`, `cone`, `textOnPitch` (#BFD3C4), `bodyOnPitch` (#D7E3DA); error/warning/textTertiary get own values; streak/xp/coin/success → grass; gradients deleted (fix 11 call sites); confetti palette → grass/chalk/cone.
- [x] Typography per §3 (keep every existing name; extras mapped to condensed/text equivalents); heroDisplay = 60.
- [x] Spacing (screenPadding 20, section 16/18, rowVertical 12, hero 18, hitTarget 44) · CornerRadius (button 8, card 12, pitchCard 14, tile 6, chip 6, segmentInner 4, textField 8) · Shadow all clear · Animation drop pulse · Icons per #8b.
- [x] AdaptiveBackground → flat surfaceBase; cardStyle/primaryButtonStyle/secondaryButtonStyle/modernTextFieldStyle flat.
- [x] Remove `pulseAnimation()` uses (AuthenticationView, DashboardView, CustomDrillGeneratorView) and the modifier; drop 1.1× tab scale.
- [x] Build.

### 02 Components — Components/Touchline/ (+ pbxproj group "Touchline")
- [x] pbxproj helper script; add group.
- [x] TQPitchMarkings, TQPitchCard, TQButton, TQRow, TQStatRail, TQWeekStrip(+Grid), TQControls, TQSearchField, TQBanner, TQSkeleton, TQTabBar, TQClock, TQLevelBar. (TQDiagram lands with Drill detail.)
- [x] Restyle ModernButton (wrapper→TQButton), ModernSegmentControl (wrapper→TQSegment), ModernCard, ModernTextField; delete TurfBackground/heroCard/CornerBracket/PitchDivider/ProgressRing/ActionChip/Pill selectors/ModernTabBar/AnimatedTabBar and fix call sites; MainTabView → TQTabBar on surfaceBase.
- [x] Preview file `TQPreviews.swift` (DEBUG) mirroring #9a so components can be eyeballed.
- [x] Build.

### 03 Home — DashboardView/DashboardComponents/TodaysFocusCard (#4a, #9b, #9c, #9d)
- [x] Header: subline "Tue 9 Sep · Matchday −n" (future match) / "· Day n" fallback; "NAME · #kit" condensed 30 (kit grass; "#—" when none); 40 pt avatar.
- [x] TQPitchCard hero "TODAY'S SESSION" + "WK n · DAY m": drill = DailyCoaching.recommendedDrill when Pro coaching loaded, else today's plan session's first exercise; figures min/reps/foot/lvl; coach reasoning one line; Start session (opens ActiveTrainingView with the day's exercises).
- [x] Loading (#9c): local data immediate; only coach slots pulse; 6 s timeout → plan drill + info banner. Offline (#9d): warning banner above hero w/ Retry, "· FROM PLAN" eyebrow suffix, italic "Coach's note unavailable offline.", Drills row disabled "needs connection". Empty (#9b): "YOUR FIRST SESSION / TEN MINUTES, ONE BALL, A WALL", Start quick drill (QuickDrillSheet flow), "or build a plan first" link; rows: Build a training plan (AI badge), Log a match, Drills from the coach disabled "after your first session"; week strip 0/—.
- [x] TQWeekStrip "THIS WEEK n / m" from this week's sessions + plan days.
- [x] Rows: active plan (WK n/8 · %) → Plan detail; Last match (vs opp · W/L/D · nG nA) → Match history; Drills from the coach (count badge) → SmartDrillRecommendationsView.
- [x] Footer "LVL n · n,nnn XP · n DAY STREAK" (labelMedium; streak grass). Remove CompactPlayerStats, xpProgressCard, DailyGoalCard, Quick Actions, Recent Activity/Matches/Recommended, FAB, coach marks re-anchored.
- [x] Build; compare to 01/12/13/14 PNGs on simulator.

### 04 Active session + Session complete (#5c, #6a)
- [x] ActiveSessionManager: add clock (countdown from estimatedDurationSeconds, count-up fallback), pause/resume, reps counter (+10), effort zone from metabolicLoad (Z1–Z5); persist reps/duration to SessionExercise; drop per-exercise rating phase (see Q2).
- [x] ActiveTrainingView: full-screen pitch (markings 20 %), top bar close / "DRILL n OF m" / menu(≡ → sheet with diagram + steps), 3 pt progress segments, eyebrow + displayMedium name, TQClock, reps + effort numberLarge, coach tip strip (35 % base overlay), controls pause 64 / "+10 REPS" grass / next.
- [x] SessionCompleteView: pitch header 420 pt r28 bottom ("FULL TIME · date", "SESSION COMPLETE", summary line, TQStatRail +XP / streak / +coins), TQLevelBar previous→new 0.8 s + "630 / 720 · 90 to lvl 13", drill recap TQRows (.index), "How did it feel?" TQSegment Easy/OK/Good/Hard → overallRating, Done + Share. Level-up → level bar completes + one row "LEVEL 13 · Prospect"; achievements → rows; weekly check-in → row. Remove confetti here.
- [x] Build; compare to 04/05 PNGs.

### 05 Remaining screens (restyle onto components)
- [x] Train (#5a, #9e): TrainHubView/ExerciseLibraryView/ExerciseLibraryComponents — "TRAIN" + grass "+ New drill" (sheet AI/Manual/Video); TQSearchField "Search n drills"; strip TQPitchCard "FROM YOUR COACH · n NEW"; chips All/Saved/Technical/Physical/Tactical/Video (+ filter sheet behind trailing chip); flat TQRow list (tile, name, meta, heart). Empty: search disabled 50 %, pitch card "YOUR LIBRARY IS EMPTY / DESCRIBE WHAT YOU WANT TO FIX" + Generate a drill, rows Browse templates (45) / Pull in video drills (VID) / Write one yourself (+).
- [x] AI drill generating/failed (#9f, #9g): CustomDrillGeneratorView — "YOU ASKED FOR" raised card; pitch card with spinner + "DRAWING THE SETUP"; step rows ticking with real pipeline stages; Cancel. Failed: error banner, Try again (primary) / Edit the request (raised), "CLOSE MATCHES IN YOUR LIBRARY" rows. Same layout for offline (Try again disabled), quota (Try again → Upgrade), moderation (Edit only).
- [x] Plans (#8a): TrainingPlansListView — "PLANS" + "+ New plan"; active plan TQPitchCard (WK n / 8, progress bar, "Next: … · day"); TQSegment Pre-built / My plans · n; rows 42 pt "8W" tile, name, meta, level badge, chevron.
- [x] Plan detail (#5b): TrainingPlanDetailView — push not sheet; "PLAN" nav + Edit; eyebrow "ACTIVE · role · level"; displayLarge title; description; TQStatRail (%, week n/8, total h, done); TQScheduleGrid 8×7 (tap cell → day sheet) + legend; pinned TQPitchCard "TODAY · WK n DAY m" + Start.
- [x] Drill detail (#7c): ExerciseDetailView + DrillDiagramView → TQDiagram; header back / eyebrow "AI DRILL · category" / heart + share; title + figures; steps as index rows + "+n coaching points" collapsed; pinned Start drill + "+PLAN"; notes/feedback below fold; video card only for video drills.
- [x] Community (#6b): CommunityView/DrillMarketplaceView — "COMMUNITY" + raised "+ Post"; TQSegment Feed/Drills/Leaderboard (Drills default); TQPitchCard "DRILL OF THE WEEK" (most-saved last 7 d, fallback all-time) with Add to my drills / Preview; chips; rows with saves count + heart.
- [x] You (#6c): EnhancedProfileView — "YOU" + gear; TQPitchCard avatar 78×112, eyebrow tier · position, name, LVL · XP · coins, level bar, ghosted kit number; TQStatRail sessions / hours / streak / season G A; groups TRAINING / ACCOUNT / APP as rows; Pro row ACTIVE badge; Sign out ghost at bottom.
- [x] Sign-in (#7a): AuthenticationView — pitch header 470 pt fading to base, icon + wordmark; eyebrow, 60 pt headline, paragraph; Apple (inverse), Google (raised), Email (raised → email form screen restyled), "Train as a guest →" text, legal line.
- [x] Onboarding (#7b): UnifiedOnboardingView/OnboardingComponents — drop welcome + feature tour; one decision per screen goal → frequency → position (+foot) → weak spots → name/age/level, then plan generation + paywall (existing); TQStepper; selectable rows (number, title, consequence, radio); Next names the next step; "Next up · …" footer.
- [x] Build after each screen; PNG comparison on simulator.

### 06 Cleanup
- [x] Delete dead components/files; swiftlint; unit tests (`-only-testing:TechnIQTests`); update CLAUDE.md component table + Key Files; memory note.

## Judgment calls made (say so in the recap)
- Onboarding stepper counts 5 decision steps (mock says 04 but lists 5 screens).
- Header subline: "Matchday −n" only when a future-dated match exists; else "Day n" of the plan.
- Last-match row: Match has no team score → "vs Opp · W · 2G 1A".
- Drill of the week = most-saved shared drill in last 7 days, fallback all-time.
- Continue with email → existing email form on its own screen (not mocked).
- Effort → rating: Easy 5 · Good 4 · OK 3 · Hard 2 (feeds skill scores + XP rating bonus).

## Decisions (Evan, 2026-09-09)
1. `kitNumber` on Player is OPTIONAL (Int16, 0 = none). Header/You show name only when nil. Collected on the onboarding position step (+ Edit profile, cloud sync).
2. Drop per-drill 5-star rating; each drill's performanceRating derives from Session complete's Easy/OK/Good/Hard. No sets line. Reps: plain count; show "/target" only when a target exists (none in model today).
3. Retired components still used by out-of-scope screens: keep flat + deprecated.
4. Branch `feat/touchline-ui`; commit after each green step.
5. Onboarding drops the playing-style question (stays in Edit profile).
6. Build after every step. STOP for review after step 03 (Home) — Evan compares against screens/01-home.png before step 04.
