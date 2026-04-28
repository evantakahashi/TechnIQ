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
