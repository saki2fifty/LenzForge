"""
Flask Application Factory
Creates and configures the Flask app with all extensions
"""

from flask import Flask, jsonify, request
import secrets
from flask_cors import CORS
from flask_socketio import SocketIO
import logging
from pathlib import Path

# Studio routes
from .routes import system, camera, tracking, effects, export_data, streaming, logs, docs, performance, stats

# Global SocketIO instance
socketio = SocketIO(async_mode="threading")

def create_app(config=None):
    """
    Create and configure the Flask application

    Args:
        config: Optional configuration dictionary

    Returns:
        Configured Flask app instance
    """
    # Create Flask app
    app = Flask(__name__,
                static_folder='static',
                template_folder='templates')

    # Load configuration
    app.config['SECRET_KEY'] = secrets.token_hex(32)
    app.config['TRUSTED_HOSTS'] = ['127.0.0.1', 'localhost', '[::1]']
    app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max upload

    if config:
        app.config.update(config)

    # Local browser API origins
    CORS(app, resources={
        r"/api/*": {
            "origins": ["http://127.0.0.1:5000", "http://localhost:5000"],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })

    @app.before_request
    def validate_origin():
        origin = request.headers.get('Origin')
        if request.method in ('POST', 'PUT', 'DELETE', 'PATCH') and origin and origin != request.host_url.rstrip('/'):
            return jsonify(success=False, error={'message': 'Cross-origin changes are not allowed'}), 403

    # Initialize SocketIO
    socketio.init_app(app)

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    app.logger.setLevel(logging.INFO)

    # Register blueprints
    app.register_blueprint(system.bp, url_prefix='/api')
    app.register_blueprint(camera.bp, url_prefix='/api/camera')
    app.register_blueprint(tracking.bp, url_prefix='/api/tracking')
    app.register_blueprint(effects.bp, url_prefix='/api/effects')
    app.register_blueprint(export_data.bp, url_prefix='/api/export')
    app.register_blueprint(streaming.streaming_bp)  # Streaming routes (no prefix)
    app.register_blueprint(logs.bp, url_prefix='/api/logs')
    app.register_blueprint(docs.bp, url_prefix='/api/docs')
    app.register_blueprint(performance.performance_bp)  # Performance routes
    app.register_blueprint(stats.bp, url_prefix='/api')  # Statistics routes

    # Initialize logging handler
    logs.init_logging_handler()

    # Root route - serve the web UI
    @app.route('/')
    def index():
        """Serve the main web interface"""
        from flask import render_template
        return render_template('studio.html')

    # Health check endpoint
    @app.route('/health')
    def health():
        """Simple health check endpoint"""
        return jsonify({
            'status': 'healthy',
            'version': '3.0.0',
            'service': 'LenzForge Studio Backend'
        })

    # Error handlers
    @app.errorhandler(404)
    def not_found(error):
        """Handle 404 errors"""
        return jsonify({
            'success': False,
            'error': {
                'code': 'NOT_FOUND',
                'message': 'The requested resource was not found'
            }
        }), 404

    @app.errorhandler(500)
    def internal_error(error):
        """Handle 500 errors"""
        app.logger.error(f"Internal error: {error}")
        return jsonify({
            'success': False,
            'error': {
                'code': 'INTERNAL_ERROR',
                'message': 'An internal server error occurred'
            }
        }), 500

    # WebSocket events - Main namespace
    @socketio.on('connect')
    def handle_connect():
        """Handle client connection"""
        app.logger.info('Client connected')

    @socketio.on('disconnect')
    def handle_disconnect():
        """Handle client disconnection"""
        app.logger.info('Client disconnected')

    # WebSocket events - Logs namespace
    @socketio.on('connect', namespace='/logs')
    def handle_logs_connect():
        """Handle logs namespace connection"""
        app.logger.info('Logs client connected')

    @socketio.on('disconnect', namespace='/logs')
    def handle_logs_disconnect():
        """Handle logs namespace disconnection"""
        app.logger.info('Logs client disconnected')

    app.logger.info('LenzForge Studio API initialized')

    return app


def run_server(host='127.0.0.1', port=5000, debug=False):
    """
    Run the Flask development server

    Args:
        host: Host to bind to
        port: Port to bind to
        debug: Enable debug mode
    """
    app = create_app()
    socketio.run(app, host=host, port=port, debug=debug, allow_unsafe_werkzeug=True)


if __name__ == '__main__':
    run_server(debug=False)
