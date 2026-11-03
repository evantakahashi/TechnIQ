"""The app's ten pre-built drills (scripts/prebuilt_drills/drills.json).

Every DSL must parse and pass the validators through the same deterministic pipeline the
drill generator uses, and the generated Swift catalog must match what the script produces
now (drift guard: edit the JSON, rerun scripts/compile_prebuilt_drills.py, commit both).
"""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location(
    "compile_prebuilt_drills", ROOT / "scripts" / "compile_prebuilt_drills.py")
compiler = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(compiler)

DRILLS = compiler.load_drills()


def test_there_are_ten_drills_with_complete_content():
    assert len(DRILLS) == 10
    for d in DRILLS:
        compiler.check_content(d)


@pytest.mark.parametrize("drill", DRILLS, ids=[d["key"] for d in DRILLS])
def test_dsl_compiles_and_validates(drill):
    diagram, animation = compiler.compile_drill(drill)
    assert diagram["elements"]
    assert any(e["type"] == "player" for e in diagram["elements"])
    assert diagram["paths"]
    assert animation["phases"]
    labels = [p["label"] for p in animation["phases"]]
    assert labels == drill["filmLabels"]


def test_generated_swift_is_up_to_date():
    expected = compiler.render_swift(DRILLS)
    actual = compiler.SWIFT_OUT.read_text(encoding="utf-8")
    assert actual == expected, (
        "PrebuiltDrillCatalog+Generated.swift is stale: run "
        "python3 scripts/compile_prebuilt_drills.py")


def test_compile_is_deterministic():
    assert compiler.render_swift(DRILLS) == compiler.render_swift(json.loads(
        compiler.DRILLS_JSON.read_text(encoding="utf-8")))


def test_content_check_rejects_placeholders_and_bad_step_counts():
    good = dict(DRILLS[0])
    with pytest.raises(compiler.ContentError):
        compiler.check_content({**good, "steps": good["steps"][:2]})
    with pytest.raises(compiler.ContentError):
        compiler.check_content({**good, "steps": ["Follow standard ball control protocol"] * 3})
    with pytest.raises(compiler.ContentError):
        compiler.check_content({**good, "cue": ""})
