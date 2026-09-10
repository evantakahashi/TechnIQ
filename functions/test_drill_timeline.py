"""Compiler tests: steps -> phase timeline."""
import json, glob
from drill_timeline import compile_timeline, BALL


def _first(drill_id):
    for f in glob.glob('/private/tmp/claude-501/-Users-evantakahashi-TechnIQ/'
                       'b08d8283-5ffa-4cc9-a162-1b68b76fde40/scratchpad/goldenset_v3/*.json'):
        d = json.load(open(f))
        if d['_case']['id'] == drill_id:
            return d
    raise AssertionError(drill_id)


def test_sync_pair_becomes_one_dual_track_phase():
    d = _first('passing-pair')
    tl = compile_timeline(d)
    dual = [p for p in tl['phases'] if BALL in p['tracks']
            and sum(1 for k in p['tracks'] if k != BALL) >= 1
            and any(p['tracks'][k][0] != p['tracks'][k][1]
                    for k in p['tracks'] if k != BALL)]
    assert dual, "expected at least one phase where a player moves WITH a ball flight"


def test_resets_become_fade_phases():
    d = _first('weakfoot-finish')
    tl = compile_timeline(d)
    kinds = [p['kind'] for p in tl['phases']]
    assert 'fade' in kinds
    # consecutive hidden steps collapse: fades never adjacent
    assert all(not (a == b == 'fade') for a, b in zip(kinds, kinds[1:]))


def test_durations_scale_with_distance():
    d = _first('speed-ball')
    tl = compile_timeline(d)
    action = [p for p in tl['phases'] if p['kind'] == 'action']
    assert len({p['d'] for p in action}) > 1, "distances differ so durations must"


def test_hips_face_incoming_ball_on_feeds():
    d = _first('shoot-turn')
    tl = compile_timeline(d)
    feed = next(p for p in tl['phases']
                if p['kind'] == 'action' and BALL in p['tracks']
                and any(k != BALL and p['hips'].get(k) for k in p['hips']))
    assert feed['hips'], "receiver facing vector expected on the feed"


def test_outcome_phases_for_duels():
    d = _first('defend-1v1')
    tl = compile_timeline(d)
    assert sum(1 for p in tl['phases'] if p['kind'] == 'outcome') == 2
