from flask import Blueprint, jsonify, request
from tracking.calibration import analyzer, fit_shape

bp=Blueprint('calibration',__name__)

@bp.post('/sample')
def sample():
    from . import streaming
    camera=streaming._active_camera
    if not camera or not camera.is_opened(): return jsonify(error='Start camera capture first.'),409
    frame=camera.wait_frame(timeout=.1)
    if frame is None: return jsonify(error='Waiting for a camera frame.'),409
    try:
        return jsonify(analyzer.analyze(frame[2],frame[0]))
    except (ValueError,RuntimeError,OSError) as exc:
        return jsonify(error=str(exc)),400

@bp.post('/fit')
def fit():
    try:
        data=request.get_json()
        if not isinstance(data,dict): raise ValueError('Supply calibration observations.')
        return jsonify(profile=fit_shape(data.get('observations',[]),data.get('initial',[])))
    except (ValueError,KeyError,TypeError) as exc:
        return jsonify(error=str(exc)),400

@bp.post('/stop')
def stop():
    analyzer.close()
    return jsonify(success=True)
