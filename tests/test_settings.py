import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

import pytest
from pipeline import tracking_config, performance_config
from server.app import create_app
from server.routes import streaming, tracking
from settings_store import SettingsStore


@pytest.fixture
def saved_app(tmp_path, monkeypatch):
    monkeypatch.setattr(performance_config, '_config', performance_config.PerformanceConfig())
    monkeypatch.setattr(tracking, '_tracking_stats', {name: {'enabled': name in ('face_mesh', 'iris')} for name in tracking.FEATURES})
    app = create_app({'TESTING': True, 'SETTINGS_PATH': tmp_path / 'backend.json'})
    yield app
    streaming._active_effects.clear()


def test_api_saves_before_response_and_restores_in_new_process(saved_app):
    from unittest.mock import patch
    client = saved_app.test_client()
    # Model validation itself is tested in test_model_library. Isolate file
    # availability here so CI can verify persistence of custom IDs as well.
    with patch('tracking.models.library.resolve'):
        response = client.post('/api/tracking/configure', json={
            'backend': 'gpu', 'max_width': 960, 'num_faces': 2,
            'detection_confidence': 0, 'presence_confidence': .7, 'tracking_confidence': .8,
            'blendshapes': False, 'face_transform': False,
            'face_model': 'custom_face', 'hand_model': 'custom_hand', 'pose_model': 'pose_landmarker_heavy'})
    assert response.status_code == 200
    expected_tracking = response.json['config']
    assert client.post('/api/tracking/enable', json={'face_mesh': False, 'iris': False, 'hands': True, 'pose': True}).status_code == 200
    assert client.post('/api/performance/config', json={'preview_quality': 62, 'preview_scale': .5, 'preview_max_fps': 24}).status_code == 200
    assert client.post('/api/effects/apply', json={'effect_name': 'GaussianBlurEffect', 'enabled': False}).status_code == 200
    store = saved_app.extensions['settings_store']
    document = json.loads(store.path.read_text())['settings']
    assert document['tracking'] == expected_tracking
    assert document['effects'][0]['enabled'] is False
    code = '''
import json, sys
sys.path.insert(0, sys.argv[2])
from unittest.mock import patch
from server.app import create_app
from server.routes import effects
with patch('tracking.models.library.resolve'):
    app = create_app({'TESTING': True, 'SETTINGS_PATH': sys.argv[1]})
client = app.test_client()
print('RESTORED=' + json.dumps({'tracking': client.get('/api/tracking/configure').json['config'],
    'features': client.get('/api/tracking/status').json['features'],
    'performance': client.get('/api/performance/config').json['config'],
    'effects': effects.describe_chain(), 'camera': client.get('/api/status').json['camera_active']}))
'''
    result = subprocess.run([sys.executable, '-c', code, str(store.path), str(Path(__file__).resolve().parents[1] / 'backend')],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    restored = json.loads(next(line.removeprefix('RESTORED=') for line in result.stdout.splitlines() if line.startswith('RESTORED=')))
    assert restored['tracking'] == expected_tracking
    assert restored['features'] == dict(face=False, iris=False, hands=True, pose=True)
    assert restored['performance'] == dict(mediapipe_max_width=960, preview_max_fps=24, preview_quality=62, preview_scale=.5)
    assert restored['effects'] == document['effects']
    assert restored['camera'] is False


def test_failed_save_preserves_file_and_runtime(saved_app, monkeypatch):
    client = saved_app.test_client()
    assert client.post('/api/tracking/configure', json={'backend': 'cpu'}).status_code == 200
    path = saved_app.extensions['settings_store'].path
    before = path.read_bytes()
    previous_config = tracking_config.get_tracking_config()
    def fail(*_args):
        raise OSError('disk full')
    monkeypatch.setattr(os, 'replace', fail)
    response = client.post('/api/tracking/configure', json={'backend': 'gpu'})
    assert response.status_code == 500 and 'disk full' in response.json['error']['message']
    assert path.read_bytes() == before
    assert tracking_config.get_tracking_config() == previous_config
    previous_performance = performance_config.get_performance_config()
    response = client.post('/api/performance/config', json={'mediapipe_max_width': 320, 'preview_quality': 50})
    assert response.status_code == 500
    assert performance_config.get_performance_config() == previous_performance
    assert tracking_config.get_tracking_config() == previous_config
    assert not list(path.parent.glob('*.tmp'))
    response = client.post('/api/effects/apply', json={'effect_name': 'GaussianBlurEffect'})
    assert response.status_code == 500
    assert not streaming._active_effects
    assert path.read_bytes() == before


def test_reset_is_saved_and_invalid_edits_do_not_change_disk(saved_app):
    client = saved_app.test_client()
    client.post('/api/tracking/configure', json={'backend': 'gpu'})
    response = client.post('/api/tracking/reset', json={})
    path = saved_app.extensions['settings_store'].path
    before = path.read_bytes()
    assert json.loads(before)['settings']['tracking'] == response.json['config']
    assert client.post('/api/tracking/configure', json={'detection_confidence': -1}).status_code == 400
    assert path.read_bytes() == before


def test_store_recovers_corruption_and_merges_concurrent_sections(tmp_path):
    path = tmp_path / 'backend.json'
    path.write_text('{broken', encoding='utf-8')
    store = SettingsStore(path)
    assert not store.data
    assert path.with_suffix('.invalid.json').read_text() == '{broken'
    with ThreadPoolExecutor() as pool:
        list(pool.map(lambda i: store.save(str(i), {'value': i}), range(10)))
    assert len(SettingsStore(path).data) == 10


def test_missing_model_does_not_discard_other_saved_settings(saved_app, monkeypatch):
    store = saved_app.extensions['settings_store']
    store.save('tracking', {'backend': 'cpu', 'pose_model': 'missing_custom', 'detection_confidence': .25})
    monkeypatch.setattr('tracking.models.library.resolve', lambda *_: (_ for _ in ()).throw(ValueError('Model missing')))
    app = create_app({'TESTING': True, 'SETTINGS_PATH': store.path})
    config = app.test_client().get('/api/tracking/configure').json['config']
    assert config['backend'] == 'cpu' and config['detection_confidence'] == .25
    assert app.extensions['settings_store'].data['tracking']['pose_model'] == 'missing_custom'


def test_test_apps_do_not_create_user_settings(monkeypatch, tmp_path):
    monkeypatch.setenv('LENZFORGE_SETTINGS_DIR', str(tmp_path))
    create_app({'TESTING': True}).test_client().post('/api/tracking/configure', json={'backend': 'gpu'})
    assert not list(tmp_path.iterdir())


def test_rejected_effect_request_does_not_touch_preferences(saved_app):
    response = saved_app.test_client().post('/api/effects/clear', json={}, headers={'Origin': 'https://untrusted.example'})
    assert response.status_code == 403
    assert not saved_app.extensions['settings_store'].path.exists()


def test_disk_write_does_not_block_inference_settings_reads(saved_app, monkeypatch):
    started, release = threading.Event(), threading.Event()
    def slow_save(_changes):
        started.set()
        assert release.wait(3)
    monkeypatch.setattr(tracking_config, 'save_sections', slow_save)
    with ThreadPoolExecutor(max_workers=2) as pool:
        writer = pool.submit(tracking_config.update_tracking_config, {'backend': 'gpu'})
        assert started.wait(2)
        try:
            reader = pool.submit(tracking_config.get_tracking_config)
            assert reader.result(timeout=.5)[0].backend == 'cpu'
        finally:
            release.set()
        assert writer.result(timeout=2)[0].backend == 'gpu'
