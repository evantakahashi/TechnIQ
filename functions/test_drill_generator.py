"""Integration tests for drill_generator with a mocked LLM."""
import pytest
from unittest.mock import MagicMock
from drill_generator import generate_drill, DrillGenerationFailed


VALID_DSL = """\
cone C1 at (0, 0)
cone C2 at (3, 0)
player P1 at (-2, 0) role "worker"
player P2 at (5, 5) role "server"
player P3 at (3, -3) role "defender"
ball B1 at (-2, 0)
goal GL at (10, 0) width 5

step 1: P1 dribbles to C1
step 2: P2 passes to P1
step 3: P1 dribbles to C2
step 4: P2 passes to P1
step 5: P1 shoots at GL

point: Keep the ball close under pressure
point: Dribble past the defender, scan before the touch, drive through the shot
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
        "equipment": ["ball", "cones", "goals", "partner"],
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
    llm = make_llm(["broken1", "broken2", "broken3", "broken4"])
    with pytest.raises(DrillGenerationFailed):
        generate_drill(make_request(), llm_call=llm)
    assert llm.call_count == 4


def test_fails_after_second_validation_error():
    invalid_dsl = "cone C1 at (0,0)\nplayer P1 at (5,0) role \"worker\"\nstep 1: P1 dribbles to GHOST\n"
    llm = make_llm([invalid_dsl, invalid_dsl, invalid_dsl, invalid_dsl])
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


def test_prompt_features_skill_description_prominently():
    """skill_description must appear in the SKILL TO TRAIN banner, not just as
    a footnote. Regression for drills defaulting to archetype shape over skill."""
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["skill_description"] = "first touch under pressure receiving bouncing balls"
    generate_drill(req, llm_call=capture)

    prompt = captured[0]
    assert "SKILL TO TRAIN" in prompt
    # Skill description appears in the banner line (above 'Player:')
    banner_section = prompt.split("Player:")[0]
    assert "first touch under pressure" in banner_section
    # Anti-template language in place
    assert "do NOT copy" in prompt or "not copy" in prompt.lower()
    # Old slavish-copy language is gone
    assert "in the same style" not in prompt


def test_prompt_falls_back_to_selected_weaknesses_then_weakness():
    """When skill_description is empty, use selected_weaknesses; then weakness."""
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["selected_weaknesses"] = [{"category": "Shooting", "specific": "Weak foot volleys"}]
    generate_drill(req, llm_call=capture)
    assert "Weak foot volleys" in captured[0]


def test_prompt_lists_selected_weaknesses_block():
    captured = []

    def capture(prompt: str) -> str:
        captured.append(prompt)
        return VALID_DSL

    req = make_request()
    req["selected_weaknesses"] = [
        {"category": "First Touch", "specific": "Bouncing balls"},
        {"category": "First Touch", "specific": "Turning with first touch"},
    ]
    generate_drill(req, llm_call=capture)
    assert "Specific weaknesses flagged" in captured[0]
    assert "Bouncing balls" in captured[0]
    assert "Turning with first touch" in captured[0]


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
        "position": "midfielder", "equipment": ["ball", "cones", "goals", "partner"],
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
        "position": "midfielder", "equipment": ["ball", "cones", "goals", "partner"],
    }
    generate_drill(request, llm_call=lambda _: valid_dsl)
    assert captured["number_of_players"] == 2
    assert captured["field_size"] == "small"
    assert captured["category"] == "technical"
    assert captured["recent_drill_names"] == []
    assert captured["playing_style"] == ""
    assert captured["skill_goals"] == []
