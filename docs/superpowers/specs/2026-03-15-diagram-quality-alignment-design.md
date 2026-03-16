# Diagram Quality & Alignment — Design Spec

**Goal:** Fix drill diagram quality by adding new element types, a server-side post-processor for spatial validation, player-tailored prompt enrichment, and coaching-diagram rendering.

**Sub-project 1 of 3** in the broader AI Drill Generation Improvements initiative. Sub-projects 2 (Drill Complexity & Personalization) and 3 (Drill UX Polish) will follow separately.

---

## Problem Statement

AI-generated drill diagrams have several quality issues:
- Diagrams don't match drill instructions (e.g., instructions say 4 cones, diagram shows 2)
- Diagrams and drills feel independently designed rather than coupled
- Paths cross unnecessarily, spatial layouts don't match real drill geometry
- Missing element types: `wall` falls through to `.cone` default, no defender/server distinction
- Drills are often unrealistic: random cone turns, pointless sprints, passing to cones
- No player-tailored calibration of distances, rep counts, or difficulty

## Architecture

**Approach: Hybrid post-processor with archetype-informed, player-tailored prompting.**

The LLM generates its best guess at a drill + diagram. A deterministic server-side post-processor then validates and fixes spatial issues (overlaps, bounds, archetype geometry, path consistency). Enriched prompts give the LLM drill design domain knowledge and player-specific context so the raw output starts closer to correct.

No additional LLM calls. Post-processor is pure Python logic.

## Scope

**In scope:**
- 4 new diagram element types (defender, server, mannequin, wall)
- Server-side post-processor (`functions/drill_post_processor.py`)
- Prompt enrichment across Scout, Writer, Referee phases
- Client rendering for new element types
- Unit tests for post-processor and rendering
- Integration test for full Writer → Post-Processor → Referee flow

**Out of scope (separate sub-projects):**
- User-adjustable drill complexity controls
- Star rating UX
- Drill title quality
- Full rendering redesign (keeping current aesthetic)

---

## Section 1: Data Model Changes

### New Element Types

Expand `DiagramElementType` from 5 to 9 types:

| Type | Visual | When Used |
|------|--------|-----------|
| `player` | Green circle | Generic / attacker |
| `defender` | Red circle | Drills with opposition |
| `server` | Blue circle | 2-3 player drills with a feeder |
| `wall` | Gray rectangle | Wall-passing drills |
| `mannequin` | Gray circle with X | Passive defender simulation |
| `cone` | Orange triangle | Markers / gates (unchanged) |
| `goal` | Goal posts (unchanged) | Shooting drills |
| `ball` | White circle (unchanged) | Ball position |
| `target` | Blue diamond (unchanged) | Target zones |

### Files Modified

- `TechnIQ/Models/CustomDrillModels.swift` — Add `defender`, `server`, `mannequin`, `wall` to `DiagramElementType` enum
- Default fallback stays `.cone` for unknown types (backward compatible)

### Path Styles

No changes. Current styles work well:
- `dribble` = solid line (with ball)
- `run` = dashed line (without ball)
- `pass` = solid line + arrowhead (ball trajectory). Also used for shots on goal.

---

## Section 2: Server-Side Post-Processor

New module: `functions/drill_post_processor.py`

Runs after Writer phase, before Referee phase. Deterministic — no LLM calls. **Replaces the existing `programmatic_validate()` function in `main.py`** — all its checks are absorbed into the post-processor with additional spatial/archetype logic.

### Spatial Fixes
- **Minimum spacing:** No elements closer than 2m. Overlapping elements nudged apart along the vector between them.
- **Bounds clamping:** All elements within field dimensions with 1m padding from edges.
- **Age-appropriate distances:** Cone spacing validated against age group tables (all values in meters, matching the diagram coordinate system):
  - U6-U8: 1-2m close, 5-7m passing
  - U9-U12: 2-3m close, 8-10m passing
  - U13+: 3-5m close, 10-15m passing

### Archetype Vocabulary

The post-processor uses a unified archetype vocabulary. The existing Coach phase `pattern_type` values (`zigzag`, `triangle`, `linear`, `gates`, `grid`, `free`, `diamond`, `square`, `rondo_circle`, `channel`, `overlap_run`, `wall_pass_sequence`) are mapped to the canonical archetypes:

| Coach `pattern_type` | Canonical Archetype |
|---------------------|-------------------|
| `zigzag`, `linear` | `cone_weave` |
| `triangle`, `diamond`, `square` | `triangle_passing` |
| `wall_pass_sequence` | `wall_passing` |
| `channel`, `overlap_run` | `server_executor` |
| `rondo_circle` | `rondo` |
| `gates`, `grid` | `gate_dribbling` |
| `free` | (no snapping — skip archetype validation) |

The Coach prompt is NOT rewritten — the mapping handles the translation. Scout prompt outputs canonical archetypes directly.

### Archetype Snapping
- Detect drill archetype from Scout output's `drill_archetype` field + Coach's `pattern_type` (mapped via table above)
- Validate layout matches archetype geometry (e.g., triangle drill elements should approximate equilateral triangle)
- Snap elements to standard patterns when close but misaligned

### Path Validation
- Every path `from`/`to` must reference existing element labels
- Passes can only target `player`, `server`, `defender`, `wall`, or `goal` — never `cone`, `target`, `mannequin`, `ball`
- Every instruction step should have at least one corresponding path
- No orphan paths referencing nonexistent steps
- Remove duplicate paths

### Equipment Consistency

Equipment-to-element mapping (since not all equipment types have 1:1 diagram elements):

| Equipment | Maps to Element Type(s) |
|-----------|------------------------|
| `ball` | `ball` |
| `cones` | `cone` |
| `goals` | `goal` |
| `wall` | `wall` |
| `partner` | `player`, `server`, or `defender` (any player-type element) |
| `hurdles` | `cone` (represented as cone markers) |
| `ladder` | `cone` (start/end markers) |
| `poles` | `cone` (represented as cone markers) |

Consistency check: for each equipment item, at least one element of the mapped type(s) must exist. `none` equipment is excluded from checks.

### Output
- Auto-fixes spatial issues silently (overlaps, bounds, snapping)
- Returns fixed diagram + list of `validationWarnings` strings
- Warnings are included in `CustomDrillResponse.validationWarnings` for client display (field already exists in the model)
- Warnings are also passed to the Referee phase to inform its scoring

---

## Section 3: Prompt Enrichment — Player-Tailored

Embed drill design domain knowledge into LLM prompts, personalized to the player profile.

### Data Sources

Player data flows through the pipeline via `player_profile` dict (built from the client request):
- `age` — player's age (integer)
- `position` — player's position string
- `experienceLevel` — "beginner", "intermediate", "advanced"
- `playingStyle` — "possession", "attacking", etc.
- `weaknesses` — list of strings from `selectedWeaknesses` in the drill request (primary source)
- `skillGoals` — list from player profile's `skillGoals`

The `selectedWeaknesses` from `CustomDrillRequest` is the primary weakness source (user explicitly chose these for this drill). `skillGoals` from the player profile provides supplementary context.

### Scout Phase — Player-Aware Archetype Selection
- Use player's **age** to determine spacing tables and drill duration
- Use player's **experience level** to filter archetypes:
  - Beginner → unopposed only (cone_weave, wall_passing, gate_dribbling, dribble_and_shoot)
  - Intermediate → can include server_executor, triangle_passing, relay_shuttle
  - Advanced → can include opposition (1v1_plus_server, rondo)
- Use player's **position** to weight archetype relevance:
  - Winger → more 1v1/dribbling archetypes
  - Midfielder → more passing patterns
  - Striker → more finishing/first touch
  - Defender → more 1v1 defending, clearance drills
- Use player's **weaknesses** (from `selectedWeaknesses`) + **skill goals** to prioritize which archetype targets the gap
- Must pick from known archetypes: cone_weave, wall_passing, triangle_passing, server_executor, rondo, 1v1_plus_server, gate_dribbling, relay_shuttle, dribble_and_shoot

### Writer Phase — Personalized Drill Construction

**Prompt changes required:**
- Update the Writer prompt's element types line from `"cone", "player", "target", "goal", "ball"` to `"cone", "player", "defender", "server", "wall", "mannequin", "target", "goal", "ball"`
- Add role assignment rules: "Use 'defender' type for opposition players, 'server' type for feeders/passers, 'mannequin' for passive obstacles, 'wall' for rebound walls"

**Player-tailored content:**
- Cone distances scaled to player's age group (in meters)
- Measurable success criteria calibrated to experience level:
  - Beginner: "complete 10 passes without losing control"
  - Advanced: "complete 20 weak-foot passes in 30 seconds"
- Coaching points relevant to player's position and weakness:
  - Striker with poor first touch → "cushion the ball with inside of foot, don't stab at it"
  - Winger with weak 1v1 → "drop shoulder to sell the feint before accelerating"
- Player's `playingStyle` influences drill character:
  - "possession" → emphasize passing/control
  - "attacking" → emphasize finishing/1v1
- Rep counts and intensity matched to age:
  - U10: 3-5 min drill
  - U14+: 10-15 min drill
- Movement-after-passing rule: passer must move to new position
- Role assignment: multi-player drills must assign clear roles with rotation instructions

### Referee Phase — Player-Fit Validation
- Is difficulty appropriate for this player's experience level?
- Are distances realistic for this age group?
- Does the drill actually target the identified weakness?
- Is the success criteria achievable but challenging for this level?
- Does the spatial layout match the archetype?
- Does every player have a clear role and rotation?
- Do movement paths mirror real match geometry?

---

## Section 4: Client-Side Rendering

### New Element Renderers in `DrillDiagramView.swift`

Keep current aesthetic. Add renderers for new types:

- **`defender`** — Red circle, same size as player (26pt), white label text
- **`server`** — Blue circle, same size as player, white label text
- **`mannequin`** — Gray circle, same size as player, "X" overlay
- **`wall`** — Gray rounded rectangle, ~40pt wide x 12pt tall, always horizontal orientation, label below. No rotation field — walls are always rendered horizontally. The post-processor places them at appropriate positions.

### Switch Statement Update

`elementView` switch adds 4 new cases. Existing cases unchanged.

### Backward Compatibility

Existing drills without new element types render identically. Unknown types still default to `.cone`.

---

## Section 5: Unit Testing

### Post-Processor Tests (`functions/test_drill_post_processor.py`)

- Overlap detection + resolution: two elements at same coords → nudged apart
- Bounds clamping: element at x=-5 → clamped to x=1
- Pass-to-cone rejection: pass path targeting a cone → flagged
- Pass-to-goal allowed: pass path targeting a goal → valid
- Equipment consistency: wall in equipment but not in elements → warning
- Equipment mapping: partner in equipment, server element present → valid
- Archetype detection: instructions with "weave through cones" → cone_weave
- Coach pattern_type mapping: "zigzag" maps to cone_weave archetype
- Path-instruction alignment: 3 instructions but only 1 path → warning
- Age-appropriate spacing: U10 player with 15m cone spacing → warning
- Path reference validation: path from nonexistent label → removed
- Multiple archetypes tested: cone_weave, triangle_passing, wall_passing, server_executor

### Swift Rendering Tests (`TechnIQTests/DrillDiagramTests.swift`)

- All 9 element types parse correctly from raw string
- Unknown type defaults to `.cone`
- Backward compatibility: existing drill JSON renders unchanged
- DiagramElement id generation works for new types

### Integration Test (`functions/test_drill_pipeline_integration.py`)

- Full Writer → Post-Processor → Referee flow with new element types
- Verify post-processor warnings are passed to Referee
- Verify retry loop works with post-processor in the middle
- Test with each archetype to ensure end-to-end flow

---

## Pipeline Integration

Current pipeline: **Scout → Coach → Writer ⇄ Referee** (up to 3 retries)

Updated pipeline: **Scout → Coach → Writer → Post-Processor → Referee** (up to 3 retries on Writer→Post-Processor→Referee loop)

The post-processor sits between Writer and Referee. It **replaces** the existing `programmatic_validate()` function — all current programmatic checks are absorbed into the post-processor. Referee receives the post-processed diagram + warning list, which informs its validation scoring.

---

## Decisions

- **Auto-fix vs warnings:** Post-processor auto-fixes spatial issues silently AND returns warnings for issues it can't fix or that are informational. Warnings go to both the Referee and the client response's `validationWarnings` field.
- **Mannequin:** Included in v1. It's a simple element type (gray circle + X) and enables solo drills that simulate defensive pressure without requiring a second player.
- **Wall orientation:** Always horizontal. No rotation field needed — keeps the data model simple.
- **`pass` style for shots:** `pass` path style is used for both passes and shots on goal. No new `shoot` style needed.
