"""Single inference worker with a latest-frame mailbox shared by all viewers."""
import logging
from collections import deque
import queue
import threading
import time
import numpy as np
from pipeline.tracking_config import get_tracking_config
from tracking.engine import TrackingEngine
from capture.frame import VideoFrame
from ipc.qpc import get_qpc_ticks, get_qpc_frequency

logger = logging.getLogger(__name__)


class MediaPipeWorker(threading.Thread):
    def __init__(self, lmk1_writer, mp_width, mp_height, camera_width, camera_height, queue_size=1):
        super().__init__(daemon=True, name='LenzForge-Tracking')
        self.lmk1_writer = lmk1_writer
        self.mp_width, self.mp_height = mp_width, mp_height
        self.frame_queue = queue.Queue(maxsize=1)
        self.running = False
        self.enabled = True
        self.frames_processed = self.frames_dropped = 0
        self.last_inference_time = self.total_inference_time = 0.0
        self._stop_event = threading.Event()
        self._lock = threading.RLock()
        self._requested = {'face': True, 'iris': True, 'hands': False, 'pose': False}
        self._snapshot = {'landmarks': {}, 'frame_id': -1, 'timestamp': 0}
        self.error = None
        self.started_at = time.monotonic()
        self._engine = None
        self._timings = deque(maxlen=240)
        self._applied_revision = -1
        self._retired = []

    def queue_frame(self, frame_bgr, ts_qpc, frame_id):
        if self._stop_event.is_set() or not self.enabled:
            return
        # The capture owner never mutates a published frame. Replace stale work.
        try:
            self.frame_queue.put_nowait((frame_bgr, ts_qpc, frame_id))
        except queue.Full:
            try:
                self.frame_queue.get_nowait()
                self.frames_dropped += 1
            except queue.Empty:
                pass
            try:
                self.frame_queue.put_nowait((frame_bgr, ts_qpc, frame_id))
            except queue.Full:
                self.frames_dropped += 1

    def run(self):
        self.running = True
        processor = None
        try:
            while not self._stop_event.is_set():
                try:
                    frame, timestamp, frame_id = self.frame_queue.get(timeout=0.2)
                except queue.Empty:
                    continue
                start = time.perf_counter()
                with self._lock:
                    requested = self._requested.copy()
                config, revision = get_tracking_config()
                if processor is None or revision != self._applied_revision or processor.features != requested:
                    if processor:
                        processor.cancel()
                        closer = threading.Thread(target=processor.close, daemon=True, name='LenzForge-Tracking-Cleanup')
                        closer.start()
                        self._retired = [t for t in self._retired if t.is_alive()] + [closer]
                    processor = self._engine = TrackingEngine(config, requested)
                    self._applied_revision = revision
                    with self._lock:
                        self._timings.clear()
                if not isinstance(frame, VideoFrame):
                    frame = VideoFrame(frame, frame.shape[1], frame.shape[0])
                scale = min(1, config.max_width / frame.width) if config.max_width else 1
                self.mp_width = max(2, int(frame.width * scale) // 2 * 2)
                self.mp_height = max(2, int(frame.height * scale) // 2 * 2)
                landmarks = processor.process(frame.tracking_rgb(self.mp_width, self.mp_height)) if any(requested.values()) else {}
                face = landmarks.get('face', [])
                if face:
                    self.lmk1_writer.write_landmarks([(p['x'], p['y'], p['z']) for p in face], timestamp, frame_id)
                else:
                    self.lmk1_writer.write_empty(timestamp, frame_id)
                self.last_inference_time = (time.perf_counter() - start) * 1000
                self.total_inference_time += self.last_inference_time
                self.frames_processed += 1
                completed = time.monotonic()
                with self._lock:
                    self._timings.append((completed, self.last_inference_time,
                                          (get_qpc_ticks() - timestamp) * 1000 / get_qpc_frequency()))
                    self._snapshot = {'landmarks': landmarks, 'frame_id': frame_id, 'timestamp': timestamp}
        except Exception as exc:
            self.error = str(exc)
            logger.exception('Tracking worker stopped')
        finally:
            if processor:
                processor.close()
            for closer in self._retired:
                closer.join(timeout=10)
            self.running = False

    def enable_tracking(self, feature, enabled=True):
        if feature not in self._requested:
            raise ValueError(f'Unknown tracking feature: {feature}')
        with self._lock:
            self._requested[feature] = bool(enabled)

    def get_enabled_tracking(self):
        with self._lock:
            return self._requested.copy()

    def get_snapshot(self):
        with self._lock:
            return self._snapshot.copy()

    def get_stats(self):
        count = len(self.get_snapshot()['landmarks'].get('face', []))
        average = self.total_inference_time / max(self.frames_processed, 1)
        with self._lock:
            samples = list(self._timings)
        recent = [s for s in samples if s[0] > time.monotonic() - 2]
        fps = (len(recent) - 1) / max(recent[-1][0] - recent[0][0], .001) if len(recent) > 1 else 0
        metrics = {'round_trip_p50_ms': float(np.median([s[1] for s in samples])) if samples else 0,
                   'round_trip_p95_ms': float(np.percentile([s[1] for s in samples], 95)) if samples else 0,
                   'capture_to_landmarks_p95_ms': float(np.percentile([s[2] for s in samples], 95)) if samples else 0}
        config, revision = get_tracking_config()
        runtime = self._engine.status() if self._engine else {'requested_backend': config.backend, 'active_backend': None, 'phase': 'starting'}
        return {'enabled': self.enabled, 'features': self.get_enabled_tracking(), **runtime, **metrics,
                'settings': config.to_dict(), 'settings_revision': revision, 'applied_revision': self._applied_revision,
                'inference_size': [self.mp_width, self.mp_height],
                'model_ms': self._engine.model_ms if self._engine else 0,
                'running': self.running, 'frames_processed': self.frames_processed,
                'frames_dropped': self.frames_dropped, 'last_inference_ms': self.last_inference_time,
                'avg_inference_ms': average, 'processing_time': self.last_inference_time,
                'fps': fps, 'queue_size': self.frame_queue.qsize(),
                'face_detected': count > 0, 'landmark_count': count, 'error': self.error}

    def set_enabled(self, enabled):
        self.enabled = bool(enabled)

    def stop(self):
        self._stop_event.set()
        if self._engine:
            self._engine.cancel()
        if self.ident is not None:
            self.join(timeout=15)
            if self.is_alive():
                raise RuntimeError('Tracking worker did not stop; its ring buffer must remain open')
