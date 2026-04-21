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
