"""Delayed moving-face IPC fixture: no camera, AI models, or personal settings."""
import json
import math
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
    video = NV12RingWriter('LenzForge_SyncVideo_' + suffix, 64, 64)
    landmarks = LMK1Writer('LenzForge_SyncLandmarks_' + suffix, 64, 64)
    stop = threading.Event()
    mailbox = threading.Condition()
    latest = None
    reference = json.loads((ROOT / 'viewer/mannequin/assets/canonical_face.json').read_text())['vertices']

    def capture():
        nonlocal latest
        index = 0
        deadline = time.perf_counter()
        while not stop.is_set():
            stamp = get_qpc_ticks()
            # Y is an independent, readable witness of the captured frame ID.
            video.write_frame(bytes([40 + index % 160]) * 4096, bytes([128]) * 2048, stamp)
            with mailbox:
                latest = (index, stamp)
                mailbox.notify()
            index += 1
            deadline += 1 / 60
            stop.wait(max(0, deadline - time.perf_counter()))

    def tracking():
        previous = -1
        while not stop.is_set():
            with mailbox:
                mailbox.wait_for(lambda: stop.is_set() or latest and latest[0] != previous, timeout=.1)
                if stop.is_set() or latest is None:
                    continue
                index, stamp = latest
            previous = index
            phase = index % 300
            delay = .008 if phase < 90 else .045 if phase < 180 else .28 if phase < 210 else .012
            if stop.wait(delay):
                break
            if 210 <= phase < 240:
                landmarks.write_empty(stamp, index)
                continue
            angle = math.sin(index * .2) * 1.1
            cosine, sine = math.cos(angle), math.sin(angle)
            shift = math.sin(index * .35) * 7
            points = [((32 + (x*cosine-z*sine)*1.3 + shift)/64,
                       (30-y*1.3)/64, (-x*sine-z*cosine)*1.3/64) for x, y, z in reference]
            points.extend([points[1]] * 10)
            landmarks.write_landmarks(points, stamp, index)

    threads = [threading.Thread(target=capture), threading.Thread(target=tracking)]
    for thread in threads:
        thread.start()
    version = json.loads((ROOT / 'toolchain.json').read_text())['godot']
    godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
    try:
        result = subprocess.run([str(godot), '--path', str(ROOT / 'viewer'),
            '--log-file', str(ROOT / 'artifacts/attachment-sync.log'), '--script',
            'res://tests/attachment_sync.gd', '--', video.name, landmarks.name],
            capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        (ROOT / 'artifacts/attachment-sync-console.log').write_text(output)
        print(output)
        if result.returncode or 'ATTACHMENT_SYNC ' not in output or 'ERROR' in output:
            raise RuntimeError('Attachment synchronization validation failed')
    finally:
        stop.set()
        with mailbox:
            mailbox.notify_all()
        for thread in threads:
            thread.join()
        video.close()
        landmarks.close()


if __name__ == '__main__':
    main()
