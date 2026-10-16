"""Validated live tracking settings, shared across capture sessions."""
from dataclasses import asdict, dataclass, replace
import math
import threading


@dataclass(frozen=True)
class TrackingConfig:
    backend: str = 'auto'
    max_width: int = 640
    num_faces: int = 1
    detection_confidence: float = 0.5
    presence_confidence: float = 0.5
    tracking_confidence: float = 0.5
    blendshapes: bool = True
    face_transform: bool = True
    face_model: str = 'face_landmarker'
    hand_model: str = 'hand_landmarker'
    pose_model: str = 'pose_landmarker_lite'

    def to_dict(self):
        return asdict(self)

    def updated(self, changes):
        if not isinstance(changes, dict) or not changes or changes.keys() - self.to_dict().keys():
            raise ValueError('Supply supported tracking settings')
        candidate = replace(self, **changes)
        if candidate.backend not in ('auto', 'gpu', 'cpu'):
            raise ValueError('backend must be auto, gpu, or cpu')
        if type(candidate.max_width) is not int or candidate.max_width not in (320, 480, 640, 960, 0):
            raise ValueError('max_width must be 320, 480, 640, 960, or 0 (native)')
        if type(candidate.num_faces) is not int or not 1 <= candidate.num_faces <= 4:
            raise ValueError('num_faces must be an integer from 1 to 4')
        for key in ('detection_confidence', 'presence_confidence', 'tracking_confidence'):
            value = getattr(candidate, key)
            if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1:
                raise ValueError(f'{key} must be a finite number from 0 to 1')
        if type(candidate.blendshapes) is not bool or type(candidate.face_transform) is not bool:
            raise ValueError('blendshapes and face_transform must be boolean')
        from tracking.models import library
        for kind in ('face', 'hand', 'pose'):
            if kind + '_model' in changes:
                library.resolve(getattr(candidate, kind + '_model'), kind)
        return candidate


_lock = threading.Lock()
_config = TrackingConfig()
_revision = 0


def get_tracking_config():
    with _lock:
        return _config, _revision


def update_tracking_config(changes=None, reset=False):
    global _config, _revision
    with _lock:
        _config = TrackingConfig() if reset else _config.updated(changes)
        _revision += 1  # Reapplying GPU also explicitly retries a failed browser.
        return _config, _revision
