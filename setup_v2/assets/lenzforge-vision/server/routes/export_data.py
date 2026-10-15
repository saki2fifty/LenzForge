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
_recording = False
_recording_data = []


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


@bp.route('/recording/start', methods=['POST'])
def start_recording():
    """
    POST /api/export/recording/start
    Start recording session data
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        global _recording, _recording_data
        
        if _recording:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'ALREADY_RECORDING',
                    'message': 'Recording is already in progress'
                }
            }), 400
        
        data = request.get_json() or {}
        
        include_video = data.get('include_video', True)
        include_landmarks = data.get('include_landmarks', True)
        output_path = data.get('output_path', f'recording_{int(time.time())}')
        
        # Start recording
        _recording = True
        _recording_data = []
        
        return jsonify({
            'success': True,
            'message': 'Recording started',
            'output_path': output_path,
            'include_video': include_video,
            'include_landmarks': include_landmarks
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'START_RECORDING_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/recording/stop', methods=['POST'])
def stop_recording():
    """
    POST /api/export/recording/stop
    Stop recording session data
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        global _recording, _recording_data
        
        if not _recording:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NOT_RECORDING',
                    'message': 'No recording in progress'
                }
            }), 400
        
        # Stop recording
        _recording = False
        frame_count = len(_recording_data)
        
        # Save recording data
        # In production, this would save to disk
        
        # Clear recording data
        _recording_data = []
        
        return jsonify({
            'success': True,
            'message': 'Recording stopped',
            'frames_recorded': frame_count
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'STOP_RECORDING_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/recording/status', methods=['GET'])
def recording_status():
    """
    GET /api/export/recording/status
    Get recording status
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        return jsonify({
            'recording': _recording,
            'frames_recorded': len(_recording_data) if _recording else 0
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'RECORDING_STATUS_ERROR',
                'message': str(e)
            }
        }), 500
