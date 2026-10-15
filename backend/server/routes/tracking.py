"""Tracking controls and measurements from the shared inference worker."""
from flask import Blueprint, jsonify, request

bp = Blueprint('tracking', __name__)
FEATURES = {'face_mesh': 'face', 'iris': 'iris', 'hands': 'hands', 'pose': 'pose'}
_tracking_stats = {name: {'enabled': name in ('face_mesh', 'iris')} for name in FEATURES}


def requested_features():
    return {feature: _tracking_stats[name]['enabled'] for name, feature in FEATURES.items()}


@bp.get('/status')
def get_status():
    from .streaming import get_processor
    processor = get_processor()
    return jsonify(features=requested_features(), worker=processor.get_stats() if processor else None)


@bp.post('/enable')
def enable_tracking():
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not data or any(key not in FEATURES or type(value) is not bool for key, value in data.items()):
        return jsonify(success=False, error={'message': 'Supply boolean face_mesh, iris, hands, or pose values'}), 400
    from .streaming import get_processor
    processor = get_processor()
    for name, enabled in data.items():
        _tracking_stats[name]['enabled'] = enabled
        if processor:
            processor.enable_tracking(FEATURES[name], enabled)
    return jsonify(success=True, features=requested_features())


@bp.get('/landmarks')
def get_landmarks():
    from .streaming import get_processor
    processor = get_processor()
    return jsonify(processor.get_snapshot() if processor else {'landmarks': {}, 'frame_id': -1, 'timestamp': 0})


@bp.get('/statistics')
def get_statistics():
    from .streaming import get_processor
    processor = get_processor()
    return jsonify(processor.get_stats() if processor else {'running': False, 'frames_processed': 0})


@bp.post('/configure')
@bp.post('/reset')
def unsupported_legacy_control():
    return jsonify(success=False, error={'message': 'Use /enable for feature toggles; restart capture to recreate the tracking models. Runtime model configuration is not implemented.'}), 501
