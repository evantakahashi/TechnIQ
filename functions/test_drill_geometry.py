"""Reject impossible geometry before it reaches the timeline compiler."""
import json
from pathlib import Path

import pytest

from drill_validator import ValidationError, validate_drill


def _pass_drill():
    return {'diagram': {'field': {'width': 20, 'length': 10}, 'elements': [
        {'type': 'player', 'label': 'P1', 'role': 'worker', 'x': 0, 'y': 0},
        {'type': 'player', 'label': 'P2', 'role': 'server', 'x': 4, 'y': 0},
        {'type': 'ball', 'label': 'B1', 'x': 0, 'y': 0}], 'paths': [
        {'from': 'P1', 'to': 'P2', 'style': 'pass', 'step': 1,
         'fx': 0, 'fy': 0, 'tx': 4, 'ty': 0}]},
        'equipment': ['ball', 'partner'], 'coaching_points': []}


@pytest.mark.parametrize('bad', [float('nan'), float('inf'), -float('inf'), True, '4'])
def test_nonfinite_or_nonnumeric_element_coordinates_rejected(bad):
    drill = _pass_drill()
    drill['diagram']['elements'][0]['x'] = bad
    with pytest.raises(ValidationError, match='finite numeric coordinates'):
        validate_drill(drill)


@pytest.mark.parametrize('change', ['missing', 'nonfinite'])
def test_baked_paths_need_all_four_finite_coordinates(change):
    drill = _pass_drill()
    if change == 'missing':
        del drill['diagram']['paths'][0]['ty']
    else:
        drill['diagram']['paths'][0]['ty'] = float('nan')
    with pytest.raises(ValidationError, match='four finite path coordinates'):
        validate_drill(drill)


@pytest.mark.parametrize('label', ['P1', '__ball__', ''])
def test_ambiguous_element_identity_rejected(label):
    drill = _pass_drill()
    drill['diagram']['elements'][1]['label'] = label
    with pytest.raises(ValidationError, match='duplicate element label|reserved'):
        validate_drill(drill)


@pytest.mark.parametrize('where', ['field', 'element'])
def test_nonpositive_geometry_dimensions_rejected(where):
    drill = _pass_drill()
    target = drill['diagram']['field'] if where == 'field' else drill['diagram']['elements'][0]
    target['width'] = 0
    with pytest.raises(ValidationError, match='positive and finite'):
        validate_drill(drill)


def test_a_partner_does_not_make_a_cone_a_receiver():
    drill = _pass_drill()
    drill['diagram']['elements'].append({'type': 'cone', 'label': 'C1', 'x': 8, 'y': 5})
    drill['diagram']['paths'][0].update(to='C1', tx=8, ty=5)
    with pytest.raises(ValidationError, match='nobody is there'):
        validate_drill(drill)


def test_cone_cannot_act_even_without_a_declared_ball():
    drill = _pass_drill()
    drill['diagram']['elements'] = drill['diagram']['elements'][:2]
    drill['diagram']['elements'].append({'type': 'cone', 'label': 'C1', 'x': 8, 'y': 5})
    drill['diagram']['paths'][0].update({'from': 'C1', 'style': 'dribble', 'fx': 8, 'fy': 5})
    with pytest.raises(ValidationError, match='only a player'):
        validate_drill(drill)


def test_two_simultaneous_kicks_cannot_share_one_ball():
    drill = _pass_drill()
    drill['diagram']['paths'].append(
        {'from': 'P2', 'to': 'P1', 'style': 'pass', 'step': 2, 'sync': True,
         'fx': 4, 'fy': 0, 'tx': 0, 'ty': 0})
    with pytest.raises(ValidationError, match='same ball twice'):
        validate_drill(drill)


def test_player_cannot_run_to_two_spots_in_one_beat():
    drill = _pass_drill()
    drill['diagram']['elements'] += [
        {'type': 'cone', 'label': 'C1', 'x': 4, 'y': 3},
        {'type': 'cone', 'label': 'C2', 'x': 8, 'y': 3}]
    drill['diagram']['paths'] = [
        {'from': 'P2', 'to': 'C1', 'style': 'run', 'step': 1},
        {'from': 'P2', 'to': 'C2', 'style': 'run', 'step': 2, 'sync': True}]
    with pytest.raises(ValidationError, match='two places simultaneously'):
        validate_drill(drill)


def test_first_step_cannot_be_synchronized_with_nothing():
    drill = _pass_drill()
    drill['diagram']['paths'][0]['sync'] = True
    with pytest.raises(ValidationError, match='sync needs a preceding action'):
        validate_drill(drill)


def test_toss_distance_uses_live_coordinates_not_spawn_markers():
    drill = _pass_drill()
    drill['diagram']['paths'][0].update(style='toss', tx=12)
    with pytest.raises(ValidationError, match='toss travels 12.0m'):
        validate_drill(drill)


def test_player_can_move_closer_before_a_short_toss():
    drill = _pass_drill()
    drill['diagram']['elements'][1]['x'] = 12
    drill['diagram']['elements'].append({'type': 'cone', 'label': 'C1', 'x': 4, 'y': 2})
    drill['diagram']['paths'][0].update(style='toss', step=2)
    drill['diagram']['paths'].insert(0,
        {'from': 'P2', 'to': 'C1', 'style': 'run', 'step': 1,
         'fx': 12, 'fy': 0, 'tx': 4, 'ty': 0})
    validate_drill(drill)


@pytest.mark.parametrize('server_x,valid', [(0, False), (8, True)])
def test_supporting_run_does_not_hide_first_time_strike_geometry(server_x, valid):
    drill = _pass_drill()
    drill['diagram']['elements'][0]['x'] = server_x
    drill['diagram']['elements'][2]['x'] = server_x
    drill['diagram']['elements'] += [
        {'type': 'player', 'label': 'P3', 'role': 'server', 'x': 0, 'y': 5},
        {'type': 'cone', 'label': 'C1', 'x': 2, 'y': 6},
        {'type': 'gate', 'label': 'G1', 'x': 10, 'y': 0, 'width': 2}]
    drill['diagram']['paths'][0].update(style='toss', fx=server_x)
    drill['diagram']['paths'] += [
        {'from': 'P3', 'to': 'C1', 'style': 'run', 'step': 2, 'sync': True,
         'fx': 0, 'fy': 5, 'tx': 2, 'ty': 5},
        {'from': 'P2', 'to': 'G1', 'style': 'header', 'step': 3,
         'fx': 4, 'fy': 0, 'tx': 10, 'ty': 0}]
    if valid:
        validate_drill(drill)
    else:
        with pytest.raises(ValidationError, match='first-time strike is unrealistic'):
            validate_drill(drill)


@pytest.mark.parametrize('fixture', sorted(Path('eval/golden/drills').glob('*.json')),
                         ids=lambda p: p.stem)
def test_golden_geometry_remains_valid(fixture):
    validate_drill(json.loads(fixture.read_text()))
