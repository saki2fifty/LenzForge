"""
Logging API Routes
Real-time log streaming and control
"""
from flask import Blueprint, jsonify, request
from flask_socketio import emit
import logging
import json
from datetime import datetime
from collections import deque
import threading

bp = Blueprint('logs', __name__)

# Global state
log_buffer = deque(maxlen=1000)  # Store last 1000 logs
logging_enabled = True
lock = threading.Lock()

# WebSocket namespace will be registered in app.py

class WebSocketLogHandler(logging.Handler):
    """Custom handler that buffers logs for WebSocket streaming"""

    def emit(self, record):
        global logging_enabled
        if not logging_enabled:
            return

        try:
            log_entry = {
                'timestamp': datetime.fromtimestamp(record.created).isoformat(),
                'level': record.levelname,
                'message': self.format(record),
                'module': record.module,
                'function': record.funcName
            }

            with lock:
                log_buffer.append(log_entry)

            # Emit to WebSocket clients using global socketio
            try:
                # Import socketio from server.app module
                from server.app import socketio
                socketio.emit('log', log_entry, namespace='/logs')
            except:
                pass  # Silent fail if socketio not available

        except Exception as e:
            # Don't let logging errors break the app
            pass


@bp.route('/status', methods=['GET'])
def get_status():
    """Get logging system status"""
    return jsonify({
        'enabled': logging_enabled,
        'buffer_size': len(log_buffer),
        'buffer_max': log_buffer.maxlen
    })


@bp.route('/enable', methods=['POST'])
def set_enabled():
    """Enable/disable logging"""
    global logging_enabled

    data = request.json
    if not data:
        return jsonify({'error': 'Missing request body'}), 400

    enabled = data.get('enabled', True)
    logging_enabled = enabled

    # Adjust root logger level
    root_logger = logging.getLogger()
    if enabled:
        root_logger.setLevel(logging.DEBUG)
    else:
        # Set to CRITICAL+1 to effectively disable all logging
        root_logger.setLevel(logging.CRITICAL + 1)

    return jsonify({
        'success': True,
        'enabled': logging_enabled
    })


@bp.route('/recent', methods=['GET'])
def get_recent():
    """Get recent logs from buffer"""
    limit = request.args.get('limit', 100, type=int)

    with lock:
        logs = list(log_buffer)[-limit:]

    return jsonify({
        'logs': logs,
        'count': len(logs)
    })


@bp.route('/clear', methods=['POST'])
def clear_logs():
    """Clear log buffer"""
    with lock:
        log_buffer.clear()

    return jsonify({
        'success': True,
        'message': 'Log buffer cleared'
    })


def init_logging_handler():
    """Initialize the WebSocket log handler"""
    root_logger = logging.getLogger()
    for existing in root_logger.handlers:
        if isinstance(existing, WebSocketLogHandler):
            return existing
    handler = WebSocketLogHandler()
    handler.setLevel(logging.INFO)

    # Format: timestamp - level - module - message
    formatter = logging.Formatter('%(name)s - %(message)s')
    handler.setFormatter(formatter)

    # Add to root logger
    root_logger = logging.getLogger()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.INFO)

    return handler
