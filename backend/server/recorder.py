"""Bounded-memory recording, serialized with stop/start and frame publication."""
import json
from pathlib import Path
import threading
import time
import uuid
import cv2
from ipc.qpc import get_qpc_frequency


class Recorder:
    def __init__(self, directory=None):
        self.directory = Path(directory) if directory else Path(__file__).resolve().parents[2] / 'recordings'
        self._lock = threading.RLock()
        self.video = self.landmarks = None
        self.active = False
        self.frames = 0
        self.paths = []
        self.error = None

    def start(self, width, height, fps, include_video=True, include_landmarks=True):
        with self._lock:
            if self.active:
                raise ValueError('A recording is already active')
            if not include_video and not include_landmarks:
                raise ValueError('Select video or landmarks to record')
            self.directory.mkdir(parents=True, exist_ok=True)
            stem = time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]
            self.paths, self.frames, self.error = [], 0, None
            self.fps, self.first_timestamp = fps, None
            try:
                if include_video:
                    path = self.directory / (stem + '.avi')
                    self.video = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*'MJPG'), fps, (width, height))
                    if not self.video.isOpened():
                        raise RuntimeError('MJPEG video encoder could not be opened')
                    self.paths.append(str(path))
                if include_landmarks:
                    path = self.directory / (stem + '.jsonl')
                    self.landmarks = path.open('w', encoding='utf-8')
                    self.paths.append(str(path))
                self.active = True
                return self.status()
            except Exception:
                self.stop()
                raise

    def write(self, frame, timestamp, landmarks):
        with self._lock:
            if not self.active:
                return
            try:
                if self.first_timestamp is None:
                    self.first_timestamp = timestamp
                elapsed = (timestamp - self.first_timestamp) / get_qpc_frequency()
                target = int(elapsed * self.fps) + 1
                # Preserve recording duration when preview work skips a capture frame.
                if target - self.frames > self.fps * 10:
                    raise RuntimeError('Recording interrupted by a capture gap over 10 seconds')
                while self.frames < target:
                    if self.video:
                        self.video.write(frame)
                    self.frames += 1
                if self.landmarks:
                    self.landmarks.write(json.dumps({'seconds': elapsed, 'landmarks': landmarks}) + '\n')
            except Exception as exc:
                self.error = str(exc)
                self.stop()

    def stop(self):
        with self._lock:
            self.active = False
            if self.video:
                self.video.release()
                self.video = None
            if self.landmarks:
                self.landmarks.close()
                self.landmarks = None
            return self.status()

    def status(self):
        with self._lock:
            return {'recording': self.active, 'frames_recorded': self.frames, 'files': self.paths, 'error': self.error}
