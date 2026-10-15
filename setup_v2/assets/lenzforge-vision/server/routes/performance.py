"""
Performance Configuration Routes
API endpoints for managing performance settings
"""
from flask import Blueprint, jsonify, request
import logging
from pipeline.performance_config import get_performance_config

performance_bp = Blueprint('performance', __name__)
logger = logging.getLogger(__name__)


@performance_bp.route('/api/performance/config', methods=['GET'])
def get_config():
    """
    Get current performance configuration
    
    Returns:
        JSON with all performance settings
    """
    try:
        config = get_performance_config()
        return jsonify({
            'success': True,
            'config': config.to_dict()
        })
    except Exception as e:
        logger.error(f"Error getting performance config: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@performance_bp.route('/api/performance/config', methods=['POST'])
def update_config():
    """
    Update performance configuration
    
    Request body should contain configuration parameters:
    {
        "mediapipe_max_width": 640,      // MediaPipe resolution (480, 640, 960, 0=full)
        "preview_max_fps": 30,            // Preview FPS limit (15, 30, 60)
        "preview_quality": 85,            // JPEG quality (70-95)
        "preview_scale": 1.0,             // Preview scale (0.25-1.0)
        "enable_triple_buffer": true,     // Triple buffering
        "max_queue_size": 3               // Queue size
    }
    
    Returns:
        JSON with success status and updated config
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        config = get_performance_config()
        
        # Validate and update MediaPipe resolution
        if 'mediapipe_max_width' in data:
            width = int(data['mediapipe_max_width'])
            if width not in [0, 480, 640, 960]:
                return jsonify({
                    'success': False,
                    'error': 'mediapipe_max_width must be 0, 480, 640, or 960'
                }), 400
            config.mediapipe_max_width = width
            logger.info(f"Updated MediaPipe max width: {width}")
        
        # Validate and update preview FPS
        if 'preview_max_fps' in data:
            fps = int(data['preview_max_fps'])
            if fps < 1 or fps > 120:
                return jsonify({
                    'success': False,
                    'error': 'preview_max_fps must be between 1 and 120'
                }), 400
            config.preview_max_fps = fps
            logger.info(f"Updated preview max FPS: {fps}")
        
        # Validate and update JPEG quality
        if 'preview_quality' in data:
            quality = int(data['preview_quality'])
            if quality < 1 or quality > 100:
                return jsonify({
                    'success': False,
                    'error': 'preview_quality must be between 1 and 100'
                }), 400
            config.preview_quality = quality
            logger.info(f"Updated preview quality: {quality}")
        
        # Validate and update preview scale
        if 'preview_scale' in data:
            scale = float(data['preview_scale'])
            if scale < 0.1 or scale > 1.0:
                return jsonify({
                    'success': False,
                    'error': 'preview_scale must be between 0.1 and 1.0'
                }), 400
            config.preview_scale = scale
            logger.info(f"Updated preview scale: {scale}")
        
        # Update triple buffering
        if 'enable_triple_buffer' in data:
            config.enable_triple_buffer = bool(data['enable_triple_buffer'])
            logger.info(f"Updated triple buffer: {config.enable_triple_buffer}")
        
        # Validate and update queue size
        if 'max_queue_size' in data:
            size = int(data['max_queue_size'])
            if size < 1 or size > 10:
                return jsonify({
                    'success': False,
                    'error': 'max_queue_size must be between 1 and 10'
                }), 400
            config.max_queue_size = size
            logger.info(f"Updated max queue size: {size}")
        
        return jsonify({
            'success': True,
            'message': 'Performance configuration updated',
            'config': config.to_dict()
        })
        
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': f'Invalid value: {str(e)}'
        }), 400
    except Exception as e:
        logger.error(f"Error updating performance config: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@performance_bp.route('/api/performance/presets', methods=['GET'])
def get_presets():
    """
    Get performance presets
    
    Returns:
        JSON with available performance presets
    """
    presets = {
        'maximum_quality': {
            'name': 'Maximum Quality',
            'description': 'Best quality, higher CPU usage',
            'mediapipe_max_width': 0,      # Full resolution
            'preview_max_fps': 60,
            'preview_quality': 95,
            'preview_scale': 1.0,
            'enable_triple_buffer': True,
            'max_queue_size': 3
        },
        'balanced': {
            'name': 'Balanced',
            'description': 'Good quality and performance',
            'mediapipe_max_width': 640,
            'preview_max_fps': 30,
            'preview_quality': 85,
            'preview_scale': 1.0,
            'enable_triple_buffer': True,
            'max_queue_size': 3
        },
        'maximum_performance': {
            'name': 'Maximum Performance',
            'description': 'Best performance, lower quality',
            'mediapipe_max_width': 480,
            'preview_max_fps': 30,
            'preview_quality': 75,
            'preview_scale': 0.5,
            'enable_triple_buffer': True,
            'max_queue_size': 2
        },
        'low_bandwidth': {
            'name': 'Low Bandwidth',
            'description': 'Optimized for slow connections',
            'mediapipe_max_width': 480,
            'preview_max_fps': 15,
            'preview_quality': 70,
            'preview_scale': 0.25,
            'enable_triple_buffer': False,
            'max_queue_size': 2
        }
    }
    
    return jsonify({
        'success': True,
        'presets': presets
    })


@performance_bp.route('/api/performance/preset/<preset_name>', methods=['POST'])
def apply_preset(preset_name):
    """
    Apply a performance preset
    
    Args:
        preset_name: Name of preset to apply
        
    Returns:
        JSON with success status and updated config
    """
    try:
        # Get presets
        presets_response = get_presets()
        presets = presets_response.get_json()['presets']
        
        if preset_name not in presets:
            return jsonify({
                'success': False,
                'error': f'Unknown preset: {preset_name}'
            }), 404
        
        # Apply preset
        preset = presets[preset_name]
        config = get_performance_config()
        config.from_dict(preset)
        
        logger.info(f"Applied performance preset: {preset_name}")
        
        return jsonify({
            'success': True,
            'message': f'Applied preset: {preset["name"]}',
            'config': config.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error applying preset: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
