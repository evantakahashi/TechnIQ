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


def test_parse_wall_with_width():
    dsl = (
        'wall W1 at (15, 7) width 5\n'
        'player P1 at (5, 7) role "worker"\n'
        'step 1: P1 passes to W1\n'
        'step 2: P1 receives from W1\n'
    )
    diagram = parse_dsl(dsl)
    w1 = diagram["diagram"]["elements"][0]
    assert w1["type"] == "wall"
    assert w1.get("width") == 5.0
    paths = diagram["diagram"]["paths"]
    assert paths[0]["style"] == "pass"
    assert paths[0]["to"] == "W1"


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


def test_new_verbs_parse():
    from dsl_parser import parse_dsl
    d = parse_dsl('''player P1 at (5, 5) role "worker"
player P2 at (10, 5) role "server"
ball B1 at (5, 5)
wall W1 at (15, 5) width 5
goal GL at (19, 5) width 7.32
step 1: P1 throws to W1
step 2: P2 tosses to P1
step 3: P1 heads to GL
point: a
point: b''')
    styles = [p["style"] for p in d["diagram"]["paths"]]
    assert styles == ["throw", "toss", "header"]


def test_defender_server_shorthand():
    from dsl_parser import parse_dsl
    d = parse_dsl('''player P1 at (5, 5) role "worker"
defender D1 at (8, 5)
server S1 at (2, 5)
ball B1 at (5, 5)
step 1: P1 dribbles to D1
point: a
point: b''')
    els = {e["label"]: e for e in d["diagram"]["elements"]}
    assert els["D1"]["type"] == "player" and els["D1"]["role"] == "defender"
    assert els["S1"]["type"] == "player" and els["S1"]["role"] == "server"


def test_or_option_parses_as_alt():
    from dsl_parser import parse_dsl
    d = parse_dsl('''player P1 at (5, 5) role "worker"
player P2 at (10, 5) role "server"
ball B1 at (5, 5)
gate G1 at (18, 3) width 2
gate G2 at (18, 12) width 2
step 1: P1 dribbles to P2
step 2: P1 dribbles to G1
or: P1 dribbles to G2
point: a
point: b''')
    alts = [p for p in d["diagram"]["paths"] if p.get("alt")]
    assert len(alts) == 1 and alts[0]["to"] == "G2" and alts[0]["step"] == 2
