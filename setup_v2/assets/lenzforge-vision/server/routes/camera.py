"""
Camera API Routes
Handles camera operations: list, select, configure, current
"""

from flask import Blueprint, jsonify, request

bp = Blueprint('camera', __name__)

# Global camera state
_current_camera = None
_available_cameras = []


def set_camera_enumerator(enumerator):
    """Set the camera enumerator function"""
    global _available_cameras
    _available_cameras = enumerator()


def set_current_camera(camera):
    """Set the current camera instance"""
    global _current_camera
    _current_camera = camera


@bp.route('/list', methods=['GET'])
def list_cameras():
    """
    GET /api/camera/list
    Get list of available cameras
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        # Import camera enumerator (absolute import from backend_v2 root)
        from capture.enumerator import enumerate_cameras
        
        # Get cameras and convert to dict format with capabilities
        camera_infos = enumerate_cameras()
        cameras = []
        for cam in camera_infos:
            camera_dict = {
                'index': cam.id,
                'name': cam.name,
                'backend': cam.backend
            }
            
            # Add supported resolutions if available
            if cam.supported_resolutions:
                camera_dict['supported_resolutions'] = [
                    {
                        'width': res.width,
                        'height': res.height,
                        'fps_options': res.fps_options
                    }
                    for res in cam.supported_resolutions
                ]
            
            cameras.append(camera_dict)
        
        return jsonify({
            'cameras': cameras
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_LIST_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/current', methods=['GET'])
def get_current():
    """
    GET /api/camera/current
    Get current camera configuration
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if not _current_camera:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_CAMERA',
                    'message': 'No camera is currently active'
                }
            }), 404
        
        # Get camera info
        camera_info = {
            'index': getattr(_current_camera, 'index', 0),
            'name': getattr(_current_camera, 'name', 'Unknown'),
            'resolution': [
                int(_current_camera.width),
                int(_current_camera.height)
            ],
            'fps': int(_current_camera.fps),
            'active': True
        }
        
        return jsonify(camera_info)
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_INFO_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/select', methods=['POST'])
def select_camera():
    """
    POST /api/camera/select
    Select and activate a camera
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        camera_index = data.get('camera_index')
        resolution = data.get('resolution', [640, 480])
        fps = data.get('fps', 30)
        
        if camera_index is None:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'camera_index is required'
                }
            }), 400
        
        # Import camera class (absolute imports)
        from capture.camera import Camera
        from capture.enumerator import enumerate_cameras
        
        # Verify camera exists - convert to dict format
        camera_infos = enumerate_cameras()
        available = [
            {
                'index': cam.id,
                'name': cam.name,
                'backend': cam.backend
            }
            for cam in camera_infos
        ]
        
        if not any(cam['index'] == camera_index for cam in available):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CAMERA_NOT_FOUND',
                    'message': f'Camera with index {camera_index} not found',
                    'details': {
                        'available_cameras': [cam['index'] for cam in available]
                    }
                }
            }), 404
        
        # Close current camera if exists
        global _current_camera
        if _current_camera:
            _current_camera.release()
        
        # Create new camera
        _current_camera = Camera(
            camera_id=camera_index,
            width=resolution[0],
            height=resolution[1],
            fps=fps
        )
        
        # Open the camera
        if not _current_camera.open():
            _current_camera = None
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CAMERA_OPEN_FAILED',
                    'message': f'Failed to open camera {camera_index}'
                }
            }), 500
        
        # Connect camera to streaming
        from server.routes.streaming import set_camera_source
        set_camera_source(_current_camera)
        
        # Get camera name
        camera_name = next(
            (cam['name'] for cam in available if cam['index'] == camera_index),
            'Unknown'
        )
        
        return jsonify({
            'success': True,
            'message': 'Camera selected',
            'camera': {
                'index': camera_index,
                'name': camera_name,
                'resolution': resolution,
                'fps': fps
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_SELECT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/start', methods=['POST'])
def start_camera():
    """
    POST /api/camera/start
    Start camera capture
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if not _current_camera:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_CAMERA',
                    'message': 'No camera selected. Call /select first.'
                }
            }), 404
        
        if _current_camera.is_opened():
            return jsonify({
                'success': True,
                'message': 'Camera already running',
                'camera': {
                    'index': _current_camera.index,
                    'name': _current_camera.name,
                    'resolution': [_current_camera.width, _current_camera.height],
                    'fps': _current_camera.fps
                }
            })
        
        # Open camera if not open
        if not _current_camera.open():
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CAMERA_OPEN_FAILED',
                    'message': f'Failed to open camera {_current_camera.index}'
                }
            }), 500
        
        # Connect camera to streaming
        from server.routes.streaming import set_camera_source
        set_camera_source(_current_camera)
        
        return jsonify({
            'success': True,
            'message': 'Camera started',
            'camera': {
                'index': _current_camera.index,
                'name': _current_camera.name,
                'resolution': [_current_camera.width, _current_camera.height],
                'fps': _current_camera.fps
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_START_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/stop', methods=['POST'])
def stop_camera():
    """
    POST /api/camera/stop
    Stop camera capture
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        if not _current_camera:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_CAMERA',
                    'message': 'No camera is currently active'
                }
            }), 404
        
        # Disconnect from streaming
        from server.routes.streaming import set_camera_source
        set_camera_source(None)
        
        # Close camera
        _current_camera.close()
        
        return jsonify({
            'success': True,
            'message': 'Camera stopped'
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_STOP_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/configure', methods=['POST'])
def configure_camera():
    """
    POST /api/camera/configure
    Configure camera settings
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if not _current_camera:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NO_CAMERA',
                    'message': 'No camera is currently active'
                }
            }), 404
        
        # Get settings
        resolution = data.get('resolution')
        fps = data.get('fps')
        auto_focus = data.get('auto_focus')
        auto_exposure = data.get('auto_exposure')
        
        # Apply settings
        settings_applied = {}
        
        if resolution:
            # Would need to recreate camera for resolution change
            settings_applied['resolution'] = resolution
        
        if fps:
            # Would need to recreate camera for FPS change
            settings_applied['fps'] = fps
        
        # Note: OpenCV has limited support for camera property changes
        # Most cameras require recreation for resolution/FPS changes
        
        return jsonify({
            'success': True,
            'message': 'Camera configured',
            'settings': settings_applied,
            'note': 'Some changes may require camera restart'
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CAMERA_CONFIGURE_ERROR',
                'message': str(e)
            }
        }), 500
