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


@bp.route('/status', methods=['GET'])
def get_status():
    """
    GET /api/status
    Get system status and health
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        uptime = time.time() - _start_time
        
        # Get system metrics
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        
        # Get pipeline stats if available
        pipeline_stats = {}
        if _pipeline_manager:
            pipeline_stats = {
                'fps': getattr(_pipeline_manager, 'current_fps', 0.0),
                'camera_active': getattr(_pipeline_manager, 'camera_active', False),
                'tracking_active': _pipeline_running
            }
        else:
            pipeline_stats = {
                'fps': 0.0,
                'camera_active': False,
                'tracking_active': False
            }
        
        # Get camera negotiated format (Phase 1)
        camera_info = {}
        vid1_info = {}
        qpc_freq = 0
        
        if _pipeline_manager and hasattr(_pipeline_manager, 'camera') and _pipeline_manager.camera:
            cam = _pipeline_manager.camera
            
            # Camera negotiated format
            if hasattr(cam, 'negotiated_format') and cam.negotiated_format:
                camera_info['negotiated'] = cam.negotiated_format
            
            # VID1 ring stats
            if hasattr(cam, 'ring_writer') and cam.ring_writer:
                try:
                    stats = cam.ring_writer.get_stats()
                    vid1_info = {
                        'w': cam.width,
                        'h': cam.height,
                        'y_stride': stats.get('y_stride', cam.width),
                        'uv_stride': stats.get('uv_stride', cam.width),
                        'slot_count': stats.get('slot_count', 8),
                        'slot_stride': stats.get('slot_stride', 0),
                        'wr_seq': stats.get('wr_seq', 0),
                        'rd_seq': 0,  # Reader's responsibility
                        'delta': stats.get('wr_seq', 0) - 0
                    }
                    qpc_freq = stats.get('qpc_freq', 0)
                except Exception as e:
                    logging.error(f"Error getting VID1 stats: {e}")
        
        response = {
            'status': 'running' if _pipeline_running else 'stopped',
            'version': '2.0.0',
            'uptime_seconds': round(uptime, 2),
            'backend': pipeline_stats,
            'memory_usage_mb': round(memory.used / (1024 * 1024), 2),
            'cpu_usage_percent': round(cpu_percent, 1)
        }
        
        # Add Phase 1 fields if available
        if camera_info:
            response['camera'] = camera_info
        if vid1_info:
            response['vid1'] = vid1_info
        if qpc_freq:
            response['qpc_freq'] = qpc_freq
        
        return jsonify(response)
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'STATUS_ERROR',
                'message': str(e)
            }
        }), 500


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
            'version': '2.0.0',
            'build_date': '2025-10-25',
            'python_version': f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            'mediapipe_version': mp_version,
            'opencv_version': cv2.__version__,
            'numpy_version': np.__version__,
            'capabilities': {
                'tracking_types': ['face', 'iris', 'hands', 'pose'],
                'effects_count': 47,
                'max_resolution': [1920, 1080],
                'max_fps': 60
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


@bp.route('/start', methods=['POST'])
def start_pipeline():
    """
    POST /api/start
    Start the tracking pipeline
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _pipeline_running, _pipeline_manager
    
    try:
        if _pipeline_running:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'ALREADY_RUNNING',
                    'message': 'Pipeline is already running'
                }
            }), 400
        
        # Create pipeline manager if it doesn't exist (lazy initialization)
        if not _pipeline_manager:
            try:
                logging.info("Creating pipeline manager on-demand...")
                import sys
                from pathlib import Path
                
                # Ensure backend_v2 is in path
                backend_dir = Path(__file__).parent.parent.parent
                if str(backend_dir) not in sys.path:
                    sys.path.insert(0, str(backend_dir))
                
                import backend_v2.pipeline.manager as pipeline_module
                import backend_v2.config as config_module
                
                config = config_module.get_config()
                _pipeline_manager = pipeline_module.PipelineManager(config)
                logging.info("Pipeline manager created successfully")
            except Exception as init_error:
                logging.error(f"Failed to create pipeline manager: {init_error}")
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'INIT_ERROR',
                        'message': f'Failed to initialize pipeline: {str(init_error)}'
                    }
                }), 500
        
        # Start pipeline (this should be async in production)
        _pipeline_manager.start()
        _pipeline_running = True
        
        return jsonify({
            'success': True,
            'message': 'Pipeline started',
            'fps': 30
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'START_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/stop', methods=['POST'])
def stop_pipeline():
    """
    POST /api/stop
    Stop the tracking pipeline
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _pipeline_running
    
    try:
        if not _pipeline_running:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NOT_RUNNING',
                    'message': 'Pipeline is not running'
                }
            }), 400
        
        if _pipeline_manager:
            _pipeline_manager.stop()
        
        _pipeline_running = False
        
        return jsonify({
            'success': True,
            'message': 'Pipeline stopped'
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'STOP_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/restart', methods=['POST'])
def restart_pipeline():
    """
    POST /api/restart
    Restart the tracking pipeline
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _pipeline_running
    
    try:
        # Stop if running
        if _pipeline_running and _pipeline_manager:
            _pipeline_manager.stop()
            _pipeline_running = False
            time.sleep(0.5)  # Brief pause
        
        # Start
        if _pipeline_manager:
            _pipeline_manager.start()
            _pipeline_running = True
        
        return jsonify({
            'success': True,
            'message': 'Pipeline restarted',
            'fps': 30
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'RESTART_ERROR',
                'message': str(e)
            }
        }), 500
