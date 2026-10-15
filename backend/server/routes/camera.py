"""Serialized capture lifecycle for the desktop and browser clients."""
import threading
from flask import Blueprint, jsonify, request

bp = Blueprint('camera', __name__)
_current_camera = None
_lifecycle = threading.RLock()


def camera_info(camera):
    return {'index': camera.index, 'name': camera.name, 'resolution': [camera.width, camera.height],
            'fps': camera.fps, 'is_opened': camera.is_opened(), 'error': camera.error}


def close_camera():
    global _current_camera
    with _lifecycle:
        from .streaming import set_camera_source
        set_camera_source(None)
        if _current_camera:
            _current_camera.close()
            _current_camera = None


def open_camera(index, resolution, fps):
    global _current_camera
    from capture.camera import Camera
    camera = Camera(index, *resolution, fps)
    with _lifecycle:
        close_camera()
        if not camera.open():
            camera.close()
            raise RuntimeError(camera.error or 'Camera could not be opened')
        _current_camera = camera
        from .streaming import set_camera_source
        set_camera_source(camera)
        return camera


@bp.get('/list')
def list_cameras():
    # Do not open a second handle to an actively streaming camera.
    from capture.enumerator import enumerate_cameras
    cameras = [{'index': -1, 'name': 'Demo pattern', 'backend': 'Synthetic', 'resolutions': []}]
    if _current_camera and _current_camera.index >= 0:
        cameras.append({**camera_info(_current_camera), 'backend': 'MSMF', 'resolutions': []})
    else:
        cameras += [{'index': c.id, 'name': c.name, 'backend': c.backend, 'resolutions': []} for c in enumerate_cameras()]
    return jsonify(success=True, cameras=cameras)


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
            camera = open_camera(index, resolution, fps)
            return jsonify(success=True, camera=camera_info(camera))
    except (ValueError, TypeError) as exc:
        return jsonify(success=False, error={'message': str(exc)}), 400
    except RuntimeError as exc:
        return jsonify(success=False, error={'message': str(exc)}), 503


start_camera = select_camera


@bp.post('/stop')
def stop_camera():
    close_camera()
    return jsonify(success=True, message='Capture stopped')


@bp.post('/configure')
def configure_camera():
    data = request.get_json(silent=True) or {}
    with _lifecycle:
        if not _current_camera:
            return jsonify(success=False, error={'message': 'Select a camera first'}), 409
        try:
            camera = open_camera(_current_camera.index, data.get('resolution', [_current_camera.width, _current_camera.height]), data.get('fps', _current_camera.fps))
            return jsonify(success=True, camera=camera_info(camera))
        except (ValueError, TypeError) as exc:
            return jsonify(success=False, error={'message': str(exc)}), 400
        except RuntimeError as exc:
            return jsonify(success=False, error={'message': str(exc)}), 503
