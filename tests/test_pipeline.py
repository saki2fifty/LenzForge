import struct
import time
import uuid
import cv2
import numpy as np
import pytest
from capture.camera import Camera, bgr_to_nv12
from capture.mediapipe_worker import MediaPipeWorker
from ipc.qpc import get_qpc_ticks, get_qpc_frequency
from ipc.ring_landmarks import LMK1Writer
from ipc.ring_nv12 import NV12RingWriter
from server.recorder import Recorder


def unique_name():
    return 'LenzForge_Test_' + uuid.uuid4().hex


def test_video_protocol_layout_and_publication():
    ring = NV12RingWriter(unique_name(), 64, 64)
    try:
        assert len(ring.mmap[:64]) == 64
        assert struct.unpack_from('<4sI', ring.mmap) == (b'VID1', 1)
        assert struct.unpack_from('<Q', ring.mmap, 40)[0] == get_qpc_frequency()
        timestamp = get_qpc_ticks()
        ring.write_frame(bytes([64]) * 4096, bytes([128]) * 2048, timestamp)
        assert struct.unpack_from('<I', ring.mmap, 16)[0] == 1
        assert struct.unpack_from('<QII', ring.mmap, 64) == (timestamp, 0, 1)
        assert ring.mmap[96] == 64
        assert ring.mmap[96 + 4096] == 128
    finally:
        ring.close()


def test_landmark_protocol_layout_and_empty_frames():
    ring = LMK1Writer(unique_name(), 640, 360)
    try:
        assert struct.unpack_from('<Q', ring.mmap, 36)[0] == get_qpc_frequency()
        assert ring.mmap[56:64] == bytes(8)
        ring.write_landmarks([(0.25, 0.5, -0.1)] * 478, 1234, 0)
        assert struct.unpack_from('<QIII', ring.mmap, 64) == (1234, 0, 1, 1)
        assert struct.unpack_from('<HHHH', ring.mmap, 96) == (0, 478, 12, 0)
        assert struct.unpack_from('<fff', ring.mmap, 104) == pytest.approx((.25, .5, -.1))
        ring.write_empty(5678, 1)
        assert struct.unpack_from('<QIII', ring.mmap, 64 + ring.slot_stride) == (5678, 1, 1, 0)
        with pytest.raises(ValueError):
            ring.write_landmarks([(0, 0, 0)] * 479, 9876, 2)
    finally:
        ring.close()


def test_nv12_color_conversion_round_trip():
    frame = np.full((64, 64, 3), (30, 100, 180), dtype=np.uint8)
    y, uv = bgr_to_nv12(frame)
    packed = np.frombuffer(y + uv, dtype=np.uint8).reshape(96, 64)
    restored = cv2.cvtColor(packed, cv2.COLOR_YUV2BGR_NV12)
    assert np.max(np.abs(restored.astype(int) - frame.astype(int))) <= 2


def test_tracking_mailbox_keeps_newest_frame():
    worker = MediaPipeWorker(None, 64, 64, 64, 64)
    frame = np.zeros((64, 64, 3), np.uint8)
    for index in range(30):
        worker.queue_frame(frame, 100 + index, index)
    assert worker.frame_queue.qsize() == 1
    assert worker.frame_queue.get_nowait()[2] == 29
    assert worker.frames_dropped == 29


def test_capture_runs_without_viewers_and_restarts():
    camera = Camera(-1, 320, 180, 30, mp_enabled=False)
    try:
        previous_buffers = None
        for _ in range(2):
            assert camera.open(), camera.error
            buffers = (camera.video_buffer, camera.landmark_buffer)
            assert buffers != previous_buffers
            previous_buffers = buffers
            first = camera.wait_frame(timeout=1)
            assert first is not None
            second = camera.wait_frame(first[0], timeout=1)
            assert second is not None and second[0] > first[0]
            assert second[1] > first[1]
            assert camera.read()[1].shape == (180, 320, 3)
            camera.close()
            assert not camera._thread.is_alive()
    finally:
        camera.close()


def test_recording_writes_playable_video_and_landmarks(tmp_path):
    recorder = Recorder(tmp_path)
    recorder.start(64, 64, 30)
    timestamp = get_qpc_ticks()
    for index in range(6):
        recorder.write(np.full((64, 64, 3), index * 20, np.uint8),
                       timestamp + round(index * get_qpc_frequency() / 30), {'face': []})
    result = recorder.stop()
    assert result['error'] is None
    assert len(result['files']) == 2
    video = cv2.VideoCapture(result['files'][0])
    try:
        assert video.isOpened()
        assert video.read()[0]
        assert video.get(cv2.CAP_PROP_FRAME_COUNT) >= 5
    finally:
        video.release()
    assert len((tmp_path / result['files'][1]).read_text().splitlines()) == 6


@pytest.mark.parametrize('dimensions', [(65, 64), (0, 0), (4000, 2200)])
def test_invalid_capture_dimensions_are_rejected(dimensions):
    with pytest.raises(ValueError):
        Camera(-1, *dimensions)


def test_camera_stops_and_reports_disconnection(monkeypatch):
    class DisconnectedCamera:
        released = False
        reads = 0

        def isOpened(self):
            return True

        def set(self, *args):
            return True

        def get(self, prop):
            return 0  # This mock only supplies BGR frames.

        def read(self):
            self.reads += 1
            return (True, np.zeros((64, 64, 3), np.uint8)) if self.reads == 1 else (False, None)

        def release(self):
            self.released = True

    device = DisconnectedCamera()
    monkeypatch.setattr(cv2, 'VideoCapture', lambda *args: device)
    camera = Camera(0, 64, 64, mp_enabled=False)
    camera.FRAME_TIMEOUT = .1
    try:
        assert camera.open()
        assert camera.wait_frame(timeout=1) is not None
        camera._thread.join(timeout=2)
        assert not camera._thread.is_alive()
        assert not camera.is_opened()
        assert 'stopped delivering frames' in camera.error
        assert device.released
    finally:
        camera.close()
