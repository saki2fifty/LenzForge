"""Background capture with one owner. Viewers consume frames without driving capture.

OpenCV's maintained MSMF backend removes the Python-version-specific capture DLL.
The native Godot viewer still receives NV12 video through shared memory.
"""
from dataclasses import dataclass
import logging
import threading
import time
import uuid
import cv2
import numpy as np
from capture.mediapipe_worker import MediaPipeWorker
from ipc.ring_nv12 import NV12RingWriter
from ipc.ring_landmarks import LMK1Writer
from ipc.qpc import get_qpc_ticks
from pipeline.performance_config import get_performance_config

logger = logging.getLogger('CAMERA')


@dataclass
class CameraStats:
    frames_captured: int = 0
    frames_dropped: int = 0
    is_opened: bool = False


def bgr_to_nv12(frame):
    height, width = frame.shape[:2]
    planar = cv2.cvtColor(frame, cv2.COLOR_BGR2YUV_I420).reshape(-1)
    pixels = width * height
    uv = np.empty(pixels // 2, dtype=np.uint8)
    uv[0::2] = planar[pixels:pixels + pixels // 4]
    uv[1::2] = planar[pixels + pixels // 4:]
    return planar[:pixels].tobytes(), uv.tobytes()


class Camera:
    FRAME_TIMEOUT = 3.0

    def __init__(self, camera_id, width=1280, height=720, fps=30, mp_enabled=True, mp_max_width=None):
        if not (type(camera_id) is int and camera_id >= -1):
            raise ValueError('camera_id must be a whole number >= -1 (-1 is the demo source)')
        if width < 64 or height < 64 or width > 3840 or height > 2160 or width % 2 or height % 2:
            raise ValueError('Resolution must be even and between 64x64 and 3840x2160')
        if fps < 1 or fps > 120:
            raise ValueError('FPS must be between 1 and 120')
        self.camera_id = self.index = camera_id
        self.name = 'Demo pattern' if camera_id == -1 else f'Camera {camera_id}'
        self.device_id = ''
        self.width, self.height, self.fps = width, height, fps
        self.mp_enabled, self.mp_max_width = mp_enabled, mp_max_width
        self.stats = CameraStats()
        self.frame_count = 0
        self.current_frame = None
        self.ring_writer = self.lmk1_writer = self.mp_worker = None
        self.msmf_camera = None
        self.negotiated_format = None
        self.error = None
        self._condition = threading.Condition()
        self._stop = threading.Event()
        self._ready = threading.Event()
        self._thread = None
        self._timestamp = 0
        self.video_buffer = ''
        self.landmark_buffer = ''

    def open(self):
        if self.is_opened():
            return True
        if self._thread and self._thread.is_alive():
            raise RuntimeError('Previous capture thread is still stopping')
        self._stop.clear()
        self._ready.clear()
        self.error = None
        self.current_frame = None
        self.frame_count = 0
        self.stats = CameraStats()
        self._thread = threading.Thread(target=self._capture, daemon=True, name='LenzForge-Capture')
        self._thread.start()
        if not self._ready.wait(15):
            self._stop.set()
            self.error = 'Camera initialization timed out'
            return False
        return self.stats.is_opened

    def _capture(self):
        try:
            first = None
            if self.camera_id >= 0:
                self.msmf_camera = cv2.VideoCapture(self.camera_id, cv2.CAP_MSMF)
                if not self.msmf_camera.isOpened():
                    raise RuntimeError(f'Cannot open {self.name}. Close other camera apps and check Windows camera permissions.')
                self.msmf_camera.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                self.msmf_camera.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
                self.msmf_camera.set(cv2.CAP_PROP_FPS, self.fps)
                ok, first = self.msmf_camera.read()
                if not ok or first is None:
                    raise RuntimeError(f'{self.name} returned no frames. Check that the device is connected and available.')
                self.height, self.width = first.shape[:2]
            if self.width % 2 or self.height % 2:
                raise RuntimeError('Camera negotiated odd dimensions unsupported by NV12')
            generation = uuid.uuid4().hex
            self.video_buffer = 'LenzForge_Video_' + generation
            self.landmark_buffer = 'LenzForge_Landmarks_' + generation
            self.ring_writer = NV12RingWriter(self.video_buffer, self.width, self.height)
            self.lmk1_writer = LMK1Writer(self.landmark_buffer, self.width, self.height)
            perf = get_performance_config()
            limit = self.mp_max_width if self.mp_max_width is not None else perf.mediapipe_max_width
            scale = min(1, limit / self.width) if limit else 1
            self.mp_width = max(2, int(self.width * scale) // 2 * 2)
            self.mp_height = max(2, int(self.height * scale) // 2 * 2)
            if self.mp_enabled:
                self.mp_worker = MediaPipeWorker(self.lmk1_writer, self.mp_width, self.mp_height, self.width, self.height)
                self.mp_worker.start()
            self.negotiated_format = {'format': 'NV12', 'width': self.width, 'height': self.height,
                                      'fps': self.fps, 'y_stride': self.width, 'uv_stride': self.width}
            self.stats.is_opened = True
            self._ready.set()
            last_frame_at = time.monotonic()
            while not self._stop.is_set():
                start = time.monotonic()
                if self.camera_id == -1:
                    frame = self._demo_frame()
                elif first is not None:
                    frame, first = first, None
                else:
                    ok, frame = self.msmf_camera.read()
                    if not ok or frame is None:
                        self.stats.frames_dropped += 1
                        if time.monotonic() - last_frame_at >= self.FRAME_TIMEOUT:
                            raise RuntimeError(f'{self.name} stopped delivering frames. Reconnect it, then start capture again.')
                        self._stop.wait(0.02)
                        continue
                last_frame_at = time.monotonic()
                timestamp = get_qpc_ticks()  # One timestamp for both protocols.
                y, uv = bgr_to_nv12(frame)
                self.ring_writer.write_frame(y, uv, timestamp)
                if self.mp_worker:
                    self.mp_worker.queue_frame(frame, timestamp, self.frame_count)
                else:
                    self.lmk1_writer.write_empty(timestamp, self.frame_count)
                with self._condition:
                    self.current_frame = frame
                    self._timestamp = timestamp
                    self.frame_count += 1
                    self.stats.frames_captured += 1
                    self._condition.notify_all()
                self._stop.wait(max(0, 1 / self.fps - (time.monotonic() - start)))
        except Exception as exc:
            self.error = str(exc)
            logger.exception('Capture stopped')
        finally:
            self.stats.is_opened = False
            self._ready.set()
            with self._condition:
                self._condition.notify_all()
            if self.mp_worker:
                self.mp_worker.stop()
            for writer in (self.ring_writer, self.lmk1_writer):
                if writer:
                    writer.close()
            if self.msmf_camera:
                self.msmf_camera.release()

    def _demo_frame(self):
        frame = np.full((self.height, self.width, 3), (30, 24, 17), dtype=np.uint8)
        for x in range(0, self.width, 80):
            cv2.line(frame, (x, 0), (x, self.height), (48, 42, 34), 1)
        for y in range(0, self.height, 80):
            cv2.line(frame, (0, y), (self.width, y), (48, 42, 34), 1)
        x = int((np.sin(self.frame_count / 45) * .3 + .5) * self.width)
        cv2.circle(frame, (x, self.height // 2), self.height // 6, (180, 210, 60), 3, cv2.LINE_AA)
        cv2.putText(frame, 'LENZFORGE / DEMO SOURCE', (32, 50), cv2.FONT_HERSHEY_SIMPLEX, .8, (220, 220, 220), 1, cv2.LINE_AA)
        return frame

    def wait_frame(self, after_id=-1, timeout=1.0):
        with self._condition:
            self._condition.wait_for(lambda: (self.current_frame is not None and self.frame_count > after_id) or not self.stats.is_opened, timeout)
            if self.current_frame is None or self.frame_count <= after_id or not self.stats.is_opened:
                return None
            return self.frame_count, self._timestamp, self.current_frame

    def read(self):
        result = self.wait_frame()
        return (True, result[2].copy()) if result else (False, None)

    def close(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=10)
            if self._thread.is_alive():
                raise RuntimeError('Camera is still shutting down')
        self.current_frame = None

    release = close

    def is_opened(self):
        return self.stats.is_opened

    def get_properties(self):
        return {'width': self.width, 'height': self.height, 'fps': self.fps, 'backend': 'MSMF', 'id': self.camera_id}

    def get_stats(self):
        return self.stats

    def reset_stats(self):
        self.stats.frames_captured = self.stats.frames_dropped = 0

    def set_property(self, prop, value):
        return False  # Resolution changes require reopening on the owner thread.
