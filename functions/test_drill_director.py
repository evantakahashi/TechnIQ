"""Director merges are whitelist-only; bad edits can't break continuity."""
from drill_director import direct_timeline


def _tl():
    return {"phases": [
        {"d": 500, "tracks": {"__ball__": [[3, 7], [10, 7]], "P1": [[3, 7], [3, 7]]},
         "hips": {}, "label": "a", "ease": "lin", "kind": "action", "step": 1},
        {"d": 500, "tracks": {"__ball__": [[10, 7], [15, 7]]},
         "hips": {}, "label": "b", "ease": "lin", "kind": "action", "step": 2},
    ]}


def _drill():
    return {"name": "t", "_case": {"request": {"skill_description": "s"}},
            "coaching_points": [], "diagram": {"elements": []}}


def test_edits_apply_within_rails():
    out = direct_timeline(_drill(), _tl(),
        lambda p: '[{"i":0,"d":9999,"label":"Feel the defender lean"},{"i":1,"label":"Strike low 5 times"}]')
    assert out["phases"][0]["d"] == 2600          # clamped
    assert out["phases"][0]["label"] == "Feel the defender lean"
    assert out["phases"][1]["label"] == "b"       # digits rejected


def test_inserted_beat_is_still_and_capped():
    out = direct_timeline(_drill(), _tl(),
        lambda p: '[{"insert_after":0,"d":5000,"label":"Breathe"}]')
    assert len(out["phases"]) == 3
    beat = out["phases"][1]
    assert beat["d"] == 800
    for tr in beat["tracks"].values():
        assert tr[0] == tr[1]                     # still by construction


def test_garbage_reply_keeps_compiled_cut():
    tl = _tl()
    assert direct_timeline(_drill(), tl, lambda p: "sorry!") is tl
