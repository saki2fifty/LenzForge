"""One preview encoder, with a cached JPEG shared by all browser clients."""
import logging
import threading
import time
import cv2
import numpy as np
from flask import Blueprint, Response, jsonify, render_template
from pipeline.performance_config import get_performance_config
from ipc.qpc import get_qpc_frequency
from ..overlays import overlay_landmarks

streaming_bp = Blueprint('streaming', __name__)
logger = logging.getLogger(__name__)
_active_camera = _processor = _landmark_data = None
_active_effects = []
_fps = 0.0
_stop = threading.Event()
_thread = None
_condition = threading.Condition()
_jpeg = None
_sequence = 0
_clients = 0


def get_processor():
    return _processor


def set_camera_source(camera):
    global _active_camera, _processor, _thread, _jpeg, _landmark_data, _fps
    _stop.set()
    if _thread:
        _thread.join(timeout=10)
        if _thread.is_alive():
            raise RuntimeError('Preview worker is still stopping')
    from .export_data import recorder, set_current_frame, set_current_landmarks
    recorder.stop()
    _active_camera = camera
    _processor = camera.mp_worker if camera else None
    if _processor:
        from .tracking import _tracking_stats
        for name, feature in [('face_mesh', 'face'), ('iris', 'iris'), ('hands', 'hands'), ('pose', 'pose')]:
            _processor.enable_tracking(feature, _tracking_stats[name]['enabled'])
    _jpeg = _landmark_data = None
    _fps = 0.0
    set_current_frame(None)
    set_current_landmarks(None)
    _stop.clear()
    if camera and camera.is_opened():
        _thread = threading.Thread(target=_encode_loop, args=(camera,), daemon=True, name='LenzForge-Preview')
        _thread.start()
    else:
        _thread = None
    with _condition:
        _condition.notify_all()


def _encode_loop(camera):
    global _landmark_data, _jpeg, _sequence, _fps
    from .export_data import recorder, set_current_frame, set_current_landmarks
    previous = -1
    next_encode_at = 0.0
    measured = 0
    measurement_start = time.monotonic()
    while not _stop.is_set():
        result = camera.wait_frame(previous, timeout=0.2)
        if result is None:
            if not camera.is_opened():
                _stop.wait(0.1)
            continue
        previous, timestamp, source = result
        snapshot = _processor.get_snapshot() if _processor else {'landmarks': {}, 'timestamp': 0}
        age = (timestamp - snapshot['timestamp']) / get_qpc_frequency()
        landmarks = snapshot['landmarks'] if 0 <= age <= .15 else {}
        _landmark_data = landmarks
        set_current_frame(source)
        set_current_landmarks(landmarks)
        if recorder.active:
            recorder.write(source.to_bgr(), timestamp, landmarks)
        measured += 1
        now = time.monotonic()
        if now - measurement_start >= 1:
            _fps = measured / (now - measurement_start)
            measurement_start, measured = now, 0
        config = get_performance_config()
        if not _clients or now < next_encode_at:
            continue
        frame = source.to_bgr().copy()
        for effect in tuple(_active_effects):
            if effect.is_enabled():
                try:
                    frame = effect.apply(frame)
                except Exception:
                    logger.exception('Effect failed: %s', type(effect).__name__)
        frame = overlay_landmarks(frame, landmarks)
        size = config.get_preview_resolution(frame.shape[1], frame.shape[0])
        if size != (frame.shape[1], frame.shape[0]):
            frame = cv2.resize(frame, size, interpolation=cv2.INTER_AREA)
        ok, encoded = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, config.preview_quality])
        if ok:
            with _condition:
                _jpeg = encoded.tobytes()
                _sequence += 1
                _condition.notify_all()
            next_encode_at = max(now, next_encode_at + 1 / max(config.preview_max_fps, 1))


def generate_frames():
    global _clients
    last = -1
    with _condition:
        _clients += 1
    try:
        while True:
            with _condition:
                _condition.wait_for(lambda: _sequence != last and _jpeg is not None, timeout=1)
                if _jpeg is None:
                    blank = np.full((360, 640, 3), (28, 23, 18), dtype=np.uint8)
                    cv2.putText(blank, 'Select a source to begin', (140, 185), cv2.FONT_HERSHEY_SIMPLEX, .7, (210, 220, 220), 1)
                    ok, encoded = cv2.imencode('.jpg', blank)
                    frame = encoded.tobytes() if ok else b''
                elif _sequence == last:
                    continue
                else:
                    last, frame = _sequence, _jpeg
            yield b'--frame\r\nContent-Type: image/jpeg\r\n\r\n' + frame + b'\r\n'
    finally:
        with _condition:
            _clients -= 1


@streaming_bp.get('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame', headers={'Cache-Control': 'no-store'})


@streaming_bp.get('/viewer')
def viewer():
    return render_template('studio.html')


@streaming_bp.get('/stream_stats')
def stream_stats():
    camera = _active_camera
    from .tracking import requested_features
    tracking = _processor.get_stats() if _processor else {'features': requested_features()}
    from pipeline.tracking_config import get_tracking_config
    config, revision = get_tracking_config()
    tracking.update(settings=config.to_dict(), settings_revision=revision)
    from tracking.models import library
    tracking['library'] = library.snapshot()
    from .export_data import recorder
    return jsonify(recording=recorder.status()['recording'], fps=round(_fps, 1), camera_active=bool(camera and camera.is_opened()),
        resolution=[camera.width, camera.height] if camera else [0, 0],
        source=camera.name if camera else 'No source', clients=_clients,
        frames=camera.frame_count if camera else 0, tracking=tracking,
        camera_index=camera.index if camera else None,
        capture_format=camera.pixel_format if camera else None,
        capture_timing=camera.get_performance() if camera else {},
        buffers={"video": camera.video_buffer, "landmarks": camera.landmark_buffer} if camera else {},
        error=camera.error if camera else None)
