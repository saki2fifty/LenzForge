"""
Configuration API Routes
Handles configuration operations: get, update, save, load
"""

from flask import Blueprint, jsonify, request
import json
from pathlib import Path

bp = Blueprint('configuration', __name__)

# Global configuration
_current_config = {
    'camera_index': 0,
    'resolution': [640, 480],
    'target_fps': 30,
    'camera_preferences': {},
    'tracking': {
        'enable_face_mesh': True,
        'enable_iris': True,
        'enable_hands': False,
        'enable_pose': False
    },
    'ipc': {
        'enable_landmarks_ring': True,
        'enable_video_ring': True,
        'landmarks_ring_name': 'LenzForge_Landmarks',
        'video_ring_name': 'LenzForge_Video'
    }
}


@bp.route('/', methods=['GET'])
def get_config():
    """
    GET /api/config
    Get complete system configuration
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        return jsonify(_current_config)
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CONFIG_GET_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/', methods=['POST'])
def update_config():
    """
    POST /api/config
    Update system configuration
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        # Update configuration
        global _current_config
        
        # Update top-level keys
        for key in ['camera_index', 'resolution', 'target_fps', 'camera_preferences']:
            if key in data:
                _current_config[key] = data[key]
        
        # Update nested keys
        if 'tracking' in data:
            _current_config['tracking'].update(data['tracking'])
        
        if 'ipc' in data:
            _current_config['ipc'].update(data['ipc'])
        
        return jsonify({
            'success': True,
            'message': 'Configuration updated',
            'config': _current_config
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CONFIG_UPDATE_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/save', methods=['POST'])
def save_config():
    """
    POST /api/config/save
    Save current configuration to file
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json() or {}
        filename = data.get('filename', 'config.json')
        
        # Ensure .json extension
        if not filename.endswith('.json'):
            filename += '.json'
        
        # Save to file
        config_path = Path(filename)
        with open(config_path, 'w') as f:
            json.dump(_current_config, f, indent=2)
        
        return jsonify({
            'success': True,
            'message': 'Configuration saved',
            'filename': filename,
            'path': str(config_path.absolute())
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CONFIG_SAVE_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/load', methods=['POST'])
def load_config():
    """
    POST /api/config/load
    Load configuration from file
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        filename = data.get('filename')
        
        if not filename:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'filename is required'
                }
            }), 400
        
        # Load from file
        config_path = Path(filename)
        
        if not config_path.exists():
            return jsonify({
                'success': False,
                'error': {
                    'code': 'FILE_NOT_FOUND',
                    'message': f'Configuration file "{filename}" not found'
                }
            }), 404
        
        with open(config_path, 'r') as f:
            loaded_config = json.load(f)
        
        # Update current configuration
        global _current_config
        _current_config = loaded_config
        
        return jsonify({
            'success': True,
            'message': 'Configuration loaded',
            'filename': filename,
            'config': _current_config
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CONFIG_LOAD_ERROR',
                'message': str(e)
            }
        }), 500
