"""Conservative OpenCV device probing; enumeration is explicit and cached."""
from dataclasses import dataclass
import threading
import time
import cv2


@dataclass
class CameraInfo:
    id: int
    name: str
    backend: str = 'MSMF'
    supported_resolutions: list = None


_cache = []
_checked = -60.0
_lock = threading.Lock()


def enumerate_cameras(max_check=5):
    global _cache, _checked
    with _lock:
        if time.monotonic() - _checked < 30:
            return list(_cache)
        found = []
        for index in range(max_check):
            camera = cv2.VideoCapture(index, cv2.CAP_MSMF)
            try:
                if camera.isOpened():
                    found.append(CameraInfo(index, f'Camera {index}'))
            finally:
                camera.release()
        _cache, _checked = found, time.monotonic()
        return list(found)
