"""Measured process, capture, tracking, and shared-memory statistics."""
import time
import psutil
from flask import Blueprint, jsonify
from . import streaming

bp = Blueprint('stats', __name__)
_started = time.monotonic()


@bp.get('/system/stats')
def get_system_stats():
    process = psutil.Process()
    return jsonify(success=True, data={
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'process_memory_mb': process.memory_info().rss / 1024**2,
        'process_threads': process.num_threads(),
        'uptime_seconds': time.monotonic() - _started,
    })


@bp.get('/camera/stats')
def get_camera_stats():
    camera = streaming._active_camera
    if not camera:
        return jsonify(success=True, data={'active': False, 'total_frames': 0})
    return jsonify(success=True, data={
        'active': camera.is_opened(), 'index': camera.index, 'name': camera.name,
        'resolution': [camera.width, camera.height], 'fps': streaming._fps,
        'total_frames': camera.frame_count, 'dropped_frames': camera.stats.frames_dropped,
    })


@bp.get('/mediapipe/stats')
def get_mediapipe_stats():
    processor = streaming.get_processor()
    return jsonify(success=True, data=processor.get_stats() if processor else {'running': False})


@bp.get('/ringbuffer/stats')
def get_ringbuffer_stats():
    camera = streaming._active_camera
    return jsonify(success=True, data={
        'active': bool(camera and camera.is_opened()),
        'video': camera.video_buffer if camera else None,
        'landmarks': camera.landmark_buffer if camera else None,
        'frames_published': camera.frame_count if camera else 0,
    })
