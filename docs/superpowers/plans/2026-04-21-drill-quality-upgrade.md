# Drill Quality Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise drill-gen game-realism for intermediate/advanced players by adding periodization prompting, a coaching-quality validator, pressure-tagged exemplar retrieval with neighbor cascade, and a DSL `defender` role — all behind the existing single-LLM pipeline.

**Architecture:** Keep `generate_drill()` as the sole orchestrator. Inject one new guidance layer (category rule packs + periodization) into the prompt, one new gate (quality validator C1–C4) into the retry loop, and one new cut (level-scoped pressure filter + neighbor cascade) into exemplar retrieval. No iOS changes; response shape unchanged.

**Tech Stack:** Python 3.12, Anthropic SDK (`claude-sonnet-4-6`), pytest 8.x, Pillow (renderer), Firebase Functions 2nd-gen runtime.

**Spec:** `docs/superpowers/specs/2026-04-21-drill-quality-upgrade-design.md`
**Deferred items (do not reopen):** `~/.claude/projects/-Users-evantakahashi-TechnIQ/memory/project_drill_quality_deferred.md`

---

## Conventions

- Run tests from `functions/`: `pytest -q <path>` (no venv; pytest is on PATH).
- Every task ends with a single commit using a short present-tense message: `feat(drill): ...`, `feat(exemplar): ...`, etc. Do not mention Claude in commit trailers (user's global rule).
- Never stage `functions/.env`, `GoogleService-Info.plist`, or anything in `.claude/rules/no-commit.md`.
- When a step says "Write the failing test" — write the test, save the file, and move on. The next step runs it.
- Never use `git add -A` or `git add .`. Stage files by exact path.
- For steps that show code inside an existing function, the surrounding function signature in this plan is the authoritative signature to produce — if the current repo differs, the step shows the full replacement.

---

## File structure

**New files:**
- `functions/category_rules.py` — rule packs (6 covered categories) + `get_rule_pack()`.
- `functions/drill_quality.py` — `score_drill_quality()` + C1–C4 predicates + `GENERIC_COACHING_BLACKLIST`.
- `functions/test_category_rules.py` — rule-pack lookup tests.
- `functions/test_drill_quality.py` — C1–C4 independent + combined tests.

**Modified files:**
- `functions/drill_generator.py` — `SYSTEM_PROMPT` rewrite, `_build_prompt()` periodization + rule-pack injection + empty-exemplar handling, `generate_drill()` `MAX_ATTEMPTS=4` + `QualityError` + typed errors.
- `functions/exemplars.json` — `pressure` field on every entry; 4 new high-intensity entries at end.
- `functions/exemplars.py` — `get_exemplars(archetype, level=None, n=3)` with level filter + neighbor cascade + empty-return semantics; `ARCHETYPE_NEIGHBORS` map.
- `functions/test_exemplars.py` — extend with level-filter, neighbor-cascade, empty-return tests; update `test_at_least_sixteen_entries` → `test_has_twenty_four_entries`.
- `functions/tools/render_exemplar.py` — add dark purple color + "D" badge for defender role.
- `functions/test_dsl_parser.py` — add defender-role parse test.
- `functions/test_drill_generator.py` — add `test_retries_on_quality_error`, `test_prompt_injects_rule_pack_when_covered`, `test_prompt_degrades_when_no_rule_pack`, `test_prompt_injects_periodization_block`, `test_prompt_handles_empty_exemplars`.

**Untouched:**
- `functions/main.py`, `functions/archetype_picker.py`, `functions/drill_validator.py`, `functions/drill_post_processor.py`, `functions/dsl_parser.py` (already accepts any role string generically), all Swift sources.

---

## Task order and dependencies

```
T0: resolve T9 exemplar baseline → commit or revert
   ↓
T1: category rule packs (standalone)
T2: DSL defender role renderer (standalone)
T3: exemplar pressure tagging + level filter + neighbor cascade (depends on T0)
   ↓
T4: coaching-quality validator (depends on T1)
T5: prompt rewrite (depends on T1, T3)
T6: retry loop wiring (depends on T4, T5)
   ↓
T7-T10: author + approve + commit 4 high-intensity exemplars (depends on T2, T3)
```

Execute T1–T3 in parallel-friendly order (each is independent after T0). T4–T6 are sequential. T7–T10 can happen any time after T2+T3 finish.

---

## Task 0: Resolve the T9 exemplar baseline

**Files:**
- Dirty: `functions/exemplars.json`, `functions/test_exemplars.py` (uncommitted T9 drafts add 12 exemplars bringing total to 20)

**Context:** Before Plan 1 starts, the working tree holds 12 drafted exemplars from T9 (the "expand to 20" task). Plan 1 Task 3 adds `pressure` fields to *all* existing exemplars, so we need the baseline committed first. Either the user signed off on all 12 during T9 (commit them), or they didn't (revert them and fall back to the 8-exemplar baseline).

- [ ] **Step 1: Read the dirty state to confirm what's pending**

Run: `git diff --stat functions/exemplars.json functions/test_exemplars.py`

Expected: 2 files changed, roughly `+85` / `-9` lines. Confirms T9 drafts are present.

- [ ] **Step 2: Ask the user: approve or revert?**

Ask exactly: "T9 left 12 exemplars drafted but uncommitted. Approve all 12 (commit) or revert to the 8-exemplar baseline? If approve, I'll commit now as 'feat(exemplar): add T9 baseline (12 new, total 20)'."

Wait for answer before proceeding.

- [ ] **Step 3a (if user approves): run all exemplar tests to confirm the 12 new ones parse**

Run: `pytest -q functions/test_exemplars.py`
Expected: All tests PASS. Should see 20 parametrized `test_exemplar_parses_post_processes_and_validates` cases.

- [ ] **Step 3b (if user approves): stage and commit the T9 baseline**

```bash
git add functions/exemplars.json functions/test_exemplars.py
git commit -m "feat(exemplar): add T9 baseline (12 new, total 20)"
```

- [ ] **Step 3c (if user rejects): revert both files**

```bash
git checkout -- functions/exemplars.json functions/test_exemplars.py
```

Then rerun `pytest -q functions/test_exemplars.py` and expect PASS with the 8 existing parametrized cases.

**Post-task state:** `functions/exemplars.json` is either 20 entries (approved) or 8 entries (reverted). Subsequent tasks reference "N existing exemplars" — use whichever count applies.

---

## Task 1: Category rule packs

**Files:**
- Create: `functions/category_rules.py`
- Test: `functions/test_category_rules.py`

**Context:** One dict keyed by `WeaknessCategory.displayName` strings. 6 covered categories: Dribbling, Passing, Shooting, First Touch, Defending, Speed & Agility. `get_rule_pack()` is case-insensitive; unknown keys return `None`.

- [ ] **Step 1: Write the failing test**

Create `functions/test_category_rules.py`:

```python
"""Tests for category rule-pack lookup."""
import pytest
from category_rules import RULE_PACKS, get_rule_pack


def test_six_covered_categories():
    covered = {"Dribbling", "Passing", "Shooting", "First Touch", "Defending", "Speed & Agility"}
    assert covered.issubset(RULE_PACKS.keys())


def test_every_pack_has_required_fields():
    required = {"primary_action", "verb_keywords", "must_include",
                "must_avoid", "success_metric", "perception_action_cue"}
    for name, pack in RULE_PACKS.items():
        assert required.issubset(pack.keys()), f"{name!r} missing fields"
        assert isinstance(pack["verb_keywords"], list) and pack["verb_keywords"]
        assert isinstance(pack["must_include"], list) and pack["must_include"]
        assert isinstance(pack["must_avoid"], list) and pack["must_avoid"]


def test_get_rule_pack_exact_match():
    pack = get_rule_pack("Shooting")
    assert pack is not None
    assert "shoot" in pack["verb_keywords"] or any("shoot" in k for k in pack["verb_keywords"])


def test_get_rule_pack_case_insensitive():
    assert get_rule_pack("shooting") == get_rule_pack("Shooting")
    assert get_rule_pack("FIRST TOUCH") == get_rule_pack("First Touch")


def test_get_rule_pack_unknown_returns_none():
    assert get_rule_pack("Stamina") is None
    assert get_rule_pack("Positioning") is None
    assert get_rule_pack("") is None
    assert get_rule_pack("nonsense category") is None


def test_verb_keywords_are_lowercase():
    for name, pack in RULE_PACKS.items():
        for kw in pack["verb_keywords"]:
            assert kw == kw.lower(), f"{name!r} keyword {kw!r} not lowercase"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest -q functions/test_category_rules.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'category_rules'`.

- [ ] **Step 3: Write the implementation**

Create `functions/category_rules.py`:

```python
"""Weakness-category rule packs. Injected into the drill-gen prompt."""
from __future__ import annotations

from typing import Any

RULE_PACKS: dict[str, dict[str, Any]] = {
    "Dribbling": {
        "primary_action": "carry the ball past a defender or through a gate under time pressure, change pace or direction to beat opposition",
        "verb_keywords": ["dribble", "carry", "beat", "turn", "cut", "feint", "accelerate"],
        "must_include": ["worker with ball", "beatable target (defender or tight gate)", "end-line or finishing target"],
        "must_avoid": ["isolated cone slalom with no opposition and no end target", "passive walking between cones"],
        "success_metric": "≥70% of reps beat the defender/gate cleanly and arrive at the end target with the ball under control",
        "perception_action_cue": "worker scans for defender body shape; attacks front foot to force the turn",
    },
    "Passing": {
        "primary_action": "play a weighted, accurate pass between teammates under passive or active pressure, then reposition for the return",
        "verb_keywords": ["pass", "receive", "play", "open up", "support"],
        "must_include": ["≥2 players exchanging passes", "directional target or rotating position", "receiver repositioning between passes"],
        "must_avoid": ["two stationary players exchanging passes in a straight line with no off-ball movement"],
        "success_metric": "≥80% of passes arrive to the receiver's correct foot in ≤2 seconds with pressure applied",
        "perception_action_cue": "passer looks up before the pass; receiver opens body to next option before the ball arrives",
    },
    "Shooting": {
        "primary_action": "strike on goal after a setup touch, with server service or a defender closing to force a quick decision",
        "verb_keywords": ["shoot", "strike", "finish", "drive", "curl", "place"],
        "must_include": ["goal element", "setup touch before the strike", "server feed OR defender pressure"],
        "must_avoid": ["stationary ball placed in front of empty goal", "unlimited time with no pressure or service"],
        "success_metric": "≥60% of shots on target within 2 seconds of the final touch",
        "perception_action_cue": "scan keeper/goal before the final touch; plant foot next to ball, head still at contact",
    },
    "First Touch": {
        "primary_action": "receive a moving ball while a server feeds and a defender closes, control it directionally, play forward in ≤2 touches",
        "verb_keywords": ["receive", "control", "touch", "cushion", "redirect", "turn"],
        "must_include": ["server who passes the ball in", "pressure source (active defender or tight time window)", "directional exit (gate, goal, or second player)"],
        "must_avoid": ["stationary receive with no pressure", "ground ball only — must vary service (bouncing, driven, lofted)"],
        "success_metric": "≥70% of receptions exit forward toward the target within 2 touches",
        "perception_action_cue": "server varies ball height and pace; worker scans over shoulder before reception to locate pressure",
    },
    "Defending": {
        "primary_action": "close down an attacker, deny the forward pass or dribble line, win or delay the ball until cover arrives",
        "verb_keywords": ["close", "press", "jockey", "block", "tackle", "intercept", "recover"],
        "must_include": ["attacker with ball", "defender worker", "target the attacker is trying to reach (goal, line, gate)"],
        "must_avoid": ["defender as a passive cone — must actively close and react", "1v1 with no objective for either player"],
        "success_metric": "≥60% of reps, defender wins the ball OR delays the attacker ≥3 seconds without fouling",
        "perception_action_cue": "defender reads attacker's hips and touch; closes on the outside, forces them onto weaker foot",
    },
    "Speed & Agility": {
        "primary_action": "accelerate, decelerate, and change direction around cones or a defender while keeping the ball under control",
        "verb_keywords": ["accelerate", "sprint", "cut", "change direction", "burst", "dribble"],
        "must_include": ["multiple change-of-direction points (cones, gates, or defender)", "clear end line or finishing target", "explosive start or burst cue"],
        "must_avoid": ["jogging through a flat line of cones", "no change-of-pace demand"],
        "success_metric": "each rep completed in ≤6 seconds at full intent; no loss of ball control on direction changes",
        "perception_action_cue": "low hips into cuts; explosive push off the outside foot, eyes up between changes",
    },
}


def get_rule_pack(category: str) -> dict[str, Any] | None:
    """Case-insensitive lookup. Returns None for uncovered categories."""
    if not category:
        return None
    needle = category.strip().lower()
    for name, pack in RULE_PACKS.items():
        if name.lower() == needle:
            return pack
    return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest -q functions/test_category_rules.py`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add functions/category_rules.py functions/test_category_rules.py
git commit -m "feat(drill): add category rule packs for top 6 weaknesses"
```

---

## Task 2: DSL defender role (renderer + parse regression test)

**Files:**
- Modify: `functions/tools/render_exemplar.py` (lines 32-38 colors dict, lines 240-249 badge block)
- Test: `functions/test_dsl_parser.py` (add defender-role parse test)

**Context:** The DSL grammar already accepts any string in `role "..."` — no parser change needed. `VALID_PASS_TARGETS` and `EQUIPMENT_TO_ELEMENT_TYPES` already include `"defender"`. Only two things actually change: (a) prompt grammar docstring lists defender as an option (happens in T5), (b) renderer gets a dark-purple color + "D" badge.

- [ ] **Step 1: Write the failing parse test**

Append to `functions/test_dsl_parser.py`:

```python
def test_parse_defender_role():
    dsl = """\
player P1 at (3, 7.5) role "server"
player P2 at (8, 7.5) role "worker"
player P3 at (12, 7.5) role "defender"
ball B1 at (3, 7.5)
goal GL at (18, 7.5) width 7.32

step 1: P1 passes to P2
step 2: P2 dribbles to P3
step 3: P2 shoots at GL
"""
    diagram = parse_dsl(dsl)
    players = [e for e in diagram["diagram"]["elements"] if e["type"] == "player"]
    roles = {p["label"]: p.get("role") for p in players}
    assert roles == {"P1": "server", "P2": "worker", "P3": "defender"}
```

- [ ] **Step 2: Run test to verify it passes (parser already handles this)**

Run: `pytest -q functions/test_dsl_parser.py::test_parse_defender_role`
Expected: PASS. (If it fails, the regex in `_ELEMENT_RE` needs widening — but inspection confirms it captures any string inside `role "..."`.)

- [ ] **Step 3: Write the failing renderer test**

Create `functions/test_render_exemplar.py`:

```python
"""Lightweight test that the renderer doesn't crash on a defender role."""
from pathlib import Path

from dsl_parser import parse_dsl
from drill_post_processor import post_process_drill
from tools.render_exemplar import _render_png


def test_renderer_handles_defender_role(tmp_path):
    dsl = """\
player P1 at (3, 7.5) role "server"
player P2 at (8, 7.5) role "worker"
player P3 at (12, 7.5) role "defender"
ball B1 at (3, 7.5)
goal GL at (18, 7.5) width 7.32

step 1: P1 passes to P2
step 2: P2 dribbles to P3
step 3: P2 shoots at GL
"""
    drill = parse_dsl(dsl)
    drill["equipment"] = ["ball", "goals", "partner"]
    drill, _ = post_process_drill(drill, player_age=14)
    out = tmp_path / "defender.png"
    _render_png(drill, out, exemplar_id="test", archetype="test")
    assert out.exists() and out.stat().st_size > 0
```

- [ ] **Step 4: Run test to verify it passes (or reveals missing badge logic)**

Run: `pytest -q functions/test_render_exemplar.py`
Expected: PASS (today the renderer falls through to no badge for defender — image still saves). We still want the badge + color.

- [ ] **Step 5: Add defender color + "D" badge to renderer**

Edit `functions/tools/render_exemplar.py`. Replace the `COLORS` dict (currently lines 32-38):

```python
COLORS = {
    "cone":     (255, 140, 0),    # orange
    "gate":     (0, 200, 180),    # teal
    "ball":     (255, 255, 255),  # white
    "goal":     (40, 120, 255),   # blue
    "player":   (220, 40, 40),    # red (worker default)
    "defender": (140, 50, 200),   # dark purple (by role)
}
```

Replace the player-block badge logic (currently around line 237-249 — the block that draws the player circle and its W/S badge). Replace that block with:

```python
        else:
            r = 12
            role = el.get("role", "") if el["type"] == "player" else ""
            fill_color = COLORS["defender"] if role == "defender" else color
            draw.ellipse([(x - r, y - r), (x + r, y + r)],
                         fill=fill_color, outline=(0, 0, 0))
            # Role badge (W/S/D) inside player circle
            if font and el["type"] == "player":
                badge = {"worker": "W", "server": "S", "defender": "D"}.get(role, "")
                if badge:
                    bbox = font.getbbox(badge)
                    bw = bbox[2] - bbox[0]
                    bh = bbox[3] - bbox[1]
                    draw.text((x - bw // 2, y - bh // 2), badge,
                              fill=(255, 255, 255), font=font)
```

- [ ] **Step 6: Re-run renderer test and manually eyeball a rendered PNG**

Run: `pytest -q functions/test_render_exemplar.py`
Expected: PASS.

Then render an exemplar with a defender to visually confirm:
```bash
cd functions && python -m tools.try_drill --skill "first touch under pressure" --level intermediate --render
```
Open `/tmp/try_drill_*.png` — check any defender players appear dark purple with a "D" badge. (If no defender is in the generated drill, skip visual check; renderer unit test is sufficient.)

- [ ] **Step 7: Commit**

```bash
git add functions/tools/render_exemplar.py functions/test_dsl_parser.py functions/test_render_exemplar.py
git commit -m "feat(drill): add defender role to DSL parser + renderer"
```

---

## Task 3: Exemplar pressure tagging + level filter + neighbor cascade

**Files:**
- Modify: `functions/exemplars.json` (add `pressure` field to every entry)
- Modify: `functions/exemplars.py` (new `get_exemplars` signature + `ARCHETYPE_NEIGHBORS` + logging)
- Modify: `functions/test_exemplars.py` (level-filter + cascade + empty-return tests; update count assertion)

**Context:** Each existing exemplar gets one of `"none"`, `"passive"`, `"active"`. Level allowlist: beginner → `{none, passive}`; intermediate → `{passive, active}`; advanced → `{active}`. Cascade: primary archetype → neighbor → empty (no silent fallback to unfiltered). Task 0 determines the baseline count (8 or 20).

### Pressure-tag rubric (apply to every existing exemplar)

Apply these rules to the DSL of each existing exemplar:

- `"none"` — no second player active in the DSL, OR the only other player is a stationary target with no step-participation as a pass target (e.g., lone worker dribbling cones).
- `"passive"` — one or more players labeled `server` appears as `from` or `to` in at least one step, but no `defender` role is present and no coaching point describes closing/pressing time pressure.
- `"active"` — a `defender` role is present, OR a coaching point explicitly describes time-pressure/closing (e.g., "attacker takes on the defender at a jog-to-sprint change of pace").

The existing 20 baseline exemplars map as:

| id | pressure |
|---|---|
| cone_weave_beginner_01 | none |
| cone_weave_intermediate_01 | none |
| wall_passing_beginner_01 | passive |
| wall_passing_intermediate_01 | passive |
| gate_dribbling_beginner_01 | none |
| gate_dribbling_intermediate_01 | none |
| dribble_and_shoot_beginner_01 | none |
| dribble_and_shoot_intermediate_01 | none |
| server_executor_beginner_01 | passive |
| server_executor_intermediate_01 | passive |
| server_executor_advanced_01 | passive |
| triangle_passing_beginner_01 | passive |
| triangle_passing_intermediate_01 | passive |
| triangle_passing_advanced_01 | passive |
| 1v1_plus_server_beginner_01 | active |
| 1v1_plus_server_intermediate_01 | active |
| 1v1_plus_server_advanced_01 | active |
| rondo_beginner_01 | passive |
| rondo_intermediate_01 | passive |
| rondo_advanced_01 | active |

(If T0 reverted to the 8-entry baseline, apply only the rows whose IDs exist.)

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_exemplars.py`:

```python
def test_every_exemplar_has_pressure_field():
    for e in EXEMPLARS:
        assert e.get("pressure") in {"none", "passive", "active"}, \
            f"{e['id']!r} has pressure={e.get('pressure')!r}"


def test_get_exemplars_filters_by_level_advanced():
    # advanced → only "active"
    hits = get_exemplars("1v1_plus_server", level="advanced")
    assert hits, "1v1_plus_server should have at least one advanced-active exemplar"
    assert all(e["pressure"] == "active" for e in hits)


def test_get_exemplars_filters_by_level_beginner():
    # beginner → "none" or "passive" OK, never "active"
    hits = get_exemplars("wall_passing", level="beginner")
    assert hits
    assert all(e["pressure"] in {"none", "passive"} for e in hits)


def test_get_exemplars_cascades_to_neighbor_when_empty():
    # cone_weave has no "active" pressure exemplars; advanced should cascade
    # to a neighbor archetype (gate_dribbling or 1v1_plus_server)
    hits = get_exemplars("cone_weave", level="advanced")
    # Cascade yields from a neighbor or returns empty — never wrong-pressure from cone_weave
    for e in hits:
        assert e["pressure"] == "active"
        assert e["archetype"] != "cone_weave"


def test_get_exemplars_returns_empty_when_all_cascade_paths_fail():
    # A fabricated archetype with no neighbors returns empty
    assert get_exemplars("fabricated_archetype_xyz", level="advanced") == []


def test_get_exemplars_no_level_is_backwards_compatible():
    # Callers that don't pass level get all archetype matches (no filter)
    all_cone = get_exemplars("cone_weave")
    assert len(all_cone) >= 1
    assert all(e["archetype"] == "cone_weave" for e in all_cone)
```

Also **replace** the existing `test_at_least_sixteen_entries` with a forward-looking count:

```python
def test_has_expected_entry_count():
    # Plan 1 will bring this to 24 after T7-T10 add 4 high-intensity exemplars.
    # During execution, count monotonically grows from 20 → 24.
    assert len(EXEMPLARS) >= 20
```

(If T0 reverted to 8, set the `>=` to 8 here and adjust again during T7-T10.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q functions/test_exemplars.py`
Expected: FAIL on `test_every_exemplar_has_pressure_field` (field missing) and on the level-filter tests (signature doesn't accept `level`).

- [ ] **Step 3: Add `pressure` field to every entry in `exemplars.json`**

Edit `functions/exemplars.json` and add `"pressure": "<value>"` to every entry per the rubric table above. Example for `cone_weave_beginner_01`:

```json
  {
    "id": "cone_weave_beginner_01",
    "archetype": "cone_weave",
    "pressure": "none",
    "dsl": "cone C1 at (6.5, 7.5)\n...",
    "notes": "Classic 4-cone weave, 3m spacing, ball mastery fundamentals"
  },
```

Place `"pressure"` between `"archetype"` and `"dsl"` for every entry. Repeat for all 20 (or 8) entries following the rubric table.

- [ ] **Step 4: Rewrite `functions/exemplars.py` with level filter + cascade**

Replace the entire file contents with:

```python
"""Exemplar loader + level/pressure filter with neighbor-archetype cascade."""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

_EXEMPLARS_PATH = Path(__file__).with_name("exemplars.json")
logger = logging.getLogger(__name__)

with _EXEMPLARS_PATH.open("r", encoding="utf-8") as _f:
    EXEMPLARS: list[dict[str, Any]] = json.load(_f)

# Pressure tiers allowed per level.
_LEVEL_PRESSURE_ALLOW: dict[str, set[str]] = {
    "beginner":     {"none", "passive"},
    "intermediate": {"passive", "active"},
    "advanced":     {"active"},
}

# Neighbor archetypes to try when primary archetype has no matching pressure.
# Order matters: first hit wins.
ARCHETYPE_NEIGHBORS: dict[str, list[str]] = {
    "cone_weave":        ["gate_dribbling", "1v1_plus_server"],
    "wall_passing":      ["triangle_passing", "rondo"],
    "gate_dribbling":    ["1v1_plus_server", "cone_weave"],
    "dribble_and_shoot": ["1v1_plus_server", "server_executor"],
    "server_executor":   ["1v1_plus_server", "rondo"],
    "triangle_passing":  ["rondo", "wall_passing"],
    "1v1_plus_server":   ["rondo", "gate_dribbling"],
    "rondo":             ["1v1_plus_server", "triangle_passing"],
}


def get_exemplars(
    archetype: str,
    level: str | None = None,
    n: int = 3,
) -> list[dict[str, Any]]:
    """Return up to n exemplars matching archetype (and level pressure, if given).

    Cascade when level-filtered primary archetype is empty:
      1. primary archetype + allowed pressures
      2. each neighbor archetype + allowed pressures (first hit wins)
      3. empty list — NO fallback to unfiltered (wrong-pressure) exemplars.
    """
    allowed = _LEVEL_PRESSURE_ALLOW.get(level) if level else None

    def _match(arch: str) -> list[dict[str, Any]]:
        hits = [e for e in EXEMPLARS if e.get("archetype") == arch]
        if allowed is None:
            return hits
        return [e for e in hits if e.get("pressure", "none") in allowed]

    primary = _match(archetype)
    if primary:
        return primary[:n]

    if allowed is None:
        return []  # no level filter and primary has nothing → nothing

    for neighbor in ARCHETYPE_NEIGHBORS.get(archetype, []):
        cascaded = _match(neighbor)
        if cascaded:
            logger.info("[exemplar-cascade] %s (level=%s) → neighbor %s (%d hits)",
                        archetype, level, neighbor, len(cascaded))
            return cascaded[:n]

    logger.info("[exemplar-cascade] %s (level=%s) → empty (no primary, no neighbor)",
                archetype, level)
    return []
```

- [ ] **Step 5: Run tests to verify all pass**

Run: `pytest -q functions/test_exemplars.py`
Expected: All tests PASS, including the new level-filter + cascade + empty-return tests, and the existing parametrized per-exemplar validator.

- [ ] **Step 6: Full test suite sanity check**

Run: `pytest -q functions/`
Expected: All tests PASS. (Callers of `get_exemplars` in `drill_generator.py` still pass only `archetype` — the `level=None` default keeps backward compatibility. T5 will start using `level`.)

- [ ] **Step 7: Commit**

```bash
git add functions/exemplars.json functions/exemplars.py functions/test_exemplars.py
git commit -m "feat(drill): add pressure tag + level filter to exemplars"
```

---

## Task 4: Coaching-quality validator (C1–C4 + generic realism floor)

**Files:**
- Create: `functions/drill_quality.py`
- Test: `functions/test_drill_quality.py`

**Context:** Four checks on a post-processed drill. C1 = primary action surfaced; C2 = compound structural realism (C2a–C2d all must pass); C3 = coaching-point thickness + on-target; C4 = rep density. Threshold: `score >= 3` AND (if `level != "beginner"`) C2 is mandatory. For `rule_pack is None` at intermediate/advanced, C1 auto-passes and C3 relaxes to "≥2 coaching points, ≥1 non-generic." Beginner + no rule pack = only C4 applies.

- [ ] **Step 1: Write the failing tests**

Create `functions/test_drill_quality.py`:

```python
"""Unit tests for score_drill_quality (C1-C4 + generic realism floor)."""
import pytest
from drill_quality import (
    score_drill_quality,
    GENERIC_COACHING_BLACKLIST,
)


SHOOTING_RULE_PACK = {
    "verb_keywords": ["shoot", "strike", "finish", "drive", "curl", "place"],
    "must_include": ["goal element", "setup touch before the strike",
                     "server feed OR defender pressure"],
    "must_avoid": ["stationary ball placed in front of empty goal"],
    "success_metric": "≥60% of shots on target within 2 seconds of the final touch",
    "perception_action_cue": "scan keeper/goal before the final touch",
    "primary_action": "strike on goal after a setup touch, with server service or a defender closing",
}


def _drill(elements, paths, points):
    return {"diagram": {"elements": elements, "paths": paths}, "coaching_points": points}


# Fixtures for testing each check in isolation

def _advanced_shooting_drill_good():
    """Passes all 4 checks."""
    return _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "server", "x": 2, "y": 7},
            {"type": "player", "label": "P2", "role": "worker", "x": 8, "y": 7},
            {"type": "player", "label": "P3", "role": "defender", "x": 13, "y": 7},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
            {"type": "ball",   "label": "B1", "x": 2, "y": 7},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "P2", "style": "dribble", "step": 2},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "P2", "style": "pass", "step": 4},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=[
            "Set up the strike with your second-to-last touch",
            "Scan the keeper before the final touch, then drive through the ball",
        ],
    )


# --- C1: forces_primary_action ---

def test_c1_passes_when_verb_keyword_in_coaching_point():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("verb" not in r.lower() and "keyword" not in r.lower() for r in reasons) or score >= 3


def test_c1_fails_when_no_verb_keyword_anywhere():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "cone",   "label": "C1", "x": 10, "y": 5},
        ],
        paths=[{"from": "P1", "to": "C1", "style": "dribble", "step": 1}],
        points=["Good effort", "Keep going"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C1" in r for r in reasons)


# --- C2: structural_realism (compound) ---

def test_c2_passes_full_structural_drill():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C2" in r for r in reasons), f"unexpected C2 failure: {reasons}"


def test_c2_fails_when_fewer_than_two_players():
    # Solo worker, no server/defender → C2a fails → C2 fails
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=["Strike through the ball", "Plant foot next to it"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C2" in r for r in reasons)


def test_c2_fails_when_no_outcome_object():
    # 2 players, no goal/gate/line-mention → C2b fails
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "player", "label": "P2", "role": "server", "x": 10, "y": 5},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "P1", "style": "pass", "step": 2},
            {"from": "P1", "to": "P2", "style": "pass", "step": 3},
        ],
        points=["Pass firmly", "Open your body"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C2" in r for r in reasons)


def test_c2_passes_with_server_participating_in_two_steps_and_outcome_object():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "server", "x": 2, "y": 5},
            {"type": "player", "label": "P2", "role": "worker", "x": 8, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "P2", "style": "pass", "step": 1},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "P2", "style": "pass", "step": 3},
            {"from": "P2", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "P2", "style": "pass", "step": 5},
        ],
        points=["Setup touch first", "Strike through the ball"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C2" in r for r in reasons)


# --- C3: coaching_points_on_target ---

def test_c3_fails_when_only_one_coaching_point():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Only one point"]
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C3" in r for r in reasons)


def test_c3_fails_when_coaching_points_are_generic():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Work hard", "Give 100%"]
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C3" in r for r in reasons)


# --- C4: rep_density ---

def test_c4_passes_with_five_steps():
    drill = _advanced_shooting_drill_good()
    # already has 5 steps
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert not any("C4" in r for r in reasons)


def test_c4_fails_with_only_two_steps_and_no_repeat_element():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
        ],
        points=["Strike firm", "Head still"],
    )
    _, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert any("C4" in r for r in reasons)


# --- Threshold + level interactions ---

def test_threshold_three_of_four_passes_for_advanced():
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    assert score >= 3
    # For a passing drill, reasons should be empty or only describe passed checks
    # (Implementation chooses: only-failures in reasons)
    assert all("C" in r for r in reasons) or reasons == []


def test_c2_mandatory_for_advanced_even_if_score_is_three():
    # Construct a drill that passes C1, C3, C4 but fails C2 (solo worker).
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "goal",   "label": "GL", "x": 18, "y": 7.5, "width": 7.32},
        ],
        paths=[
            {"from": "P1", "to": "GL", "style": "shoot", "step": 1},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 2},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 3},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 4},
            {"from": "P1", "to": "GL", "style": "shoot", "step": 5},
        ],
        points=[
            "Strike through the ball with a setup touch",
            "Finish across the keeper on the far post",
        ],
    )
    score, reasons = score_drill_quality(drill, SHOOTING_RULE_PACK, level="advanced")
    # score might be 3 (C1, C3, C4 pass) but acceptance must require C2 for advanced
    assert any("C2" in r for r in reasons), \
        f"C2 must be mandatory for advanced; got reasons={reasons}"


def test_beginner_does_not_require_c2():
    # A beginner cone_weave drill with no server and no outcome object should still pass
    drill = _drill(
        elements=[
            {"type": "cone",   "label": "C1", "x": 6, "y": 7},
            {"type": "cone",   "label": "C2", "x": 9, "y": 7},
            {"type": "cone",   "label": "C3", "x": 12, "y": 7},
            {"type": "cone",   "label": "C4", "x": 15, "y": 7},
            {"type": "player", "label": "P1", "role": "worker", "x": 3, "y": 7},
        ],
        paths=[
            {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            {"from": "P1", "to": "C2", "style": "dribble", "step": 2},
            {"from": "P1", "to": "C3", "style": "dribble", "step": 3},
            {"from": "P1", "to": "C4", "style": "dribble", "step": 4},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 5},
        ],
        points=[
            "Use inside and outside of the same foot to dribble close",
            "Keep the ball within half a step",
        ],
    )
    # Dribbling rule pack has "dribble" as a verb keyword — pretend passed in
    dribbling_pack = {
        "verb_keywords": ["dribble", "carry", "beat", "turn"],
        "must_include": ["worker with ball"],
        "must_avoid": [],
        "success_metric": "70% reps beat the defender",
        "perception_action_cue": "scan body shape",
        "primary_action": "carry past defender",
    }
    score, reasons = score_drill_quality(drill, dribbling_pack, level="beginner")
    # Beginner does not require C2 — score of 3 (C1, C3, C4) is accepted without C2
    assert score >= 3


# --- Generic realism floor (rule_pack is None) ---

def test_intermediate_with_no_rule_pack_uses_realism_floor():
    # Intermediate/advanced without rule pack: C1 auto-pass, C2 still checked,
    # C3 requires ≥1 non-generic coaching point, C4 unchanged.
    drill = _advanced_shooting_drill_good()
    score, reasons = score_drill_quality(drill, None, level="intermediate")
    assert score >= 3


def test_intermediate_with_no_rule_pack_rejects_all_generic_points():
    drill = _advanced_shooting_drill_good()
    drill["coaching_points"] = ["Work hard", "Give 100%", "Focus up"]
    _, reasons = score_drill_quality(drill, None, level="intermediate")
    assert any("C3" in r for r in reasons)


def test_beginner_with_no_rule_pack_only_requires_c4():
    drill = _drill(
        elements=[
            {"type": "player", "label": "P1", "role": "worker", "x": 5, "y": 5},
            {"type": "cone",   "label": "C1", "x": 10, "y": 5},
        ],
        paths=[
            {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 2},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 3},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 4},
            {"from": "P1", "to": "C1", "style": "dribble", "step": 5},
        ],
        points=["Work hard"],  # generic-only, no pack — OK at beginner
    )
    score, _ = score_drill_quality(drill, None, level="beginner")
    # Only C4 is enforced here; C4 passes (5 steps)
    assert score >= 1


def test_generic_coaching_blacklist_populated():
    assert "work hard" in GENERIC_COACHING_BLACKLIST
    assert "give 100%" in GENERIC_COACHING_BLACKLIST
    assert "focus" in GENERIC_COACHING_BLACKLIST
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q functions/test_drill_quality.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'drill_quality'`.

- [ ] **Step 3: Implement `functions/drill_quality.py`**

Create `functions/drill_quality.py`:

```python
"""Coaching-quality validator. Runs after DSL + structural validation."""
from __future__ import annotations

import re
from typing import Any

# Short phrases that add no coaching value on their own.
GENERIC_COACHING_BLACKLIST: frozenset[str] = frozenset({
    "work hard", "give 100%", "give 100 percent", "do your best",
    "try your best", "good effort", "focus", "focus up", "concentrate",
    "stay alert", "have fun", "keep going", "you got this",
})

# Verbs that mark a coaching point as football-specific (for generic realism floor).
_FOOTBALL_VERBS: frozenset[str] = frozenset({
    "receive", "pass", "shoot", "dribble", "defend", "turn", "close",
    "press", "scan", "switch", "cushion", "strike", "curl", "drive",
    "cut", "feint", "block", "tackle", "intercept", "recover",
    "accelerate", "sprint", "burst", "finish", "jockey", "carry",
})

# Stopwords to strip when mining keywords from success_metric for C3.
_STOPWORDS: frozenset[str] = frozenset({
    "the", "and", "for", "with", "from", "into", "onto", "within",
    "each", "all", "any", "some", "that", "this", "these", "those",
    "than", "then", "their", "they", "have", "been", "being",
})


def score_drill_quality(
    drill: dict[str, Any],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> tuple[int, list[str]]:
    """Return (checks_passed, reasons_for_failures). Max score = 4.

    Threshold: score >= 3. Additionally, for level != 'beginner', C2 is
    mandatory (caller should reject if C2 fails even when score >= 3).
    Caller enforces the mandatory-C2 rule via the reasons list.
    """
    reasons: list[str] = []

    elements: list[dict[str, Any]] = drill.get("diagram", {}).get("elements", [])
    paths:    list[dict[str, Any]] = drill.get("diagram", {}).get("paths", [])
    coaching: list[str]            = drill.get("coaching_points", [])

    c1_ok = _c1_forces_primary_action(drill, rule_pack, level)
    c2_ok = _c2_structural_realism(elements, paths, coaching, level)
    c3_ok = _c3_coaching_points_on_target(coaching, rule_pack, level)
    c4_ok = _c4_rep_density(paths)

    if not c1_ok:
        reasons.append("C1: drill does not surface the primary action (no verb_keyword in steps or coaching)")
    if not c2_ok:
        reasons.append("C2: structural realism failed (need ≥2 players, outcome object, pressure source, and repeating element)")
    if not c3_ok:
        reasons.append("C3: coaching points too thin or off-target (need ≥2, ≥1 on-skill or non-generic)")
    if not c4_ok:
        reasons.append("C4: not enough reps (need ≥5 steps OR one element repeated in ≥3 steps)")

    score = sum((c1_ok, c2_ok, c3_ok, c4_ok))
    return score, reasons


# ---- check predicates ----

def _c1_forces_primary_action(
    drill: dict[str, Any],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> bool:
    # Generic realism floor: no rule pack → auto-pass.
    if rule_pack is None:
        return True
    keywords = [k.lower() for k in rule_pack.get("verb_keywords", [])]
    if not keywords:
        return True
    haystack_parts: list[str] = []
    for p in drill.get("diagram", {}).get("paths", []):
        haystack_parts.append(str(p.get("style", "")).lower())
    for cp in drill.get("coaching_points", []):
        haystack_parts.append(str(cp).lower())
    haystack = " ".join(haystack_parts)
    return any(k in haystack for k in keywords)


def _c2_structural_realism(
    elements: list[dict[str, Any]],
    paths: list[dict[str, Any]],
    coaching: list[str],
    level: str,
) -> bool:
    # Beginner auto-pass.
    if level == "beginner":
        return True

    # C2a: ≥2 distinct player elements with role in {worker, server, defender}
    player_roles = [
        e.get("role", "") for e in elements
        if e.get("type") == "player" and e.get("role") in {"worker", "server", "defender"}
    ]
    if len(player_roles) < 2:
        return False

    # C2b: ≥1 outcome object — element of type goal or gate, OR a coaching point
    # mentions line/gate/goal/zone.
    has_outcome_element = any(e.get("type") in {"goal", "gate"} for e in elements)
    outcome_terms_in_cp = any(
        any(term in cp.lower() for term in ("line", "gate", "goal", "zone"))
        for cp in coaching
    )
    if not (has_outcome_element or outcome_terms_in_cp):
        return False

    # C2c: pressure source — defender role present, OR a server appears
    # in ≥2 distinct step numbers as from/to.
    has_defender = any(
        e.get("type") == "player" and e.get("role") == "defender" for e in elements
    )
    server_labels = {
        e.get("label") for e in elements
        if e.get("type") == "player" and e.get("role") == "server"
    }
    server_step_counts: dict[str, set[int]] = {sl: set() for sl in server_labels}
    for p in paths:
        step = p.get("step")
        if step is None:
            continue
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl in server_labels:
                server_step_counts[lbl].add(step)
    server_active = any(len(s) >= 2 for s in server_step_counts.values())
    if not (has_defender or server_active):
        return False

    # C2d: rep-loop shape — ≥1 element participates (as from or to) in ≥2 distinct steps.
    el_step_counts: dict[str, set[int]] = {}
    for p in paths:
        step = p.get("step")
        if step is None:
            continue
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl:
                el_step_counts.setdefault(lbl, set()).add(step)
    if not any(len(s) >= 2 for s in el_step_counts.values()):
        return False

    return True


def _c3_coaching_points_on_target(
    coaching: list[str],
    rule_pack: dict[str, Any] | None,
    level: str,
) -> bool:
    if len(coaching) < 2:
        return False

    # Generic realism floor: no rule pack at intermediate/advanced →
    # ≥1 coaching point must be non-generic (not in blacklist AND contains a football verb).
    if rule_pack is None:
        if level == "beginner":
            return True  # floor does not apply to beginner
        return any(_is_non_generic(cp) for cp in coaching)

    keywords = {k.lower() for k in rule_pack.get("verb_keywords", [])}
    metric_words = _significant_words(rule_pack.get("success_metric", ""))

    joined = " ".join(cp.lower() for cp in coaching)
    if any(k in joined for k in keywords):
        return True
    if any(w in joined for w in metric_words):
        return True
    return False


def _c4_rep_density(paths: list[dict[str, Any]]) -> bool:
    if len(paths) >= 5:
        return True
    el_counts: dict[str, int] = {}
    for p in paths:
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl:
                el_counts[lbl] = el_counts.get(lbl, 0) + 1
    return any(c >= 3 for c in el_counts.values())


# ---- helpers ----

def _is_non_generic(point: str) -> bool:
    lower = point.lower().strip()
    if any(phrase in lower for phrase in GENERIC_COACHING_BLACKLIST):
        return False
    words = set(re.findall(r"[a-z]+", lower))
    return bool(words & _FOOTBALL_VERBS)


def _significant_words(text: str) -> set[str]:
    words = re.findall(r"[a-z]+", (text or "").lower())
    return {w for w in words if len(w) >= 5 and w not in _STOPWORDS}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q functions/test_drill_quality.py`
Expected: All tests PASS.

- [ ] **Step 5: Full test suite sanity check**

Run: `pytest -q functions/`
Expected: All tests PASS. (Nothing imports `drill_quality` yet outside its test file.)

- [ ] **Step 6: Commit**

```bash
git add functions/drill_quality.py functions/test_drill_quality.py
git commit -m "feat(drill): add coaching-quality validator (C1-C4 + generic realism floor)"
```

---

## Task 5: Prompt rewrite (periodization + rule packs + defender grammar + empty-exemplar handling)

**Files:**
- Modify: `functions/drill_generator.py` (SYSTEM_PROMPT, _build_prompt signature + body)
- Modify: `functions/test_drill_generator.py` (new prompt-content tests)

**Context:** The prompt gains three new blocks: a periodization banner keyed by level, a category rule-pack block (when `get_rule_pack` returns non-None), and an elite-requirements block (when level is intermediate/advanced). When `get_exemplars` returns empty (cascade exhausted), the "Reference drills" section is replaced with a from-first-principles instruction. The SYSTEM_PROMPT grammar docs add `"defender"` as a valid role.

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_drill_generator.py` (same `VALID_DSL`, `make_llm`, `make_request` helpers apply):

```python
def test_prompt_injects_periodization_block():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["experience_level"] = "advanced"
    generate_drill(req, llm_call=capture)
    assert "PRACTICE TYPE BY LEVEL" in captured[0]
    assert "Global practice" in captured[0]


def test_prompt_injects_rule_pack_when_covered():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["weakness"] = "Shooting"
    req["experience_level"] = "intermediate"
    generate_drill(req, llm_call=capture)
    prompt = captured[0]
    assert "SKILL-SPECIFIC COACHING REQUIREMENTS" in prompt
    assert "Shooting" in prompt
    # A verb keyword from the Shooting pack must appear in the prompt
    assert any(v in prompt.lower() for v in ["shoot", "strike", "finish"])


def test_prompt_degrades_when_no_rule_pack():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["weakness"] = "Stamina"  # uncovered category
    req["experience_level"] = "advanced"
    generate_drill(req, llm_call=capture)
    prompt = captured[0]
    # Rule-pack block absent, but elite requirements still present for advanced
    assert "SKILL-SPECIFIC COACHING REQUIREMENTS" not in prompt
    assert "Active resistance" in prompt or "active pressure" in prompt.lower()


def test_prompt_injects_elite_requirements_for_intermediate():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["experience_level"] = "intermediate"
    generate_drill(req, llm_call=capture)
    assert "Active resistance" in captured[0] or "passive pressure" in captured[0].lower()


def test_prompt_handles_empty_exemplars(monkeypatch):
    import drill_generator

    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    # Patch the name bound inside drill_generator (imported at module load)
    monkeypatch.setattr(drill_generator, "get_exemplars", lambda *a, **k: [])

    req = make_request()
    drill_generator.generate_drill(req, llm_call=capture)
    prompt = captured[0]
    # The "Reference drills" header should not appear
    assert "Reference drills" not in prompt
    # Instead, an explicit from-first-principles instruction should
    assert "first principles" in prompt.lower() or "no matching reference" in prompt.lower()


def test_system_prompt_mentions_defender_role():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    generate_drill(make_request(), llm_call=capture)
    # The DSL grammar docstring inside SYSTEM_PROMPT must mention defender
    assert '"defender"' in captured[0]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q functions/test_drill_generator.py`
Expected: Several new tests FAIL because SYSTEM_PROMPT + `_build_prompt` haven't been updated.

- [ ] **Step 3: Update SYSTEM_PROMPT and `_build_prompt` in `drill_generator.py`**

Replace the `SYSTEM_PROMPT` string (currently lines 15–39) with:

```python
SYSTEM_PROMPT = """\
You design soccer training drills. Your #1 job: make the player REPEATEDLY PRACTICE THE REQUESTED SKILL.
The archetype/examples below are a starting shape, NOT a template. Adapt or depart from them if a different
structure gives the player more reps of the skill.

Before writing DSL, reason briefly (to yourself, not in output):
  1. What exact action trains this skill? (e.g., "first touch under pressure" -> receive a ball while a defender closes)
  2. How do I force that action many times in ~10-15 minutes?
  3. Which example comes closest, and what do I need to CHANGE to fit this skill?

Then output ONLY valid DSL - no markdown, no prose, no code fences, no reasoning.

DSL grammar:
- Elements: `cone C1 at (x, y)`, `gate G1 at (x, y) width 2`, `ball B1 at (x, y)`,
  `goal GL at (x, y) width 7.32`, `player P1 at (x, y) role "worker"` (or `"server"` or `"defender"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb in {passes to, dribbles to, runs to, shoots at, receives from}
- Coaching points: `point: <freeform text>` - these must reinforce the requested skill.

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside a 20m x 15m area.
- The drill must TRAIN THE REQUESTED SKILL, not generic ball-work.
- Prioritize game-relevant reps: every step should move the worker toward or through the requested skill.
"""
```

Add the new import near the top of `drill_generator.py` (right after the existing imports):

```python
from category_rules import get_rule_pack
```

Replace `_build_prompt` (currently lines 119–169) with:

```python
_PERIODIZATION_BY_LEVEL = {
    "beginner":     "Isolated practice: technical reps with 0 defenders OK. Focus on clean mechanics.",
    "intermediate": "Analytical practice: passive pressure — a server participates and constrains choices. Moderate decision load.",
    "advanced":     "Global practice: active pressure — a defender closes, real decisions required, game-realistic transitions.",
}

_ELITE_REQUIREMENTS = """\
For intermediate/advanced, the drill MUST include ALL of:
- Active resistance: a server who passes, a defender who closes, or a trigger that forces a decision.
- Directionality: a clear objective end (goal, gate, or line) and a reset state.
- Scanning: the worker must look away from the ball at some point (e.g., reads a visual cue from the server before the next action).
"""


def _build_prompt(
    *,
    weakness: str,
    skill_description: str,
    selected_weaknesses: list[dict[str, Any]],
    level: str,
    age: int,
    position: str,
    equipment: list[str],
    archetype: str,
    age_cap: float,
    exemplars: list[dict[str, Any]],
    rule_pack: dict[str, Any] | None,
    prior_errors: list[tuple[str, str]],
) -> str:
    focus = _format_focus(skill_description, weakness, selected_weaknesses)

    lines = [SYSTEM_PROMPT, ""]

    # Periodization banner
    peri = _PERIODIZATION_BY_LEVEL.get(level, _PERIODIZATION_BY_LEVEL["intermediate"])
    lines += ["PRACTICE TYPE BY LEVEL:", f"- {level} → {peri}", ""]

    # Elite requirements for intermediate/advanced
    if level in ("intermediate", "advanced"):
        lines += [_ELITE_REQUIREMENTS, ""]

    # Category rule pack (only when covered)
    if rule_pack is not None:
        lines += [
            f"SKILL-SPECIFIC COACHING REQUIREMENTS ({weakness}):",
            f"Primary action the drill must force: {rule_pack['primary_action']}",
            f"Must include: {', '.join(rule_pack['must_include'])}",
            f"Must avoid: {', '.join(rule_pack['must_avoid'])}",
            f"Success metric: {rule_pack['success_metric']}",
            f"Perception-action cue: {rule_pack['perception_action_cue']}",
            "",
        ]

    # Prior attempt errors (typed as syntax|quality)
    if prior_errors:
        lines.append("PRIOR ATTEMPT ERRORS:")
        for tag, msg in prior_errors:
            if tag == "quality":
                lines.append(f"- [quality] PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE: {msg}")
            else:
                lines.append(f"- [{tag}] {msg}")
        lines.append("")

    lines += [
        "=" * 60,
        f"SKILL TO TRAIN (this is what matters most): {focus}",
        "=" * 60,
        "",
        f"Player: age {age} {position}, experience {level}",
    ]
    if selected_weaknesses:
        lines.append("Specific weaknesses flagged:")
        for w in selected_weaknesses:
            cat = w.get("category", "")
            spec = w.get("specific", "")
            if cat or spec:
                lines.append(f"  - {cat}: {spec}")
    lines += [
        f"Starting archetype (a shape to adapt, not copy): {archetype}",
        f"Constraints: max area 20x15m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
    ]

    # Exemplar block — or graceful degradation
    if exemplars:
        lines.append("Reference drills (for DSL grammar and ideas - do NOT copy their layout):")
        for ex in exemplars:
            lines.append(ex["dsl"])
            lines.append("---")
    else:
        lines.append(
            "No matching reference drill for this pressure level. "
            "Design from first principles using the skill-specific requirements and elite rules above."
        )

    lines += [
        "",
        f"Design a drill that maximizes game-relevant reps of: {focus}",
        "Adapt or depart from the references as needed. The drill's purpose is the skill, not the shape.",
        "Output DSL only.",
    ]
    return "\n".join(lines)
```

- [ ] **Step 4: Update `generate_drill()` call sites to pass `rule_pack` and new `level=` arg to `get_exemplars`**

In `generate_drill()` (currently lines 48–95), replace the body between the function header and the `for _attempt` loop:

```python
    weakness = request["weakness"]
    level = request["experience_level"]
    age = int(request["player_age"])
    position = request["position"]
    equipment: list[str] = list(request["equipment"])
    skill_description = (request.get("skill_description") or "").strip()
    selected_weaknesses = request.get("selected_weaknesses") or []

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, level=level, n=3)
    rule_pack = get_rule_pack(weakness)
    age_cap = _age_cap(age)

    errors: list[tuple[str, str]] = []
```

And replace the `_build_prompt(...)` call inside the loop with:

```python
        prompt = _build_prompt(
            weakness=weakness,
            skill_description=skill_description,
            selected_weaknesses=selected_weaknesses,
            level=level,
            age=age,
            position=position,
            equipment=equipment,
            archetype=archetype,
            age_cap=age_cap,
            exemplars=exemplars,
            rule_pack=rule_pack,
            prior_errors=errors,
        )
```

And change the except block at the bottom of the loop to use the typed error tuple:

```python
        except (DSLParseError, ValidationError) as e:
            errors.append(("syntax", str(e)))
```

(The `QualityError` branch lands in T6; keep the loop syntax-only here.)

- [ ] **Step 5: Run tests to verify the new prompt-content tests pass**

Run: `pytest -q functions/test_drill_generator.py`
Expected: All tests PASS, including the 6 new prompt tests.

- [ ] **Step 6: Full test suite sanity check**

Run: `pytest -q functions/`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add functions/drill_generator.py functions/test_drill_generator.py
git commit -m "feat(drill): rewrite prompt with periodization + rule packs + empty-exemplar handling"
```

---

## Task 6: Wire quality validator into the retry loop (MAX_ATTEMPTS=4)

**Files:**
- Modify: `functions/drill_generator.py` (`MAX_ATTEMPTS`, `QualityError`, call `score_drill_quality`)
- Modify: `functions/test_drill_generator.py` (add `test_retries_on_quality_error`)

**Context:** Bump `MAX_ATTEMPTS` from 2 → 4. Add a `QualityError` exception class. After `validate_drill`, call `score_drill_quality`; reject if `score < 3` OR (level != "beginner" AND C2 failure present in reasons). On quality failure, append a `("quality", msg)` tuple to `errors` and retry. Hard-fail `DrillGenerationFailed` after 4 exhausted attempts.

- [ ] **Step 1: Write the failing test**

Append to `functions/test_drill_generator.py`:

```python
def test_retries_on_quality_error_then_succeeds():
    """First attempt: valid DSL but no server/outcome (C2 fails at advanced).
    Second attempt: valid DSL with server + goal + multiple steps (passes)."""
    LOW_QUALITY_ADVANCED = """\
player P1 at (5, 7) role "worker"
cone C1 at (10, 7)
ball B1 at (5, 7)

step 1: P1 dribbles to C1
step 2: P1 dribbles to C1

point: Work hard
point: Give 100%
"""
    HIGH_QUALITY_ADVANCED = """\
player P1 at (2, 7) role "server"
player P2 at (8, 7) role "worker"
player P3 at (13, 7) role "defender"
ball B1 at (2, 7)
goal GL at (18, 7.5) width 7.32

step 1: P1 passes to P2
step 2: P2 dribbles to P3
step 3: P2 shoots at GL
step 4: P1 passes to P2
step 5: P2 shoots at GL

point: Attack the defender's front foot to force them to turn
point: Scan the keeper before the final touch, then drive through the ball
"""
    captured_prompts = []

    def capture(prompt: str) -> str:
        captured_prompts.append(prompt)
        if len(captured_prompts) == 1:
            return LOW_QUALITY_ADVANCED
        return HIGH_QUALITY_ADVANCED

    req = make_request()
    req["weakness"] = "Shooting"
    req["experience_level"] = "advanced"
    drill = generate_drill(req, llm_call=capture)
    assert drill is not None
    assert len(captured_prompts) == 2
    # Second prompt must carry the typed quality error feedback
    second_prompt = captured_prompts[1]
    assert "PRIOR ATTEMPT WAS VALID DSL BUT NOT A USEFUL PRACTICE" in second_prompt


def test_exhausts_four_attempts_on_quality_failure():
    LOW_QUALITY = """\
player P1 at (5, 7) role "worker"
cone C1 at (10, 7)
ball B1 at (5, 7)

step 1: P1 dribbles to C1

point: Work hard
"""
    llm = make_llm([LOW_QUALITY, LOW_QUALITY, LOW_QUALITY, LOW_QUALITY])
    req = make_request()
    req["weakness"] = "Shooting"
    req["experience_level"] = "advanced"
    with pytest.raises(DrillGenerationFailed):
        generate_drill(req, llm_call=llm)
    assert llm.call_count == 4


def test_max_attempts_is_four():
    from drill_generator import MAX_ATTEMPTS
    assert MAX_ATTEMPTS == 4
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest -q functions/test_drill_generator.py`
Expected: The 3 new tests FAIL (`MAX_ATTEMPTS` is 2; no `QualityError` raised; quality feedback never reaches second prompt).

- [ ] **Step 3: Wire `QualityError` into `generate_drill()`**

Open `functions/drill_generator.py`. Bump the constant:

```python
MAX_ATTEMPTS = 4
```

Add the import near the other local imports:

```python
from drill_quality import score_drill_quality
```

Add a new exception class next to `DrillGenerationFailed`:

```python
class QualityError(RuntimeError):
    """Raised when a parsed drill fails the coaching-quality gate."""

    def __init__(self, reasons: list[str]):
        self.reasons = reasons
        super().__init__("; ".join(reasons))
```

Replace the try/except block inside the `for _attempt` loop with:

```python
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)
            drill["equipment"] = equipment
            drill, _warnings = post_process_drill(drill, player_age=age)
            validate_drill(drill)
            score, reasons = score_drill_quality(drill, rule_pack, level)
            c2_failed = any(r.startswith("C2:") for r in reasons)
            if score < 3 or (level != "beginner" and c2_failed):
                raise QualityError(reasons)
            return drill
        except (DSLParseError, ValidationError) as e:
            errors.append(("syntax", str(e)))
        except QualityError as e:
            errors.append(("quality", "; ".join(e.reasons)))
```

(`_build_prompt`'s handling of `errors: list[tuple[str, str]]` was already landed in T5.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest -q functions/test_drill_generator.py`
Expected: All tests PASS, including retry-on-quality and exhaust-after-4.

- [ ] **Step 5: Full test suite sanity check**

Run: `pytest -q functions/`
Expected: All tests PASS (100+ tests).

- [ ] **Step 6: Smoke test via the CLI harness**

Run from `functions/`:
```bash
python -m tools.try_drill --skill "first touch under pressure" --level intermediate --render
python -m tools.try_drill --weakness Shooting --level advanced --render
python -m tools.try_drill --weakness Defending --level advanced --render
```
Expected: Each completes in ≤ 15s, emits JSON + PNG to `/tmp`. Eyeball the PNGs: advanced drills should show a defender or server actively participating.

- [ ] **Step 7: Commit**

```bash
git add functions/drill_generator.py functions/test_drill_generator.py
git commit -m "feat(drill): wire quality validator into retry loop (MAX_ATTEMPTS=4)"
```

---

## Task 7: Author high-intensity exemplar `dribble_and_shoot_advanced_01`

**Files:**
- Modify: `functions/exemplars.json`

**Context:** Gap — dribble_and_shoot currently only has `passive` exemplars. For advanced (which filters to `pressure: "active"`), the cascade falls back to neighbor archetypes. Add one explicit active variant: worker beats cone, defender recovers from 5m back, shot must beat the defender's reach.

- [ ] **Step 1: Draft the DSL**

Propose this DSL (adjust coordinates as needed to stay within 20x15m):

```
player P1 at (2, 7.5) role "worker"
player P2 at (8, 10) role "defender"
cone C1 at (6, 5)
cone C2 at (11, 10)
ball B1 at (2, 7.5)
goal GL at (18, 7.5) width 7.32

step 1: P1 dribbles to C1
step 2: P1 dribbles to C2
step 3: P2 runs to P1
step 4: P1 shoots at GL

point: Beat the first cone with your strong foot, then cut inside to lose the recovering defender
point: Defender starts 5m behind the attacker's line — sprint to recover as soon as P1 clears C1
point: Strike across the keeper; the defender's reach forces the low far-post finish
```

- [ ] **Step 2: Render + eyeball**

Temporarily add this exemplar to `functions/exemplars.json` as a JSON entry:

```json
  {
    "id": "dribble_and_shoot_advanced_01",
    "archetype": "dribble_and_shoot",
    "pressure": "active",
    "dsl": "player P1 at (2, 7.5) role \"worker\"\nplayer P2 at (8, 10) role \"defender\"\ncone C1 at (6, 5)\ncone C2 at (11, 10)\nball B1 at (2, 7.5)\ngoal GL at (18, 7.5) width 7.32\n\nstep 1: P1 dribbles to C1\nstep 2: P1 dribbles to C2\nstep 3: P2 runs to P1\nstep 4: P1 shoots at GL\n\npoint: Beat the first cone with your strong foot, then cut inside to lose the recovering defender\npoint: Defender starts 5m behind the attacker's line — sprint to recover as soon as P1 clears C1\npoint: Strike across the keeper; the defender's reach forces the low far-post finish",
    "notes": "Dribble past cone, defender recovers from 5m back, worker finishes under pressure"
  }
```

Render:
```bash
cd functions && python -m tools.render_exemplar exemplars.json dribble_and_shoot_advanced_01
open /tmp/dribble_and_shoot_advanced_01.png
```

- [ ] **Step 3: User critiques the render**

Stop and wait for user feedback on the PNG. Iterate the DSL (coordinates, step order, coaching points) until user approves. If user rejects outright, revert the `exemplars.json` change and skip this task.

- [ ] **Step 4: Verify tests still pass**

Run: `pytest -q functions/test_exemplars.py`
Expected: PASS — new entry parses + validates + has `pressure: "active"`. The `test_has_expected_entry_count` assertion should now reflect 21 (or 9).

- [ ] **Step 5: Commit**

```bash
git add functions/exemplars.json
git commit -m "feat(exemplar): add dribble_and_shoot_advanced_01"
```

---

## Task 8: Author high-intensity exemplar `server_executor_advanced_02`

**Files:**
- Modify: `functions/exemplars.json`

**Context:** `server_executor_advanced_01` (authored in T9) is `passive`. Add an `active` variant: server plays ball in, immediately closes to 3m pressure; worker must first-touch away from pressure.

- [ ] **Step 1: Draft the DSL**

```
player P1 at (3, 10) role "server"
player P2 at (9, 6) role "worker"
player P3 at (6, 6) role "defender"
ball B1 at (3, 10)
goal GL at (18, 7.5) width 7.32

step 1: P1 passes to P2
step 2: P3 runs to P2
step 3: P2 dribbles to P2
step 4: P2 shoots at GL

point: Server plays a firm ball in and immediately closes to 3m — the worker reads the closing angle
point: First touch rolls across the defender's momentum, not into them
point: One touch to strike — hesitation lets the defender recover
```

- [ ] **Step 2: Render + eyeball**

Temporarily add to `exemplars.json`:

```json
  {
    "id": "server_executor_advanced_02",
    "archetype": "server_executor",
    "pressure": "active",
    "dsl": "player P1 at (3, 10) role \"server\"\nplayer P2 at (9, 6) role \"worker\"\nplayer P3 at (6, 6) role \"defender\"\nball B1 at (3, 10)\ngoal GL at (18, 7.5) width 7.32\n\nstep 1: P1 passes to P2\nstep 2: P3 runs to P2\nstep 3: P2 dribbles to P2\nstep 4: P2 shoots at GL\n\npoint: Server plays a firm ball in and immediately closes to 3m — the worker reads the closing angle\npoint: First touch rolls across the defender's momentum, not into them\npoint: One touch to strike — hesitation lets the defender recover",
    "notes": "Server feeds then closes; defender adds time pressure on the first touch; worker finishes quickly"
  }
```

Render:
```bash
cd functions && python -m tools.render_exemplar exemplars.json server_executor_advanced_02
open /tmp/server_executor_advanced_02.png
```

- [ ] **Step 3: User critiques, iterate to approval (or revert)**

- [ ] **Step 4: Verify tests pass**

Run: `pytest -q functions/test_exemplars.py`
Expected: PASS. Entry count 22 (or 10).

- [ ] **Step 5: Commit**

```bash
git add functions/exemplars.json
git commit -m "feat(exemplar): add server_executor_advanced_02"
```

---

## Task 9: Author high-intensity exemplar `1v1_plus_server_advanced_02`

**Files:**
- Modify: `functions/exemplars.json`

**Context:** Add a transition variant: 1v1 with a recovery runner joining after ~3 seconds, forcing the attacker to commit quickly.

- [ ] **Step 1: Draft the DSL**

```
player P1 at (2, 7.5) role "server"
player P2 at (5, 7.5) role "worker"
player P3 at (11, 7.5) role "defender"
player P4 at (3, 4) role "defender"
ball B1 at (2, 7.5)
goal GL at (18, 7.5) width 7.32

step 1: P1 passes to P2
step 2: P2 dribbles to P3
step 3: P4 runs to P2
step 4: P2 shoots at GL

point: Commit to beating P3 immediately — P4 joins after ~3 seconds
point: Take the first touch into space on P3's weaker side to buy the half-beat
point: If P4 closes before the shot, play a quick square pass back to the server instead of forcing it
```

- [ ] **Step 2: Render + eyeball**

Temporarily add to `exemplars.json`:

```json
  {
    "id": "1v1_plus_server_advanced_02",
    "archetype": "1v1_plus_server",
    "pressure": "active",
    "dsl": "player P1 at (2, 7.5) role \"server\"\nplayer P2 at (5, 7.5) role \"worker\"\nplayer P3 at (11, 7.5) role \"defender\"\nplayer P4 at (3, 4) role \"defender\"\nball B1 at (2, 7.5)\ngoal GL at (18, 7.5) width 7.32\n\nstep 1: P1 passes to P2\nstep 2: P2 dribbles to P3\nstep 3: P4 runs to P2\nstep 4: P2 shoots at GL\n\npoint: Commit to beating P3 immediately — P4 joins after ~3 seconds\npoint: Take the first touch into space on P3's weaker side to buy the half-beat\npoint: If P4 closes before the shot, play a quick square pass back to the server instead of forcing it",
    "notes": "1v1 to finish with a recovery runner — forces the attacker to commit quickly"
  }
```

Render:
```bash
cd functions && python -m tools.render_exemplar exemplars.json 1v1_plus_server_advanced_02
open /tmp/1v1_plus_server_advanced_02.png
```

- [ ] **Step 3: User critiques, iterate to approval (or revert)**

- [ ] **Step 4: Verify tests pass**

Run: `pytest -q functions/test_exemplars.py`
Expected: PASS. Entry count 23 (or 11).

- [ ] **Step 5: Commit**

```bash
git add functions/exemplars.json
git commit -m "feat(exemplar): add 1v1_plus_server_advanced_02"
```

---

## Task 10: Author high-intensity exemplar `rondo_advanced_02`

**Files:**
- Modify: `functions/exemplars.json`

**Context:** Add a transition rondo: 3v1+1 where the possession team, on winning the ball, must dribble through a target gate within 5 seconds.

- [ ] **Step 1: Draft the DSL**

```
player P1 at (5, 5) role "worker"
player P2 at (14, 5) role "worker"
player P3 at (10, 11) role "worker"
player P4 at (10, 8) role "defender"
gate G1 at (18, 8) width 3
ball B1 at (5, 5)

step 1: P1 passes to P2
step 2: P2 passes to P3
step 3: P3 passes to P1
step 4: P4 runs to P1
step 5: P1 dribbles to G1

point: 3v1 keep-away until the defender forces a turnover — then transition immediately
point: On regain, attack the target gate within 5 seconds — no extra passes, no hesitation
point: Support angles adjust every pass; whoever's closest to the gate becomes the target carrier
```

- [ ] **Step 2: Render + eyeball**

Temporarily add to `exemplars.json`:

```json
  {
    "id": "rondo_advanced_02",
    "archetype": "rondo",
    "pressure": "active",
    "dsl": "player P1 at (5, 5) role \"worker\"\nplayer P2 at (14, 5) role \"worker\"\nplayer P3 at (10, 11) role \"worker\"\nplayer P4 at (10, 8) role \"defender\"\ngate G1 at (18, 8) width 3\nball B1 at (5, 5)\n\nstep 1: P1 passes to P2\nstep 2: P2 passes to P3\nstep 3: P3 passes to P1\nstep 4: P4 runs to P1\nstep 5: P1 dribbles to G1\n\npoint: 3v1 keep-away until the defender forces a turnover — then transition immediately\npoint: On regain, attack the target gate within 5 seconds — no extra passes, no hesitation\npoint: Support angles adjust every pass; whoever's closest to the gate becomes the target carrier",
    "notes": "3v1 keep-away with a transition-to-gate objective; active pressure plus decision trigger"
  }
```

Render:
```bash
cd functions && python -m tools.render_exemplar exemplars.json rondo_advanced_02
open /tmp/rondo_advanced_02.png
```

- [ ] **Step 3: User critiques, iterate to approval (or revert)**

- [ ] **Step 4: Verify tests pass**

Run: `pytest -q functions/test_exemplars.py`
Expected: PASS. Entry count 24 (or 12). Update `test_has_expected_entry_count` to the final number if needed.

- [ ] **Step 5: Commit**

```bash
git add functions/exemplars.json
git commit -m "feat(exemplar): add rondo_advanced_02"
```

---

## Final verification

After T0–T10, run the full verification gauntlet:

- [ ] **A. All tests pass**

Run: `pytest -q functions/`
Expected: All tests PASS.

- [ ] **B. CLI smoke across categories × levels**

From `functions/`, for each of the 6 covered categories (Dribbling, Passing, Shooting, First Touch, Defending, Speed & Agility) × (beginner, intermediate, advanced), run one CLI generation:

```bash
for weakness in "Dribbling" "Passing" "Shooting" "First Touch" "Defending" "Speed & Agility"; do
  for level in beginner intermediate advanced; do
    python -m tools.try_drill --weakness "$weakness" --level "$level" --render
  done
done
```

Expected: Every run completes in ≤ 15s (average) / ≤ 30s (worst case). Every PNG lands in `/tmp/`.

- [ ] **C. Validator score spot-check**

For the 12 advanced runs above, programmatically load each drill JSON and compute `score_drill_quality(drill, get_rule_pack(weakness), "advanced")`. Target: ≥80% of 12 land at `score >= 3` AND C2 passes. Record the miss rate — this is the "80% of advanced drills" gate from the spec.

- [ ] **D. Blinded manual rating — THE gate**

Build a blinded 20-prompt test set: 6 covered categories × {beginner, intermediate, advanced} = 18, plus 2 uncovered edge cases (e.g., Stamina advanced, Positioning intermediate). Generate all 20 via the CLI. User rates each drill 1–5 for "game realism" without seeing the validator score. Target: **mean ≥ 3.5, no drill below 2**. This is the real Plan 1 success metric.

- [ ] **E. iOS regression sanity (local emulator)**

Run the Firebase Functions emulator:
```bash
cd functions && firebase emulators:start --only functions
```
From the iOS app pointed at the emulator, generate one drill with a Shooting + advanced request. Expected: the drill loads in `DrillDiagramView` without crash. Defender players appear (may not have a distinct color on iOS — that's fine per spec's "No iOS changes" rule).

If A–E all hold, Plan 1 is done. Deploy to Firebase and resume Task #1 (T8: Deploy + QA).

---

## Unresolved questions

- T9 status: commit the 12 drafted exemplars or revert? (T0 asks this explicitly.)
- iOS display of defender role: show purple badge on iOS or leave as default red? (Spec says no iOS work in Plan 1.)
- Latency cap: 30s worst case on 4 retries — acceptable, or add a 20s hard timeout with fast-fail?
- Pressure-rubric edge: is `server_executor_advanced_01` truly "passive" (it's a two-server combo but no defender)? (Plan treats as passive; revisit if validator-score miss-rate is high on server_executor advanced runs.)
