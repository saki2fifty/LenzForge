"""Serialized capture lifecycle for the desktop and browser clients."""
import threading
from flask import Blueprint, jsonify, request

bp = Blueprint('camera', __name__)
_current_camera = None
_lifecycle = threading.RLock()


def camera_info(camera):
    return {'index': camera.index, 'name': camera.name, 'device_id': camera.device_id, 'resolution': [camera.width, camera.height],
            'fps': camera.fps, 'is_opened': camera.is_opened(), 'error': camera.error}


def close_camera():
    global _current_camera
    with _lifecycle:
        from .streaming import set_camera_source
        set_camera_source(None)
        if _current_camera:
            _current_camera.close()
            _current_camera = None


def open_camera(index, resolution, fps, device_id=None):
    global _current_camera
    from capture.camera import Camera
    camera = Camera(index, *resolution, fps)
    if index >= 0:
        from capture.enumerator import enumerate_cameras
        devices = enumerate_cameras()
        device = next((c for c in devices if (c.device_id == device_id if device_id else c.id == index)), None)
        if device is None:
            raise ValueError('That camera is no longer available. Click Find cameras and select it again.')
        camera.camera_id = camera.index = device.id
        camera.name = device.name
        camera.device_id = device.device_id
    with _lifecycle:
        close_camera()
        # Keep ownership even if a driver times out, so a retry cannot create a
        # second capture thread while the first is still releasing the device.
        _current_camera = camera
        from .streaming import set_camera_source
        if not camera.open():
            try:
                camera.close()
            except RuntimeError:
                camera.error = (camera.error or 'Camera initialization failed') + '. The driver is not responding; restart the backend.'
            set_camera_source(camera)
            raise RuntimeError(camera.error or 'Camera could not be opened')
        set_camera_source(camera)
        return camera


@bp.get('/list')
def list_cameras():
    from capture.enumerator import enumerate_cameras
    try:
        cameras = [{'index': c.id, 'name': c.name, 'device_id': c.device_id,
                    'backend': c.backend, 'resolutions': []} for c in enumerate_cameras()]
        cameras.append({'index': -1, 'name': 'Demo pattern (no camera)', 'backend': 'Synthetic', 'resolutions': []})
        return jsonify(success=True, cameras=cameras)
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 503


@bp.get('/current')
def get_current():
    return jsonify(success=True, camera=camera_info(_current_camera) if _current_camera else None)


@bp.post('/select')
@bp.post('/start')
def select_camera():
    data = request.get_json(silent=True) or {}
    try:
        with _lifecycle:
            if not data and _current_camera:
                return jsonify(success=True, camera=camera_info(_current_camera))
            index = data.get('camera_index', 0)
            resolution = data.get('resolution', [1280, 720])
            fps = data.get('fps', 30)
            if not isinstance(resolution, list) or len(resolution) != 2:
                raise ValueError('resolution must contain width and height')
            camera = open_camera(index, resolution, fps, data.get('device_id'))
            return jsonify(success=True, camera=camera_info(camera))
    except (ValueError, TypeError) as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 503


start_camera = select_camera


@bp.post('/stop')
def stop_camera():
    try:
        close_camera()
        return jsonify(success=True, message='Capture stopped')
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 503


@bp.post('/configure')
def configure_camera():
    data = request.get_json(silent=True) or {}
    with _lifecycle:
        if not _current_camera:
            return jsonify(success=False, error={'message': 'Select a camera first'}), 409
        try:
            camera = open_camera(_current_camera.index, data.get('resolution', [_current_camera.width, _current_camera.height]), data.get('fps', _current_camera.fps), _current_camera.device_id)
            return jsonify(success=True, camera=camera_info(camera))
        except (ValueError, TypeError) as exc:
            return jsonify(success=False, error={'message': str(exc)}), 400
        except RuntimeError as exc:
            return jsonify(success=False, error={'message': str(exc)}), 503
