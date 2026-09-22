"""Compiler tests: steps -> phase timeline."""
import json, glob
from drill_timeline import compile_timeline, BALL, _dur


def test_short_control_has_time_to_settle():
    assert _dur('receive', 1.0) >= 520
    assert _dur('throw', 1.0) > _dur('pass', 1.0)


def _first(drill_id):
    for f in glob.glob('eval/golden/drills/*.json'):
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
    # per-leg resets: short runs of fade legs are expected, long chains are not
    run = mx = 0
    for k in kinds:
        run = run + 1 if k == 'fade' else 0
        mx = max(mx, run)
    assert mx <= 3


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


def test_no_dead_action_phases():
    for cid in ('shoot-turn', 'crossing-finish', 'passing-pair'):
        tl = compile_timeline(_first(cid))
        for p in tl['phases']:
            if p['kind'] != 'action':
                continue
            import math
            mx = max(math.hypot(t[1][0]-t[0][0], t[1][1]-t[0][1])
                     for t in p['tracks'].values())
            assert mx > 0.3 or p.get('eye'), f"dead phase in {cid}: {p['label']}"


def test_serve_scan_preserved_but_one_touch_return_not_paused():
    d = _first('passing-pair')
    phases = compile_timeline(d)['phases']
    feeds = [i for i, p in enumerate(phases) if p.get('step') in (2, 3)
             and BALL in p['tracks'] and p['tracks'][BALL][0] != p['tracks'][BALL][1]]
    assert len(feeds) == 2
    assert phases[feeds[0] - 1].get('eye')
    assert phases[feeds[0] - 1]['d'] >= 400
    assert feeds[1] == feeds[0] + 1, 'one-touch return must follow the feed immediately'


def test_controlled_shot_keeps_plant_beat_but_first_time_finish_does_not():
    phases = compile_timeline(_first('weakfoot-finish'))['phases']
    shot = next(i for i, p in enumerate(phases)
                if p.get('step') == 3 and BALL in p['tracks']
                and p['tracks'][BALL][0] != p['tracks'][BALL][1])
    assert phases[shot - 1]['eye']
    assert phases[shot - 1]['d'] == 300
    assert phases[shot - 1]['tracks'][BALL][0] == phases[shot - 1]['tracks'][BALL][1]
    phases = compile_timeline(_first('crossing-finish'))['phases']
    shot = next(i for i, p in enumerate(phases) if p.get('step') == 3)
    assert phases[shot - 1]['tracks'][BALL][0] != phases[shot - 1]['tracks'][BALL][1]


def test_direct_throw_is_caught_at_receiver_not_redirected_with_foot():
    d = _first('gk-wall')
    server = next(e for e in d['diagram']['elements'] if e['label'] == 'S1')
    catch = next(p for p in compile_timeline(d)['phases'] if p.get('step') == 4)
    assert catch['tracks'][BALL][1] == [server['x'], server['y']]


def test_self_toss_does_not_scan_for_itself_as_a_partner():
    phases = compile_timeline(_first('first-touch-solo'))['phases']
    assert phases[0]['kind'] == 'tossup'
    assert not any(p.get('eye') and p.get('step') == 1 for p in phases)


def test_short_visible_touch_and_reset_close_loop_exactly():
    d = {'diagram': {'elements': [
        {'type': 'player', 'label': 'P1', 'x': 0, 'y': 0},
        {'type': 'ball', 'label': 'B1', 'x': 0, 'y': 0},
        {'type': 'gate', 'label': 'G1', 'x': 0.2, 'y': 0}],
        'paths': [{'from': 'P1', 'to': 'G1', 'style': 'dribble', 'step': 1,
                   'fx': 0, 'fy': 0, 'tx': 0.2, 'ty': 0}]}}
    phases = compile_timeline(d)['phases']
    assert phases[0]['tracks'][BALL] == [[0, 0], [0.2, 0]]
    last = {}
    for phase in phases:
        for actor, track in phase['tracks'].items():
            if actor in last:
                assert track[0] == last[actor]
            last[actor] = track[1]
    assert last == {'P1': [0, 0], BALL: [0, 0]}


def test_three_simultaneous_actors_share_one_phase():
    d = _first('2v-pressing')
    d['diagram']['elements'].append({'type': 'player', 'label': 'P4', 'x': 26, 'y': 3})
    d['diagram']['paths'].append(
        {'from': 'P4', 'to': 'P3', 'style': 'run', 'step': 3, 'sync': True,
         'fx': 26, 'fy': 3, 'tx': 26, 'ty': 5})
    phases = compile_timeline(d)['phases']
    actions = [p for p in phases if p['kind'] == 'action']
    assert len(actions) == 1
    assert {'P2', 'P3', 'P4', BALL} <= actions[0]['tracks'].keys()
    assert actions[0]['steps'] == [1, 2, 3]


def test_receiver_faces_feed_when_sync_run_is_listed_after_pass():
    from eval.anim_lint import lint
    d = _first('passing-pair')
    run, feed = d['diagram']['paths'][3:5]
    run.update(step=5, sync=True)
    feed.update(step=4, sync=False)
    d['animation'] = compile_timeline(d)
    phase = next(p for p in d['animation']['phases'] if p.get('steps') == [4, 5])
    assert phase['tracks']['P2'][0] != phase['tracks']['P2'][1]
    assert phase['hips']['P2'][0] < -0.9, 'receiver looks toward the server while shuffling'
    assert not any(f.startswith('FACE ') for f in lint(d))


def test_sync_shot_moves_ball_while_supporter_runs():
    d = {'diagram': {'elements': [
        {'type': 'player', 'label': 'P1', 'x': 0, 'y': 0},
        {'type': 'player', 'label': 'P2', 'x': 0, 'y': 5},
        {'type': 'ball', 'label': 'B1', 'x': 0, 'y': 0},
        {'type': 'gate', 'label': 'G1', 'x': 10, 'y': 0}], 'paths': [
        {'from': 'P2', 'to': 'G1', 'style': 'run', 'step': 1,
         'fx': 0, 'fy': 5, 'tx': 3, 'ty': 5},
        {'from': 'P1', 'to': 'G1', 'style': 'shoot', 'step': 2, 'sync': True,
         'fx': 0, 'fy': 0, 'tx': 10, 'ty': 0}]}}
    phase = compile_timeline(d)['phases'][0]
    assert phase['tracks'][BALL] == [[0, 0], [10, 0]]
    assert phase['tracks']['P2'] == [[0, 5], [3, 5]]
    assert 'P1' not in phase['tracks'], 'striker does not run into the target'


def test_secondary_dribbler_updates_live_ball_state_for_reset():
    d = _first('2v-pressing')
    dribble, run = d['diagram']['paths'][:2]
    dribble.update(step=2, sync=True)
    run.update(step=1, sync=False)
    d['diagram']['paths'] = [run, dribble]
    phases = compile_timeline(d)['phases']
    ball_tracks = [p['tracks'][BALL] for p in phases if BALL in p['tracks']]
    assert ball_tracks[-1][1] == ball_tracks[0][0]
    assert all(a[1] == b[0] for a, b in zip(ball_tracks, ball_tracks[1:]))


def test_short_handover_is_shown_instead_of_silently_moving_ball():
    d = _first('first-touch')
    d['diagram']['paths'][2]['tx'] = 3.2
    phases = compile_timeline(d)['phases']
    handover = next(p for p in phases if p.get('step') == 4)
    assert handover['tracks'][BALL] == [[3.2, 7], [3, 7]]
    assert handover['tracks']['P2'] == handover['tracks'][BALL]


def test_receiving_touch_does_not_aim_at_a_later_reset():
    d = {'diagram': {'elements': [
        {'type': 'player', 'label': 'P1', 'x': 0, 'y': 0},
        {'type': 'player', 'label': 'P2', 'x': 4, 'y': 0},
        {'type': 'ball', 'label': 'B1', 'x': 0, 'y': 0}], 'paths': [
        {'from': 'P1', 'to': 'P2', 'style': 'pass', 'step': 1,
         'fx': 0, 'fy': 0, 'tx': 4, 'ty': 0},
        {'from': 'P2', 'to': 'P1', 'style': 'receive', 'step': 2,
         'fx': 4, 'fy': 0, 'tx': 0, 'ty': 0},
        {'from': 'P2', 'to': 'P1', 'style': 'dribble', 'step': 3, 'reset': True,
         'fx': 4, 'fy': 0, 'tx': 0, 'ty': 0}]}}
    touch = next(p for p in compile_timeline(d)['phases'] if p.get('step') == 2)
    assert touch['tracks'][BALL][1][0] > 4, 'touch continues into space, not back toward the reset'


def test_ball_continuity_across_phases():
    """The ball never teleports between consecutive non-fade phases."""
    import math
    for cid in ('shoot-turn', 'passing-pair', 'gk-wall'):
        tl = compile_timeline(_first(cid))
        last = None
        for p in tl['phases']:
            if p['kind'] == 'outcome':
                break
            tr = p['tracks'].get(BALL)
            if tr is None:
                continue
            if last is not None and p['kind'] == 'action':
                jump = math.hypot(tr[0][0]-last[0], tr[0][1]-last[1])
                assert jump < 0.2, f"{cid}: ball jumps {jump:.1f}m into '{p['label']}'"
            last = tr[1]


def test_ball_never_glides_home_alone():
    """In every fade leg that moves the ball, a player travels WITH it."""
    import math
    for f in glob.glob('eval/golden/drills/*.json'):
        d = json.load(open(f))
        tl = compile_timeline(d)
        for p in tl['phases']:
            if p['kind'] != 'fade' or BALL not in p['tracks']:
                continue
            bt = p['tracks'][BALL]
            if math.hypot(bt[1][0]-bt[0][0], bt[1][1]-bt[0][1]) < 1.0:
                continue
            carried = any(
                lbl != BALL
                and math.hypot(tr[0][0]-bt[0][0], tr[0][1]-bt[0][1]) < 1.8
                and math.hypot(tr[1][0]-bt[1][0], tr[1][1]-bt[1][1]) < 1.8
                for lbl, tr in p['tracks'].items())
            assert carried, f"{d['_case']['id']}: ball glides alone in '{p['label']}'"


def test_zero_lint_findings_on_golden_set():
    """The recursive audit's floor: compiled timelines lint clean."""
    import sys
    sys.path.insert(0, '.')
    from eval.anim_lint import lint
    total = []
    for f in glob.glob('eval/golden/drills/*.json'):
        d = json.load(open(f))
        d['animation'] = compile_timeline(d)
        total += lint(d)
    assert total == [], total
