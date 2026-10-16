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
    assert client.post('/api/tracking/configure', json={'pose': {}}).status_code == 400


def test_discovery_keeps_all_devices_while_capture_is_running(client, monkeypatch):
    from capture import enumerator
    from capture.enumerator import CameraInfo
    import cv2
    devices = [CameraInfo(0, 'Virtual camera', 'virtual'), CameraInfo(1, 'USB webcam', 'usb')]
    monkeypatch.setattr(enumerator, 'enumerate_cameras', lambda: devices)
    monkeypatch.setattr(cv2, 'VideoCapture', lambda *args: pytest.fail('Discovery must not open a camera'))
    assert client.post('/api/camera/select', json={'camera_index': -1, 'resolution': [64, 64]}).status_code == 200
    first = client.get('/api/camera/list').json['cameras']
    assert [(c['index'], c['name']) for c in first] == [(0, 'Virtual camera'), (1, 'USB webcam'), (-1, 'Demo pattern (no camera)')]
    assert client.get('/api/status').json['camera_active']
    devices.pop(0)
    assert len(client.get('/api/camera/list').json['cameras']) == 2


def test_discovery_failure_is_actionable(client, monkeypatch):
    from capture import enumerator
    def fail():
        raise RuntimeError('Windows camera discovery timed out')
    monkeypatch.setattr(enumerator, 'enumerate_cameras', fail)
    response = client.get('/api/camera/list')
    assert response.status_code == 503
    assert 'timed out' in response.json['error']['message']


@pytest.mark.parametrize('index', [1, 1.0])
def test_camera_selection_follows_device_identity_after_indices_change(client, monkeypatch, index):
    from capture import enumerator
    from capture.camera import Camera
    from server.routes import camera as routes
    monkeypatch.setattr(enumerator, 'enumerate_cameras', lambda: [enumerator.CameraInfo(2, 'USB webcam', 'stable-id')])
    monkeypatch.setattr(Camera, 'open', lambda self: True)
    monkeypatch.setattr(streaming, 'set_camera_source', lambda camera: None)
    response = client.post('/api/camera/select', json={'camera_index': index, 'device_id': 'stable-id'})
    assert response.status_code == 200
    assert response.json['camera']['index'] == 2
    assert response.json['camera']['name'] == 'USB webcam'
    previous = routes._current_camera
    response = client.post('/api/camera/select', json={'camera_index': 1, 'device_id': 'unplugged'})
    assert response.status_code == 400
    assert routes._current_camera is previous


def test_integral_json_number_starts_demo(client):
    response = client.post('/api/camera/select', json={'camera_index': -1.0, 'resolution': [64, 64]})
    assert response.status_code == 200
    assert response.json['camera']['index'] == -1
    assert type(response.json['camera']['index']) is int
    assert client.get('/api/status').json['camera_active']


@pytest.mark.parametrize('index', [True, False, 0.5, -1.5, '1', None, [], {}, float('nan'), float('inf')])
def test_invalid_camera_ids_are_not_coerced(client, index):
    response = client.post('/api/camera/select', json={'camera_index': index})
    assert response.status_code == 400
    assert 'whole number' in response.json['error']['message']
    assert not client.get('/api/status').json['camera_active']


def test_failed_capture_retains_error_and_can_be_stopped(client, monkeypatch):
    from capture.camera import Camera
    def fail(camera):
        camera.error = 'Camera returned no frames'
        return False
    monkeypatch.setattr(Camera, 'open', fail)
    response = client.post('/api/camera/select', json={'camera_index': -1})
    assert response.status_code == 503
    status = client.get('/api/status').json
    assert not status['camera_active']
    assert status['error'] == 'Camera returned no frames'
    assert client.post('/api/camera/stop', json={}).status_code == 200
    assert client.get('/api/status').json['error'] is None
