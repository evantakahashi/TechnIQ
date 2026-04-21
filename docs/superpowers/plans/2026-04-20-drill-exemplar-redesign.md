# Drill Exemplar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 4-phase LLM drill pipeline with deterministic scaffold + exemplar few-shot + single LLM call, cutting latency ~3x and improving diagram quality through hand-authored soccer-drill exemplars.

**Architecture:** `pick_archetype(Py) → get_exemplars(Py) → writer(LLM, 1 call) → parse_dsl(Py) → post_process(Py) → validate(Py)` with single retry on parse/validation failure. Collapses Scout+Coach+Writer+Referee into one creative call plus deterministic everything-else.

**Tech Stack:** Python 3.11 (Firebase Functions), Anthropic SDK, pytest. No new dependencies — Pillow already available for the render-preview CLI.

**Spec:** `docs/superpowers/specs/2026-04-20-drill-exemplar-redesign-design.md`

---

## File Structure

**New:**
- `functions/archetype_picker.py` — `(weakness, level) → archetype` lookup, ~40 lines
- `functions/dsl_parser.py` — DSL → `DrillDiagram` dict, ~150 lines
- `functions/drill_validator.py` — 5 structural integrity checks, ~80 lines
- `functions/exemplars.py` — loader + retrieval for `exemplars.json`, ~30 lines
- `functions/exemplars.json` — hand-authored exemplars (seed: 9, one per archetype)
- `functions/drill_generator.py` — single-LLM orchestrator with retry loop, ~120 lines
- `functions/tools/__init__.py`
- `functions/tools/render_exemplar.py` — CLI preview (PNG + JSON), ~120 lines
- `functions/test_archetype_picker.py`
- `functions/test_dsl_parser.py`
- `functions/test_drill_validator.py`
- `functions/test_exemplars.py`
- `functions/test_drill_generator.py`

**Modify:**
- `functions/main.py` — replace `generate_custom_drill` body (lines 186–395) to delegate to `drill_generator.generate()`; delete `phase_scout`, `phase_coach`, `phase_writer`, `phase_referee` (lines 397–end of those functions)

**Unchanged:**
- `functions/drill_post_processor.py` — consumed as-is
- `functions/test_drill_post_processor.py`
- iOS client — no schema changes

---

## Task 1: Archetype picker

**Files:**
- Create: `functions/archetype_picker.py`
- Test: `functions/test_archetype_picker.py`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_archetype_picker.py`:

```python
"""Tests for archetype_picker."""
import pytest
from archetype_picker import pick_archetype, ARCHETYPE_TABLE, VALID_ARCHETYPES


def test_pick_archetype_under_pressure_beginner_returns_gate_dribbling():
    assert pick_archetype("Under Pressure", "beginner") == "gate_dribbling"


def test_pick_archetype_under_pressure_advanced_returns_rondo():
    assert pick_archetype("Under Pressure", "advanced") == "rondo"


def test_pick_archetype_finishing_beginner_returns_dribble_and_shoot():
    assert pick_archetype("Finishing", "beginner") == "dribble_and_shoot"


def test_pick_archetype_unknown_weakness_falls_back_to_cone_weave():
    assert pick_archetype("Completely Made Up Weakness", "beginner") == "cone_weave"


def test_pick_archetype_unknown_level_falls_back_to_cone_weave():
    assert pick_archetype("Under Pressure", "galactic-overlord") == "cone_weave"


def test_every_table_value_is_a_valid_archetype():
    for archetype in ARCHETYPE_TABLE.values():
        assert archetype in VALID_ARCHETYPES, f"{archetype} is not a valid archetype"


def test_valid_archetypes_contains_all_nine():
    expected = {
        "cone_weave", "wall_passing", "gate_dribbling", "dribble_and_shoot",
        "relay_shuttle", "server_executor", "triangle_passing",
        "1v1_plus_server", "rondo",
    }
    assert VALID_ARCHETYPES == expected
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_archetype_picker.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'archetype_picker'`.

- [ ] **Step 3: Implement archetype_picker.py**

Create `functions/archetype_picker.py`:

```python
"""Deterministic weakness+level → archetype lookup. Replaces Scout LLM phase."""
from typing import Final

VALID_ARCHETYPES: Final[set[str]] = {
    "cone_weave",
    "wall_passing",
    "gate_dribbling",
    "dribble_and_shoot",
    "relay_shuttle",
    "server_executor",
    "triangle_passing",
    "1v1_plus_server",
    "rondo",
}

FALLBACK_ARCHETYPE: Final[str] = "cone_weave"

# (weakness_label_from_onboarding, experience_level) -> archetype
ARCHETYPE_TABLE: Final[dict[tuple[str, str], str]] = {
    ("Under Pressure", "beginner"):     "gate_dribbling",
    ("Under Pressure", "intermediate"): "rondo",
    ("Under Pressure", "advanced"):     "rondo",

    ("Finishing", "beginner"):     "dribble_and_shoot",
    ("Finishing", "intermediate"): "dribble_and_shoot",
    ("Finishing", "advanced"):     "1v1_plus_server",

    ("Ball Control", "beginner"):     "cone_weave",
    ("Ball Control", "intermediate"): "gate_dribbling",
    ("Ball Control", "advanced"):     "1v1_plus_server",

    ("Passing", "beginner"):     "wall_passing",
    ("Passing", "intermediate"): "triangle_passing",
    ("Passing", "advanced"):     "rondo",

    ("Dribbling", "beginner"):     "cone_weave",
    ("Dribbling", "intermediate"): "gate_dribbling",
    ("Dribbling", "advanced"):     "1v1_plus_server",

    ("Speed", "beginner"):     "relay_shuttle",
    ("Speed", "intermediate"): "relay_shuttle",
    ("Speed", "advanced"):     "server_executor",

    ("Crossing", "beginner"):     "server_executor",
    ("Crossing", "intermediate"): "server_executor",
    ("Crossing", "advanced"):     "server_executor",

    ("First Touch", "beginner"):     "wall_passing",
    ("First Touch", "intermediate"): "wall_passing",
    ("First Touch", "advanced"):     "rondo",

    ("Shooting", "beginner"):     "dribble_and_shoot",
    ("Shooting", "intermediate"): "dribble_and_shoot",
    ("Shooting", "advanced"):     "1v1_plus_server",
}


def pick_archetype(weakness: str, level: str) -> str:
    """Return archetype for (weakness, level) or FALLBACK_ARCHETYPE if unknown."""
    return ARCHETYPE_TABLE.get((weakness, level), FALLBACK_ARCHETYPE)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_archetype_picker.py -v`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add functions/archetype_picker.py functions/test_archetype_picker.py
git commit -m "feat(drill): deterministic archetype picker"
```

---

## Task 2: DSL parser

**Files:**
- Create: `functions/dsl_parser.py`
- Test: `functions/test_dsl_parser.py`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_dsl_parser.py`:

```python
"""Tests for dsl_parser."""
import pytest
from dsl_parser import parse_dsl, DSLParseError


SIMPLE_DRILL = """\
cone C1 at (0, 0)
cone C2 at (3, 0)
player P1 at (-2, 0) role "worker"
ball B1 at (-2, 0)

step 1: P1 dribbles to C1
step 2: P1 dribbles to C2

point: Keep the ball close
point: Use both feet
"""


def test_parse_elements_produces_correct_shape():
    diagram = parse_dsl(SIMPLE_DRILL)
    elements = diagram["diagram"]["elements"]
    assert len(elements) == 4
    assert elements[0] == {"type": "cone", "x": 0.0, "y": 0.0, "label": "C1"}
    assert elements[2]["type"] == "player"
    assert elements[2]["label"] == "P1"
    assert elements[2].get("role") == "worker"


def test_parse_paths_use_step_numbers():
    diagram = parse_dsl(SIMPLE_DRILL)
    paths = diagram["diagram"]["paths"]
    assert len(paths) == 2
    assert paths[0] == {"from": "P1", "to": "C1", "style": "dribble", "step": 1}
    assert paths[1]["step"] == 2


def test_parse_coaching_points():
    diagram = parse_dsl(SIMPLE_DRILL)
    points = diagram["coaching_points"]
    assert points == ["Keep the ball close", "Use both feet"]


def test_parse_player_with_label():
    dsl = 'player P1 at (1, 2) role "worker" label "Start here"\nstep 1: P1 runs to P1\n'
    diagram = parse_dsl(dsl)
    p1 = diagram["diagram"]["elements"][0]
    assert p1["label"] == "P1"
    assert p1.get("display_label") == "Start here"


def test_parse_gate_with_width():
    dsl = "gate G1 at (5, 0) width 2\nstep 1: G1 runs to G1\n"
    diagram = parse_dsl(dsl)
    g1 = diagram["diagram"]["elements"][0]
    assert g1["type"] == "gate"
    assert g1.get("width") == 2.0


def test_parse_goal_keyword():
    dsl = 'goal GL at (20, 0) width 7.32\nplayer P1 at (0, 0) role "worker"\nstep 1: P1 shoots at GL\n'
    diagram = parse_dsl(dsl)
    gl = diagram["diagram"]["elements"][0]
    assert gl["type"] == "goal"
    paths = diagram["diagram"]["paths"]
    assert paths[0]["style"] == "shoot"


def test_parse_all_action_verbs():
    dsl = """\
player P1 at (0, 0) role "worker"
player P2 at (5, 0) role "worker"
cone C1 at (10, 0)
goal GL at (20, 0) width 7.32

step 1: P1 passes to P2
step 2: P2 dribbles to C1
step 3: P2 runs to P1
step 4: P2 shoots at GL
step 5: P1 receives from P2
"""
    diagram = parse_dsl(dsl)
    styles = [p["style"] for p in diagram["diagram"]["paths"]]
    assert styles == ["pass", "dribble", "run", "shoot", "receive"]


def test_parse_empty_dsl_raises():
    with pytest.raises(DSLParseError):
        parse_dsl("")


def test_parse_unknown_statement_raises():
    with pytest.raises(DSLParseError) as exc:
        parse_dsl("banana B1 at (0,0)\n")
    assert "line 1" in str(exc.value).lower()


def test_parse_malformed_coord_raises():
    with pytest.raises(DSLParseError):
        parse_dsl("cone C1 at (not, a, coord)\n")


def test_parse_duplicate_id_raises():
    with pytest.raises(DSLParseError):
        parse_dsl("cone C1 at (0,0)\ncone C1 at (5,0)\n")


def test_parse_unknown_verb_raises():
    with pytest.raises(DSLParseError):
        parse_dsl("player P1 at (0,0) role \"worker\"\nstep 1: P1 teleports to P1\n")


def test_parse_non_increasing_step_raises():
    dsl = """\
player P1 at (0,0) role "worker"
cone C1 at (5,0)
cone C2 at (10,0)
step 1: P1 dribbles to C1
step 1: P1 dribbles to C2
"""
    with pytest.raises(DSLParseError):
        parse_dsl(dsl)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_dsl_parser.py -v`
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3: Implement dsl_parser.py**

Create `functions/dsl_parser.py`:

```python
"""Parser for the drill DSL. Produces dicts compatible with drill_post_processor."""
from __future__ import annotations

import re
from typing import Any

VERB_TO_STYLE = {
    "passes to": "pass",
    "dribbles to": "dribble",
    "runs to": "run",
    "shoots at": "shoot",
    "receives from": "receive",
}

ELEMENT_KEYWORDS = {"cone", "gate", "ball", "goal", "player"}


class DSLParseError(ValueError):
    """Raised when the DSL cannot be parsed."""

    def __init__(self, line_number: int, reason: str):
        self.line_number = line_number
        self.reason = reason
        super().__init__(f"line {line_number}: {reason}")


_COORD_RE = re.compile(r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)")
_ELEMENT_RE = re.compile(
    r"^(?P<kind>cone|gate|ball|goal|player)\s+(?P<id>\w+)\s+at\s+"
    r"(?P<coord>\([^)]+\))"
    r"(?:\s+width\s+(?P<width>\d+(?:\.\d+)?))?"
    r"(?:\s+role\s+\"(?P<role>[^\"]*)\")?"
    r"(?:\s+label\s+\"(?P<label>[^\"]*)\")?"
    r"\s*$"
)
_STEP_RE = re.compile(
    r"^step\s+(?P<num>\d+)\s*:\s*(?P<src>\w+)\s+(?P<verb>passes to|dribbles to|runs to|shoots at|receives from)\s+(?P<dst>\w+)\s*$"
)
_POINT_RE = re.compile(r"^point\s*:\s*(?P<text>.+?)\s*$")


def parse_dsl(dsl: str) -> dict[str, Any]:
    """Parse DSL text into a drill dict ready for drill_post_processor."""
    if not dsl.strip():
        raise DSLParseError(1, "empty DSL")

    elements: list[dict[str, Any]] = []
    paths: list[dict[str, Any]] = []
    coaching_points: list[str] = []
    seen_ids: set[str] = set()
    last_step = 0

    for idx, raw_line in enumerate(dsl.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue

        head = line.split(None, 1)[0]

        if head in ELEMENT_KEYWORDS:
            el = _parse_element(line, idx)
            if el["label"] in seen_ids:
                raise DSLParseError(idx, f"duplicate element id {el['label']}")
            seen_ids.add(el["label"])
            elements.append(el)
            continue

        if head == "step":
            path, step_num = _parse_step(line, idx)
            if step_num != last_step + 1:
                raise DSLParseError(
                    idx,
                    f"step numbers must be strictly increasing from 1; got {step_num} after {last_step}",
                )
            last_step = step_num
            paths.append(path)
            continue

        if head == "point":
            m = _POINT_RE.match(line)
            if not m:
                raise DSLParseError(idx, "malformed point")
            coaching_points.append(m.group("text"))
            continue

        raise DSLParseError(idx, f"unknown statement: {head!r}")

    return {
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": elements,
            "paths": paths,
        },
        "coaching_points": coaching_points,
    }


def _parse_element(line: str, idx: int) -> dict[str, Any]:
    m = _ELEMENT_RE.match(line)
    if not m:
        raise DSLParseError(idx, "malformed element declaration")

    coord_match = _COORD_RE.match(m.group("coord"))
    if not coord_match:
        raise DSLParseError(idx, "malformed coordinate")

    el: dict[str, Any] = {
        "type": m.group("kind"),
        "x": float(coord_match.group(1)),
        "y": float(coord_match.group(2)),
        "label": m.group("id"),
    }
    if m.group("width") is not None:
        el["width"] = float(m.group("width"))
    if m.group("role") is not None:
        el["role"] = m.group("role")
    if m.group("label") is not None:
        el["display_label"] = m.group("label")
    return el


def _parse_step(line: str, idx: int) -> tuple[dict[str, Any], int]:
    m = _STEP_RE.match(line)
    if not m:
        raise DSLParseError(idx, "malformed step")
    verb = m.group("verb")
    style = VERB_TO_STYLE.get(verb)
    if style is None:
        raise DSLParseError(idx, f"unknown verb {verb!r}")
    step_num = int(m.group("num"))
    path = {
        "from": m.group("src"),
        "to": m.group("dst"),
        "style": style,
        "step": step_num,
    }
    return path, step_num
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_dsl_parser.py -v`
Expected: PASS, 13 tests.

- [ ] **Step 5: Commit**

```bash
git add functions/dsl_parser.py functions/test_dsl_parser.py
git commit -m "feat(drill): DSL parser for drill exemplars"
```

---

## Task 3: Drill validator

**Files:**
- Create: `functions/drill_validator.py`
- Test: `functions/test_drill_validator.py`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_drill_validator.py`:

```python
"""Tests for drill_validator."""
import pytest
from drill_validator import validate_drill, ValidationError


def make_valid_drill():
    return {
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": [
                {"type": "cone", "x": 0, "y": 0, "label": "C1"},
                {"type": "player", "x": -2, "y": 0, "label": "P1", "role": "worker"},
            ],
            "paths": [
                {"from": "P1", "to": "C1", "style": "dribble", "step": 1},
            ],
        },
        "coaching_points": [],
        "equipment": ["ball", "cones"],
    }


def test_valid_drill_passes():
    validate_drill(make_valid_drill())  # no exception


def test_missing_element_target_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"][0]["to"] = "GHOST"
    with pytest.raises(ValidationError, match="references unknown element"):
        validate_drill(drill)


def test_missing_element_source_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"][0]["from"] = "GHOST"
    with pytest.raises(ValidationError, match="references unknown element"):
        validate_drill(drill)


def test_non_contiguous_step_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"].append(
        {"from": "P1", "to": "C1", "style": "dribble", "step": 3}
    )
    with pytest.raises(ValidationError, match="step numbers"):
        validate_drill(drill)


def test_equipment_mismatch_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append(
        {"type": "goal", "x": 10, "y": 0, "label": "GL"}
    )
    with pytest.raises(ValidationError, match="equipment"):
        validate_drill(drill)


def test_no_worker_raises():
    drill = make_valid_drill()
    drill["diagram"]["elements"][1]["role"] = "server"
    with pytest.raises(ValidationError, match="worker"):
        validate_drill(drill)


def test_no_steps_raises():
    drill = make_valid_drill()
    drill["diagram"]["paths"] = []
    with pytest.raises(ValidationError, match="at least one"):
        validate_drill(drill)


def test_server_plus_worker_passes():
    drill = make_valid_drill()
    drill["diagram"]["elements"].append(
        {"type": "player", "x": 5, "y": 0, "label": "P2", "role": "server"}
    )
    validate_drill(drill)  # still has P1 as worker
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_drill_validator.py -v`
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3: Implement drill_validator.py**

Create `functions/drill_validator.py`:

```python
"""Structural integrity checks for drill diagrams. Runs after post_processor."""
from __future__ import annotations

from typing import Any

# Which element types each equipment string authorizes
EQUIPMENT_TO_ELEMENT_TYPES: dict[str, set[str]] = {
    "ball":    {"ball"},
    "cones":   {"cone"},
    "goals":   {"goal"},
    "wall":    {"wall"},
    "partner": {"player"},
    "hurdles": {"cone"},
    "ladder":  {"cone"},
    "poles":   {"cone"},
}

# Element types that do not require equipment authorization
IMPLICIT_ELEMENT_TYPES: set[str] = {"player", "gate"}


class ValidationError(ValueError):
    """Raised when a drill fails a structural integrity check."""


def validate_drill(drill: dict[str, Any]) -> None:
    """Raise ValidationError if the drill fails any of the 5 checks."""
    diagram = drill.get("diagram", {})
    elements: list[dict[str, Any]] = diagram.get("elements", [])
    paths: list[dict[str, Any]] = diagram.get("paths", [])
    equipment: list[str] = drill.get("equipment", [])

    _check_at_least_one_step(paths)
    _check_step_numbers_contiguous(paths)
    _check_step_targets_exist(elements, paths)
    _check_equipment_consistency(elements, equipment)
    _check_at_least_one_worker(elements)


def _check_at_least_one_step(paths: list[dict[str, Any]]) -> None:
    if not paths:
        raise ValidationError("drill must have at least one action step")


def _check_step_numbers_contiguous(paths: list[dict[str, Any]]) -> None:
    nums = sorted(p.get("step", 0) for p in paths)
    expected = list(range(1, len(nums) + 1))
    if nums != expected:
        raise ValidationError(
            f"step numbers must be contiguous from 1; got {nums}"
        )


def _check_step_targets_exist(
    elements: list[dict[str, Any]], paths: list[dict[str, Any]]
) -> None:
    ids = {e["label"] for e in elements}
    for p in paths:
        for key in ("from", "to"):
            if p.get(key) not in ids:
                raise ValidationError(
                    f"step {p.get('step')} references unknown element {p.get(key)!r}"
                )


def _check_equipment_consistency(
    elements: list[dict[str, Any]], equipment: list[str]
) -> None:
    allowed_types: set[str] = set(IMPLICIT_ELEMENT_TYPES)
    for item in equipment:
        allowed_types.update(EQUIPMENT_TO_ELEMENT_TYPES.get(item, set()))
    for el in elements:
        t = el.get("type")
        if t not in allowed_types:
            raise ValidationError(
                f"element type {t!r} not authorized by equipment {equipment}"
            )


def _check_at_least_one_worker(elements: list[dict[str, Any]]) -> None:
    for el in elements:
        if el.get("type") == "player" and el.get("role") != "server":
            return
    raise ValidationError("drill must have at least one worker player")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_drill_validator.py -v`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add functions/drill_validator.py functions/test_drill_validator.py
git commit -m "feat(drill): structural validator for drill diagrams"
```

---

## Task 4: Exemplars loader + seed exemplars.json

**Files:**
- Create: `functions/exemplars.py`
- Create: `functions/exemplars.json`
- Test: `functions/test_exemplars.py`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_exemplars.py`:

```python
"""Tests for exemplars loader + every exemplar parses+validates."""
import pytest
from archetype_picker import VALID_ARCHETYPES
from dsl_parser import parse_dsl
from drill_post_processor import post_process_drill
from drill_validator import validate_drill
from exemplars import EXEMPLARS, get_exemplars


def test_exemplars_list_non_empty():
    assert len(EXEMPLARS) >= 9


def test_each_archetype_has_at_least_one_exemplar():
    archetypes_with_exemplars = {e["archetype"] for e in EXEMPLARS}
    assert VALID_ARCHETYPES.issubset(archetypes_with_exemplars)


def test_every_exemplar_has_required_fields():
    for e in EXEMPLARS:
        assert set(e.keys()) >= {"id", "archetype", "dsl", "notes"}
        assert e["archetype"] in VALID_ARCHETYPES


def test_every_exemplar_id_is_unique():
    ids = [e["id"] for e in EXEMPLARS]
    assert len(ids) == len(set(ids))


@pytest.mark.parametrize("exemplar", [e for e in __import__("exemplars").EXEMPLARS], ids=lambda e: e["id"])
def test_exemplar_parses_post_processes_and_validates(exemplar):
    drill = parse_dsl(exemplar["dsl"])
    drill.setdefault("equipment", ["ball", "cones", "goals", "partner"])
    drill, _warnings = post_process_drill(drill, player_age=14)
    validate_drill(drill)


def test_get_exemplars_returns_matching_archetype():
    result = get_exemplars("cone_weave")
    assert len(result) >= 1
    assert all(e["archetype"] == "cone_weave" for e in result)


def test_get_exemplars_respects_limit():
    result = get_exemplars("cone_weave", n=1)
    assert len(result) == 1


def test_get_exemplars_unknown_archetype_returns_empty():
    assert get_exemplars("nonexistent_archetype") == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_exemplars.py -v`
Expected: FAIL with `ModuleNotFoundError` for `exemplars`.

- [ ] **Step 3: Implement exemplars.py**

Create `functions/exemplars.py`:

```python
"""Exemplar loader. exemplars.json is read once at import time."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

_EXEMPLARS_PATH = Path(__file__).with_name("exemplars.json")

with _EXEMPLARS_PATH.open("r", encoding="utf-8") as _f:
    EXEMPLARS: list[dict[str, Any]] = json.load(_f)


def get_exemplars(archetype: str, n: int = 3) -> list[dict[str, Any]]:
    """Return up to n exemplars matching archetype."""
    return [e for e in EXEMPLARS if e["archetype"] == archetype][:n]
```

- [ ] **Step 4: Create seed exemplars.json with 9 hand-authored entries (one per archetype)**

Create `functions/exemplars.json`:

```json
[
  {
    "id": "cone_weave_beginner_01",
    "archetype": "cone_weave",
    "dsl": "cone C1 at (0, 0)\ncone C2 at (3, 0)\ncone C3 at (6, 0)\ncone C4 at (9, 0)\nplayer P1 at (-2, 0) role \"worker\"\nball B1 at (-2, 0)\n\nstep 1: P1 dribbles to C1\nstep 2: P1 dribbles to C2\nstep 3: P1 dribbles to C3\nstep 4: P1 dribbles to C4\n\npoint: Use inside and outside of the same foot\npoint: Keep the ball within half a step",
    "notes": "Classic 4-cone weave, 3m spacing, ball mastery fundamentals"
  },
  {
    "id": "wall_passing_beginner_01",
    "archetype": "wall_passing",
    "dsl": "cone C1 at (0, 0)\ncone C2 at (6, 0)\nplayer P1 at (0, 0) role \"worker\"\nplayer P2 at (6, 0) role \"server\"\nball B1 at (0, 0)\n\nstep 1: P1 passes to P2\nstep 2: P2 passes to P1\nstep 3: P1 passes to P2\n\npoint: Inside of the foot, plant foot pointing at target\npoint: Receive across the body with your back foot",
    "notes": "Stationary wall-pass rhythm; 6m distance suits beginner weight of pass"
  },
  {
    "id": "gate_dribbling_intermediate_01",
    "archetype": "gate_dribbling",
    "dsl": "gate G1 at (3, 2) width 2\ngate G2 at (7, -2) width 2\ngate G3 at (11, 3) width 2\nplayer P1 at (0, 0) role \"worker\"\nball B1 at (0, 0)\n\nstep 1: P1 dribbles to G1\nstep 2: P1 dribbles to G2\nstep 3: P1 dribbles to G3\n\npoint: Scan before each gate; pick your line early\npoint: Change pace after you exit each gate",
    "notes": "3 gates offset to force direction changes; intermediate U12+"
  },
  {
    "id": "dribble_and_shoot_beginner_01",
    "archetype": "dribble_and_shoot",
    "dsl": "cone C1 at (5, 0)\ncone C2 at (9, 0)\nplayer P1 at (0, 0) role \"worker\"\nball B1 at (0, 0)\ngoal GL at (18, 0) width 7.32\n\nstep 1: P1 dribbles to C1\nstep 2: P1 dribbles to C2\nstep 3: P1 shoots at GL\n\npoint: Set up with your second-to-last touch\npoint: Head still, eyes on the ball at contact",
    "notes": "2 cones → shot; introduces the finishing setup touch"
  },
  {
    "id": "relay_shuttle_beginner_01",
    "archetype": "relay_shuttle",
    "dsl": "cone C1 at (0, 0)\ncone C2 at (10, 0)\nplayer P1 at (0, -1) role \"worker\"\nplayer P2 at (0, 1) role \"worker\"\nball B1 at (0, -1)\n\nstep 1: P1 dribbles to C2\nstep 2: P1 passes to P2\nstep 3: P2 dribbles to C1\n\npoint: Full speed to the turn, slow to strike the pass\npoint: Receiver calls their name to start the rep",
    "notes": "2-player shuttle with handoff via pass; conditioning + technical"
  },
  {
    "id": "server_executor_intermediate_01",
    "archetype": "server_executor",
    "dsl": "player P1 at (0, 0) role \"server\"\nplayer P2 at (8, -3) role \"worker\"\ncone C1 at (12, 0)\ngoal GL at (18, 0) width 7.32\n\nstep 1: P1 passes to P2\nstep 2: P2 dribbles to C1\nstep 3: P2 shoots at GL\n\npoint: Open hips before the ball arrives\npoint: First touch forward into the run, not into your feet",
    "notes": "Server feeds channel runner; attacking midfielder finishing pattern"
  },
  {
    "id": "triangle_passing_intermediate_01",
    "archetype": "triangle_passing",
    "dsl": "player P1 at (0, 0) role \"worker\"\nplayer P2 at (6, 0) role \"worker\"\nplayer P3 at (3, 5) role \"worker\"\nball B1 at (0, 0)\n\nstep 1: P1 passes to P3\nstep 2: P3 passes to P2\nstep 3: P2 passes to P1\n\npoint: Receive on the back foot, open to the next pass\npoint: Follow your pass two steps to keep the triangle alive",
    "notes": "3-player triangle, 6m base; positional passing fundamentals"
  },
  {
    "id": "1v1_plus_server_advanced_01",
    "archetype": "1v1_plus_server",
    "dsl": "player P1 at (0, 0) role \"server\"\nplayer P2 at (8, -2) role \"worker\"\nplayer P3 at (8, 2) role \"worker\"\ngoal GL at (18, 0) width 7.32\n\nstep 1: P1 passes to P2\nstep 2: P2 dribbles to P3\nstep 3: P2 shoots at GL\n\npoint: Attacker takes on the defender at a jog-to-sprint change of pace\npoint: Defender pressures from the attacker's strong side to force weak-foot decisions",
    "notes": "Server feeds attacker; attacker beats defender and finishes; 8m attacking channel"
  },
  {
    "id": "rondo_intermediate_01",
    "archetype": "rondo",
    "dsl": "player P1 at (0, 0) role \"worker\"\nplayer P2 at (6, 0) role \"worker\"\nplayer P3 at (6, 6) role \"worker\"\nplayer P4 at (0, 6) role \"worker\"\nplayer P5 at (3, 3) role \"server\"\nball B1 at (0, 0)\n\nstep 1: P1 passes to P2\nstep 2: P2 passes to P3\nstep 3: P3 passes to P4\n\npoint: Body shape open before the ball arrives\npoint: One-touch only if your next option is already set up",
    "notes": "4v1 rondo on a 6x6 grid; P5 is the defender (server role)"
  }
]
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_exemplars.py -v`
Expected: PASS, including 9 parametrized exemplar tests.

- [ ] **Step 6: Commit**

```bash
git add functions/exemplars.py functions/exemplars.json functions/test_exemplars.py
git commit -m "feat(drill): seed exemplars + loader, one per archetype"
```

---

## Task 5: Drill generator orchestrator

**Files:**
- Create: `functions/drill_generator.py`
- Test: `functions/test_drill_generator.py`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_drill_generator.py`:

```python
"""Integration tests for drill_generator with a mocked LLM."""
import pytest
from unittest.mock import MagicMock
from drill_generator import generate_drill, DrillGenerationFailed


VALID_DSL = """\
cone C1 at (0, 0)
cone C2 at (3, 0)
player P1 at (-2, 0) role "worker"
ball B1 at (-2, 0)

step 1: P1 dribbles to C1
step 2: P1 dribbles to C2

point: Keep the ball close
"""


def make_llm(responses):
    """Return a callable that yields each response in turn."""
    it = iter(responses)

    def call(prompt: str) -> str:
        return next(it)

    return MagicMock(side_effect=call)


def make_request():
    return {
        "weakness": "Ball Control",
        "experience_level": "beginner",
        "player_age": 12,
        "position": "midfielder",
        "equipment": ["ball", "cones"],
    }


def test_happy_path_returns_valid_drill():
    llm = make_llm([VALID_DSL])
    drill = generate_drill(make_request(), llm_call=llm)
    assert drill["diagram"]["elements"][0]["type"] == "cone"
    assert llm.call_count == 1


def test_retries_once_on_parse_error_and_succeeds():
    llm = make_llm(["banana B1 at (0,0)", VALID_DSL])
    drill = generate_drill(make_request(), llm_call=llm)
    assert drill is not None
    assert llm.call_count == 2


def test_retries_include_prior_error_in_prompt():
    captured_prompts = []

    def capture(prompt: str) -> str:
        captured_prompts.append(prompt)
        if len(captured_prompts) == 1:
            return "banana B1 at (0,0)"
        return VALID_DSL

    generate_drill(make_request(), llm_call=capture)
    assert "PRIOR ATTEMPT ERRORS" in captured_prompts[1]
    assert "banana" in captured_prompts[1] or "unknown statement" in captured_prompts[1]


def test_fails_after_second_parse_error():
    llm = make_llm(["broken1", "broken2"])
    with pytest.raises(DrillGenerationFailed):
        generate_drill(make_request(), llm_call=llm)
    assert llm.call_count == 2


def test_fails_after_second_validation_error():
    invalid_dsl = "cone C1 at (0,0)\nplayer P1 at (5,0) role \"worker\"\nstep 1: P1 dribbles to GHOST\n"
    llm = make_llm([invalid_dsl, invalid_dsl])
    with pytest.raises(DrillGenerationFailed):
        generate_drill(make_request(), llm_call=llm)


def test_prompt_contains_archetype_exemplars():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    generate_drill(make_request(), llm_call=capture)
    # Ball Control + beginner → cone_weave per ARCHETYPE_TABLE
    assert "cone_weave" in captured[0]
    # Seed exemplar content should be embedded
    assert "dribbles to" in captured[0]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_drill_generator.py -v`
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3: Implement drill_generator.py**

Create `functions/drill_generator.py`:

```python
"""Single-LLM-call orchestrator. Collapses Scout+Coach+Writer+Referee."""
from __future__ import annotations

from typing import Any, Callable

from archetype_picker import pick_archetype
from dsl_parser import DSLParseError, parse_dsl
from drill_post_processor import post_process_drill
from drill_validator import ValidationError, validate_drill
from exemplars import get_exemplars


MAX_ATTEMPTS = 2

SYSTEM_PROMPT = """\
You design soccer training drills. Output ONLY valid DSL — no markdown, no prose, no code fences.

DSL grammar:
- Elements: `cone C1 at (x, y)`, `gate G1 at (x, y) width 2`, `ball B1 at (x, y)`,
  `goal GL at (x, y) width 7.32`, `player P1 at (x, y) role "worker"` (or `"server"`),
  optional `label "..."` on players.
- Actions: `step N: ID verb ID` where verb ∈ {passes to, dribbles to, runs to, shoots at, receives from}
- Coaching points: `point: <freeform text>`

Rules:
- Every step ID must refer to a declared element.
- Step numbers start at 1 and increase by 1.
- Use coordinates in meters. Keep the drill inside a 20m × 15m area.
"""

AGE_MAX_SPACING = {8: 7.0, 12: 10.0, 99: 15.0}


class DrillGenerationFailed(RuntimeError):
    """Raised when the LLM cannot produce a valid drill within MAX_ATTEMPTS."""


def generate_drill(
    request: dict[str, Any],
    llm_call: Callable[[str], str],
) -> dict[str, Any]:
    """Run the full pipeline. request keys:
        weakness, experience_level, player_age, position, equipment.
    llm_call is a function that takes a prompt and returns the raw LLM output.
    """
    weakness = request["weakness"]
    level = request["experience_level"]
    age = int(request["player_age"])
    position = request["position"]
    equipment: list[str] = list(request["equipment"])

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, n=3)
    age_cap = _age_cap(age)

    errors: list[str] = []

    for _attempt in range(MAX_ATTEMPTS):
        prompt = _build_prompt(
            weakness=weakness,
            level=level,
            age=age,
            position=position,
            equipment=equipment,
            archetype=archetype,
            age_cap=age_cap,
            exemplars=exemplars,
            prior_errors=errors,
        )
        raw = llm_call(prompt)
        try:
            drill = parse_dsl(raw)
            drill["equipment"] = equipment
            drill, _warnings = post_process_drill(drill, player_age=age)
            validate_drill(drill)
            return drill
        except (DSLParseError, ValidationError) as e:
            errors.append(str(e))

    raise DrillGenerationFailed(f"Exhausted {MAX_ATTEMPTS} attempts: {errors}")


def _age_cap(age: int) -> float:
    for max_age, cap in sorted(AGE_MAX_SPACING.items()):
        if age <= max_age:
            return cap
    return AGE_MAX_SPACING[99]


def _build_prompt(
    *,
    weakness: str,
    level: str,
    age: int,
    position: str,
    equipment: list[str],
    archetype: str,
    age_cap: float,
    exemplars: list[dict[str, Any]],
    prior_errors: list[str],
) -> str:
    lines = [SYSTEM_PROMPT, ""]
    if prior_errors:
        lines.append("PRIOR ATTEMPT ERRORS:")
        for err in prior_errors:
            lines.append(f"- {err}")
        lines.append("")
    lines += [
        f"Player: age {age} {position}, experience {level}",
        f"Weakness to train: {weakness}",
        f"Archetype: {archetype}",
        f"Constraints: max area 20x15m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
        f"Examples of good {archetype} drills:",
    ]
    for ex in exemplars:
        lines.append(ex["dsl"])
        lines.append("---")
    lines += [
        "",
        "Now design a drill in the same style for the player above.",
        "Output DSL only.",
    ]
    return "\n".join(lines)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_drill_generator.py -v`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add functions/drill_generator.py functions/test_drill_generator.py
git commit -m "feat(drill): single-LLM orchestrator with retry"
```

---

## Task 6: Render-preview CLI

**Files:**
- Create: `functions/tools/__init__.py`
- Create: `functions/tools/render_exemplar.py`

- [ ] **Step 1: Confirm Pillow is available**

Run: `cd functions && python -c "from PIL import Image, ImageDraw; print('ok')"`
Expected: `ok`.

If not, add `Pillow>=10.0` to `functions/requirements.txt` and re-run.

- [ ] **Step 2: Create tools package init**

Create `functions/tools/__init__.py`:

```python
```

(Empty file — makes `tools` a package.)

- [ ] **Step 3: Implement render_exemplar.py**

Create `functions/tools/render_exemplar.py`:

```python
"""CLI: render an exemplar from exemplars.json to a PNG + resolved JSON.

Usage:
    python -m tools.render_exemplar exemplars.json cone_weave_beginner_01
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as `python -m tools.render_exemplar` from functions/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dsl_parser import parse_dsl  # noqa: E402
from drill_post_processor import post_process_drill  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow is required: pip install Pillow", file=sys.stderr)
    raise

FIELD_W = 20.0
FIELD_L = 15.0
PX_PER_M = 40
PADDING = 40
COLORS = {
    "cone":   (255, 140, 0),   # orange
    "gate":   (0, 200, 180),   # teal
    "ball":   (220, 220, 220), # grey
    "goal":   (40, 120, 255),  # blue
    "player": (220, 40, 40),   # red
}
STEP_COLORS = [
    (30, 30, 200), (30, 150, 30), (200, 120, 30), (150, 30, 150),
    (30, 150, 200), (200, 30, 30), (60, 60, 60), (150, 80, 30),
]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("exemplars_file", type=Path)
    p.add_argument("exemplar_id")
    p.add_argument("--out-dir", type=Path, default=Path("/tmp"))
    args = p.parse_args()

    exemplars = json.loads(args.exemplars_file.read_text(encoding="utf-8"))
    match = next((e for e in exemplars if e["id"] == args.exemplar_id), None)
    if match is None:
        print(f"No exemplar with id {args.exemplar_id!r}", file=sys.stderr)
        return 1

    drill = parse_dsl(match["dsl"])
    drill["equipment"] = ["ball", "cones", "goals", "partner"]
    drill, warnings = post_process_drill(drill, player_age=14)
    for w in warnings:
        print(f"WARN: {w}", file=sys.stderr)

    png_path = args.out_dir / f"{args.exemplar_id}.png"
    json_path = args.out_dir / f"{args.exemplar_id}.json"

    _render_png(drill, png_path)
    json_path.write_text(json.dumps(drill, indent=2), encoding="utf-8")

    print(f"Wrote {png_path}")
    print(f"Wrote {json_path}")
    return 0


def _render_png(drill: dict, path: Path) -> None:
    elements = drill["diagram"]["elements"]
    paths = drill["diagram"]["paths"]

    width_px = int(FIELD_W * PX_PER_M + 2 * PADDING)
    height_px = int(FIELD_L * PX_PER_M + 2 * PADDING)
    img = Image.new("RGB", (width_px, height_px), (40, 90, 40))  # turf green
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    # Draw field box
    draw.rectangle(
        [(PADDING, PADDING), (width_px - PADDING, height_px - PADDING)],
        outline=(230, 230, 230), width=2,
    )

    el_by_id = {e["label"]: e for e in elements}

    # Draw paths (before elements so they sit below markers)
    for idx, p in enumerate(sorted(paths, key=lambda p: p["step"])):
        src = el_by_id.get(p["from"])
        dst = el_by_id.get(p["to"])
        if src is None or dst is None:
            continue
        sx, sy = _to_px(src["x"], src["y"])
        dx, dy = _to_px(dst["x"], dst["y"])
        color = STEP_COLORS[idx % len(STEP_COLORS)]
        width = 3 if p["style"] == "pass" else 2
        draw.line([(sx, sy), (dx, dy)], fill=color, width=width)
        if font:
            mid = ((sx + dx) // 2, (sy + dy) // 2)
            draw.text(mid, f"{p['step']}.{p['style']}", fill=(255, 255, 255), font=font)

    # Draw elements
    for el in elements:
        x, y = _to_px(el["x"], el["y"])
        color = COLORS.get(el["type"], (200, 200, 200))
        r = 12 if el["type"] == "player" else 8
        draw.ellipse([(x - r, y - r), (x + r, y + r)], fill=color, outline=(0, 0, 0))
        if font:
            draw.text((x + r + 2, y - r), el["label"], fill=(255, 255, 255), font=font)

    img.save(path, "PNG")


def _to_px(x_m: float, y_m: float) -> tuple[int, int]:
    # DSL origin (0,0) at bottom-left; PNG origin top-left
    x_px = int(x_m * PX_PER_M + PADDING)
    y_px = int((FIELD_L - y_m) * PX_PER_M + PADDING)
    return x_px, y_px


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Manually verify CLI works end-to-end**

Run: `cd functions && python -m tools.render_exemplar exemplars.json cone_weave_beginner_01`

Expected output:
```
Wrote /tmp/cone_weave_beginner_01.png
Wrote /tmp/cone_weave_beginner_01.json
```

Open the PNG and confirm 4 cones in a row + a player marker to the left + numbered arrows between them.

- [ ] **Step 5: Commit**

```bash
git add functions/tools/__init__.py functions/tools/render_exemplar.py
git commit -m "feat(drill): render-preview CLI for exemplar authoring"
```

---

## Task 6.5: Seed exemplar review gate (HARD STOP)

**Files:** none modified — review-only gate.

This task is a blocking checkpoint. Do NOT proceed to Task 7 until every seed exemplar PNG is approved. Bad exemplars poison every drill of their archetype, so the catch point is here.

- [ ] **Step 1: Render every seed exemplar to PNG**

Run:
```bash
cd functions && for id in \
  cone_weave_beginner_01 \
  wall_passing_beginner_01 \
  gate_dribbling_intermediate_01 \
  dribble_and_shoot_beginner_01 \
  relay_shuttle_beginner_01 \
  server_executor_intermediate_01 \
  triangle_passing_intermediate_01 \
  1v1_plus_server_advanced_01 \
  rondo_intermediate_01; do \
    python -m tools.render_exemplar exemplars.json "$id"; \
  done
```
Expected: 9 PNGs written to `/tmp/`.

- [ ] **Step 2: User reviews all 9 PNGs**

Open each PNG (`open /tmp/*.png` on macOS). For each:
- Would a good coach actually run this drill as drawn?
- Are cones/players positioned where they'd be in real training?
- Do the step arrows match how the ball would actually move?
- Is the spacing realistic for the target age/level?

Mark each **APPROVED** or **REVISE** with specific feedback (what's wrong, what to change).

- [ ] **Step 3: Revise any REVISE exemplars**

For each flagged exemplar, edit its `dsl` field in `functions/exemplars.json`. Re-run `test_exemplars.py` after any edit to confirm it still parses and validates. Re-render and re-review.

Run: `cd functions && python -m pytest test_exemplars.py -v`
Expected: all exemplar round-trip tests pass.

- [ ] **Step 4: Commit revised exemplars (only if changes made)**

```bash
git add functions/exemplars.json
git commit -m "feat(drill): revise seed exemplars after visual review"
```

If no revisions: no commit.

- [ ] **Step 5: User confirms all 9 are approved**

Do not proceed to Task 7 until every seed exemplar is marked APPROVED. The production pipeline inherits its taste from these 9 drills.

---

## Task 7: Wire drill_generator into main.py and delete old phases

**Files:**
- Modify: `functions/main.py`

- [ ] **Step 1: Inspect current `generate_custom_drill` entry and old phase functions**

Run: `cd functions && grep -n "^def generate_custom_drill\|^def phase_" main.py`

Expected: lines 186, 397, 551, 615, 729 (approximately). Confirm the 4 `phase_*` functions exist.

- [ ] **Step 2: Replace the body of `generate_custom_drill`**

In `functions/main.py`, find the block that currently starts at line 186 with `def generate_custom_drill(...):` and ends where the function returns. Replace the body of the function (everything after the docstring) with a call through the new orchestrator. Keep the `@https_fn.on_request` decorator, the auth check, and CORS handling — only the drill-producing body changes.

Replace the section from `request_data = req.get_json()` to the function's final `return` with:

```python
        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        player_profile = request_data.get("player_profile", {})
        requirements = request_data.get("requirements", {})

        weakness = (player_profile.get("weaknesses") or ["Ball Control"])[0]
        level = player_profile.get("experienceLevel", "beginner")
        age = int(player_profile.get("age") or 14)
        position = player_profile.get("position", "midfielder")
        equipment = requirements.get("equipment", ["ball", "cones"])

        from drill_generator import generate_drill, DrillGenerationFailed

        def _llm_call(prompt: str) -> str:
            msg = client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=1500,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text

        try:
            drill = generate_drill(
                {
                    "weakness": weakness,
                    "experience_level": level,
                    "player_age": age,
                    "position": position,
                    "equipment": equipment,
                },
                llm_call=_llm_call,
            )
        except DrillGenerationFailed as e:
            logger.error(f"Drill generation failed: {e}")
            return https_fn.Response(
                json.dumps({"error": "Drill generation failed", "details": str(e)}),
                status=500,
                headers={"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            )

        drill.setdefault("name", f"{weakness} Drill")
        drill.setdefault("description", f"Custom drill for {weakness}")
        drill.setdefault("setup", "See diagram.")
        drill.setdefault("instructions", [])
        drill.setdefault("difficulty", level)
        drill.setdefault("category", "technical")
        drill.setdefault("targetSkills", [weakness])

        return https_fn.Response(
            json.dumps(drill),
            status=200,
            headers={"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        )
    except Exception as e:
        logger.exception(f"generate_custom_drill failed: {e}")
        return https_fn.Response(
            json.dumps({"error": "Internal error", "details": str(e)}),
            status=500,
            headers={"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        )
```

Do **not** delete the `@https_fn.on_request`, `def generate_custom_drill(req):`, docstring, auth check, or the CORS `OPTIONS` branch above the request parse.

- [ ] **Step 3: Delete the old phase_* functions**

Delete these four function definitions entirely from `functions/main.py`:
- `phase_scout(...)`
- `phase_coach(...)`
- `phase_writer(...)`
- `phase_referee(...)`

Also delete any helpers used only by them (look for functions called only inside those four — typically `_build_scout_prompt`, `_build_coach_prompt`, etc., if present; verify with `grep` before deleting each).

Run: `cd functions && grep -n "phase_scout\|phase_coach\|phase_writer\|phase_referee" main.py`
Expected: no matches.

- [ ] **Step 4: Run every Python test to confirm nothing regressed**

Run: `cd functions && python -m pytest -v`
Expected: all tests pass (including `test_drill_post_processor.py`, `test_archetype_picker.py`, `test_dsl_parser.py`, `test_drill_validator.py`, `test_exemplars.py`, `test_drill_generator.py`).

- [ ] **Step 5: Syntax check main.py**

Run: `cd functions && python -c "import ast; ast.parse(open('main.py').read()); print('ok')"`
Expected: `ok`.

- [ ] **Step 6: Commit**

```bash
git add functions/main.py
git commit -m "refactor(drill): route generate_custom_drill through single-LLM pipeline"
```

---

## Task 8: Manual QA and deploy staging

**Files:** none modified

- [ ] **Step 1: Deploy to Firebase Functions staging**

Run: `cd functions && firebase deploy --only functions:generate_custom_drill`
Expected: deploy succeeds. Note the function URL.

- [ ] **Step 2: Exercise 9 archetype × 3 level combinations**

For each of the 9 archetypes, call the endpoint with a player profile that maps to it via `ARCHETYPE_TABLE` (see Task 1 for the mapping). Use a shell script or curl manually. For each response:

- Inspect `diagram.elements` for sane coordinates (within 20×15m, no overlaps)
- Inspect `diagram.paths` for contiguous `step` numbers starting at 1
- Open the iOS client, trigger a Custom Drill generation with the corresponding weakness+level, confirm the diagram renders and makes soccer sense

Keep notes in a scratch markdown file. If any combo fails, capture the DSL the LLM returned (add a temporary log line in `drill_generator.py` or inspect Firebase logs) and add a new exemplar that corrects the failure mode, then redeploy.

- [ ] **Step 3: No-regression check: existing drill endpoints**

Run one drill generation end-to-end via the iOS client. Confirm:
- Drill renders in `DrillDiagramView` without crashes
- Coaching points appear
- Saving the drill to Core Data works (existing flow, unchanged)

- [ ] **Step 4: Commit any new exemplars added during QA**

If QA surfaced weaknesses that needed new exemplars:

```bash
git add functions/exemplars.json
git commit -m "feat(drill): add exemplars surfaced during QA"
```

Otherwise no commit for this step.

---

## Task 9: Hybrid exemplar authoring (expand to ~20)

**Files:**
- Modify: `functions/exemplars.json`

Per Q11: the seed set is 9 (one per archetype, drafted by Claude). This task expands to ~20 with user-authored judgment-heavy drills. Target: ≥2 exemplars per archetype, with the judgment-heavy archetypes (`rondo`, `triangle_passing`, `server_executor`, `1v1_plus_server`) getting the user's taste directly.

- [ ] **Step 1: User dictates each new drill**

For each of the ~11 new exemplars, user describes in plain English:
- Archetype
- Player/cone layout (counts, rough spacing, shape)
- Step-by-step action sequence
- 2-3 coaching points
- Target experience level (beginner / intermediate / advanced)

Priorities, in order:
1. `rondo_advanced_01`, `rondo_beginner_01`
2. `triangle_passing_beginner_01`, `triangle_passing_advanced_01`
3. `server_executor_beginner_01`, `server_executor_advanced_01`
4. `1v1_plus_server_intermediate_01`
5. Additional variants of mechanical archetypes where current seed feels thin

- [ ] **Step 2: Claude transcribes each to DSL**

For each dictated drill, write a new entry in `functions/exemplars.json` with the conventions:
- `id`: `<archetype>_<level>_<NN>` (NN is a 2-digit counter starting at 01 per archetype+level)
- `archetype`: one of the 9 valid archetypes
- `dsl`: valid DSL per the grammar in Task 2
- `notes`: one-line description of what the drill trains

- [ ] **Step 3: Run exemplar tests after each addition**

Run: `cd functions && python -m pytest test_exemplars.py -v`
Expected: all parametrized round-trip tests pass, including the new exemplar.

If the test fails, fix the DSL in the JSON file until it passes. Do not skip the test.

- [ ] **Step 4: Render the new PNG for user review**

Run: `cd functions && python -m tools.render_exemplar exemplars.json <new_id>`
Open the PNG. User approves or sends it back with revision notes.

- [ ] **Step 5: Commit each approved exemplar**

```bash
git add functions/exemplars.json
git commit -m "feat(drill): add <exemplar_id>"
```

One commit per approved exemplar keeps the history readable and makes it easy to revert a single exemplar later.

- [ ] **Step 6: Verify coverage**

Run:
```bash
cd functions && python -c "
import json
from collections import Counter
c = Counter(e['archetype'] for e in json.load(open('exemplars.json')))
for a, n in sorted(c.items()):
    print(f'{a}: {n}')
print(f'total: {sum(c.values())}')
"
```
Expected: every archetype has ≥2 entries, total ≥18.

- [ ] **Step 7: Redeploy**

Run: `cd functions && firebase deploy --only functions:generate_custom_drill`
Expected: deploy succeeds. New exemplars take effect on next cold start.

---

## Unresolved questions

- Freeze at 9 archetypes or make expansion routine?
- Surface exemplar `notes` to users ("based on classic U10 cone weave") or internal-only?
- Fallback for unknown `(weakness, level)` — `cone_weave` or weakness-only lookup?
