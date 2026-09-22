"""Viewer-visible mistakes that continuity alone cannot catch."""
import copy
import json
from pathlib import Path

import pytest

from eval.anim_lint import lint


def _film(phases, players=((0, 0), (5, 0))):
    return {'diagram': {'elements': [
        {'type': 'player', 'label': f'P{i + 1}', 'x': xy[0], 'y': xy[1]}
        for i, xy in enumerate(players)]}, 'animation': {'phases': phases}}


def _phase(tracks, label='Play', kind='action'):
    return {'kind': kind, 'd': 1000, 'label': label, 'tracks': tracks}


def test_feed_receiver_facing_away_is_flagged():
    with open('eval/golden/drills/passing-pair.json') as fh:
        drill = json.load(fh)
    drill = copy.deepcopy(drill)
    # The first feed reaches P2. Reverse the authored receiving facing.
    feed = drill['animation']['phases'][1]
    feed['hips']['P2'] = [-v for v in feed['hips']['P2']]
    assert any(f.startswith('FACE ') for f in lint(drill))


def test_moving_receiver_must_face_arriving_feed():
    with open('eval/golden/drills/passing-pair.json') as fh:
        drill = json.load(fh)
    feed = drill['animation']['phases'][4]
    feed['hips']['P2'] = [-v for v in feed['hips']['P2']]
    assert any(f.startswith('FACE ') and 'phase4' in f for f in lint(drill))


def test_unequal_movements_flattened_to_one_duration_are_flagged():
    drill = {'diagram': {'elements': [{'type': 'player', 'label': 'P1',
                                      'x': 0, 'y': 0}]},
             'animation': {'phases': [
                 {'kind': 'action', 'd': 800, 'label': f'Move {i}',
                  'tracks': {'P1': [[i * i, 0], [(i + 1) ** 2, 0]]}}
                 for i in range(4)]}}
    assert any(f.startswith('RHYTHM ') for f in lint(drill))


def test_repeated_equal_distance_actions_can_keep_a_steady_rhythm():
    drill = _film([_phase({'P1': [[i, 0], [i + 1, 0]]}, f'Move {i}')
                   for i in range(4)], players=((0, 0),))
    assert not any(f.startswith('RHYTHM ') for f in lint(drill))


@pytest.mark.parametrize('draw_stationary_track', [False, True])
def test_collisions_include_untracked_players_and_between_sample_times(draw_stationary_track):
    tracks = {'P1': [[0, 0], [10, 0]]}
    if draw_stationary_track:
        tracks['P2'] = [[1, 0], [1, 0]]
    drill = _film([_phase(tracks)], players=((0, 0), (1, 0)))
    assert any(f.startswith('COLLIDE ') for f in lint(drill))


def test_collision_check_allows_a_clear_lane():
    drill = _film([_phase({'P1': [[0, 0], [10, 0]]})],
                  players=((0, 0), (1, 0.8)))
    assert not any(f.startswith('COLLIDE ') for f in lint(drill))


def test_players_cannot_move_as_one_overlapping_body():
    drill = _film([_phase({'P1': [[0, 0], [3, 0]],
                           'P2': [[0, 0.2], [3, 0.2]]})],
                  players=((0, 0), (0, 0.2)))
    assert any(f.startswith('COLLIDE ') for f in lint(drill))


def test_defenders_cannot_run_through_each_other():
    drill = _film([_phase({'P1': [[0, 0], [10, 0]],
                           'P2': [[1, 0], [1, 3]]})],
                  players=((0, 0), (1, 0)))
    for player in drill['diagram']['elements']:
        player['role'] = 'defender'
    assert any(f.startswith('COLLIDE ') for f in lint(drill))


def test_loop_checks_players_absent_from_first_phase():
    drill = _film([_phase({'P1': [[0, 0], [0, 0]]}),
                   _phase({'P2': [[5, 0], [6, 0]]}, 'Move')])
    assert any(f.startswith('LOOP ') and 'P2' in f for f in lint(drill))


def test_loop_checks_small_ball_drift_even_when_ball_appears_later():
    drill = _film([_phase({'P1': [[0, 0], [0, 0]]}),
                   _phase({'__ball__': [[0, 0], [0.04, 0]]}, 'Touch')])
    assert any(f.startswith('LOOP ') and '__ball__' in f for f in lint(drill))


def test_every_rotating_outcome_is_checked():
    drill = _film([_phase({'P1': [[0, 0], [0, 0]]}),
                   _phase({'P1': [[0, 0], [1, 0]]}, 'Left', 'outcome'),
                   _phase({'P1': [[0, 0], [0, 1]]}, 'Right', 'outcome'),
                   _phase({'P1': [[9, 0], [10, 0]]}, 'Third', 'outcome')])
    assert any(f.startswith('CONT-P ') and 'Third' in f for f in lint(drill))


def test_outcomes_without_main_timeline_return_a_finding():
    assert lint(_film([_phase({}, kind='outcome')])) == [
        'NOANIM: outcomes need a main timeline to branch from']


def test_ball_cannot_launch_from_empty_grass():
    drill = _film([_phase({'__ball__': [[5, 0], [8, 0]]})], players=((0, 0),))
    assert any(f.startswith('RELEASE ') for f in lint(drill))


def test_a_wall_can_cause_a_rebound():
    drill = _film([_phase({'__ball__': [[5, 0], [0, 0]]})], players=((0, 0),))
    drill['diagram']['elements'].append({'type': 'wall', 'label': 'W1', 'x': 5, 'y': 0})
    assert not any(f.startswith('RELEASE ') for f in lint(drill))


@pytest.mark.parametrize('fixture', sorted(Path('eval/golden/drills').glob('*.json')),
                         ids=lambda p: p.stem)
def test_authored_goldens_still_lint_clean(fixture):
    assert lint(json.loads(fixture.read_text())) == []
