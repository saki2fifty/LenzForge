"""
System API Routes
Handles system-level operations: status, start, stop, restart, info, logging
"""

from flask import Blueprint, jsonify, request
import psutil
import time
import logging
from datetime import datetime

bp = Blueprint('system', __name__)

# Global state (will be replaced with proper state manager)
_start_time = time.time()
_pipeline_running = False
_pipeline_manager = None
_config_manager = None


def set_pipeline_manager(manager):
    """Set the pipeline manager instance"""
    global _pipeline_manager
    _pipeline_manager = manager


def set_config_manager(manager):
    """Set the config manager instance"""
    global _config_manager
    _config_manager = manager


def apply_logging_config(config):
    """Apply logging levels per category"""
    if not config.get('master_enabled', True):
        logging.disable(logging.CRITICAL)
        return

    logging.disable(logging.NOTSET)

    categories = config.get('categories', {})

    logger_map = {
        'mediapipe': ['mediapipe', 'absl'],
        'matplotlib': ['matplotlib', 'PIL'],
        'camera': ['CAMERA', 'capture', 'cap_msmf'],
        'streaming': ['streaming', 'pipeline', 'web_processor'],
        'tracking': ['tracking'],
        'system': ['__main__', 'server', 'app'],
        'werkzeug': ['werkzeug']
    }

    for category, enabled in categories.items():
        level = logging.INFO if enabled else logging.ERROR
        for logger_name in logger_map.get(category, []):
            logging.getLogger(logger_name).setLevel(level)


@bp.get('/status')
def get_status():
    from .streaming import stream_stats
    return stream_stats()

@bp.route('/logging/config', methods=['GET'])
def get_logging_config():
    """
    GET /api/logging/config
    Get current logging configuration

    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if _config_manager:
            config = _config_manager.get('logging_config', {
                'master_enabled': True,
                'categories': {
                    'mediapipe': True,
                    'matplotlib': True,
                    'camera': True,
                    'streaming': True,
                    'tracking': True,
                    'system': True,
                    'werkzeug': True
                }
            })
        else:
            config = {
                'master_enabled': True,
                'categories': {
                    'mediapipe': True,
                    'matplotlib': True,
                    'camera': True,
                    'streaming': True,
                    'tracking': True,
                    'system': True,
                    'werkzeug': True
                }
            }

        return jsonify(config)

    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'GET_LOGGING_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/logging/config', methods=['POST'])
def set_logging_config():
    """
    POST /api/logging/config
    Update and apply logging configuration

    Request Body:
    {
        "master_enabled": true,
        "categories": {
            "mediapipe": false,
            "matplotlib": false,
            ...
        }
    }

    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        config = request.json

        if not config:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_CONFIG',
                    'message': 'No configuration provided'
                }
            }), 400

        if _config_manager:
            _config_manager.set('logging_config', config)

        apply_logging_config(config)

        return jsonify({
            'success': True,
            'message': 'Logging configuration updated'
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SET_LOGGING_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/info', methods=['GET'])
def get_info():
    """
    GET /api/info
    Get detailed system information

    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        import sys
        import cv2
        import numpy as np

        # Try to import MediaPipe
        try:
            import mediapipe as mp
            mp_version = mp.__version__
        except ImportError:
            mp_version = 'Not installed'

        return jsonify({
            'version': '3.0.0',
                        'python_version': f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            'mediapipe_version': mp_version,
            'opencv_version': cv2.__version__,
            'numpy_version': np.__version__,
            'capabilities': {
                'tracking_types': ['face', 'iris', 'hands', 'pose'],
                'effects_count': 47,
                'max_resolution': [3840, 2160],
                'max_fps': 120
            }
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'INFO_ERROR',
                'message': str(e)
            }
        }), 500


@bp.post('/start')
def start_pipeline():
    from .camera import select_camera
    return select_camera()

@bp.post('/stop')
def stop_pipeline():
    from .camera import stop_camera
    return stop_camera()

@bp.post('/restart')
def restart_pipeline():
    from .camera import configure_camera
    return configure_camera()
