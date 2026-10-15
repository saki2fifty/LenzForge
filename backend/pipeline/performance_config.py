"""Settings consumed by capture and the shared browser preview encoder."""
from dataclasses import asdict, dataclass, replace
import math


@dataclass
class PerformanceConfig:
    mediapipe_max_width: int = 640
    preview_max_fps: int = 30
    preview_quality: int = 85
    preview_scale: float = 1.0

    def get_preview_resolution(self, width, height):
        return max(2, int(width * self.preview_scale) // 2 * 2), max(2, int(height * self.preview_scale) // 2 * 2)

    def to_dict(self):
        return asdict(self)


_config = PerformanceConfig()


def get_performance_config():
    return _config


def update_performance_config(data):
    global _config
    if not isinstance(data, dict) or not data or any(key not in _config.to_dict() for key in data):
        raise ValueError('Supply mediapipe_max_width, preview_max_fps, preview_quality, or preview_scale')
    for key, value in data.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError(f'{key} must be a finite number')
        if key != 'preview_scale' and type(value) is not int:
            raise ValueError(f'{key} must be an integer')
    candidate = replace(_config, **data)
    if candidate.mediapipe_max_width not in (0, 480, 640, 960):
        raise ValueError('mediapipe_max_width must be 0, 480, 640, or 960')
    if not 1 <= candidate.preview_max_fps <= 120 or not 1 <= candidate.preview_quality <= 100 or not .1 <= candidate.preview_scale <= 1:
        raise ValueError('Use preview_max_fps 1–120, preview_quality 1–100, and preview_scale 0.1–1')
    _config = candidate  # Publish a complete validated configuration atomically.
    return candidate
