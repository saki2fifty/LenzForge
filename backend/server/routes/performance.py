"""Preview quality controls; inference resolution takes effect on capture restart."""
from flask import Blueprint, jsonify, request
from pipeline.performance_config import get_performance_config, update_performance_config

performance_bp = Blueprint('performance', __name__)
PRESETS = {
    'maximum_quality': dict(mediapipe_max_width=0, preview_max_fps=60, preview_quality=95, preview_scale=1.0),
    'balanced': dict(mediapipe_max_width=640, preview_max_fps=30, preview_quality=85, preview_scale=1.0),
    'maximum_performance': dict(mediapipe_max_width=480, preview_max_fps=30, preview_quality=75, preview_scale=.5),
    'low_bandwidth': dict(mediapipe_max_width=480, preview_max_fps=15, preview_quality=70, preview_scale=.25),
}


@performance_bp.get('/api/performance/config')
def get_config():
    return jsonify(success=True, config=get_performance_config().to_dict())


def apply(data):
    try:
        config = update_performance_config(data)
        return jsonify(success=True, config=config.to_dict(), restart_capture='mediapipe_max_width' in data)
    except (TypeError, ValueError) as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400


@performance_bp.post('/api/performance/config')
def update_config():
    return apply(request.get_json(silent=True))


@performance_bp.get('/api/performance/presets')
def get_presets():
    return jsonify(success=True, presets=PRESETS)


@performance_bp.post('/api/performance/preset/<name>')
def apply_preset(name):
    if name not in PRESETS:
        return jsonify(success=False, error={'message': 'Unknown preset'}), 404
    return apply(PRESETS[name])
