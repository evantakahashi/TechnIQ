# Drill Quality Upgrade — Plan 1

**Date:** 2026-04-21
**Branch:** feature/drill-exemplar-redesign (continues from same branch; may split to new branch during writing-plans)
**Status:** Design approved, awaiting user review before plan-writing

---

## Background

Earlier on 2026-04-21 we fixed two bugs in drill generation:
1. `main.py` was reading `player_profile.weaknesses` (static) instead of `requirements.selected_weaknesses` / `skill_description` (the user's actual request). Every drill defaulted to "Ball Control" → cone_weave archetype.
2. The generator prompt said "design in the same style" which anchored the LLM to copying exemplar layouts over reasoning about the skill.

After those fixes, drills are now **skill-specific** (first-touch requests produce first-touch coaching points). But user testing confirms they are still **football-poor**: cone patterns instead of practices, no pressure, no decision-making, no success criteria, no game-realism.

Two rounds of external critique arrived with overlapping-but-different proposals. After viability analysis, we adopted a **layered approach**: ship cheap prompt + validator + exemplar-tagging changes first (this plan), measure via the local CLI harness (`tools/try_drill.py`), then decide whether a deeper architectural rebuild is needed.

See `~/.claude/projects/-Users-evantakahashi-TechnIQ/memory/project_drill_quality_deferred.md` for the 6 items deliberately cut from Plan 1 and the reasoning.

---

## Goals

1. **Force game-realism** — drills for intermediate/advanced players must contain pressure, direction, and decision-making.
2. **Stop "valid bad drills"** — add a coaching-quality gate that rejects drills that pass DSL validation but don't train the requested skill.
3. **Keep the iteration loop fast** — everything still runs through the single-LLM pipeline, playable via `python -m tools.try_drill` in ~5s.
4. **No iOS changes** — entirely backend; iOS consumes unchanged `{drill, generated_at}` response shape.

## Non-goals

- Structural rebuild (TrainingSpec dataclass, two-stage generator, scenario RAG, full DSL expansion). See deferred memory.
- User-facing drill-rating UI. Separate project.
- Fixing `archetype_picker.py` gaps like "Speed & Agility" not matching "Speed". Rule packs cover the missing cases well enough; archetype lookup just falls back to `cone_weave`, which the LLM can adapt.

---

## Scope

### Included (7 items)

| # | Component | Files touched |
|---|-----------|---------------|
| 1 | Category rule packs | `functions/category_rules.py` (new), `functions/drill_generator.py` |
| 2 | Prompt rewrite (periodization + elite reqs + rule injection) | `functions/drill_generator.py` |
| 3 | Coaching-quality validator | `functions/drill_quality.py` (new), `functions/drill_generator.py` |
| 4 | Retry loop with quality feedback | `functions/drill_generator.py` |
| 5 | Exemplar intensity tagging | `functions/exemplars.json`, `functions/exemplars.py`, `functions/test_exemplars.py` |
| 6 | 4-6 new high-intensity exemplars | `functions/exemplars.json` |
| 7 | DSL `defender` role | `functions/dsl_parser.py`, `functions/drill_post_processor.py`, `functions/test_dsl_parser.py` |

### Excluded

See `project_drill_quality_deferred.md`.

---

## Components

### 1. Category rule packs — `functions/category_rules.py`

A module with one dict keyed by iOS-side `WeaknessCategory.displayName` strings. Coverage: **Dribbling, Passing, Shooting, First Touch, Defending, Speed & Agility** (the 6 most-requested categories). Uncovered categories (Stamina, Positioning, Weak Foot, Aerial Ability) return `None`; prompt gracefully degrades to no-rule-pack mode.

Each entry:

```python
{
    "primary_action": "receive a ball while a defender closes, control it directionally, play forward in ≤2 touches",
    "verb_keywords": ["receive", "control", "turn", "play forward"],  # for validator text-matching
    "must_include": ["server", "pressure", "directional outcome"],
    "must_avoid": ["isolated cone slalom with no service", "stationary receive without pressure"],
    "success_metric": "≥70% of reps exited forward within 2 touches",
    "perception_action_cue": "server varies ball height and pace; worker scans over shoulder before reception",
}
```

**`verb_keywords`** is the validator's hook — text-matching against step verbs and coaching points is cheap and robust.

**`get_rule_pack(category: str) -> dict | None`** — case-insensitive lookup; returns `None` for uncovered categories.

### 2. Prompt rewrite — `functions/drill_generator.py`

Two additions to the existing prompt:

**a. Periodization framing** (placed in SYSTEM_PROMPT, gated by level):

```
PRACTICE TYPE BY LEVEL:
- beginner → Isolated practice (technical reps, 0 defenders OK)
- intermediate → Analytical practice (passive pressure — server participates, constrained choices)
- advanced → Global practice (active pressure — defender closes, real decisions, game-realistic transitions)
```

**b. Elite requirements** (gated by `level in ("intermediate", "advanced")`, injected in `_build_prompt`):

```
For intermediate/advanced, the drill MUST include:
- Active resistance: a server who passes, a defender who closes, or a trigger that forces a decision
- Directionality: a clear objective end (goal, gate, line) and a reset state
- Scanning: the worker must look away from the ball at some point (e.g., reads a visual cue from the server before the next action)
```

**c. Category rule pack block** (injected if `get_rule_pack(weakness)` returns non-None):

```
SKILL-SPECIFIC COACHING REQUIREMENTS ({category}):
Primary action the drill must force: {primary_action}
Must include: {', '.join(must_include)}
Must avoid: {', '.join(must_avoid)}
Success metric: {success_metric}
Perception-action cue: {perception_action_cue}
```

**d. Replace "maximize reps" with "maximize game-relevant reps"** in the closing instruction.

### 3. Coaching-quality validator — `functions/drill_quality.py`

```python
def score_drill_quality(
    drill: dict,
    rule_pack: dict | None,
    level: str,
) -> tuple[int, list[str]]:
    """Return (checks_passed, reasons_for_failures). Max score = 4."""
```

**Four checks, each worth 1 point. C2 is compound.**

| Check | Logic | Applies |
|-------|-------|---------|
| **C1: forces_primary_action** | ≥1 `verb_keyword` from rule_pack appears as a **case-insensitive substring** of any step verb OR any coaching_point text. | covered categories all levels; uncovered: auto-pass (handled by C2 floor) |
| **C2: structural_realism** *(compound — ALL four sub-checks must pass to earn the point)* | **C2a:** ≥2 distinct player elements (role in {worker, server, defender}). **C2b:** ≥1 outcome object — element of type `goal`, or element of type `gate`, or a coaching point containing the word "line", "gate", "goal", "zone". **C2c:** ≥1 pressure source — player with role `"defender"` is present, OR ≥1 server appears as `from_id`/`to_id` in ≥2 distinct step numbers. **C2d:** ≥1 element participates (from_id or to_id) in ≥2 distinct step numbers (rep-loop shape, not a linear one-off chain). | intermediate + advanced (beginner auto-pass) |
| **C3: coaching_points_on_target** | ≥2 total coaching points AND ≥1 coaching point (case-insensitive substring) contains a `verb_keyword` OR any significant word (length ≥5, stopwords stripped) from `success_metric`. | covered categories all levels; uncovered: relaxed to "≥2 coaching points, ≥1 non-generic" (see §Generic realism floor below) |
| **C4: rep_density** | Total step count ≥5 OR any single element ID appears as `from_id` or `to_id` in ≥3 distinct steps. | all levels |

**C1 vs C3 are not redundant:** C1 passes if the right action appears *anywhere* (steps or coaching); C3 specifically requires it in the coaching narrative AND enforces coaching-point thickness. A drill can have correct steps but paper-thin or generic coaching — C3 catches that.

**Why C2 is compound:** single-predicate C2 ("server participates") is gameable — the LLM can satisfy it by mentioning a server that barely moves. Requiring ≥2 players + outcome object + pressure source + rep-loop shape all at once is much harder to fake with text tricks.

**Threshold:** `score >= 3` passes. **Additionally, if level != "beginner", C2 is mandatory** — C2 failure forces rejection regardless of other checks. This prevents a drill from slipping through with 3/4 on C1+C3+C4 while being structurally flat (no pressure, no outcome).

**Why these 4:** they cover the four failure modes called out in review: (1) drill doesn't actually train the skill, (2) no real football structure for intermediate/advanced, (3) coaching points generic or thin, (4) not enough reps.

#### Generic realism floor (uncovered categories, level != beginner)

When `rule_pack is None` AND level is intermediate/advanced, the validator uses these substitutions:

- **C1:** auto-pass (no rule pack to check against)
- **C2:** unchanged — all four sub-checks still apply (they're category-agnostic)
- **C3:** replaced with "≥2 coaching points total, ≥1 is non-generic." A coaching point is "generic" if it matches the `GENERIC_COACHING_BLACKLIST` (e.g., "work hard", "give 100%", "focus", "concentrate", "stay alert", "try your best", "good effort") and contains no football-action verbs (receive, pass, shoot, dribble, defend, turn, close, press, scan, switch, cushion, strike, curl, drive, cut, feint). At least one non-generic coaching point must exist.
- **C4:** unchanged

For `rule_pack is None` AND level is beginner: only C4 applies. Beginner + uncovered = "do no harm" mode.

**Net effect:** even for the four categories without rule packs (Stamina, Positioning, Weak Foot, Aerial Ability), an intermediate/advanced drill still has to show structural football (C2), non-trivial coaching (C3), and adequate reps (C4). No "valid bad drill" free pass.

### 4. Retry loop with quality feedback — `functions/drill_generator.py`

Changes to `generate_drill()`:

```python
MAX_ATTEMPTS = 4  # was 2

class QualityError(Exception):
    """Raised when drill passes syntax but fails coaching-quality gate."""

for _attempt in range(MAX_ATTEMPTS):
    prompt = _build_prompt(..., prior_errors=errors)
    raw = llm_call(prompt)
    try:
        drill = parse_dsl(raw)
        drill["equipment"] = equipment
        drill, _warnings = post_process_drill(drill, player_age=age)
        validate_drill(drill)                                # syntax
        score, reasons = score_drill_quality(drill, rule_pack, level)
        if score < 3:
            raise QualityError(reasons)
        return drill
    except (DSLParseError, ValidationError) as e:
        errors.append(("syntax", str(e)))
    except QualityError as e:
        errors.append(("quality", "; ".join(e.args[0])))
```

**Error framing in prompt:**

```
PRIOR ATTEMPT ERRORS:
- [syntax] unknown statement at line 3
- [quality] PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE BECAUSE: no server/defender participation; coaching points don't reference the primary action
```

The framing matters — "valid DSL but not useful" tells the LLM the geometry was fine but the football was wrong. That's different from a parse error, and the LLM responds differently.

### 5. Exemplar intensity tagging — `functions/exemplars.json` + `functions/exemplars.py`

**Schema addition:** each exemplar gets a `pressure` field.

```json
{
  "id": "cone_weave_beginner_01",
  "archetype": "cone_weave",
  "pressure": "none",
  "dsl": "..."
}
```

Values: `"none"` (no opposition, no server action) | `"passive"` (server feeds balls but doesn't move adversarially) | `"active"` (defender closes, server presses, real time pressure).

**`get_exemplars(archetype, level=None, n=3)`:**

Cascade, in order:
1. Primary archetype + pressure tag matching level → if non-empty, return.
2. **Neighbor archetypes** (see map below) + pressure tag matching level → return from first neighbor that yields results.
3. **Empty list** — drop the exemplar block from the prompt entirely. **No silent fallback to unfiltered (wrong-pressure) exemplars.** Rationale per review: a bad exemplar is worse than no exemplar; better to lean on rule pack + prompt than anchor the LLM on a passive shape when the player needs active pressure.

```python
ARCHETYPE_NEIGHBORS = {
    "cone_weave":        ["gate_dribbling", "1v1_plus_server"],
    "wall_passing":      ["triangle_passing", "rondo"],
    "gate_dribbling":    ["1v1_plus_server", "cone_weave"],
    "dribble_and_shoot": ["1v1_plus_server", "server_executor"],
    "server_executor":   ["1v1_plus_server", "rondo"],
    "triangle_passing":  ["rondo", "wall_passing"],
    "1v1_plus_server":   ["rondo", "gate_dribbling"],
    "rondo":             ["1v1_plus_server", "triangle_passing"],
}

def get_exemplars(archetype, level=None, n=3):
    allowed = {
        "beginner":     {"none", "passive"},
        "intermediate": {"passive", "active"},
        "advanced":     {"active"},
    }.get(level) if level else None

    def _match(arch):
        hits = [e for e in EXEMPLARS if e["archetype"] == arch]
        if allowed is None:
            return hits
        return [e for e in hits if e.get("pressure", "none") in allowed]

    primary = _match(archetype)
    if primary:
        return primary[:n]
    for neighbor in ARCHETYPE_NEIGHBORS.get(archetype, []):
        neighbor_hits = _match(neighbor)
        if neighbor_hits:
            return neighbor_hits[:n]
    return []  # no fallback to wrong-pressure exemplars
```

**Prompt handling for empty exemplars:** `_build_prompt` must detect empty list and render alternative text: `"No matching reference drill for this pressure level. Design from first principles using the rule pack and elite requirements above."` The "Reference drills" header is skipped when empty.

**Observability:** log (not fail) when cascade falls back to a neighbor or returns empty. Tag: `[exemplar-cascade]`.

**Test updates:** `test_exemplars.py` gets cases for the level filter, the neighbor cascade, and the empty-return path.

### 6. New high-intensity exemplars (4-6) — `functions/exemplars.json`

Gap analysis of the current 20 exemplars (most are `none` / `passive`):

| Archetype | Current pressure coverage | Gap |
|-----------|---------------------------|-----|
| cone_weave | none (all 2) | no gap — beginner only by design |
| wall_passing | passive (both) | may need 1 active for intermediate |
| gate_dribbling | passive + none | may need 1 active |
| dribble_and_shoot | passive (all 2) | needs 1 active (defender recovers) |
| server_executor | passive (all 3) | needs 1 active (server becomes closer) |
| triangle_passing | passive (all 3) | OK — triangle is inherently passive |
| 1v1_plus_server | active (all 3?) | author 1 more advanced variant |
| rondo | passive + active | 1 more advanced transition variant |

**Plan: 4 new exemplars (targeted, not bulk):**

1. **`dribble_and_shoot_advanced_01`** — pressure: active. Worker beats cone, defender recovers from 5m back, shot must beat defender's reach.
2. **`server_executor_advanced_02`** — pressure: active. Server plays ball in, immediately closes to 3m pressure, worker must first-touch away from pressure. (Named `_02` because `_01` was authored during T9 as a `passive` variant; don't collide.)
3. **`1v1_plus_server_advanced_02`** — pressure: active. 1v1 with recovery runner joining after 3 seconds (transition element).
4. **`rondo_advanced_02`** — pressure: active. 3v1+1 transition rondo: possession team, on winning ball, must dribble through target gate within 5 sec.

**Existing 20 exemplars** get a `pressure` field retroactively (bulk-edit to `exemplars.json`).

**Authoring workflow per user:** I draft each exemplar's DSL using coaching knowledge + web research for drill references, render via `tools/render_exemplar`, user critiques, iterate until accepted. Same cadence as T9.

### 7. DSL `defender` role — `functions/dsl_parser.py`, `drill_post_processor.py`

**Grammar change:** currently accepts `role "worker"` and `role "server"`. Add `role "defender"`.

**Parser:** minimal — add `"defender"` to the role-string allowlist.

**Post-processor:** defender treated identically to other players for geometric clamping, spacing.

**Validator:** syntax validator (`drill_validator.py`) unchanged. Quality validator (C2) checks defender participation.

**Render:** `tools/render_exemplar.py` gets a new color for defender (distinct from worker's red, e.g., dark purple/gray). Badge letter: "D". Low-risk visual change.

**No new step verbs.** Defender uses existing verbs (`runs to`, `dribbles to`, `passes to`, `receives from`). "Closes down" is a coaching point concept, not a DSL verb.

---

## Data flow (post-changes)

```
iOS POST /generate_custom_drill  (unchanged shape)
  ↓
main.py  (unchanged: extracts weakness, skill_description, selected_weaknesses, level, age, ...)
  ↓
generate_drill(request, llm_call):
    weakness, level = ...
    archetype   = pick_archetype(weakness, level)              # unchanged
    exemplars   = get_exemplars(archetype, level=level, n=3)   # NEW: filtered by pressure
    rule_pack   = category_rules.get_rule_pack(weakness)       # NEW: None OK
    errors: list[tuple[str, str]] = []

    for attempt in range(MAX_ATTEMPTS=4):
        prompt = _build_prompt(
            ...,
            rule_pack=rule_pack,     # NEW
            exemplars=exemplars,
            prior_errors=errors,
        )
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)                              # NEW: defender role
            drill["equipment"] = equipment
            drill, _ = post_process_drill(drill, player_age=age)
            validate_drill(drill)                               # syntax (unchanged)
            score, reasons = score_drill_quality(drill, rule_pack, level)  # NEW
            if score < 3:
                raise QualityError(reasons)
            return drill
        except (DSLParseError, ValidationError) as e:
            errors.append(("syntax", str(e)))
        except QualityError as e:
            errors.append(("quality", "; ".join(e.args[0])))

    raise DrillGenerationFailed(f"Exhausted 4 attempts: {errors}")
  ↓
main.py: wraps {drill, generated_at}, renames coaching_points → coachingPoints, sets defaults (unchanged)
  ↓
iOS
```

---

## Testing

### Unit tests

- **`test_category_rules.py`** (new): lookup by exact string, lookup by `.lower()` case-insensitive, unknown key returns `None`.
- **`test_drill_quality.py`** (new):
  - Each check C1–C4 independently — pass + fail cases.
  - Combined scoring: exactly 3 passes → accept; exactly 2 → reject with reasons.
  - Auto-pass behavior when rule_pack is `None` (C1, C3 skipped).
  - beginner never requires C2.
- **`test_drill_generator.py`** (extend): new `test_retries_on_quality_error` — first LLM call returns valid DSL that fails C2 (no server for advanced), second call returns a drill with server → assert 2 calls, final drill returned, "PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE" appears in 2nd prompt.
- **`test_exemplars.py`** (extend): `test_get_exemplars_filters_by_level`, `test_get_exemplars_falls_back_when_no_match`.
- **`test_dsl_parser.py`** (extend): defender role parses and round-trips through post-processor.

### Integration

- CLI harness: run `try_drill.py` across 4 skills (first touch, finishing, 1v1 defending, crossing) × 3 levels. Render PNGs. User visual critique.

### Existing tests

- All 100 current tests must pass unchanged except `test_exemplars.py` (new filter-by-level assertions are additions, not breaking changes).

---

## Success criteria

1. All existing + new tests pass.
2. For level=advanced, `score_drill_quality` returns ≥3/4 AND C2 passes on 80%+ of CLI-generated drills, measured over ≥12 generations across the 6 covered categories.
3. **Blinded manual rating — the real gate:** user rates a fixed test set of **20 prompts** (the 6 covered categories × beginner/intermediate/advanced, plus a few uncovered edge cases) on a 1-5 "game-realism" scale without seeing the validator score. Target: **mean ≥3.5, no drill below 2**. This is the metric that actually decides whether Plan 1 is done; the validator score in #2 is a correlated proxy we use for fast iteration.
4. CLI latency ≤ 15s for a 2-retry generation (first attempt quality-fail, second succeeds). Worst case (4 retries exhausted) ≤ 30s.
5. iOS-observable response shape unchanged.

---

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Quality checker too strict → all 4 attempts fail → `DrillGenerationFailed` returned to user | 3/4 threshold; `MAX_ATTEMPTS=4`; fallback: if attempt 4 fails quality but passes syntax, return it anyway with a warning logged. (Spec decision: **do NOT add this fallback in Plan 1** — we want to see failure rate, and iOS already handles errors gracefully. Revisit after measurement.) |
| Category rule packs feel formulaic / LLM parrots the language | Rule packs are guidance, not a script. LLM still writes the DSL and coaching points. Plus `verb_keywords` matches loosely — doesn't require verbatim copying. |
| Defender role in DSL not rendered in `render_exemplar.py` | Add new color + "D" badge in the same PR. Low risk. |
| New high-intensity exemplars drift from user's taste | User critiques each before commit; same cadence as T9 (one commit per approved exemplar). |
| `pressure="active"` filter for advanced returns empty set for some archetypes (e.g., cone_weave has no active variants) | `get_exemplars` cascades to neighbor archetypes (e.g., cone_weave → gate_dribbling → 1v1_plus_server). If all empty, returns `[]` and the prompt instructs the LLM to design from first principles. Explicitly **no** fallback to unfiltered passive exemplars — a bad reference is worse than no reference. Logged as `[exemplar-cascade]`. |
| Prompt grows too long, hits context limits | Current prompt is ~1200 tokens; rule pack + periodization adds ~400 tokens. Well within 8k window for claude-sonnet-4-6. |

---

## File manifest (final diff targets)

**New:**
- `functions/category_rules.py`
- `functions/drill_quality.py`
- `functions/test_category_rules.py`
- `functions/test_drill_quality.py`
- `docs/superpowers/specs/2026-04-21-drill-quality-upgrade-design.md` (this file)

**Modified:**
- `functions/drill_generator.py` (prompt, retry loop, imports)
- `functions/exemplars.py` (level filter)
- `functions/exemplars.json` (add `pressure` field to existing 20; add 4 new high-intensity)
- `functions/dsl_parser.py` (defender role)
- `functions/drill_post_processor.py` (defender in geometric handling if needed)
- `functions/tools/render_exemplar.py` (defender color/badge)
- `functions/test_exemplars.py` (level-filter tests)
- `functions/test_drill_generator.py` (quality retry test)
- `functions/test_dsl_parser.py` (defender role test)

**Untouched** (no iOS / no infra changes):
- `functions/main.py`
- `functions/archetype_picker.py`
- `functions/drill_validator.py`
- All `TechnIQ/**/*.swift`

---

## Commit cadence (decided)

**Per-component commits.** Each component is a separate commit (or small commit series where tests + impl live together per TDD). The 4 new exemplars get one commit each (T9-style) after user approval of the render.

1. `feat(drill): add category rule packs for top 6 weaknesses`
2. `feat(drill): add pressure tag + level filter to exemplars` (includes neighbor-archetype cascade)
3. `feat(drill): add defender role to DSL parser + renderer`
4. `feat(drill): add coaching-quality validator (C1-C4 + generic realism floor)`
5. `feat(drill): rewrite prompt with periodization + rule packs + empty-exemplar handling`
6. `feat(drill): wire quality validator into retry loop (MAX_ATTEMPTS=4)`
7-10. `feat(exemplar): add <id>` × 4 new high-intensity exemplars

## Decisions recorded

- **Defender render color:** `(140, 50, 200)` dark purple with "D" badge. Clearly distinct from worker red `(220, 40, 40)` and server role (no specific color today — worker red with "S" badge). Picked, moving on.
- **Exhausted-retry behavior:** hard-fail (`DrillGenerationFailed`) and let iOS surface the error. Measure the miss rate in production. Fallback-to-last-valid-drill is deferred behind a flag until we know the rate.
- **Validator strictness:** C2 is compound + mandatory for non-beginner (per review). Generic realism floor applied to uncovered categories at intermediate/advanced. No free passes for "valid bad drills."
- **Exemplar cascade:** primary archetype → neighbor archetype → empty. No fallback to wrong-pressure exemplars.
