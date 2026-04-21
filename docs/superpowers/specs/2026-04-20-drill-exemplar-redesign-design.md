# AI Drill Generation: Exemplar-Driven Redesign

**Date:** 2026-04-20
**Status:** Design approved, plan pending

## Goal

Replace the 4-phase Scout → Coach → Writer → Referee LLM pipeline with a single LLM call guided by hand-authored soccer-drill exemplars. Optimize for diagram quality and soccer realism; latency improves as a side effect.

## Problem

Current pipeline in `functions/main.py` makes up to 12 LLM calls per drill across 4 agent phases. Despite the complexity, output quality is inconsistent:

- **Spatial nonsense** — cones placed outside the play area, players overlapping, gates facing the wrong way.
- **Path/flow confusion** — passing sequences that don't make sense, players running through obstacles.
- **Missing soccer realism** — drills that look correct structurally but no real coach would run (e.g., shooting from bizarre angles, cone weaves with 1m spacing for U16 players, "passing" drills where the ball never moves).

Root cause: LLMs don't have a strong prior for what makes a good soccer drill. Prompting with abstract rules ("use realistic spacing") doesn't fix taste. Multiple agent phases compound errors — Scout picks a bad archetype, Coach writes steps that don't match, Writer draws a diagram that matches neither.

## Approach

Replace the LLM-heavy pipeline with a **deterministic scaffold + exemplar few-shot + deterministic validation**:

1. A Python lookup maps `(weakness, experience_level)` to one of 9 archetypes — no LLM.
2. Retrieve 2-3 hand-authored exemplar drills for that archetype from `exemplars.json`.
3. Single Claude call receives player context + constraints + exemplars, emits DSL.
4. Python parser converts DSL to the existing `DrillDiagram` JSON schema.
5. Existing `drill_post_processor.py` clamps spacing and bounds.
6. New tiny validator checks structural integrity.
7. On parse/validation failure: one retry with error feedback; then fail.

## Architecture

**Old pipeline:**
```
Scout(LLM) → Coach(LLM) → Writer(LLM) → post_processor(Py) → Referee(LLM)
```

**New pipeline:**
```
pick_archetype(Py)       (weakness, experience) → archetype
  ↓
retrieve_exemplars(Py)   archetype → 2-3 exemplars
  ↓
writer(LLM)              exemplars + context → DSL
  ↓
parse_dsl(Py)            DSL → DrillDiagram JSON
  ↓
post_processor(Py)       spacing/bounds (existing)
  ↓
validator(Py)            structural integrity (new)
  ↓
[on failure: retry writer once with error feedback]
```

Key properties:
- 3 LLM calls → 1 (2 on retry)
- All non-creative work is deterministic and unit-testable
- Exemplars keyed by archetype alone — no 2D indexing

## DSL Specification

Human- and LLM-friendly text format. Units are meters. Origin `(0,0)` is bottom-left of the usable area.

**Elements:**
```
cone C1 at (0, 0)
cone C2 at (5, 0)
gate G1 at (10, 0) width 2
ball B1 at (0, 0)
goal GL at (20, 0) width 7.32
player P1 at (0, -1) role "server"
player P2 at (2, 0) role "worker" label "Start here"
```
- IDs: `C#` cones, `G#` gates, `B#` balls, `GL` goal, `P#` players
- `role` and `label` are optional
- All elements must have unique IDs

**Actions** (ordered steps):
```
step 1: P1 passes to P2
step 2: P2 dribbles to C1
step 3: P2 shoots at GL
step 4: P2 runs to P1
```
- Verbs: `passes to`, `dribbles to`, `runs to`, `shoots at`, `receives from`
- Target must be a declared element ID
- Step numbers strictly increasing from 1, no gaps

**Coaching points** (freeform bullets):
```
point: Keep the ball on your preferred foot through the gate
point: First touch out of your feet, not under them
```

**Example — cone_weave beginner:**
```
cone C1 at (0, 0)
cone C2 at (3, 0)
cone C3 at (6, 0)
cone C4 at (9, 0)
player P1 at (-2, 0) role "worker"
ball B1 at (-2, 0)

step 1: P1 dribbles to C1
step 2: P1 dribbles to C2
step 3: P1 dribbles to C3
step 4: P1 dribbles to C4

point: Use inside and outside of the same foot
point: Keep the ball within half a step at all times
```

## Components

### 1. Archetype picker — `functions/archetype_picker.py`

Deterministic lookup table. Covers the 9 weaknesses surfaced by the onboarding picker × 3 experience levels = ~27 entries. Unknown (weakness, level) pairs fall back to `cone_weave`.

```python
ARCHETYPE_TABLE: dict[tuple[str, str], str] = {
    ("Under Pressure", "beginner"): "gate_dribbling",
    ("Under Pressure", "intermediate"): "rondo",
    ("Under Pressure", "advanced"): "rondo",
    ("Finishing", "beginner"): "dribble_and_shoot",
    # ... remaining 23 entries authored alongside exemplars
}

def pick_archetype(weakness: str, level: str) -> str:
    return ARCHETYPE_TABLE.get((weakness, level), "cone_weave")
```

Replaces the entire Scout LLM phase.

### 2. Exemplars — `functions/exemplars.json`

Hand-authored, version-controlled. ~20 total, ≥2 per archetype.

```json
[
  {
    "id": "cone_weave_beginner_01",
    "archetype": "cone_weave",
    "dsl": "cone C1 at (0,0)\ncone C2 at (3,0)\n...\npoint: Keep the ball within half a step",
    "notes": "Classic 4-cone weave for U10 ball mastery"
  }
]
```

Retrieval (`functions/exemplars.py`):
```python
def get_exemplars(archetype: str, n: int = 3) -> list[dict]:
    return [e for e in EXEMPLARS if e["archetype"] == archetype][:n]
```

Loaded once at cold start.

### 3. Writer prompt

Single Claude call. Model: `claude-sonnet-4-6` (same as today).

```
[SYSTEM]
You design soccer training drills. Output ONLY valid DSL — no markdown, no prose.
DSL grammar: <compact grammar reference>

[USER]
Player: <age> <position>, experience <level>
Weakness to train: <weakness>
Archetype: <archetype>
Constraints: max area 15x15m, max spacing <age_max>m, equipment <allowed_list>

Examples of good <archetype> drills:
<exemplar 1 DSL>
---
<exemplar 2 DSL>
---
<exemplar 3 DSL>

Now design a drill in the same style for the player above.
Output DSL only.
```

On retry, a `PRIOR ATTEMPT ERRORS:` block is prepended with specific validator messages.

### 4. DSL parser — `functions/dsl_parser.py`

Recursive-descent, strict grammar. Raises `DSLParseError(line, reason)` on malformed input. Output: a `DrillDiagram` dict matching the existing JSON schema consumed by `drill_post_processor.py` and the iOS `DrillDiagramView`.

Mapping:
- DSL elements → `DrillDiagram.elements[]`
- DSL actions → `DrillDiagram.steps[].paths[]`
- DSL points → `DrillDiagram.coaching_points[]`

### 5. Validator — `functions/drill_validator.py`

~60 lines. Runs after `post_processor`. Raises `ValidationError(reason)` on any failure:

1. **Step targets exist** — every action source/target is a declared element ID.
2. **Step numbers contiguous** — `1, 2, 3, ...` with no gaps or duplicates.
3. **Equipment consistency** — every element type in the diagram is in the requested equipment list.
4. **At least one worker** — ≥1 `player` with role not `"server"`.
5. **At least one action step** — no empty drills.

No LLM Referee — deterministic checks only.

### 6. Retry loop — in `generate_custom_drill`

```python
errors: list[str] = []
for attempt in range(2):
    dsl = call_writer(prompt, prior_errors=errors)
    try:
        diagram = parse_dsl(dsl)
        diagram = post_process(diagram, age, equipment)
        validate(diagram)
        return diagram
    except (DSLParseError, ValidationError) as e:
        errors.append(str(e))
raise DrillGenerationFailed(errors)
```

Max 2 LLM calls. On final failure the function returns 500; iOS client surfaces existing retry UX.

### 7. Render-preview CLI — `functions/tools/render_exemplar.py`

Standalone tool for authoring. Usage:
```
python -m functions.tools.render_exemplar exemplars.json cone_weave_beginner_01
```

Behavior:
- Parses the DSL with the production parser
- Runs the production post-processor
- Writes a PNG to `/tmp/<id>.png` showing cones, players, labeled arrows for steps
- Dumps resolved JSON for coordinate inspection

Every exemplar PR includes the rendered PNG for visual review.

## Data Flow

```
iOS client
  ↓ HTTP POST (weakness, experience, age, position, equipment)
generate_custom_drill (functions/main.py)
  ↓
pick_archetype(weakness, experience) → archetype   [Py, ~0ms]
  ↓
get_exemplars(archetype) → [exemplar, ...]          [Py, ~0ms]
  ↓
build_prompt(player, archetype, exemplars, errors)  [Py, ~0ms]
  ↓
claude.call(prompt) → dsl                           [LLM, ~3-5s]
  ↓
parse_dsl(dsl) → diagram                            [Py, ~5ms]
  ↓
post_process(diagram, age, equipment) → diagram    [Py, ~5ms]
  ↓
validate(diagram) → ok | ValidationError            [Py, ~1ms]
  ↓ (on failure: loop once with errors in prompt)
return diagram → iOS client
```

Target end-to-end latency: ~5s (vs. current ~15-20s across 4 agents).

## Error Handling

| Failure | Handling |
|---------|----------|
| Unknown `(weakness, level)` pair | Fall back to `cone_weave` archetype |
| `archetype` has no exemplars | 500 with log; fail loudly during development |
| `DSLParseError` on attempt 1 | Retry with error in prompt |
| `ValidationError` on attempt 1 | Retry with error in prompt |
| Any error on attempt 2 | 500 to client; client shows existing retry UX |
| LLM timeout | Existing 540s Function timeout + retry logic in client |

No silent fallbacks to pre-authored drills — users should see errors when they happen, not get a mystery drill that wasn't tailored to them.

## Testing

### Unit tests (Python, pytest)

- `archetype_picker_test.py` — every (weakness, level) row returns a valid archetype; unknown keys fall back.
- `dsl_parser_test.py` — valid DSL parses correctly; malformed DSL raises `DSLParseError` with useful line numbers. Cover each statement type and each failure mode.
- `drill_validator_test.py` — each of the 5 checks fires correctly on a hand-crafted invalid diagram; passes on valid.
- `exemplars_test.py` — every entry in `exemplars.json` parses, post-processes, and validates successfully. This is the guardrail that prevents shipping broken exemplars.

### Integration test

- `test_generate_custom_drill.py` — end-to-end with a mocked LLM response. Happy path + retry path (first response malformed, second valid).

### Manual QA

- Generate drills for each of the 9 archetypes × 3 experience levels = 27 combinations.
- Eyeball diagrams in the iOS client for soccer realism.
- Compare against drills generated by the old pipeline for the same inputs.

## Authoring Workflow

Hybrid split (Q11):

1. **I draft ~12 mechanical exemplars:** cone_weave, gate_dribbling, relay_shuttle, wall_passing, dribble_and_shoot (2-3 each across experience levels).
2. **User drafts ~8 judgment-heavy exemplars:** rondo, triangle_passing, server_executor, 1v1_plus_server.
3. **Every exemplar PR includes:**
   - The DSL in `exemplars.json`
   - A rendered PNG from the preview CLI
   - Short notes on what the drill is training
4. **Acceptance bar:** "Would a good coach actually run this exact drill?" If no, revise.

## Migration & Rollout

- Changes are backend-only; iOS client continues calling the existing `generate_custom_drill` endpoint with the same request/response shapes.
- Existing Core Data-persisted drills are unaffected (they're already rendered diagrams, not regenerated).
- Feature flag not required — single atomic deploy of the new `generate_custom_drill` body. Old agent code (`phase_scout`, `phase_coach`, `phase_writer`, `phase_referee`) is deleted in the same PR.
- `drill_post_processor.py` is reused as-is; no schema changes to `DrillDiagram`.

## Non-Goals

- Changing the `DrillDiagram` JSON schema or iOS rendering.
- Adding archetypes beyond the existing 9.
- Real-time personalization beyond the existing weakness/experience inputs.
- Replacing the LLM entirely with a rule-based generator.
- Storing exemplars in Firestore (they're repo-versioned on purpose).

## Unresolved Questions

- Who owns adding new archetypes later — do we freeze at 9 or make exemplar expansion routine?
- Should `notes` from exemplars surface anywhere in-app (e.g., "based on classic U10 cone weave"), or stay internal?
- Is `cone_weave` the right safe-default archetype for unknown (weakness, level) pairs, or should the fallback be weakness-only (ignore level)?
