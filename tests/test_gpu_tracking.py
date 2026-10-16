import json
import struct
import time
from dataclasses import replace

import numpy as np
import pytest

from pipeline.tracking_config import TrackingConfig, update_tracking_config
from tracking.browser_tracker import unpack_result
from tracking import engine as module
from server.app import create_app

FEATURES = dict(face=True, iris=True, hands=False, pose=False)
RGB = np.zeros((64, 64, 3), np.uint8)


@pytest.mark.parametrize('data', [None, {}, {'backend': 'cuda'}, {'num_faces': 1.5},
    {'num_faces': True}, {'max_width': 4096}, {'presence_confidence': float('nan')},
    {'detection_confidence': -1}, {'tracking_confidence': True}, {'blendshapes': 'false'}])
def test_rejects_invalid_live_settings_without_changing_state(data):
    from pipeline.tracking_config import get_tracking_config
    before = get_tracking_config()
    with pytest.raises(ValueError):
        update_tracking_config(data)
    assert get_tracking_config() == before


def test_runtime_api_preserves_zero_and_retries_by_revision():
    with create_app({'TESTING': True}).test_client() as client:
        response = client.post('/api/tracking/configure', json={'backend': 'gpu', 'detection_confidence': 0})
        assert response.status_code == 200
        assert response.json['config']['detection_confidence'] == 0
        revision = response.json['revision']
        assert client.post('/api/tracking/configure', json={'backend': 'gpu'}).json['revision'] > revision
        assert client.get('/api/status').json['tracking']['settings']['backend'] == 'gpu'
        reset = client.post('/api/tracking/reset', json={}).json
        assert reset['config'] == TrackingConfig().to_dict()


def test_binary_result_checks_identity_and_unpacks_all_outputs():
    meta = json.dumps({'face_counts': [478], 'hand_sides': ['left'], 'pose_count': 33,
                       'blendshapes': {'jawOpen': .2}, 'face_transform': [[1]*4]*4}).encode()
    meta += b' ' * (-len(meta) % 4)
    points = np.full(478 * 3 + 21 * 3 + 33 * 4, .25, dtype='<f4').tobytes()
    packet = struct.pack('<IId', 8, len(meta), 3.2) + meta + points
    output, elapsed = unpack_result(packet, 8, FEATURES)
    assert len(output['face']) == 478 and len(output['iris']['right']) == 5
    assert len(output['hands']['left']) == 21 and len(output['pose']) == 33
    assert output['pose'][0]['visibility'] == .25
    assert output['blendshapes']['jawOpen'] == .2 and elapsed == 3.2
    with pytest.raises(RuntimeError):
        unpack_result(packet, 9, FEATURES)
    with pytest.raises(RuntimeError):
        unpack_result(packet[:-4], 8, FEATURES)


class CPU:
    delay = .002
    def __init__(self, config):
        self.config = config
    def enable_tracking(self, *args):
        pass
    def process(self, rgb, is_rgb=False):
        time.sleep(self.delay)
        return {'face': [{'x': .5, 'y': .5, 'z': 0}], 'source': 'cpu'}
    def cleanup(self):
        pass


class GPU:
    START_TIMEOUT = 25
    delay = .0002
    fail = False
    renderer = 'Test GPU'
    inference_ms = .2
    def __init__(self, *args):
        self.closed = False
    def process(self, rgb, timeout=None):
        if self.fail:
            raise RuntimeError('GPU context lost')
        time.sleep(self.delay)
        return {'face': [{'x': .5, 'y': .5, 'z': 0}], 'source': 'gpu'}
    def close(self):
        self.closed = True


def drive(engine, condition, seconds=3):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = engine.process(RGB)
        if condition(engine.status()):
            return result
    pytest.fail(f'Tracking state did not settle: {engine.status()}')


def test_gpu_initialization_failure_keeps_cpu_live(monkeypatch):
    monkeypatch.setattr(module, 'WebProcessor', CPU)
    def fail(*args):
        raise RuntimeError('No compatible GPU')
    monkeypatch.setattr(module, 'BrowserTracker', fail)
    engine = module.TrackingEngine(TrackingConfig(backend='gpu'), FEATURES)
    try:
        result = drive(engine, lambda state: state['fallback_reason'])
        assert result['source'] == 'cpu'
        assert engine.status()['active_backend'] == 'cpu'
    finally:
        engine.close()


def test_runtime_gpu_failure_falls_back_without_stopping_tracking(monkeypatch):
    monkeypatch.setattr(module, 'WebProcessor', CPU)
    monkeypatch.setattr(module, 'BrowserTracker', GPU)
    engine = module.TrackingEngine(TrackingConfig(backend='gpu'), FEATURES)
    try:
        assert drive(engine, lambda state: state['active_backend'] == 'gpu')['source'] == 'gpu'
        failed_gpu = engine.gpu
        failed_gpu.fail = True
        assert engine.process(RGB)['source'] == 'cpu'
        assert engine.status()['fallback_reason'] == 'GPU context lost'
    finally:
        engine.close()
    assert failed_gpu.closed


@pytest.mark.parametrize(('gpu_delay', 'chosen'), [(.008, 'cpu'), (.0001, 'gpu')])
def test_auto_selects_measured_faster_backend(monkeypatch, gpu_delay, chosen):
    monkeypatch.setattr(module, 'WebProcessor', CPU)
    monkeypatch.setattr(module, 'BrowserTracker', GPU)
    monkeypatch.setattr(GPU, 'delay', gpu_delay)
    engine = module.TrackingEngine(TrackingConfig(backend='auto'), FEATURES)
    try:
        drive(engine, lambda state: state['comparison'] is not None and state['phase'] == 'ready')
        assert engine.status()['active_backend'] == chosen
        assert engine.status()['comparison']['selected'] == chosen
    finally:
        engine.close()


def test_live_resolution_changes_without_restarting_capture(monkeypatch):
    from capture import mediapipe_worker
    from capture.frame import VideoFrame
    from ipc.qpc import get_qpc_ticks
    class Engine:
        model_ms = 0
        def __init__(self, config, features): self.config, self.features = config, features
        def process(self, rgb): return {'size': list(rgb.shape[:2])}
        def cancel(self): pass
        def close(self): pass
        def status(self): return {'active_backend': 'cpu'}
    class Ring:
        def write_empty(self, *args): pass
    monkeypatch.setattr(mediapipe_worker, 'TrackingEngine', Engine)
    worker = mediapipe_worker.MediaPipeWorker(Ring(), 640, 360, 960, 540)
    frame = VideoFrame(np.zeros((540, 960, 3), np.uint8), 960, 540)
    worker.start()
    try:
        for index, width in enumerate((480, 320)):
            update_tracking_config({'max_width': width})
            worker.queue_frame(frame, get_qpc_ticks(), index)
            deadline = time.monotonic() + 2
            while worker.get_snapshot()['frame_id'] != index and time.monotonic() < deadline:
                time.sleep(.01)
            assert worker.get_snapshot()['landmarks']['size'] == [width * 540 // 960, width]
            assert worker.is_alive()
    finally:
        worker.stop()
