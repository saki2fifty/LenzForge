"""Profile the full capture-to-viewer path; no video or images are saved."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
import capture
from server.app import create_app
from server.routes.camera import close_camera
from werkzeug.serving import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--camera', type=int, default=-1, help='Windows camera index; -1 uses the demo')
    parser.add_argument('--seconds', type=float, default=15)
    parser.add_argument('--frame-cap', type=int, help='Override Godot frame cap; 0 lets VSync set the rate')
    parser.add_argument('--fps', type=int, choices=[24, 30, 60], default=60)
    parser.add_argument('--no-overlay', action='store_true')
    parser.add_argument('--beard', action='store_true', help='Enable the default physics beard')
    parser.add_argument('--beard-strands', type=int, default=256)
    parser.add_argument('--beard-segments', type=int, default=8)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 300:
        parser.error('--seconds must be 1 to 300')
    if not 16 <= args.beard_strands <= 1024:
        parser.error('--beard-strands must be 16 to 1024')
    if not 2 <= args.beard_segments <= 16:
        parser.error('--beard-segments must be 2 to 16')
    app = create_app()
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
    command += [str(args.frame_cap if args.frame_cap is not None else 0), str(args.fps)]
    command.append('0' if args.no_overlay else '1')
    command += ['1' if args.beard else '0', str(args.beard_strands), str(args.beard_segments)]
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=args.seconds + 50)
        output = result.stdout + result.stderr
        (artifacts / 'benchmark-console.log').write_text(output, encoding='utf-8')
        lines = [line for line in output.splitlines() if line.startswith('LENZFORGE_PERFORMANCE ')]
        if result.returncode or not lines or 'ERROR' in output:
            raise RuntimeError(output)
        with app.test_client() as client:
            status = client.get('/api/status').json
        report = {'configuration': {'utc': datetime.now(timezone.utc).isoformat(),
                  'seconds': args.seconds, 'requested_fps': args.fps,
                  'overlay': not args.no_overlay, 'beard': args.beard, 'beard_strands': args.beard_strands,
                  'beard_segments': args.beard_segments},
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
