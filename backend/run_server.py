"""Local application entry point. Capture belongs to the application, not viewers."""
import argparse
import atexit
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# OpenCV reads some Windows video settings when its native library loads.
# Apply capture defaults before importing any routes that import cv2.
import capture


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=5000)
    parser.add_argument('--demo', action='store_true', help='Start the animated test pattern without accessing a webcam')
    args = parser.parse_args()
    from server.app import create_app
    from server.routes.camera import open_camera, close_camera
    from waitress import serve
    app = create_app()
    atexit.register(close_camera)
    if args.demo:
        open_camera(-1, [1280, 720], 30)
    print(f'LenzForge Studio: http://{args.host}:{args.port}', flush=True)
    try:
        serve(app, host=args.host, port=args.port, threads=12)
    finally:
        close_camera()


if __name__ == '__main__':
    main()
