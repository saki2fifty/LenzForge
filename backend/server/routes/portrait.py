"""Small binary foreground masks for desktop GPU composition."""
from flask import Blueprint, Response, jsonify, request
from tracking.portrait_mask import MODELS, PortraitWorker
from . import streaming

bp = Blueprint('portrait', __name__)
worker = PortraitWorker(lambda: streaming._active_camera)


@bp.post('/mask')
def mask():
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or data.get('rate') not in (15, 30, 60) or not isinstance(data.get('source'), str):
        return jsonify(error='Supply a capture source and mask rate (15, 30 or 60).'), 400
    quality = data.get('quality', 'fast')
    if not isinstance(quality, str) or quality not in MODELS:
        return jsonify(error='Choose fast or balanced person detection.'), 400
    camera = streaming._active_camera
    if not camera or not camera.is_opened() or camera.video_buffer != data['source']:
        return jsonify(state='Waiting for the current camera source.'), 409
    packet, status = worker.request(data['source'], data['rate'], quality)
    if packet is None: return jsonify(status), 503 if status['error'] else 202
    return Response(packet, mimetype='application/octet-stream', headers={
        'Cache-Control':'no-store', 'X-LenzForge-Source':data['source'], 'X-LenzForge-Mask-Quality':quality})


@bp.post('/stop')
def stop():
    worker.stop()
    return jsonify(success=True)
