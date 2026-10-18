import threading
import time

from tracking.portrait_mask import HEADER, WIDTH, HEIGHT, PortraitWorker


class Camera:
    video_buffer = 'camera-generation-a'
    def is_opened(self): return True
    def wait_frame(self, timeout=0): return (1, 123456, object())


def test_optional_worker_reuses_latest_frame_and_expires():
    calls = []
    closed = threading.Event()
    class Segmenter:
        def __init__(self, quality): pass
        def process(self, frame): calls.append(frame); return bytes([255]) * WIDTH * HEIGHT
        def close(self): closed.set()
    camera = Camera()
    worker = PortraitWorker(lambda: camera, Segmenter)
    worker.LEASE_SECONDS = .12
    assert worker.thread is None and not calls
    worker.request(camera.video_buffer, 30)
    deadline = time.monotonic() + 2
    while worker.packet is None and time.monotonic() < deadline: time.sleep(.005)
    assert worker.packet is not None
    packet, _ = worker.request(camera.video_buffer, 30)
    magic, width, height, stamp, frame, elapsed = HEADER.unpack_from(packet)
    assert (magic, width, height, frame) == (b'MSK1', 256, 144, 1)
    assert stamp > 0 and elapsed >= 0
    assert len(packet) == HEADER.size + WIDTH * HEIGHT
    assert worker.request('different-generation', 30)[0] is None
    thread = worker.thread
    thread.join(timeout=2)
    assert not thread.is_alive() and closed.is_set()
    assert len(calls) == 1  # Polls never rerun inference on the same captured frame.
    assert worker.packet is None and worker.thread is None


def test_slow_inference_never_blocks_request_or_accumulates_jobs():
    entered, release, closed = threading.Event(), threading.Event(), threading.Event()
    class Segmenter:
        def __init__(self, quality): pass
        def process(self, _frame): entered.set(); release.wait(2); return bytes(WIDTH*HEIGHT)
        def close(self): closed.set()
    camera = Camera()
    worker = PortraitWorker(lambda: camera, Segmenter)
    worker.request(Camera.video_buffer, 30)
    assert entered.wait(2)
    for _ in range(100):
        packet, _ = worker.request(Camera.video_buffer, 30)
        assert packet is None
    thread = worker.thread
    worker.stop()
    release.set()
    thread.join(timeout=2)
    assert closed.is_set() and worker.packet is None and not thread.is_alive()


def test_failure_is_visible_and_retry_requires_toggle():
    attempts = []
    def fail(quality): attempts.append(1); raise ValueError('Model unavailable')
    worker = PortraitWorker(Camera, fail)
    worker.request(Camera.video_buffer, 30)
    deadline = time.monotonic()+2
    while worker.thread is not None and time.monotonic()<deadline: time.sleep(.005)
    for _ in range(3):
        assert worker.request(Camera.video_buffer, 30)[1]['error'] == 'Model unavailable'
    assert len(attempts) == 1
    worker.stop()
    assert not worker.error


def test_mask_route_checks_capture_generation_and_origin(monkeypatch, tmp_path):
    monkeypatch.setenv('LENZFORGE_SETTINGS_DIR', str(tmp_path))
    from server.app import create_app
    from server.routes import portrait
    camera = Camera()
    monkeypatch.setattr(portrait.streaming, '_active_camera', camera)
    class Worker:
        def request(self, source, rate, quality): return b'mask', {}
        def stop(self): pass
    monkeypatch.setattr(portrait, 'worker', Worker())
    client = create_app({'TESTING': True}).test_client()
    assert client.post('/api/portrait/mask', json={'source':camera.video_buffer,'rate':120}).status_code == 400
    assert client.post('/api/portrait/mask', json={'source':camera.video_buffer,'rate':60,'quality':[]}).status_code == 400
    assert client.post('/api/portrait/mask', json={'source':'old','rate':30}).status_code == 409
    assert client.post('/api/portrait/mask', json={'source':camera.video_buffer,'rate':30}, headers={'Origin':'https://example.com'}).status_code == 403
    result = client.post('/api/portrait/mask', json={'source':camera.video_buffer,'rate':30})
    assert result.data == b'mask' and result.mimetype == 'application/octet-stream'
    assert result.headers['Cache-Control'] == 'no-store'
    assert result.headers['X-LenzForge-Source'] == camera.video_buffer
    assert result.headers['X-LenzForge-Mask-Quality'] == 'fast'
    assert client.post('/api/portrait/mask', json={'source':camera.video_buffer,'rate':60,'quality':'balanced'}).status_code == 200


def test_changing_quality_drops_inflight_result_and_rebuilds_only_once():
    from tracking.portrait_mask import MODELS
    entered, release = threading.Event(), threading.Event()
    opened, closed = [], []
    class Segmenter:
        def __init__(self, quality): self.quality = quality; opened.append(quality)
        def process(self, frame):
            if self.quality == 'fast': entered.set(); release.wait(2)
            width, height = MODELS[self.quality][3:]
            return bytes(width*height)
        def close(self): closed.append(self.quality)
    camera = Camera()
    worker = PortraitWorker(lambda: camera, Segmenter)
    worker.request(Camera.video_buffer, 30)
    assert entered.wait(2)
    for _ in range(50):
        assert worker.request(Camera.video_buffer, 60, 'balanced')[0] is None
    release.set()
    deadline = time.monotonic()+2
    while worker.packet is None and time.monotonic()<deadline: time.sleep(.005)
    packet = worker.request(Camera.video_buffer, 60, 'balanced')[0]
    assert packet is not None and HEADER.unpack_from(packet)[1:3] == (256,256)
    thread = worker.thread
    worker.stop(); thread.join(timeout=2)
    assert opened == closed == ['fast', 'balanced']
