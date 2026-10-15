import pytest
from server.app import create_app
from server.routes import streaming
from server.routes.camera import close_camera


@pytest.fixture
def client():
    app = create_app({'TESTING': True})
    with app.test_client() as client:
        yield client
    close_camera()
    streaming._active_effects.clear()


def test_health_and_studio(client):
    assert client.get('/health').json['version'] == '3.0.0'
    page = client.get('/')
    assert page.status_code == 200 and b'REAL-TIME AR STUDIO' in page.data
    assert client.get('/api/effects/list').json['total_effects'] == 47


def test_effect_chain_clear_keeps_shared_list(client):
    assert client.post('/api/effects/apply', json={'effect_name': 'GaussianBlurEffect'}).status_code == 200
    assert len(streaming._active_effects) == 1
    assert client.post('/api/effects/clear', json={}).status_code == 200
    assert streaming._active_effects == []


def test_cross_origin_control_and_untrusted_host_are_rejected(client):
    assert client.post('/api/camera/stop', json={}, headers={'Origin': 'https://untrusted.example'}).status_code == 403
    assert client.get('/health', headers={'Host': 'untrusted.example'}).status_code == 400


def test_camera_request_validation(client):
    assert client.post('/api/camera/select', json={'camera_index': -1, 'resolution': [65, 64]}).status_code == 400
    assert client.post('/api/export/recording/start', json={}).status_code == 409


def test_current_landmarks_come_from_worker(client, monkeypatch):
    class Worker:
        def get_snapshot(self):
            return {'frame_id': 42, 'timestamp': 12345, 'landmarks': {'face': [{'x': .5, 'y': .4, 'z': 0}]}}
    monkeypatch.setattr(streaming, '_processor', Worker())
    assert client.get('/api/tracking/landmarks').json['frame_id'] == 42


def test_invalid_tracking_and_partial_performance_updates_do_not_change_state(client):
    tracking = client.get('/api/tracking/status').json
    assert client.post('/api/tracking/enable', json={'hands': 'false'}).status_code == 400
    assert client.get('/api/tracking/status').json == tracking
    before = client.get('/api/performance/config').json
    assert client.post('/api/performance/config', json={'preview_quality': 50, 'preview_scale': 5}).status_code == 400
    assert client.get('/api/performance/config').json == before
    assert client.post('/api/tracking/configure', json={'pose': {}}).status_code == 501
