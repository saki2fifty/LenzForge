"""
Statistics API Routes
Provides specialized endpoints for different stat categories
"""
from flask import Blueprint, jsonify
import psutil
import time
import logging

bp = Blueprint('stats', __name__)
logger = logging.getLogger(__name__)

# Import route modules to access their globals
from . import streaming

_start_time = time.time()


@bp.route('/system/stats', methods=['GET'])
def get_system_stats():
    """
    GET /api/system/stats
    Get system resource statistics
    
    Returns CPU, memory, uptime, and process info
    """
    try:
        uptime = time.time() - _start_time
        
        # System metrics
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        memory_mb = memory.used / (1024 * 1024)
        memory_percent = memory.percent
        
        # Process info
        process = psutil.Process()
        process_memory = process.memory_info().rss / (1024 * 1024)
        process_threads = process.num_threads()
        
        return jsonify({
            'success': True,
            'data': {
                'cpu_percent': round(cpu_percent, 1),
                'memory_mb': round(memory_mb, 1),
                'memory_percent': round(memory_percent, 1),
                'memory_total_mb': round(memory.total / (1024 * 1024), 1),
                'uptime_seconds': round(uptime, 2),
                'process_memory_mb': round(process_memory, 1),
                'process_threads': process_threads
            }
        })
    
    except Exception as e:
        logger.error(f"Error getting system stats: {e}")
        return jsonify({
            'success': False,
            'error': {
                'code': 'SYSTEM_STATS_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/camera/stats', methods=['GET'])
def get_camera_stats():
    """
    GET /api/camera/stats
    Get camera capture statistics
    
    Returns camera state, resolution, FPS, frame timing
    """
    try:
        camera = streaming._active_camera
        
        if camera is None:
            return jsonify({
                'success': True,
                'data': {
                    'active': False,
                    'index': None,
                    'name': None,
                    'resolution': None,
                    'fps': 0,
                    'frame_time_ms': 0,
                    'total_frames': 0
                }
            })
        
        # Camera properties
        index = getattr(camera, 'index', 0)
        name = getattr(camera, 'name', 'Unknown Camera')
        width = getattr(camera, 'width', 0)
        height = getattr(camera, 'height', 0)
        
        # FPS and timing
        fps = streaming._fps
        frame_time = (1000.0 / fps) if fps > 0 else 0
        
        # Try to get additional camera stats
        total_frames = 0
        dropped_frames = 0
        drop_rate = 0
        
        if hasattr(camera, 'get_stats'):
            try:
                cam_stats = camera.get_stats()
                total_frames = cam_stats.get('total_frames', 0)
                dropped_frames = cam_stats.get('dropped_frames', 0)
                drop_rate = cam_stats.get('drop_rate', 0)
            except:
                pass
        
        return jsonify({
            'success': True,
            'data': {
                'active': True,
                'index': index,
                'name': name,
                'resolution': {
                    'width': width,
                    'height': height
                },
                'fps': round(fps, 1),
                'frame_time_ms': round(frame_time, 1),
                'total_frames': total_frames,
                'dropped_frames': dropped_frames,
                'drop_rate_percent': round(drop_rate, 2)
            }
        })
    
    except Exception as e:
        logger.error(f"Error getting camera stats: {e}")
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_STATS_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/mediapipe/stats', methods=['GET'])
def get_mediapipe_stats():
    """
    GET /api/mediapipe/stats
    Get MediaPipe processing statistics
    
    Returns processing FPS, detections, landmark counts
    """
    try:
        processor = streaming._processor
        landmark_data = streaming._landmark_data
        
        # Default values
        processing_fps = 0
        face_detected = False
        landmark_count = 0
        confidence = 0
        processing_time_ms = 0
        queue_size = 0
        
        # Try to get processor stats
        if processor is not None:
            if hasattr(processor, 'get_stats'):
                try:
                    mp_stats = processor.get_stats()
                    processing_fps = mp_stats.get('fps', 0)
                    face_detected = mp_stats.get('face_detected', False)
                    landmark_count = mp_stats.get('landmark_count', 0)
                    confidence = mp_stats.get('confidence', 0)
                    processing_time_ms = mp_stats.get('processing_time', 0)
                    queue_size = mp_stats.get('queue_size', 0)
                except Exception as e:
                    logger.debug(f"Processor get_stats not available: {e}")
        
        # Fallback: check landmark data directly
        if landmark_data:
            if 'face' in landmark_data and landmark_data['face']:
                face_detected = True
                landmark_count = len(landmark_data['face'])
                # Try to get average confidence
                confidences = [lm.get('confidence', 0) for lm in landmark_data['face'] if 'confidence' in lm]
                if confidences:
                    confidence = sum(confidences) / len(confidences)
        
        return jsonify({
            'success': True,
            'data': {
                'active': processor is not None,
                'processing_fps': round(processing_fps, 1),
                'face_detected': face_detected,
                'landmark_count': landmark_count,
                'average_confidence': round(confidence, 3),
                'processing_time_ms': round(processing_time_ms, 1),
                'queue_size': queue_size
            }
        })
    
    except Exception as e:
        logger.error(f"Error getting MediaPipe stats: {e}")
        return jsonify({
            'success': False,
            'error': {
                'code': 'MEDIAPIPE_STATS_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/ringbuffer/stats', methods=['GET'])
def get_ringbuffer_stats():
    """
    GET /api/ringbuffer/stats
    Get ring buffer health and statistics
    
    Returns VID1 and LMK1 buffer states, sequences, health
    """
    try:
        camera = streaming._active_camera
        
        vid1_stats = None
        lmk1_stats = None
        
        if camera is not None:
            # VID1 ring buffer stats
            if hasattr(camera, 'ring_writer'):
                try:
                    ring_stats = camera.ring_writer.get_stats()
                    vid1_stats = {
                        'write_sequence': ring_stats.get('wr_seq', 0),
                        'slot_count': ring_stats.get('slot_count', 8),
                        'slot_stride': ring_stats.get('slot_stride', 0),
                        'y_stride': ring_stats.get('y_stride', 0),
                        'uv_stride': ring_stats.get('uv_stride', 0),
                        'qpc_freq': ring_stats.get('qpc_freq', 0),
                        'buffer_health': 'healthy' if ring_stats.get('wr_seq', 0) > 0 else 'idle'
                    }
                except Exception as e:
                    logger.debug(f"VID1 ring stats not available: {e}")
            
            # LMK1 ring buffer stats
            if hasattr(camera, 'landmark_writer'):
                try:
                    lmk_stats = camera.landmark_writer.get_stats()
                    lmk1_stats = {
                        'write_sequence': lmk_stats.get('wr_seq', 0),
                        'landmark_count': lmk_stats.get('landmark_count', 478),
                        'slot_count': lmk_stats.get('slot_count', 8),
                        'buffer_health': 'healthy' if lmk_stats.get('wr_seq', 0) > 0 else 'idle'
                    }
                except Exception as e:
                    logger.debug(f"LMK1 ring stats not available: {e}")
        
        return jsonify({
            'success': True,
            'data': {
                'vid1': vid1_stats,
                'lmk1': lmk1_stats,
                'active': camera is not None
            }
        })
    
    except Exception as e:
        logger.error(f"Error getting ring buffer stats: {e}")
        return jsonify({
            'success': False,
            'error': {
                'code': 'RINGBUFFER_STATS_ERROR',
                'message': str(e)
            }
        }), 500
