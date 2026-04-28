# Restore Drill Request Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the request fields (`number_of_players`, `field_size`, `category`, `requirements.difficulty`, `recent_drill_names`, `playingStyle`, `skillGoals`) that were silently dropped by the Plan 1 single-LLM-pipeline refactor (commit `1493e93`), and add a quality-gate carve-out so explicit solo drills (`number_of_players=1`) are not falsely rejected by C2.

**Architecture:**
- Handler (`functions/main.py:generate_custom_drill`) extracts all relevant request fields and passes them in the dict to `generate_drill`.
- `generate_drill` (`functions/drill_generator.py`) accepts the new keys, threads them into `_build_prompt`, which injects per-field directives. `requirements.difficulty` becomes the source of truth for periodization (with fallback to `player_profile.experienceLevel`).
- `score_drill_quality` (`functions/drill_quality.py`) accepts an optional `number_of_players` argument; when `=1`, the C2 player-count and pressure-source sub-checks are replaced by a "constraint substitute" check (measurable success metric in coaching points).

**Tech Stack:** Python 3.12, Anthropic SDK (`claude-sonnet-4-6`), Firebase Functions 2nd-gen, pytest.

---

## Design Decisions (do not re-litigate during implementation)

1. **`requirements.difficulty` wins for periodization.** Falls back to `player_profile.experienceLevel`, then `"intermediate"`. Reason: user is explicitly choosing this drill's difficulty in the UI; profile is general player level.
2. **`field_size` mapping** (matches iOS enum comments at `CustomDrillModels.swift:113-117`):
   - `small` → `20×15m` (current default)
   - `medium` → `30×20m`
   - `large` → `50×30m`
3. **`number_of_players` semantic:**
   - `=1` → solo drill, no partners. Static obstacles only.
   - `=2` → worker + 1 partner (server or defender).
   - `=3..4` → worker + 2-3 partners.
   - `>=5` → small-sided team drill.
   The prompt expresses this as a hard constraint ("Use exactly N players"); the LLM picks roles.
4. **C2 solo-drill carve-out:** When `number_of_players == 1`, skip `len(player_roles) < 2` and `has_defender or server_active` checks. Replace with: at least one coaching point must contain a measurable success metric (digits + time/count word: `seconds?|sec|reps?|times?|in a row|consecutive`). Outcome-element check and rep-loop check still apply unchanged.
5. **`category` (technical/physical/tactical/mental):** Inject into prompt as drill-type context. Does NOT modify archetype lookup or rule-pack selection.
6. **`recent_drill_names`:** Prompt directive — "make this structurally distinct from these recent drills."
7. **`playingStyle`, `skillGoals`:** Prompt context (player flavor). No structural impact.
8. **`drill_feedback`:** Out of scope. Defer.

---

### Task 1: Handler extracts and forwards all relevant fields

**Files:**
- Create: `functions/test_main_generate_custom_drill.py`
- Modify: `functions/main.py:246-312`

- [ ] **Step 1: Write the failing tests**

Create `functions/test_main_generate_custom_drill.py`:

```python
"""Tests for generate_custom_drill handler — focuses on field passthrough.

Patches drill_generator.generate_drill to capture the request dict the handler
forwards. No real LLM calls.
"""
from __future__ import annotations

import json
import os
from unittest.mock import patch

import pytest
from werkzeug.test import EnvironBuilder
from firebase_functions import https_fn


@pytest.fixture(autouse=True)
def allow_unauth(monkeypatch):
    monkeypatch.setenv("ALLOW_UNAUTHENTICATED", "true")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-real")


def _make_request(payload: dict) -> https_fn.Request:
    body = json.dumps(payload).encode("utf-8")
    env = EnvironBuilder(
        method="POST",
        path="/generate_custom_drill",
        data=body,
        headers={"Content-Type": "application/json"},
    ).get_environ()
    return https_fn.Request(env)


_FAKE_DRILL = {
    "diagram": {
        "elements": [{"type": "player", "label": "P1", "role": "worker", "x": 5.0, "y": 5.0}],
        "paths": [{"step": 1, "from": "P1", "to": "P1", "style": "dribble"}],
    },
    "coaching_points": ["dribble close", "scan up"],
    "equipment": ["ball"],
}


def _capture_request_dict():
    """Return (capture_list, fake_generate). capture_list[0] holds the dict."""
    captured: list[dict] = []

    def fake_generate(req_dict, llm_call):
        captured.append(req_dict)
        return dict(_FAKE_DRILL)

    return captured, fake_generate


def test_handler_forwards_number_of_players():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball", "cones"],
            "number_of_players": 1,
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    assert resp.status_code == 200
    assert captured[0]["number_of_players"] == 1


def test_handler_forwards_field_size():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "field_size": "large",
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["field_size"] == "large"


def test_handler_forwards_category():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "category": "tactical",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Defending"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["category"] == "tactical"


def test_handler_forwards_recent_drill_names():
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "recent_drill_names": ["Cone Weave A", "Triangle Pass"],
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["recent_drill_names"] == ["Cone Weave A", "Triangle Pass"]


def test_handler_forwards_player_flavor():
    """playingStyle and skillGoals from profile flow through."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {
            "age": 14,
            "position": "midfielder",
            "experienceLevel": "intermediate",
            "playingStyle": "attacking",
            "skillGoals": ["improve weak foot", "increase pace"],
        },
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["playing_style"] == "attacking"
    assert captured[0]["skill_goals"] == ["improve weak foot", "increase pace"]


def test_handler_uses_requirements_difficulty_for_level():
    """When requirements.difficulty is set, it overrides profile.experienceLevel."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "beginner"},
        "requirements": {
            "skill_description": "test",
            "difficulty": "advanced",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["experience_level"] == "advanced"


def test_handler_falls_back_to_profile_level():
    """When requirements.difficulty is missing, falls back to profile.experienceLevel."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "advanced"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["experience_level"] == "advanced"


def test_handler_defaults_number_of_players_to_2():
    """Missing number_of_players defaults to 2 (worker + partner)."""
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        generate_custom_drill(_make_request(payload))
    assert captured[0]["number_of_players"] == 2
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_main_generate_custom_drill.py -v`
Expected: 8 failures with `KeyError` or `AssertionError` on the new keys.

- [ ] **Step 3: Modify the handler to extract and forward new fields**

Replace lines `246-312` of `functions/main.py` with:

```python
        player_profile = request_data.get("player_profile", {})
        requirements = request_data.get("requirements", {})

        # Weakness precedence: request-specific signals beat static profile.
        selected_weaknesses = requirements.get("selected_weaknesses") or []
        skill_description = (requirements.get("skill_description") or "").strip()
        if selected_weaknesses and selected_weaknesses[0].get("category"):
            weakness = selected_weaknesses[0]["category"]
        elif player_profile.get("weaknesses"):
            weakness = player_profile["weaknesses"][0]
        else:
            weakness = "Ball Control"

        # Periodization source of truth: requirements.difficulty wins, then profile, then default.
        level = (
            requirements.get("difficulty")
            or player_profile.get("experienceLevel")
            or "intermediate"
        )
        age = int(player_profile.get("age") or 14)
        position = player_profile.get("position", "midfielder")
        equipment = requirements.get("equipment", ["ball", "cones"])
        category = requirements.get("category", "technical")
        number_of_players = int(requirements.get("number_of_players") or 2)
        field_size = request_data.get("field_size", "small")
        recent_drill_names = requirements.get("recent_drill_names") or []
        playing_style = player_profile.get("playingStyle", "")
        skill_goals = player_profile.get("skillGoals") or []

        # Initialize Anthropic client
        anthropic_api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not anthropic_api_key:
            return https_fn.Response(
                json.dumps({"error": "Anthropic API key not configured"}),
                status=500,
                headers={
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            )

        from anthropic import Anthropic
        client = Anthropic(api_key=anthropic_api_key)

        from drill_generator import generate_drill, DrillGenerationFailed

        def _llm_call(prompt: str) -> str:
            msg = client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=1500,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text

        # Validate request data
        if not player_profile or not requirements:
            return https_fn.Response(
                json.dumps({"error": "Invalid request", "details": "player_profile and requirements are required"}),
                status=400,
                headers={"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            )

        try:
            drill = generate_drill(
                {
                    "weakness": weakness,
                    "experience_level": level,
                    "player_age": age,
                    "position": position,
                    "equipment": equipment,
                    "skill_description": skill_description,
                    "selected_weaknesses": selected_weaknesses,
                    "category": category,
                    "number_of_players": number_of_players,
                    "field_size": field_size,
                    "recent_drill_names": recent_drill_names,
                    "playing_style": playing_style,
                    "skill_goals": skill_goals,
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_main_generate_custom_drill.py -v`
Expected: 8 passing.

- [ ] **Step 5: Run full test suite to verify no regressions**

Run: `cd functions && python -m pytest -q`
Expected: all passing (or only skips for network-dependent tests).

- [ ] **Step 6: Commit**

```bash
git add functions/main.py functions/test_main_generate_custom_drill.py
git commit -m "fix(drill): handler forwards number_of_players, field_size, category, recent_drill_names, player flavor"
```

---

### Task 2: drill_generator accepts new request fields

**Files:**
- Modify: `functions/drill_generator.py:59-115`
- Modify: `functions/test_drill_generator.py`

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_drill_generator.py`:

```python
def test_generate_drill_accepts_new_fields(monkeypatch):
    """generate_drill reads new optional keys without raising KeyError."""
    from drill_generator import generate_drill

    # Stub _build_prompt to capture kwargs and skip LLM
    captured = {}
    def fake_build_prompt(**kwargs):
        captured.update(kwargs)
        return "PROMPT"
    monkeypatch.setattr("drill_generator._build_prompt", fake_build_prompt)

    # Stub llm_call to return a minimal valid drill DSL — pre-build a known-good drill.
    valid_dsl = '''player P1 at (5, 5) role "worker" label "P1"
player P2 at (10, 5) role "server" label "P2"
goal GL at (15, 7.5) width 7
ball B1 at (5, 5)
step 1: P1 passes to P2
step 2: P2 passes to P1
step 3: P1 dribbles to GL
step 4: P1 shoots at GL
step 5: P1 runs to P1
point: receive with the far foot
point: scan before you receive
'''
    request = {
        "weakness": "Passing", "experience_level": "intermediate", "player_age": 14,
        "position": "midfielder", "equipment": ["ball", "cones", "partner"],
        "skill_description": "improve passing",
        "selected_weaknesses": [],
        "category": "technical",
        "number_of_players": 2,
        "field_size": "medium",
        "recent_drill_names": ["Drill A"],
        "playing_style": "possession",
        "skill_goals": ["accuracy"],
    }
    drill = generate_drill(request, llm_call=lambda _: valid_dsl)
    assert drill is not None
    assert captured["number_of_players"] == 2
    assert captured["field_size"] == "medium"
    assert captured["category"] == "technical"
    assert captured["recent_drill_names"] == ["Drill A"]
    assert captured["playing_style"] == "possession"
    assert captured["skill_goals"] == ["accuracy"]


def test_generate_drill_defaults_for_missing_new_fields(monkeypatch):
    """Missing new fields use safe defaults — backward compatible."""
    from drill_generator import generate_drill

    captured = {}
    def fake_build_prompt(**kwargs):
        captured.update(kwargs)
        return "PROMPT"
    monkeypatch.setattr("drill_generator._build_prompt", fake_build_prompt)

    valid_dsl = '''player P1 at (5, 5) role "worker" label "P1"
player P2 at (10, 5) role "server" label "P2"
goal GL at (15, 7.5) width 7
ball B1 at (5, 5)
step 1: P1 passes to P2
step 2: P2 passes to P1
step 3: P1 dribbles to GL
step 4: P1 shoots at GL
step 5: P1 runs to P1
point: receive with the far foot
point: scan before you receive
'''
    request = {
        "weakness": "Passing", "experience_level": "intermediate", "player_age": 14,
        "position": "midfielder", "equipment": ["ball", "cones", "partner"],
    }
    generate_drill(request, llm_call=lambda _: valid_dsl)
    assert captured["number_of_players"] == 2
    assert captured["field_size"] == "small"
    assert captured["category"] == "technical"
    assert captured["recent_drill_names"] == []
    assert captured["playing_style"] == ""
    assert captured["skill_goals"] == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_drill_generator.py::test_generate_drill_accepts_new_fields test_drill_generator.py::test_generate_drill_defaults_for_missing_new_fields -v`
Expected: failures (TypeError on unexpected kwargs OR AssertionError because fields not captured).

- [ ] **Step 3: Modify generate_drill to read and forward new keys**

In `functions/drill_generator.py` lines `68-97`, replace the field-reading and `_build_prompt` call:

```python
    weakness = request["weakness"]
    level = request["experience_level"]
    age = int(request["player_age"])
    position = request["position"]
    equipment: list[str] = list(request["equipment"])
    skill_description = (request.get("skill_description") or "").strip()
    selected_weaknesses = request.get("selected_weaknesses") or []
    category = request.get("category") or "technical"
    number_of_players = int(request.get("number_of_players") or 2)
    field_size = request.get("field_size") or "small"
    recent_drill_names = request.get("recent_drill_names") or []
    playing_style = request.get("playing_style") or ""
    skill_goals = request.get("skill_goals") or []

    archetype = pick_archetype(weakness, level)
    exemplars = get_exemplars(archetype, level=level, n=3)
    rule_pack = get_rule_pack(weakness)
    age_cap = _age_cap(age)

    errors: list[tuple[str, str]] = []

    for _attempt in range(MAX_ATTEMPTS):
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
            category=category,
            number_of_players=number_of_players,
            field_size=field_size,
            recent_drill_names=recent_drill_names,
            playing_style=playing_style,
            skill_goals=skill_goals,
        )
```

Also update `_build_prompt` signature at line `152-166` to accept the new kwargs (still keyword-only):

```python
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
    category: str = "technical",
    number_of_players: int = 2,
    field_size: str = "small",
    recent_drill_names: list[str] | None = None,
    playing_style: str = "",
    skill_goals: list[str] | None = None,
) -> str:
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_drill_generator.py::test_generate_drill_accepts_new_fields test_drill_generator.py::test_generate_drill_defaults_for_missing_new_fields -v`
Expected: 2 passing.

- [ ] **Step 5: Run full drill_generator tests for regressions**

Run: `cd functions && python -m pytest test_drill_generator.py -q`
Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add functions/drill_generator.py functions/test_drill_generator.py
git commit -m "feat(drill): generate_drill accepts category, number_of_players, field_size, variety + flavor fields"
```

---

### Task 3: Prompt injects directives for each new field

**Files:**
- Modify: `functions/drill_generator.py:152-239`
- Modify: `functions/test_drill_generator.py`

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_drill_generator.py`:

```python
import pytest


@pytest.fixture
def base_prompt_kwargs():
    return {
        "weakness": "Passing",
        "skill_description": "improve passing",
        "selected_weaknesses": [],
        "level": "intermediate",
        "age": 14,
        "position": "midfielder",
        "equipment": ["ball", "cones"],
        "archetype": "server_executor",
        "age_cap": 12.0,
        "exemplars": [],
        "rule_pack": None,
        "prior_errors": [],
    }


def test_prompt_solo_directive_when_one_player(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, number_of_players=1)
    assert "SOLO drill" in prompt or "solo drill" in prompt
    assert "no partners" in prompt.lower() or "no partner" in prompt.lower()
    assert "1 player" in prompt or "exactly 1" in prompt


def test_prompt_partner_directive_when_two_players(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, number_of_players=2)
    assert "2 player" in prompt or "exactly 2" in prompt


def test_prompt_team_directive_when_many_players(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, number_of_players=5)
    assert "5 player" in prompt or "exactly 5" in prompt


def test_prompt_field_size_small_uses_20x15(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, field_size="small")
    assert "20" in prompt and "15" in prompt


def test_prompt_field_size_medium_uses_30x20(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, field_size="medium")
    assert "30" in prompt and "20" in prompt


def test_prompt_field_size_large_uses_50x30(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, field_size="large")
    assert "50" in prompt and "30" in prompt


def test_prompt_includes_category(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, category="tactical")
    assert "tactical" in prompt.lower()


def test_prompt_includes_recent_drill_names(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(
        **base_prompt_kwargs,
        recent_drill_names=["Cone Weave A", "Triangle Pass"],
    )
    assert "Cone Weave A" in prompt
    assert "Triangle Pass" in prompt
    assert "distinct" in prompt.lower() or "different" in prompt.lower() or "avoid" in prompt.lower()


def test_prompt_includes_playing_style_and_goals(base_prompt_kwargs):
    from drill_generator import _build_prompt
    prompt = _build_prompt(
        **base_prompt_kwargs,
        playing_style="attacking winger",
        skill_goals=["improve weak foot", "increase pace"],
    )
    assert "attacking winger" in prompt
    assert "improve weak foot" in prompt or "weak foot" in prompt


def test_prompt_omits_recent_drills_block_when_empty(base_prompt_kwargs):
    """No recent drills → no 'avoid these' block in prompt."""
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, recent_drill_names=[])
    # Should not contain heading for recent drills
    assert "RECENT DRILLS" not in prompt.upper() or "AVOID" not in prompt.upper()


def test_prompt_omits_player_flavor_when_empty(base_prompt_kwargs):
    """No playing_style and no skill_goals → no flavor block injected."""
    from drill_generator import _build_prompt
    prompt = _build_prompt(**base_prompt_kwargs, playing_style="", skill_goals=[])
    assert "PLAYER STYLE" not in prompt.upper()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_drill_generator.py -k "prompt_solo or prompt_partner or prompt_team or prompt_field_size or prompt_includes_category or prompt_includes_recent or prompt_includes_playing or prompt_omits" -v`
Expected: 11 failures.

- [ ] **Step 3: Add field-size dimension lookup and update prompt body**

Add at module level near `_PERIODIZATION_BY_LEVEL` in `functions/drill_generator.py`:

```python
_FIELD_SIZE_DIMS = {
    "small":  (20, 15),
    "medium": (30, 20),
    "large":  (50, 30),
}
```

In `_build_prompt`, normalize defaults at the top:

```python
    recent_drill_names = recent_drill_names or []
    skill_goals = skill_goals or []
    width, length = _FIELD_SIZE_DIMS.get(field_size, _FIELD_SIZE_DIMS["small"])
```

Replace the existing constraints line (around line 217) and surrounding block with:

```python
    # Player count directive
    if number_of_players == 1:
        player_directive = (
            "PLAYER COUNT: Use exactly 1 player (the worker). "
            "This is a SOLO drill — no partners (no server, no defender). "
            "Use static obstacles (cones, gates, walls) and a measurable success target instead of human pressure."
        )
    elif number_of_players == 2:
        player_directive = "PLAYER COUNT: Use exactly 2 players (worker + 1 partner serving as server or defender)."
    elif number_of_players <= 4:
        player_directive = f"PLAYER COUNT: Use exactly {number_of_players} players (worker + {number_of_players - 1} partners)."
    else:
        player_directive = f"PLAYER COUNT: Use exactly {number_of_players} players — small-sided team drill."
    lines += [player_directive, ""]

    # Drill category context
    lines += [f"DRILL CATEGORY: {category}", ""]

    # Recent drill names — variety
    if recent_drill_names:
        lines += [
            "RECENT DRILLS (make this structurally distinct from these — different shape/pattern):",
        ] + [f"  - {n}" for n in recent_drill_names] + [""]

    # Player flavor — non-binding context
    if playing_style or skill_goals:
        flavor = ["PLAYER STYLE / GOALS (use to tailor coaching cues, not to constrain shape):"]
        if playing_style:
            flavor.append(f"  - Style: {playing_style}")
        if skill_goals:
            flavor.append(f"  - Goals: {', '.join(skill_goals)}")
        lines += flavor + [""]
```

Then update the constraints line (replace `Constraints: max area 20x15m` with):

```python
    lines += [
        f"Starting archetype (a shape to adapt, not copy): {archetype}",
        f"Constraints: max area {width}x{length}m, max cone spacing {age_cap}m, equipment {equipment}",
        "",
    ]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_drill_generator.py -k "prompt_solo or prompt_partner or prompt_team or prompt_field_size or prompt_includes_category or prompt_includes_recent or prompt_includes_playing or prompt_omits" -v`
Expected: 11 passing.

- [ ] **Step 5: Full regression**

Run: `cd functions && python -m pytest -q`
Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add functions/drill_generator.py functions/test_drill_generator.py
git commit -m "feat(drill): prompt injects player-count, field-size, category, variety + flavor directives"
```

---

### Task 4: C2 quality-gate carve-out for solo drills

**Files:**
- Modify: `functions/drill_quality.py:30-62, 86-143`
- Modify: `functions/drill_generator.py:104` (pass number_of_players)
- Modify: `functions/test_drill_quality.py`

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_drill_quality.py`:

```python
import re


def _make_solo_drill(coaching_points, with_outcome=True, with_rep_loop=True):
    """Build a 1-player drill with optional outcome element + rep-loop."""
    elements = [{"type": "player", "label": "P1", "role": "worker", "x": 5.0, "y": 5.0}]
    if with_outcome:
        elements.append({"type": "gate", "label": "G1", "x": 15.0, "y": 7.5})
    elements.append({"type": "cone", "label": "C1", "x": 8.0, "y": 5.0})
    elements.append({"type": "cone", "label": "C2", "x": 12.0, "y": 5.0})
    paths = [
        {"step": 1, "from": "P1", "to": "C1", "style": "dribble"},
        {"step": 2, "from": "P1", "to": "C2", "style": "dribble"},
        {"step": 3, "from": "P1", "to": "G1", "style": "shoot"},
        {"step": 4, "from": "P1", "to": "C1", "style": "dribble"},
        {"step": 5, "from": "P1", "to": "C2", "style": "dribble"},
    ]
    if not with_rep_loop:
        paths = paths[:1]
    return {
        "diagram": {"elements": elements, "paths": paths},
        "coaching_points": coaching_points,
    }


def test_c2_solo_drill_with_metric_passes_at_advanced():
    from drill_quality import score_drill_quality

    drill = _make_solo_drill(
        coaching_points=[
            "Strike with the laces and follow through",
            "Complete 10 successful shots in 60 seconds",
        ],
    )
    score, reasons = score_drill_quality(drill, rule_pack=None, level="advanced",
                                         number_of_players=1)
    c2_failures = [r for r in reasons if r.startswith("C2:")]
    assert not c2_failures, f"C2 should pass for solo drill with metric, got: {c2_failures}"


def test_c2_solo_drill_without_metric_fails():
    from drill_quality import score_drill_quality

    drill = _make_solo_drill(
        coaching_points=[
            "Keep the ball close",
            "Stay on the balls of your feet",
        ],
    )
    score, reasons = score_drill_quality(drill, rule_pack=None, level="advanced",
                                         number_of_players=1)
    c2_failures = [r for r in reasons if r.startswith("C2:")]
    assert c2_failures, "C2 must fail for solo drill with no measurable metric"


def test_c2_solo_drill_without_outcome_fails():
    from drill_quality import score_drill_quality

    drill = _make_solo_drill(
        coaching_points=["Complete 10 reps in 30 seconds"],
        with_outcome=False,
    )
    score, reasons = score_drill_quality(drill, rule_pack=None, level="advanced",
                                         number_of_players=1)
    c2_failures = [r for r in reasons if r.startswith("C2:")]
    assert c2_failures, "C2 must still require outcome element even for solo drills"


def test_c2_solo_drill_without_rep_loop_fails():
    from drill_quality import score_drill_quality

    drill = _make_solo_drill(
        coaching_points=["Complete 10 reps in 30 seconds"],
        with_rep_loop=False,
    )
    score, reasons = score_drill_quality(drill, rule_pack=None, level="advanced",
                                         number_of_players=1)
    c2_failures = [r for r in reasons if r.startswith("C2:")]
    assert c2_failures, "C2 must still require rep loop even for solo drills"


def test_c2_multi_player_default_path_unchanged():
    """Existing 2+ player drills behave exactly as before."""
    from drill_quality import score_drill_quality

    drill = {
        "diagram": {
            "elements": [
                {"type": "player", "label": "P1", "role": "worker", "x": 5.0, "y": 5.0},
                {"type": "player", "label": "P2", "role": "server", "x": 10.0, "y": 5.0},
                {"type": "goal", "label": "GL", "x": 15.0, "y": 7.5},
            ],
            "paths": [
                {"step": 1, "from": "P2", "to": "P1", "style": "pass"},
                {"step": 2, "from": "P1", "to": "GL", "style": "shoot"},
                {"step": 3, "from": "P2", "to": "P1", "style": "pass"},
                {"step": 4, "from": "P1", "to": "GL", "style": "shoot"},
                {"step": 5, "from": "P1", "to": "P2", "style": "pass"},
            ],
        },
        "coaching_points": ["Strike across the ball", "Plant foot pointing at target"],
    }
    score_default, _ = score_drill_quality(drill, rule_pack=None, level="advanced")
    score_explicit, _ = score_drill_quality(drill, rule_pack=None, level="advanced",
                                             number_of_players=2)
    assert score_default == score_explicit
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && python -m pytest test_drill_quality.py -k "c2_solo or c2_multi_player_default" -v`
Expected: 5 failures (TypeError: unexpected kwarg `number_of_players`).

- [ ] **Step 3: Add `number_of_players` parameter to score_drill_quality and carve-out logic**

In `functions/drill_quality.py`:

Add at module level near `_FOOTBALL_VERBS`:

```python
# Detects measurable success targets in coaching points (e.g., "10 in 60 seconds").
_METRIC_RE = re.compile(
    r"\b\d+\s*(?:reps?|times?|seconds?|sec|secs|in a row|consecutive|in\s*\d+\s*(?:seconds?|sec))",
    re.IGNORECASE,
)
```

Replace `score_drill_quality` signature and body:

```python
def score_drill_quality(
    drill: dict[str, Any],
    rule_pack: dict[str, Any] | None,
    level: str,
    number_of_players: int = 2,
) -> tuple[int, list[str]]:
    """Return (checks_passed, reasons_for_failures). Max score = 4.

    Solo carve-out: when number_of_players == 1, C2's player-count and
    pressure-source sub-checks are replaced by a "measurable target in
    coaching points" sub-check. Outcome and rep-loop sub-checks are unchanged.
    """
    reasons: list[str] = []

    elements: list[dict[str, Any]] = drill.get("diagram", {}).get("elements", [])
    paths:    list[dict[str, Any]] = drill.get("diagram", {}).get("paths", [])
    coaching: list[str]            = drill.get("coaching_points", [])

    c1_ok = _c1_forces_primary_action(drill, rule_pack, level)
    c2_ok = _c2_structural_realism(elements, paths, coaching, level, number_of_players)
    c3_ok = _c3_coaching_points_on_target(coaching, rule_pack, level)
    c4_ok = _c4_rep_density(paths)

    if not c1_ok:
        reasons.append("C1: drill does not surface the primary action (no verb_keyword in steps or coaching)")
    if not c2_ok:
        if number_of_players == 1:
            reasons.append("C2: solo drill needs outcome element + rep loop + a measurable success metric in coaching")
        else:
            reasons.append("C2: structural realism failed (need ≥2 players, outcome object, pressure source, and repeating element)")
    if not c3_ok:
        reasons.append("C3: coaching points too thin or off-target (need ≥2, ≥1 on-skill or non-generic)")
    if not c4_ok:
        reasons.append("C4: not enough reps (need ≥5 steps OR one element appearing on ≥3 path endpoints)")

    score = sum((c1_ok, c2_ok, c3_ok, c4_ok))
    return score, reasons
```

Replace `_c2_structural_realism` to accept and branch on `number_of_players`:

```python
def _c2_structural_realism(
    elements: list[dict[str, Any]],
    paths: list[dict[str, Any]],
    coaching: list[str],
    level: str,
    number_of_players: int = 2,
) -> bool:
    if level == "beginner":
        return True

    # Outcome check (shared across solo and multi-player paths)
    has_outcome_element = any(e.get("type") in {"goal", "gate"} for e in elements)
    outcome_terms_in_cp = any(
        any(term in cp.lower() for term in ("line", "gate", "goal", "zone"))
        for cp in coaching
    )
    if not (has_outcome_element or outcome_terms_in_cp):
        return False

    # Rep-loop check (shared)
    el_step_counts: dict[str, set[int]] = {}
    for p in paths:
        step = p.get("step")
        if step is None:
            continue
        for key in ("from", "to"):
            lbl = p.get(key)
            if lbl:
                el_step_counts.setdefault(lbl, set()).add(step)
    has_rep_loop = any(len(s) >= 2 for s in el_step_counts.values())
    if not has_rep_loop:
        return False

    if number_of_players == 1:
        # Solo carve-out: replace player-count + pressure-source with measurable metric.
        has_metric = any(_METRIC_RE.search(cp) for cp in coaching)
        return has_metric

    # Multi-player path: original checks
    player_roles = [
        e.get("role", "") for e in elements
        if e.get("type") == "player" and e.get("role") in {"worker", "server", "defender"}
    ]
    if len(player_roles) < 2:
        return False

    has_defender = any(
        e.get("type") == "player" and e.get("role") == "defender" for e in elements
    )
    server_labels = {
        lbl for e in elements
        if e.get("type") == "player" and e.get("role") == "server"
        and (lbl := e.get("label")) is not None
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

    return True
```

- [ ] **Step 4: Pass number_of_players from generate_drill into score_drill_quality**

In `functions/drill_generator.py`, at line `104`, replace:

```python
            score, reasons = score_drill_quality(drill, rule_pack, level)
```

with:

```python
            score, reasons = score_drill_quality(drill, rule_pack, level,
                                                 number_of_players=number_of_players)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd functions && python -m pytest test_drill_quality.py -v`
Expected: all passing including 5 new solo-drill tests.

- [ ] **Step 6: Run full regression**

Run: `cd functions && python -m pytest -q`
Expected: all passing.

- [ ] **Step 7: Commit**

```bash
git add functions/drill_quality.py functions/drill_generator.py functions/test_drill_quality.py
git commit -m "feat(quality): C2 carve-out for solo drills (require measurable metric instead of human pressure)"
```

---

### Task 5: End-to-end integration test through handler

**Files:**
- Modify: `functions/test_main_generate_custom_drill.py`

- [ ] **Step 1: Write the failing tests**

Append to `functions/test_main_generate_custom_drill.py`:

```python
def test_handler_solo_request_passes_through_to_quality_gate():
    """Solo request → generate_drill receives number_of_players=1 → C2 uses solo carve-out.

    We mock generate_drill to return a known drill but verify the request dict
    forwarded matches what would let the solo carve-out activate.
    """
    from main import generate_custom_drill

    captured, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 16, "position": "winger", "experienceLevel": "advanced"},
        "field_size": "medium",
        "requirements": {
            "skill_description": "solo dribbling under time pressure",
            "difficulty": "advanced",
            "category": "technical",
            "equipment": ["ball", "cones"],
            "number_of_players": 1,
            "selected_weaknesses": [{"category": "Dribbling"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    assert resp.status_code == 200
    forwarded = captured[0]
    assert forwarded["number_of_players"] == 1
    assert forwarded["experience_level"] == "advanced"
    assert forwarded["field_size"] == "medium"
    assert forwarded["category"] == "technical"


def test_handler_response_preserves_drill_shape():
    """Response wraps drill in {"drill": ..., "generated_at": ...} with camelCase keys."""
    from main import generate_custom_drill

    _, fake = _capture_request_dict()
    payload = {
        "user_id": "u1",
        "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
        "requirements": {
            "skill_description": "test",
            "equipment": ["ball"],
            "selected_weaknesses": [{"category": "Passing"}],
        },
    }
    with patch("drill_generator.generate_drill", fake):
        resp = generate_custom_drill(_make_request(payload))
    body = json.loads(resp.get_data(as_text=True))
    assert "drill" in body
    drill = body["drill"]
    assert "coachingPoints" in drill  # camelCase
    assert "coaching_points" not in drill  # no leak
    assert "estimatedDuration" in drill
    assert isinstance(drill["estimatedDuration"], int)
```

- [ ] **Step 2: Run tests to verify they pass (or fail meaningfully)**

Run: `cd functions && python -m pytest test_main_generate_custom_drill.py -v`
Expected: 10 passing total (8 from Task 1 + 2 new).

- [ ] **Step 3: Commit**

```bash
git add functions/test_main_generate_custom_drill.py
git commit -m "test(drill): add e2e integration tests for solo flow + camelCase response"
```

---

### Task 6: Live verification gauntlet (real LLM, manual review)

**Files:**
- Create: `/tmp/verify_field_passthrough.py`

This task is verification, not TDD. Generates real drills against the live Anthropic API and prints them for human review.

- [ ] **Step 1: Write the verification script**

Create `/tmp/verify_field_passthrough.py`:

```python
"""Live gauntlet: 6 cases exercising restored fields. Print + manual review.

Cases:
  1. Solo + advanced + dribbling + small field
  2. Solo + intermediate + first touch + small field + wall equipment
  3. Partner (2) + advanced + passing + medium field
  4. Small group (4) + intermediate + tactical category + large field
  5. Solo + advanced + recent_drill_names provided (variety check)
  6. Profile=beginner but requirements.difficulty=advanced (override check)
"""
from __future__ import annotations

import json
import os
import sys
import time

sys.path.insert(0, "/Users/evantakahashi/TechnIQ/functions")
os.environ["ALLOW_UNAUTHENTICATED"] = "true"

from dotenv import load_dotenv
load_dotenv("/Users/evantakahashi/TechnIQ/functions/.env")

from werkzeug.test import EnvironBuilder
from firebase_functions import https_fn
from main import generate_custom_drill


CASES = [
    {
        "label": "1 — solo / advanced / dribbling",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 17, "position": "winger", "experienceLevel": "advanced"},
            "field_size": "small",
            "requirements": {
                "skill_description": "solo dribbling under time pressure",
                "difficulty": "advanced",
                "category": "technical",
                "equipment": ["ball", "cones"],
                "number_of_players": 1,
                "selected_weaknesses": [{"category": "Dribbling"}],
            },
        },
    },
    {
        "label": "2 — solo / intermediate / first touch / wall",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 14, "position": "forward", "experienceLevel": "intermediate"},
            "field_size": "small",
            "requirements": {
                "skill_description": "first touch off the wall",
                "difficulty": "intermediate",
                "category": "technical",
                "equipment": ["ball", "wall", "cones"],
                "number_of_players": 1,
                "selected_weaknesses": [{"category": "First Touch"}],
            },
        },
    },
    {
        "label": "3 — partner (2) / advanced / passing / medium",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 16, "position": "midfielder", "experienceLevel": "advanced"},
            "field_size": "medium",
            "requirements": {
                "skill_description": "weighted passing under pressure",
                "difficulty": "advanced",
                "category": "technical",
                "equipment": ["ball", "cones", "partner"],
                "number_of_players": 2,
                "selected_weaknesses": [{"category": "Passing"}],
            },
        },
    },
    {
        "label": "4 — small group (4) / intermediate / tactical / large",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 15, "position": "midfielder", "experienceLevel": "intermediate"},
            "field_size": "large",
            "requirements": {
                "skill_description": "support play in possession",
                "difficulty": "intermediate",
                "category": "tactical",
                "equipment": ["ball", "cones", "goals", "partner"],
                "number_of_players": 4,
                "selected_weaknesses": [{"category": "Positioning"}],
            },
        },
    },
    {
        "label": "5 — solo + recent_drill_names variety",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
            "field_size": "small",
            "requirements": {
                "skill_description": "weak foot dribbling",
                "difficulty": "intermediate",
                "category": "technical",
                "equipment": ["ball", "cones"],
                "number_of_players": 1,
                "recent_drill_names": ["Cone Weave Slalom", "Figure-8 Dribble"],
                "selected_weaknesses": [{"category": "Dribbling"}],
            },
        },
    },
    {
        "label": "6 — profile=beginner but difficulty=advanced (override)",
        "payload": {
            "user_id": "u1",
            "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "beginner"},
            "field_size": "small",
            "requirements": {
                "skill_description": "stretch into advanced shooting",
                "difficulty": "advanced",
                "category": "technical",
                "equipment": ["ball", "cones", "goals"],
                "number_of_players": 2,
                "selected_weaknesses": [{"category": "Shooting"}],
            },
        },
    },
]


def make_req(payload):
    body = json.dumps(payload).encode("utf-8")
    env = EnvironBuilder(
        method="POST", path="/generate_custom_drill",
        data=body, headers={"Content-Type": "application/json"},
    ).get_environ()
    return https_fn.Request(env)


def summarize(drill):
    elements = drill.get("diagram", {}).get("elements", [])
    paths = drill.get("diagram", {}).get("paths", [])
    players = [e for e in elements if e.get("type") == "player"]
    cps = drill.get("coachingPoints", [])
    return {
        "name": drill.get("name"),
        "n_players": len(players),
        "roles": sorted({p.get("role", "?") for p in players}),
        "n_steps": len(paths),
        "n_coaching": len(cps),
        "first_cp": cps[0] if cps else None,
    }


def main():
    results = []
    for case in CASES:
        t0 = time.time()
        resp = generate_custom_drill(make_req(case["payload"]))
        elapsed = time.time() - t0
        if resp.status_code != 200:
            print(f"\n[{case['label']}] STATUS={resp.status_code}: {resp.get_data(as_text=True)[:200]}")
            results.append((case["label"], False, None, elapsed))
            continue
        data = json.loads(resp.get_data(as_text=True))
        drill = data["drill"]
        summary = summarize(drill)
        print(f"\n=== {case['label']} === ({elapsed:.1f}s)")
        print(f"  expected n_players: {case['payload']['requirements']['number_of_players']}")
        print(f"  actual:   {summary}")
        results.append((case["label"], True, summary, elapsed))

    print("\n" + "=" * 60)
    for label, ok, summary, elapsed in results:
        if not ok:
            print(f"  FAIL  {label}")
            continue
        expected = next(c["payload"]["requirements"]["number_of_players"] for c in CASES if c["label"] == label)
        match = "✓" if summary["n_players"] == expected else "✗"
        print(f"  {match}  {label}  ({elapsed:.1f}s)  players={summary['n_players']}/expected {expected}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the gauntlet**

Run: `/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12 /tmp/verify_field_passthrough.py`
Expected: 6 cases generate. For each, check that:
- `n_players` matches the requested `number_of_players` exactly.
- Solo cases have no `defender` or `server` role.
- Recent-drills case produces a structurally different shape from the named drills.
- Override case (profile=beginner, difficulty=advanced) produces an advanced-level drill (active resistance, scanning cues).

- [ ] **Step 3: Spot-check failures**

If any case fails the player-count match, capture the prompt that was sent and the raw LLM output, and decide whether the directive needs strengthening (e.g., "STRICTLY exactly N players — do not add more"). Add a follow-up commit if needed.

- [ ] **Step 4: No commit unless adjustments are made**

This task does not commit by default. If adjustments are needed, commit them as `fix(drill): strengthen player-count directive` or similar.

---

## Self-Review

**Spec coverage:**
- `number_of_players` passthrough — Tasks 1, 2, 3, 4, 5, 6 ✓
- `field_size` passthrough — Tasks 1, 2, 3, 6 ✓
- `category` passthrough — Tasks 1, 2, 3, 6 ✓
- `requirements.difficulty` override — Tasks 1, 6 ✓
- `recent_drill_names` — Tasks 1, 2, 3, 6 ✓
- `playingStyle`, `skillGoals` — Tasks 1, 2, 3 ✓
- C2 solo carve-out — Task 4 ✓
- E2E verification — Task 5 (mocked) + Task 6 (live) ✓

**Type consistency:**
- `number_of_players: int`, `field_size: str`, `category: str`, `recent_drill_names: list[str]`, `playing_style: str`, `skill_goals: list[str]` — consistent across handler and generator.
- Handler renames `playingStyle` → `playing_style`, `skillGoals` → `skill_goals` for snake_case consistency in generator dict.

**Placeholders:** None.

---

## Unresolved Questions

- Strict vs soft player count: if LLM ignores "exactly N", do we strengthen the directive or accept ±1 drift?
- `recent_drill_names` length cap: pass all or last N?
- `category=mental` — current rule packs don't cover mental skills; degrade gracefully or skip?
- Should `field_size=large` trigger team-shaped drills automatically, or stay independent of player count?
