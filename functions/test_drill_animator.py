"""Authored animation: referee accepts good cuts, rejects bad, falls back."""
import json, glob
from drill_animator import author_timeline, _fidelity, BALL


def _drill():
    for f in glob.glob('/private/tmp/claude-501/-Users-evantakahashi-TechnIQ/'
                       'b08d8283-5ffa-4cc9-a162-1b68b76fde40/scratchpad/goldenset_v3/*.json'):
        d = json.load(open(f))
        if d['_case']['id'] == 'passing-pair':
            return d
    raise AssertionError


def test_garbage_reply_falls_back_to_compiled():
    d = _drill()
    calls = []
    def llm(p):
        calls.append(p)
        return "sorry, here's a poem"
    tl = author_timeline(d, llm)
    assert tl['phases'] and not tl.get('authored')  # fallback cut


def test_fidelity_rejects_a_film_that_skips_steps():
    d = _drill()
    # a "film" where nothing moves anywhere near the drill's targets
    fake = {"phases": [{"d": 800, "tracks": {BALL: [[0, 0], [1, 1]]},
                        "hips": {}, "label": "x", "ease": "lin",
                        "kind": "action", "step": 1}]}
    assert _fidelity(d, fake), "must flag unvisited step targets"


def test_valid_authored_cut_is_used():
    d = _drill()
    # cheat: serve the compiled cut as the "authored" reply — passes referee
    from drill_timeline import compile_timeline
    good = json.dumps(compile_timeline(d))
    tl = author_timeline(d, lambda p: good)
    assert tl.get('authored') is True
