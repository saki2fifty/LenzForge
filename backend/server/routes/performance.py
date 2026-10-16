"""Preview quality controls and live inference resolution."""
from flask import Blueprint, jsonify, request
from pipeline.performance_config import get_performance_config, update_performance_config
from pipeline.tracking_config import get_tracking_config

performance_bp = Blueprint('performance', __name__)
PRESETS = {
    'maximum_quality': dict(mediapipe_max_width=0, preview_max_fps=60, preview_quality=95, preview_scale=1.0),
    'balanced': dict(mediapipe_max_width=640, preview_max_fps=30, preview_quality=85, preview_scale=1.0),
    'maximum_performance': dict(mediapipe_max_width=480, preview_max_fps=30, preview_quality=75, preview_scale=.5),
    'low_bandwidth': dict(mediapipe_max_width=480, preview_max_fps=15, preview_quality=70, preview_scale=.25),
}


@performance_bp.get('/api/performance/config')
def get_config():
    data = get_performance_config().to_dict()
    data['mediapipe_max_width'] = get_tracking_config()[0].max_width
    return jsonify(success=True, config=data)


def apply(data):
    try:
        config = update_performance_config(data)
        return jsonify(success=True, config=config.to_dict(), restart_capture=False)
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
