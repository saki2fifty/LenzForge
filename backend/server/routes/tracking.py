"""Tracking controls and measurements from the shared inference worker."""
from flask import Blueprint, jsonify, request
from pipeline.tracking_config import get_tracking_config, update_tracking_config
from tracking.models import library

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


@bp.get('/configure')
def get_configuration():
    config, revision = get_tracking_config()
    return jsonify(success=True, config=config.to_dict(), revision=revision)


@bp.post('/configure')
def configure_tracking():
    try:
        config, revision = update_tracking_config(request.get_json(silent=True))
        return jsonify(success=True, config=config.to_dict(), revision=revision)
    except (TypeError, ValueError) as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400


@bp.post('/reset')
def reset_tracking():
    config, revision = update_tracking_config(reset=True)
    return jsonify(success=True, config=config.to_dict(), revision=revision)


@bp.get('/models')
def get_models():
    return jsonify(success=True, **library.snapshot())


@bp.post('/models/download')
def download_model():
    try:
        data = request.get_json(silent=True)
        if not isinstance(data, dict): raise ValueError('Supply a model id')
        return jsonify(success=True, job=library.download(data.get('id'))), 202
    except ValueError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 409


@bp.post('/models/import')
def import_model():
    try:
        upload = request.files.get('file')
        source = upload.stream if upload else request.stream
        kind = request.form.get('kind') if upload else request.args.get('kind')
        filename = upload.filename if upload else request.args.get('name', '')
        return jsonify(success=True, job=library.import_stream(source, kind, filename)), 202
    except ValueError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 409
