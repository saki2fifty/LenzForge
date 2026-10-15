"""Hardware-free Python -> native Godot protocol test using isolated named rings."""
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
from ipc.ring_nv12 import NV12RingWriter
from ipc.ring_landmarks import LMK1Writer
from ipc.qpc import get_qpc_ticks


def main():
    suffix = uuid.uuid4().hex
    video = NV12RingWriter('LenzForge_TestVideo_' + suffix, 64, 64)
    landmarks = LMK1Writer('LenzForge_TestLandmarks_' + suffix, 64, 64)
    stop = threading.Event()
    def produce():
        index = 0
        while not stop.is_set():
            timestamp = get_qpc_ticks()
            video.write_frame(bytes([90]) * 4096, bytes([128]) * 2048, timestamp)
            if index % 20 < 15:
                landmarks.write_landmarks([(.25, .75, -.1)] * 478, timestamp, index)
            else:
                landmarks.write_empty(timestamp, index)
            index += 1
            time.sleep(1 / 60)
    thread = threading.Thread(target=produce)
    thread.start()
    version = json.loads((ROOT / 'toolchain.json').read_text())['godot']
    godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
    try:
        result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'viewer'),
            '--log-file', str(ROOT / 'artifacts/ipc.log'), '--script', 'res://tests/ipc_probe.gd',
            '--', video.name, landmarks.name], capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        (ROOT / 'artifacts/ipc-console.log').write_text(output)
        print(output)
        if result.returncode or 'IPC_PROBE video=' not in output or 'SCRIPT ERROR' in output:
            raise RuntimeError('Native IPC validation failed')
    finally:
        stop.set()
        thread.join()
        video.close()
        landmarks.close()


if __name__ == '__main__':
    main()
