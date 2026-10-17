"""Exercise LenzForge's own registered camera, without opening a physical webcam."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installed', action='store_true', help='Also test Windows camera discovery/activation (requires Install.ps1)')
    args = parser.parse_args()
    artifacts = ROOT / 'artifacts'
    probe = artifacts / 'virtual-camera-build/LenzForgeCameraProbe.exe'
    subprocess.run([str(probe), '--self-test'], check=True, timeout=20)
    subprocess.run([str(probe), '--component', str(ROOT/'viewer/gdextension/bin/LenzForgeCamera.dll')], check=True, timeout=10)
    version = json.loads((ROOT / 'toolchain.json').read_text())['godot']
    godot = ROOT / f'buildtools/godot-{version}/Godot_v{version}-stable_win64_console.exe'
    environment = dict(os.environ, LENZFORGE_SETTINGS_DIR=str(artifacts / ('virtual-camera-settings-' + uuid.uuid4().hex)))
    command = [str(godot), '--path', str(ROOT/'viewer'), '--position', '5000,5000',
               '--log-file', str(artifacts/'virtual-camera-test.log'), '--script', 'res://tests/virtual_camera.gd', '--']
    result = subprocess.run(command + ['--render'], capture_output=True, text=True, encoding='utf-8', env=environment, timeout=30)
    if result.returncode or 'ERROR' in result.stdout + result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    print(result.stdout)
    if not args.installed:
        return
    run = artifacts / ('virtual-camera-integration-' + uuid.uuid4().hex)
    log = (artifacts/'virtual-camera-integration.log').open('w', encoding='utf-8')
    viewer = subprocess.Popen(command + ['--device', str(run)], stdout=log, stderr=subprocess.STDOUT, env=environment)
    try:
        deadline = time.monotonic()+30
        while not run.with_suffix('.ready').exists():
            if viewer.poll() is not None or time.monotonic()>deadline:
                log.flush()
                raise RuntimeError((artifacts/'virtual-camera-integration.log').read_text(encoding='utf-8'))
            time.sleep(.05)
        # Reopen the camera in an independent Windows client to exercise service
        # teardown/reconnection as well as the initial stream.
        for attempt in range(2):
            capture = subprocess.run([str(probe), str(artifacts/f'virtual-camera-received-{attempt}.nv12'), '180']+(['--dxgi'] if attempt else []),
                                     capture_output=True, text=True, timeout=20)
            print(capture.stdout, capture.stderr)
            if capture.returncode:
                raise RuntimeError('Windows could not receive LenzForge camera frames')
            time.sleep(.75)
        run.with_suffix('.stop').touch()
        if viewer.wait(timeout=15):
            raise RuntimeError('Camera viewer test failed')
        print(run.with_suffix('.json').read_text())
        import cv2
        import numpy as np
        frame = np.fromfile(artifacts/'virtual-camera-received-1.nv12', dtype=np.uint8).reshape(1080, 1280)
        image = cv2.cvtColor(frame, cv2.COLOR_YUV2BGR_NV12)
        cv2.imwrite(str(artifacts/'virtual-camera-received.png'), image)
        # Detect the blue/cyan strands from the rendered mannequin. This rejects
        # black output, a raw source image, and incorrect channel ordering.
        colored = (image[:,:,0] > 160) & (image[:,:,0] > image[:,:,2].astype(np.int16)+80)
        if int(colored.sum()) < 5000:
            raise RuntimeError('Camera output did not contain the composed hair')
        if float(np.where(colored)[0].mean()) < image.shape[0]*.5:
            raise RuntimeError('Camera output is vertically inverted')
    finally:
        run.with_suffix('.stop').touch()
        if viewer.poll() is None:
            try:
                viewer.wait(timeout=8)
            except subprocess.TimeoutExpired:
                viewer.kill()
                viewer.wait()
        log.close()


if __name__ == '__main__':
    main()
