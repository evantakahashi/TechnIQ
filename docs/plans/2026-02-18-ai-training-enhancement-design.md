# AI Training Enhancement Design

## Overview
Comprehensive upgrade to the AI training generation experience — animated drill diagrams, weakness-targeted drill generation, and a redesigned active training flow.

**Approach:** Animated Diagram First (Phase 1→2→3→4→5)

---

## Phase 1: Animated Step-by-Step Drill Diagram

### Field Rendering
- Grass-textured background: alternating light/dark green stripe gradient
- Field markings: center circle, penalty box, touchlines — scaled to drill field size
- Soft vignette shadow at edges

### Element Rendering
| Element | Visual | Active State |
|---------|--------|-------------|
| Player | Filled circle, jersey-numbered label | Pulsing glow when active in current step |
| Cone | 3D gradient fill (orange top → shadow) | — |
| Goal | Goal-post rendering with hatched net pattern | — |
| Ball | White circle with pentagon hint + shadow | — |
| Target/Partner | Diamond shape | Highlight when involved |

### Path Rendering
| Style | Visual | Animation |
|-------|--------|-----------|
| Dribble | Curved bezier, solid, blue | Dot travels along curve |
| Run | Curved bezier, dashed, gray | Dot travels along curve |
| Pass | Straight/curved, solid, green, arrowhead | Animated arrowhead + dot |

### Step-by-Step Playback
- Bottom bar: current step text + "Step N of M" counter
- Tap forward/back or swipe to advance
- Per step: relevant paths animate (~1.5s), active elements pulse, inactive dim to 40%
- Auto-play toggle: advances steps on 3-4s timer
- Speed control: 0.5x / 1x / 2x

### Active Training Mode
- Full-width layout, large touch targets
- "Mark Step Done" button replaces tap-to-advance
- Haptic on step completion
- "Complete Drill" after last step → rating/feedback

### Data Model
- `DiagramPath.step: Int16` (optional, default 0 = show on all steps)

---

## Phase 2: Active Training Experience

### Per-Drill Flow
1. **Preview** — auto-play animated diagram, user watches drill play through once, "Ready" button
2. **Perform** — manual step-by-step mode, timer in corner, current instruction prominent below diagram
3. **Rate** — difficulty (too easy / just right / too hard), quality (1-5 stars), optional notes

### Training Plan Integration
- `PlanSessionCard` gets mini diagram thumbnail (static render of field layout)
- "Start Session" launches per-drill flow instead of current exercise list
- Exercises without `diagramJSON` fall back to text-based display

### Session Summary
- Drills completed, total time, average difficulty
- "You worked on: [weaknesses]" with streak counter
- XP/coin awards surfaced prominently
- "Generate Another Drill" shortcut

### Haptics
- Step completion: light impact
- Drill completion: medium success
- Session completion: notification pattern
- Path animation haptic: optional, toggleable

---

## Phase 3: Weakness Picker & Smart Recommendations

### Two-Tier Weakness Picker
**Tier 1 (~10 categories):** Dribbling, Passing, Shooting, First Touch, Defending, Speed & Agility, Stamina, Positioning, Weak Foot, Aerial Ability

**Tier 2 (3-6 per category):**
| Category | Sub-Weaknesses |
|----------|---------------|
| Dribbling | Under pressure, Change of direction, Tight spaces, Weak foot dribbling, Beat a defender 1v1, Speed dribbling |
| Passing | Long range accuracy, Weak foot passing, Through balls, First-time passing, Under pressure, Switching play |
| Shooting | Finishing 1v1, Weak foot, Volleys, Long range, Placement vs power, Headers on goal |
| First Touch | Under pressure, Aerial balls, Turning with first touch, Weak foot control, Bouncing balls |
| Defending | 1v1 tackling, Positioning, Aerial duels, Recovery runs, Reading the game, Pressing triggers |
| Speed & Agility | Acceleration, Change of direction, Sprint endurance, Agility in tight spaces |
| Stamina | Match fitness, High-intensity intervals, Recovery between efforts |
| Positioning | Off the ball movement, Creating space, Defensive shape, Transition positioning |
| Weak Foot | Passing, Shooting, Dribbling, First touch, Crossing |
| Aerial Ability | Heading accuracy, Jumping timing, Aerial duels, Headed passes |

Multi-select across categories. Freeform "Anything else?" text field below for context.

### Context-Aware Suggestions
"Suggested for You" card at top of drill generation flow. Sources:
1. Match logs — recurring weaknesses from last 5-10 matches
2. Session ratings — exercises rated <3/5, grouped by skill category
3. Past drill feedback — drills rated poorly or marked "too hard"

Shows 2-3 pills: "Based on your last 5 matches: **First Touch Under Pressure**, **Weak Foot Passing**". Tap to pre-fill picker.

### Smart Recommendations (Dashboard)
"Drills For You" section on Train Hub/Dashboard:
- 2-3 weakness-based drill preview cards
- Each: weakness name, description, difficulty tag, "Generate" one-tap button
- Refreshes on new match/session data
- Client-side analysis only — tapping "Generate" triggers normal pipeline with weakness pre-filled

---

## Phase 4: AI Pipeline Improvements

### Scout Phase
- Receives structured `selected_weaknesses` array instead of freeform text
- Weakness-specific drill archetype lookup table (e.g., "Under pressure" → rondo variants, pressing games)
- Last 5 generated drill names sent as "do not repeat" list
- Explicit difficulty calibration directive from feedback history

### Coach Phase
- 6 → 12 pattern types: add `diamond`, `square`, `rondo_circle`, `channel`, `overlap_run`, `wall_pass_sequence`
- Spatial rules per new pattern type in prompt

### Writer Phase
- `step: Int` required on all movement paths
- `variations` as structured JSON array (not markdown)
- `estimatedDuration` as top-level integer
- Temperature 0.6 → 0.7 for variety

### Referee Phase
- New programmatic check: every instruction step must have >=1 matching path
- Step-path mismatch flagged as error for Writer retry

### Backward Compat
- `selected_weaknesses` absent → falls back to freeform `skill_description` behavior

---

## Phase 5: Template Library Expansion

Target: 45 → 100-120 templates.

| Gap Area | Current | Target | Examples |
|----------|---------|--------|----------|
| Weak foot specific | 0 | 8-10 | Weak foot wall passes, shooting circuits, non-dominant dribbling gates |
| Defending | ~3 | 10-12 | 1v1 channel defending, recovery runs, press triggers, aerial duel practice |
| Under pressure | ~2 | 8-10 | Rondos (3v1, 4v2, 5v2), pressing escape, tight space turning |
| Game-realistic | ~4 | 10-12 | Counter-attack transitions, overlapping runs, switching play, build-up patterns |
| Mental/decision | 0 | 5-6 | Scanning drills, decision gates, reaction-based passing |

---

## Data Model Changes (All Additive)

| Entity | New Field | Type | Purpose |
|--------|-----------|------|---------|
| DiagramPath | step | Int16 (optional, default 0) | Link path to instruction step |
| Exercise | estimatedDurationSeconds | Int16 (optional) | Structured duration |
| Exercise | variationsJSON | String? | Structured variations array |
| Exercise | weaknessCategories | String? | Comma-separated weakness tags |
| Player | weaknessProfileJSON | String? | Cached weakness analysis |

No schema changes to TrainingPlan hierarchy. No new Firebase endpoints.

---

## Unresolved Questions
1. Template authoring: manual, AI-generated, or mix?
2. Full weakness sub-category list: finalize now or during implementation?
3. Auto-play path haptics: build for v1 or defer?
