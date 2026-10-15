import cv2
import numpy as np
import pytest
import time
from capture.camera import Camera, NV12Converter, bgr_to_nv12
from capture.frame import VideoFrame


def test_reused_converter_matches_reference_and_keeps_storage():
    converter = NV12Converter(64, 64)
    storage = (converter.planar.ctypes.data, converter.uv.ctypes.data)
    for color in [(30, 100, 180), (210, 40, 90)]:
        frame = np.full((64, 64, 3), color, np.uint8)
        actual = converter.convert(frame)
        assert tuple(bytes(plane) for plane in actual) == bgr_to_nv12(frame)
        assert storage == (converter.planar.ctypes.data, converter.uv.ctypes.data)


def test_native_frame_tracking_and_lazy_export_have_correct_colors():
    original = np.full((128, 128, 3), (30, 100, 180), np.uint8)
    y, uv = bgr_to_nv12(original)
    data = np.frombuffer(y + uv, np.uint8).reshape(1, -1)
    frame = VideoFrame(data, 128, 128, 'NV12')
    assert bytes(frame.nv12_planes()[0]) == y
    assert bytes(frame.nv12_planes()[1]) == uv
    rgb = frame.tracking_rgb(64, 64)
    assert rgb.shape == (64, 64, 3)
    assert np.max(np.abs(rgb.astype(int) - np.array([180, 100, 30]))) <= 2
    assert frame._bgr is None  # Tracking must not decode a full-resolution image.
    exported = frame.to_bgr()
    assert np.max(np.abs(exported.astype(int) - original)) <= 2
    assert frame.to_bgr() is exported


def test_native_camera_publishes_without_conversion_or_software_sleep(monkeypatch):
    image = np.full((64, 64, 3), (30, 100, 180), np.uint8)
    y, uv = bgr_to_nv12(image)
    raw = np.frombuffer(y + uv, np.uint8).reshape(1, -1)

    class NativeCamera:
        released = False
        def isOpened(self): return True
        def set(self, *args): return True
        def get(self, prop):
            return {cv2.CAP_PROP_FRAME_WIDTH: 64, cv2.CAP_PROP_FRAME_HEIGHT: 64,
                    cv2.CAP_PROP_FOURCC: cv2.VideoWriter_fourcc(*'NV12'), cv2.CAP_PROP_FPS: 30}.get(prop, 0)
        def read(self): return True, raw
        def release(self): self.released = True

    device = NativeCamera()
    monkeypatch.setattr(cv2, 'VideoCapture', lambda *args: device)
    monkeypatch.setattr(cv2, 'cvtColor', lambda *args, **kwargs: pytest.fail('Native video must not convert to RGB'))
    camera = Camera(0, 64, 64, mp_enabled=False)
    camera._stop.wait = lambda *args: pytest.fail('Hardware capture must not add software pacing')
    try:
        assert camera.open(), camera.error
        result = camera.wait_frame(timeout=1)
        assert result is not None
        packet = result[2]
        assert packet.pixel_format == 'NV12' and packet._bgr is None
        assert bytes(packet.nv12_planes()[0]) == y
        assert camera.pixel_format == 'NV12'
        assert camera.requested_fps == 60 and camera.fps == 30
    finally:
        camera.close()
    assert device.released


def test_unsupported_native_format_falls_back_to_bgr(monkeypatch):
    class BgrCamera:
        settings = []
        def isOpened(self): return True
        def set(self, prop, value):
            self.settings.append((prop, value))
            return True
        def get(self, prop): return cv2.VideoWriter_fourcc(*'MJPG') if prop == cv2.CAP_PROP_FOURCC else 0
        def read(self): return True, np.zeros((64, 64, 3), np.uint8)
        def release(self): pass
    device = BgrCamera()
    monkeypatch.setattr(cv2, 'VideoCapture', lambda *args: device)
    camera = Camera(0, 64, 64, mp_enabled=False)
    try:
        assert camera.open(), camera.error
        assert camera.pixel_format == 'BGR'
        assert (cv2.CAP_PROP_CONVERT_RGB, 1) in device.settings
        assert camera.read()[1].shape == (64, 64, 3)
    finally:
        camera.close()


@pytest.mark.parametrize('native_frame', [None, np.zeros((1, 100), np.uint8)])
def test_failed_or_padded_native_frame_falls_back_to_bgr(monkeypatch, native_frame):
    class Device:
        convert = True
        def isOpened(self): return True
        def set(self, prop, value):
            if prop == cv2.CAP_PROP_CONVERT_RGB:
                self.convert = bool(value)
            return True
        def get(self, prop):
            return cv2.VideoWriter_fourcc(*'NV12') if prop == cv2.CAP_PROP_FOURCC else 64
        def read(self):
            if self.convert:
                return True, np.zeros((64, 64, 3), np.uint8)
            return native_frame is not None, native_frame
        def release(self): pass
    device = Device()
    monkeypatch.setattr(cv2, 'VideoCapture', lambda *args: device)
    camera = Camera(0, 64, 64, mp_enabled=False)
    try:
        assert camera.open(), camera.error
        assert camera.pixel_format == 'BGR' and device.convert
        assert camera.read()[1].shape == (64, 64, 3)
    finally:
        camera.close()


def test_native_frame_exports_and_records(tmp_path):
    from server.app import create_app
    from server.routes import export_data
    from server.recorder import Recorder
    y, uv = bgr_to_nv12(np.full((64, 64, 3), (30, 100, 180), np.uint8))
    frame = VideoFrame(np.frombuffer(y + uv, np.uint8), 64, 64, 'NV12')
    try:
        export_data.set_current_frame(frame)
        with create_app({'TESTING': True}).test_client() as client:
            response = client.get('/api/export/frame?format=png')
            assert response.status_code == 200
            decoded = cv2.imdecode(np.frombuffer(response.data, np.uint8), cv2.IMREAD_COLOR)
            assert decoded.shape == (64, 64, 3)
            assert np.max(np.abs(decoded.astype(int) - [30, 100, 180])) <= 2
        recorder = Recorder(tmp_path)
        recorder.start(64, 64, 30)
        recorder.write(frame.to_bgr(), 1000, {})
        result = recorder.stop()
        video = cv2.VideoCapture(result['files'][0])
        try:
            assert video.read()[0]
        finally:
            video.release()
    finally:
        export_data.set_current_frame(None)


def test_native_preview_stays_lazy_and_supports_browser_and_recording(tmp_path, monkeypatch):
    from ipc.qpc import get_qpc_ticks
    from server.routes import streaming, export_data
    from server.recorder import Recorder
    y, uv = bgr_to_nv12(np.full((64, 64, 3), (30, 100, 180), np.uint8))
    raw = np.frombuffer(y + uv, np.uint8)
    recorder = Recorder(tmp_path)
    monkeypatch.setattr(export_data, 'recorder', recorder)

    class Source:
        mp_worker = None
        sequence = 0
        def is_opened(self): return True
        def wait_frame(self, previous, timeout):
            time.sleep(.01)
            self.sequence += 1
            return self.sequence, get_qpc_ticks(), VideoFrame(raw, 64, 64, 'NV12')

    source = Source()
    browser = None
    streaming.set_camera_source(source)
    try:
        deadline = time.monotonic() + 2
        while export_data._current_frame is None and time.monotonic() < deadline:
            time.sleep(.01)
        assert export_data._current_frame is not None
        assert export_data._current_frame._bgr is None
        assert streaming._jpeg is None

        browser = streaming.generate_frames()
        multipart = next(browser)
        assert streaming._jpeg is not None
        jpeg = multipart.split(b'\r\n\r\n', 1)[1][:-2]
        decoded = cv2.imdecode(np.frombuffer(jpeg, np.uint8), cv2.IMREAD_COLOR)
        assert np.max(np.abs(decoded.astype(int) - [30, 100, 180])) <= 5

        recorder.start(64, 64, 30)
        deadline = time.monotonic() + 2
        while recorder.status()['frames_recorded'] < 3 and time.monotonic() < deadline:
            time.sleep(.01)
        result = recorder.stop()
        assert result['error'] is None and result['frames_recorded'] >= 3
        video = cv2.VideoCapture(result['files'][0])
        try:
            assert video.read()[0]
        finally:
            video.release()
    finally:
        if browser:
            browser.close()
        streaming.set_camera_source(None)
