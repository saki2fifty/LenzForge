"""Local browser GPU inference with bounded, binary WebSocket transport.

The Python capture owner supplies frames. The browser never opens a camera and
loads all JS, WASM and model assets from this loopback-only server.
"""
import json
import logging
import os
from pathlib import Path
import secrets
import shutil
import struct
import subprocess
import tempfile
import threading
import time
from urllib.parse import urlsplit

import cv2
import numpy as np
import psutil

ROOT = Path(__file__).resolve().parents[2]
LOG = logging.getLogger(__name__)


def find_browser():
    candidates = [os.environ.get('LENZFORGE_BROWSER', '')]
    for root in ('PROGRAMFILES(X86)', 'PROGRAMFILES', 'LOCALAPPDATA'):
        base = os.environ.get(root, '')
        if base:
            candidates += [str(Path(base) / 'Microsoft/Edge/Application/msedge.exe'),
                           str(Path(base) / 'Google/Chrome/Application/chrome.exe')]
    candidates += [shutil.which(name) or '' for name in ('msedge', 'chromium', 'google-chrome')]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError('Microsoft Edge or Chrome is required for GPU tracking')


def unpack_result(packet, expected_id, features):
    if not isinstance(packet, bytes) or len(packet) < 16:
        raise RuntimeError('Invalid browser tracking result')
    frame_id, metadata_size, inference_ms = struct.unpack_from('<IId', packet)
    if (frame_id != expected_id or metadata_size > 65536 or 16 + metadata_size > len(packet)
            or not np.isfinite(inference_ms) or inference_ms < 0):
        raise RuntimeError('Mismatched browser tracking result')
    metadata = json.loads(packet[16:16 + metadata_size])
    counts = metadata.get('face_counts', [])
    sides = metadata.get('hand_sides', [])
    pose_count = metadata.get('pose_count', 0)
    if len(counts) > 4 or any(n != 478 for n in counts) or len(sides) > 2 or pose_count not in (0, 33):
        raise RuntimeError('Invalid browser landmark counts')
    values = np.frombuffer(packet, dtype='<f4', offset=16 + metadata_size)
    if values.size != sum(counts) * 3 + len(sides) * 21 * 3 + pose_count * 4 or not np.isfinite(values).all():
        raise RuntimeError('Invalid browser landmark payload')
    offset = 0

    def points(count, pose=False):
        nonlocal offset
        stride = 4 if pose else 3
        array = values[offset:offset + count * stride].reshape(count, stride)
        offset += count * stride
        keys = ('x', 'y', 'z', 'visibility') if pose else ('x', 'y', 'z')
        return [dict(zip(keys, map(float, point))) for point in array]

    faces = [points(n) for n in counts]
    result = {}
    if faces:
        face = faces[0]
        for p in face:
            p['confidence'] = 1.0  # Same compatibility placeholder as the CPU path.
        if features.get('face'):
            result['face'] = face
            if len(faces) > 1:
                result['faces'] = faces
        if features.get('iris'):
            result['iris'] = {'left': face[468:473], 'right': face[473:478]}
        if 'blendshapes' in metadata:
            result['blendshapes'] = metadata['blendshapes']
        if 'face_transform' in metadata:
            result['face_transform'] = metadata['face_transform']
    if sides:
        result['hands'] = {'left': [], 'right': []}
        for side in sides:
            if side not in ('left', 'right'):
                raise RuntimeError('Invalid hand side')
            result['hands'][side] = points(21)
    if pose_count:
        result['pose'] = points(pose_count, pose=True)
    return result, float(inference_ms)


class BrowserTracker:
    START_TIMEOUT = 25.0
    FRAME_TIMEOUT = .75

    def __init__(self, config, features, stop_event=None):
        self.config = config
        self.features = features.copy()
        self.stop_event = stop_event or threading.Event()
        self._connected = threading.Event()
        self._closed = threading.Event()
        self.connection = self.server = self.browser_process = self._profile = None
        self._server_thread = None
        self._owned_children = []
        self._packet = bytearray()
        self._frame_id = 0
        self.inference_ms = 0.0
        self.renderer = ''
        self.token = secrets.token_urlsafe(32)
        versions = json.loads((ROOT / 'toolchain.json').read_text())
        self.runtime = ROOT / 'buildtools' / f"mediapipe-web-{versions['mediapipe_web']}"
        self.assets = Path(__file__).with_name('web')
        if not (self.runtime / 'vision_bundle.mjs').is_file():
            raise RuntimeError('GPU runtime is missing. Run Setup.ps1 to install browser tracking assets')
        browser = find_browser()
        try:
            from websockets.sync.server import serve
            self.server = serve(self._handle_connection, '127.0.0.1', 0,
                                process_request=self._http, compression=None,
                                max_size=256 * 1024, max_queue=2,
                                ping_interval=5, ping_timeout=3, close_timeout=.3)
            self.origin = f'http://127.0.0.1:{self.server.socket.getsockname()[1]}'
            self._server_thread = threading.Thread(target=self.server.serve_forever,
                                                   daemon=True, name='LenzForge-GPU-Bridge')
            self._server_thread.start()
            profile_root = ROOT / 'artifacts' / 'gpu-tracking'
            profile_root.mkdir(parents=True, exist_ok=True)
            self._profile = tempfile.TemporaryDirectory(prefix='session-', dir=profile_root)
            command = [browser, '--headless=new', f'--user-data-dir={self._profile.name}',
                       '--no-first-run', '--no-default-browser-check', '--disable-extensions',
                       '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
                       '--disable-backgrounding-occluded-windows', '--disable-component-update',
                       f'{self.origin}/host.html#{self.token}']
            self.browser_process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            deadline = time.monotonic() + self.START_TIMEOUT
            while not self._connected.wait(.05):
                self._check_alive(deadline)
            self._command('configure', config=config.to_dict(), features=features, timeout=self.START_TIMEOUT)
            self._owned_children = psutil.Process(self.browser_process.pid).children(recursive=True)
        except Exception:
            self.close()
            raise

    def _http(self, connection, request):
        from websockets.datastructures import Headers
        from websockets.http11 import Response
        if request.headers.get('Host') != self.origin.removeprefix('http://'):
            return connection.respond(403, 'Local host required\n')
        path = urlsplit(request.path).path
        if path.startswith('/session/'):
            if (not secrets.compare_digest(path, '/session/' + self.token)
                    or request.headers.get('Origin') != self.origin or self.connection is not None):
                return connection.respond(403, 'Invalid tracking session\n')
            return None
        if path in ('/host.html', '/worker.mjs'):
            file = self.assets / path[1:]
        elif path.startswith('/runtime/'):
            file = (self.runtime / path.removeprefix('/runtime/')).resolve()
            if not file.is_relative_to(self.runtime.resolve()):
                return connection.respond(404, 'Not found\n')
        elif path in ('/models/face_landmarker.task', '/models/hand_landmarker.task', '/models/pose_landmarker_lite.task'):
            from graphs.tasks_compat import model_path
            file = Path(model_path(path.rsplit('/', 1)[1]))
        else:
            return connection.respond(404, 'Not found\n')
        if not file.is_file():
            return connection.respond(404, 'Asset missing; run Setup.ps1\n')
        body = file.read_bytes()
        mime = {'.mjs': 'text/javascript', '.js': 'text/javascript', '.html': 'text/html',
                '.wasm': 'application/wasm'}.get(file.suffix, 'application/octet-stream')
        headers = Headers([('Content-Type', mime), ('Content-Length', str(len(body))),
                           ('Cache-Control', 'no-store'), ('X-Content-Type-Options', 'nosniff')])
        return Response(200, 'OK', headers, body)

    def _handle_connection(self, connection):
        self.connection = connection
        self._connected.set()
        self._closed.wait()  # The inference thread owns send/receive, one request at a time.

    def _check_alive(self, deadline):
        if self.stop_event.is_set():
            raise RuntimeError('Tracking stopped')
        if self.browser_process and self.browser_process.poll() is not None:
            raise RuntimeError('GPU browser exited')
        if time.monotonic() >= deadline:
            raise TimeoutError('GPU browser did not respond in time')

    def _receive(self, timeout):
        deadline = time.monotonic() + timeout
        while True:
            self._check_alive(deadline)
            try:
                result = self.connection.recv(timeout=min(.1, max(.001, deadline - time.monotonic())))
            except TimeoutError:
                continue
            if isinstance(result, str):
                response = json.loads(result)
                if response.get('error'):
                    raise RuntimeError(response['error'])
                return response
            return result

    def _command(self, command, timeout=10, **values):
        self.connection.send(json.dumps({'type': command, **values}))
        response = self._receive(timeout)
        if not isinstance(response, dict) or response.get('type') != 'ready' or response.get('delegate') != 'GPU':
            raise RuntimeError('GPU delegate was not initialized')
        self.renderer = response.get('renderer', 'GPU')

    def configure(self, config, features):
        self._command('configure', config=config.to_dict(), features=features)
        self.config, self.features = config, features.copy()

    def process(self, rgb, timeout=None):
        height, width = rgb.shape[:2]
        size = 24 + height * width * 4
        if len(self._packet) != size:
            self._packet = bytearray(size)
            self._rgba = np.ndarray((height, width, 4), dtype=np.uint8, buffer=self._packet, offset=24)
        self._frame_id = (self._frame_id + 1) & 0xffffffff
        struct.pack_into('<IIIId', self._packet, 0, 0x3147464c, self._frame_id, width, height,
                         time.monotonic_ns() / 1_000_000)
        cv2.cvtColor(rgb, cv2.COLOR_RGB2RGBA, dst=self._rgba)
        self.connection.send(memoryview(self._packet))
        response = self._receive(self.FRAME_TIMEOUT if timeout is None else timeout)
        result, self.inference_ms = unpack_result(response, self._frame_id, self.features)
        return result

    def close(self):
        self._closed.set()
        if self.connection:
            try:
                self.connection.close()
            except Exception:
                pass
            self.connection = None
        if self.browser_process:
            children = {p.pid: p for p in self._owned_children}
            try:
                owned = psutil.Process(self.browser_process.pid)
                children.update({p.pid: p for p in owned.children(recursive=True)})
            except psutil.Error:
                pass
            try:
                # Keep the original process handles so a crashed browser parent
                # cannot leave its renderer/GPU children running indefinitely.
                for process in reversed(list(children.values())):
                    try:
                        process.terminate()
                    except psutil.Error:
                        pass
                self.browser_process.terminate()
                self.browser_process.wait(timeout=3)
                _, alive = psutil.wait_procs(list(children.values()), timeout=2)
                for process in alive:
                    try:
                        process.kill()
                    except psutil.Error:
                        pass
            except (psutil.Error, OSError, subprocess.TimeoutExpired):
                if self.browser_process.poll() is None:
                    self.browser_process.kill()
            self.browser_process = None
        if self.server:
            self.server.shutdown()
            self.server = None
        if self._server_thread:
            self._server_thread.join(timeout=2)
            self._server_thread = None
        if self._profile:
            try:
                # This directory was created below the workspace's artifacts directory.
                self._profile.cleanup()
            except OSError:
                LOG.debug('Browser profile still in use; retained in artifacts')
            self._profile = None
