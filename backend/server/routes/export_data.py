"""
Export Data API Routes
Handles data export operations: frame, landmarks, recording
"""

from flask import Blueprint, jsonify, request, send_file
import cv2
import numpy as np
from io import BytesIO
import json
import time

bp = Blueprint('export_data', __name__)

# Global state
_current_frame = None
_current_landmarks = None
from ..recorder import Recorder
recorder = Recorder()


def set_current_frame(frame):
    """Set the current frame for export"""
    global _current_frame
    _current_frame = frame


def set_current_landmarks(landmarks):
    """Set the current landmarks for export"""
    global _current_landmarks
    _current_landmarks = landmarks


@bp.route('/frame', methods=['GET'])
def export_frame():
    """
    GET /api/export/frame
    Get current frame as image

    Query Parameters:
    - format: 'jpeg' or 'png' (default: 'jpeg')
    - quality: 1-100 for JPEG (default: 85)

    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if _current_frame is None:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_FRAME',
                    'message': 'No frame available'
                }
            }), 404

        # Get parameters
        format_type = request.args.get('format', 'jpeg').lower()
        quality = int(request.args.get('quality', 85))

        # Encode frame
        if format_type == 'png':
            success, buffer = cv2.imencode('.png', _current_frame)
            mime_type = 'image/png'
        else:  # jpeg
            encode_params = [cv2.IMWRITE_JPEG_QUALITY, quality]
            success, buffer = cv2.imencode('.jpg', _current_frame, encode_params)
            mime_type = 'image/jpeg'

        if not success:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'ENCODE_ERROR',
                    'message': 'Failed to encode frame'
                }
            }), 500

        # Create BytesIO object
        img_io = BytesIO(buffer.tobytes())
        img_io.seek(0)

        return send_file(
            img_io,
            mimetype=mime_type,
            as_attachment=True,
            download_name=f'frame_{int(time.time())}.{format_type}'
        )

    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'FRAME_EXPORT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/landmarks', methods=['GET'])
def export_landmarks():
    """
    GET /api/export/landmarks
    Export current landmarks as JSON

    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if _current_landmarks is None:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_LANDMARKS',
                    'message': 'No landmarks available'
                }
            }), 404

        return jsonify({
            'timestamp': time.time(),
            'landmarks': _current_landmarks
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'LANDMARKS_EXPORT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.post('/recording/start')
def start_recording():
    from .camera import _current_camera
    if not _current_camera or not _current_camera.is_opened():
        return jsonify(success=False, error={'message': 'Start a source first'}), 409
    data = request.get_json(silent=True) or {}
    try:
        result = recorder.start(_current_camera.width, _current_camera.height, _current_camera.fps,
            data.get('include_video', True), data.get('include_landmarks', True))
        return jsonify(success=True, **result)
    except (ValueError, RuntimeError) as exc:
        return jsonify(success=False, error={'message': str(exc)}), 409

@bp.post('/recording/stop')
def stop_recording():
    return jsonify(success=True, **recorder.stop())

@bp.get('/recording/status')
def recording_status():
    return jsonify(success=True, **recorder.status())
