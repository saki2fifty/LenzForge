"""Single inference worker with a latest-frame mailbox shared by all viewers."""
import logging
import queue
import threading
import time
import cv2
from pipeline.web_processor import WebProcessor

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
            processor = WebProcessor()
            while not self._stop_event.is_set():
                try:
                    frame, timestamp, frame_id = self.frame_queue.get(timeout=0.2)
                except queue.Empty:
                    continue
                start = time.perf_counter()
                with self._lock:
                    requested = self._requested.copy()
                for feature, enabled in requested.items():
                    if processor.tracking_enabled[feature] != enabled:
                        processor.enable_tracking(feature, enabled)
                if frame.shape[1] != self.mp_width or frame.shape[0] != self.mp_height:
                    frame = cv2.resize(frame, (self.mp_width, self.mp_height), interpolation=cv2.INTER_AREA)
                landmarks = processor.process(frame)
                face = landmarks.get('face', [])
                if face:
                    self.lmk1_writer.write_landmarks([(p['x'], p['y'], p['z']) for p in face], timestamp, frame_id)
                else:
                    self.lmk1_writer.write_empty(timestamp, frame_id)
                self.last_inference_time = (time.perf_counter() - start) * 1000
                self.total_inference_time += self.last_inference_time
                self.frames_processed += 1
                with self._lock:
                    self._snapshot = {'landmarks': landmarks, 'frame_id': frame_id, 'timestamp': timestamp}
        except Exception as exc:
            self.error = str(exc)
            logger.exception('Tracking worker stopped')
        finally:
            if processor:
                processor.cleanup()
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
        return {'enabled': self.enabled, 'features': self.get_enabled_tracking(),
                'running': self.running, 'frames_processed': self.frames_processed,
                'frames_dropped': self.frames_dropped, 'last_inference_ms': self.last_inference_time,
                'avg_inference_ms': average, 'processing_time': self.last_inference_time,
                'fps': self.frames_processed / max(time.monotonic() - self.started_at, 0.001), 'queue_size': self.frame_queue.qsize(),
                'face_detected': count > 0, 'landmark_count': count, 'error': self.error}

    def set_enabled(self, enabled):
        self.enabled = bool(enabled)

    def stop(self):
        self._stop_event.set()
        if self.ident is not None:
            self.join(timeout=10)
            if self.is_alive():
                raise RuntimeError('Tracking worker did not stop; its ring buffer must remain open')
