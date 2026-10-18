"""Profile the full capture-to-viewer path; no video or images are saved."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
import capture
from server.app import create_app
from server.routes.camera import close_camera
from pipeline.tracking_config import update_tracking_config
from werkzeug.serving import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--camera', type=int, default=-1, help='Windows camera index; -1 uses the demo')
    parser.add_argument('--seconds', type=float, default=15)
    parser.add_argument('--frame-cap', type=int, help='Override the app render cap; 0 removes the software cap')
    parser.add_argument('--fps', type=int, choices=[24, 30, 60], default=60)
    parser.add_argument('--no-overlay', action='store_true')
    parser.add_argument('--beard', action='store_true', help='Enable the default physics beard')
    parser.add_argument('--beard-strands', type=int, default=256)
    parser.add_argument('--beard-segments', type=int, default=8)
    parser.add_argument('--hair-style', choices=['None', 'Regular', 'Mohawk', 'Afro'], default='None', help='Include a generated 3D scalp hair object')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--tracking-backend', choices=['auto', 'gpu', 'cpu'], default='auto')
    parser.add_argument('--warmup', type=float, default=8)
    parser.add_argument('--offscreen', action='store_true', help='Keep the rendered test window off-screen')
    parser.add_argument('--vsync', choices=['project', 'on', 'off'], default='project', help='Diagnose presentation pacing independently of the software frame cap')
    parser.add_argument('--portrait', action='store_true', help='Use a deterministic public-domain portrait as the demo source')
    parser.add_argument('--virtual-camera', action='store_true', help='Measure composed output with an actual Windows camera consumer; requires native camera installation')
    args = parser.parse_args()
    os.environ['LENZFORGE_SETTINGS_DIR'] = str(ROOT / 'artifacts' / ('benchmark-settings-' + uuid.uuid4().hex))
    if not 1 <= args.seconds <= 300:
        parser.error('--seconds must be 1 to 300')
    if not 0 <= args.warmup <= 60:
        parser.error('--warmup must be 0 to 60')
    if args.frame_cap is not None and not 0 <= args.frame_cap <= 1000:
        parser.error('--frame-cap must be 0 to 1000')
    if not 16 <= args.beard_strands <= 1024:
        parser.error('--beard-strands must be 16 to 1024')
    if not 2 <= args.beard_segments <= 16:
        parser.error('--beard-segments must be 2 to 16')
    if args.portrait:
        if args.camera != -1:
            parser.error('--portrait uses the demo source; omit --camera')
        import cv2
        import matplotlib
        import numpy as np
        from capture.camera import Camera
        source = cv2.imread(str(Path(matplotlib.get_data_path()) / 'sample_data/grace_hopper.jpg'))
        source = cv2.resize(source, (614, 720))
        portrait = np.zeros((720, 1280, 3), dtype=np.uint8)
        portrait[:, 333:947] = source
        frames = [cv2.warpAffine(portrait, np.float32([[1, 0, i - 3], [0, 1, 0]]), (1280, 720)) for i in range(7)]
        Camera._demo_frame = lambda camera: frames[camera.frame_count % len(frames)]
    update_tracking_config({'backend': args.tracking_backend})
    app = create_app({'TESTING': True})
    server = make_server('127.0.0.1', 0, app, threaded=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    version = json.loads((ROOT / 'toolchain.json').read_text())['godot']
    godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
    artifacts = ROOT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    command = [str(godot), '--path', str(ROOT / 'viewer'), '--log-file', str(artifacts / 'benchmark-viewer.log'),
               '--script', 'res://tests/performance_probe.gd', '--',
               f'http://127.0.0.1:{server.server_port}', str(args.camera), str(args.seconds)]
    command += [str(args.frame_cap if args.frame_cap is not None else -1), str(args.fps)]
    command.append('0' if args.no_overlay else '1')
    command += ['1' if args.beard else '0', str(args.beard_strands), str(args.beard_segments)]
    command.append(str(args.warmup))
    command.append(args.vsync)
    command.append('1' if args.virtual_camera else '0')
    command.append(args.hair_style)
    if args.offscreen:
        command[1:1] = ['--position', '-3000,0']
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=args.seconds + args.warmup + 50,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        output = result.stdout + result.stderr
        (artifacts / 'benchmark-console.log').write_text(output, encoding='utf-8')
        lines = [line for line in output.splitlines() if line.startswith('LENZFORGE_PERFORMANCE ')]
        if result.returncode or not lines or 'ERROR' in output:
            raise RuntimeError(output)
        with app.test_client() as client:
            status = client.get('/api/status').json
        report = {'configuration': {'utc': datetime.now(timezone.utc).isoformat(),
                  'seconds': args.seconds, 'requested_fps': args.fps,
                  'tracking_backend': args.tracking_backend, 'warmup_s': args.warmup, 'offscreen': args.offscreen,
                  'vsync': args.vsync,
                  'virtual_camera': args.virtual_camera,
                  'source': f'public-domain portrait, synthetic {args.fps} fps' if args.portrait else 'camera' if args.camera >= 0 else 'demo',
                  'overlay': not args.no_overlay, 'beard': args.beard, 'beard_strands': args.beard_strands,
                  'beard_segments': args.beard_segments, 'hair_style': args.hair_style},
                  'viewer': json.loads(lines[-1].split(' ', 1)[1]), 'backend': status}
        # Mapping names identify only this transient session and add no value to reports.
        report['backend'].pop('buffers', None)
        encoded = json.dumps(report, indent=2)
        print(encoded)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(encoded, encoding='utf-8')
    finally:
        server.shutdown()
        thread.join(timeout=5)
        server.server_close()
        close_camera()


if __name__ == '__main__':
    main()
