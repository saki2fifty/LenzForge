import importlib.util
import math
from pathlib import Path
import pytest

spec = importlib.util.spec_from_file_location('blender_beard', Path(__file__).resolve().parents[1] / 'tools/blender_beard.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


def test_curve_round_trip_preserves_shape_and_units():
    points = [(2, 3, 0), (2.1, 2.8, 0), (2.0, 2.6, 0)]
    edit = bridge.curve_override(points, .4, 3, .2)
    assert edit['length'] == pytest.approx(math.sqrt(.05)*2/.4)
    reconstructed = [(x*.4*edit['length']+2, 3-y*.4*edit['length']) for x, y in edit['guide']]
    for actual, expected in zip(reconstructed, points):
        assert actual == pytest.approx(expected[:2])
    assert edit['root_width'] == 3 and edit['tip_width'] == .2


def test_spatial_curve_round_trip_retains_depth_and_replaces_old_guide():
    points = [(2, 3, 4), (2.1, 2.8, 4.2), (2.0, 2.6, 4.3)]
    edit = bridge.curve_override(points, .4, 3, .2)
    assert 'guide3d' in edit and 'guide' not in edit
    length = .4 * edit['length']
    for actual, expected in zip(edit['guide3d'], points):
        assert (2+actual[0]*length, 3-actual[1]*length, 4-actual[2]*length) == pytest.approx(expected)
    original = {'format': 'lenzforge-beard', 'version': 2,
                'geometry': {'guides': [{'index': i, 'base_length': .4} for i in range(16)]},
                'strands': {'0': {'guide': [[0, 0], [0, 1]]}}}
    curves = [{'points': points, 'root_width': 3, 'tip_width': .2} for _ in range(16)]
    spatial = bridge.edited_document(original, curves)
    assert 'guide3d' in spatial['strands']['0'] and 'guide' not in spatial['strands']['0']
    spatial['geometry'] = original['geometry']
    for curve in curves:
        curve['points'] = [(0, 0, 0), (0, -.2, 0)]
    planar = bridge.edited_document(spatial, curves)
    assert 'guide' in planar['strands']['0'] and 'guide3d' not in planar['strands']['0']


@pytest.mark.parametrize('points', [[(0, 0, 0)], [(0, 0, 0), (float('nan'), 1, 0)], [(0, 0, 0), (10, 10, 0)]])
def test_invalid_or_unbounded_curves_are_rejected(points):
    with pytest.raises(ValueError):
        bridge.curve_override(points, .4, 3, .2)


def test_hidden_strands_and_other_edits_are_preserved():
    original = {'format': 'lenzforge-beard', 'version': 1,
                'geometry': {'guides': [{'index': i, 'base_length': .4} for i in range(16)]},
                'strands': {'0': {'root_color': 'ffffffff', 'guide': [[0, 0], [0, 1]]}}}
    curves = [{'points': [(0, 0, 0), (0, 0, 0)], 'root_width': 3, 'tip_width': .2} for _ in range(16)]
    result = bridge.edited_document(original, curves)
    assert result['strands']['0']['length'] == 0
    assert result['strands']['0']['root_color'] == 'ffffffff'
    assert 'guide' not in result['strands']['0']
    assert 'geometry' not in result and 'geometry' in original


def test_v2_combined_groom_preserves_region_ids_and_motion():
    ids = [str(i) for i in range(16)] + ['brow:0', 'hair:0']
    original = {'format': 'lenzforge-beard', 'version': 2,
                'settings': {'mustache_motion': 'Static', 'hair_motion': 'Styled', 'chin_extension': .15},
                'geometry': {'guides': [{'index': i, 'base_length': .4} for i in ids]},
                'strands': {'hair:0': {'root_color': 'ffffffff'}}}
    curves = [{'points': [(0, 0, 0), (.02, -.3, 0)], 'root_width': 3, 'tip_width': .2} for _ in ids]
    result = bridge.edited_document(original, curves)
    assert set(result['strands']) == set(ids)
    assert result['strands']['hair:0']['root_color'] == 'ffffffff'
    assert 'guide' in result['strands']['brow:0']
    assert result['settings'] == original['settings']
    assert result['version'] == 2
