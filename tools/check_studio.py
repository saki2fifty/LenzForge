"""Test the real Godot Start capture button against an isolated local API."""
import json
from pathlib import Path
import subprocess
import sys
import threading
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
import capture  # Apply native capture settings before cv2 loads.
from server.app import create_app
from server.routes.camera import close_camera
from flask import request
from werkzeug.serving import make_server


def main():
    app = create_app({'TESTING': True})
    capture_requests = []

    @app.before_request
    def observe_capture_request():
        if request.method == 'POST' and request.path == '/api/camera/select':
            capture_requests.append(request.get_json())
    # Only discovery is isolated; the demo uses the real capture, inference,
    # shared memory, API, and viewer. Never touch an attached webcam in CI.
    with patch('capture.enumerator.enumerate_cameras', return_value=[]):
        server = make_server('127.0.0.1', 0, app, threaded=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        version = json.loads((ROOT / 'toolchain.json').read_text())['godot']
        godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
        artifacts = ROOT / 'artifacts'
        artifacts.mkdir(exist_ok=True)
        try:
            result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'viewer'),
                '--log-file', str(artifacts / 'studio-capture.log'),
                '--script', 'res://tests/studio_capture.gd', '--',
                f'http://127.0.0.1:{server.server_port}', '-1'],
                capture_output=True, text=True, encoding='utf-8', timeout=40)
            output = result.stdout + result.stderr
            (artifacts / 'studio-capture-console.log').write_text(output, encoding='utf-8')
            print(output)
            if result.returncode or 'STUDIO_CAPTURE_BUTTON frames=' not in output or 'ERROR' in output:
                raise RuntimeError('Godot Start capture button integration failed')
            if not capture_requests or type(capture_requests[-1]['camera_index']) is not int:
                raise RuntimeError('Godot must serialize the selected camera index as an integer')
            with app.test_client() as client:
                status = client.get('/api/status').json
                if not status['camera_active'] or status['camera_index'] != -1 or status['frames'] < 30:
                    raise RuntimeError('Viewer did not start the expected capture source')
                config = status['tracking']['settings']
                if config['backend'] != 'cpu' or config['max_width'] != 320 or config['detection_confidence'] != 0:
                    raise RuntimeError('Viewer Tracking panel did not apply live configuration')
        finally:
            server.shutdown()
            thread.join(timeout=5)
            server.server_close()
            close_camera()


if __name__ == '__main__':
    main()
