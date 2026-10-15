"""
Camera enumeration using MSMF (pure Media Foundation)

NO DirectShow! Uses cap_msmf wrapper which prefers native MSMF extension.
"""
from typing import List, Dict, Optional
from dataclasses import dataclass
import cv2

# Import MSMF wrapper (handles fallback automatically) - ABSOLUTE IMPORT!
from capture.cap_msmf import enumerate_cameras as msmf_enumerate, CameraInfo as MSMFCameraInfo


@dataclass
class ResolutionInfo:
    """Information about a supported resolution"""
    width: int
    height: int
    fps_options: List[int]


@dataclass
class CameraInfo:
    """Information about an available camera"""
    id: int
    name: str
    backend: str = "MSMF"
    supported_resolutions: List[ResolutionInfo] = None
    
    def __str__(self) -> str:
        return f"Camera {self.id}: {self.name} ({self.backend})"


def enumerate_cameras(max_check: int = 10) -> List[CameraInfo]:
    """
    Enumerate available cameras using MSMF with capability detection
    
    Args:
        max_check: Maximum number of camera IDs to check (ignored for MSMF)
        
    Returns:
        List of available cameras with supported resolutions
    """
    # Use MSMF wrapper (fast, real names, no registry!)
    cameras_msmf = msmf_enumerate()
    
    # Convert to our format with capabilities
    result = []
    for cam in cameras_msmf:
        resolutions = []
        if hasattr(cam, 'supported_resolutions') and cam.supported_resolutions:
            resolutions = [
                ResolutionInfo(
                    width=res.width,
                    height=res.height,
                    fps_options=list(res.fps_options)
                )
                for res in cam.supported_resolutions
            ]
        
        result.append(CameraInfo(
            id=cam.index,
            name=cam.name,
            backend=cam.backend,
            supported_resolutions=resolutions
        ))
    
    return result


def get_camera_capabilities(camera_id: int) -> Optional[Dict]:
    """
    Get capabilities of a specific camera using MSMF
    
    Args:
        camera_id: Camera ID to query
        
    Returns:
        Dictionary of capabilities or None if camera not available
    """
    cap = cv2.VideoCapture(camera_id, cv2.CAP_MSMF)
    
    if not cap.isOpened():
        return None
    
    capabilities = {
        'id': camera_id,
        'backend': 'MSMF',
        'default_width': int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        'default_height': int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        'default_fps': int(cap.get(cv2.CAP_PROP_FPS)),
        'supports_properties': {
            'brightness': cap.get(cv2.CAP_PROP_BRIGHTNESS) != -1,
            'contrast': cap.get(cv2.CAP_PROP_CONTRAST) != -1,
            'saturation': cap.get(cv2.CAP_PROP_SATURATION) != -1,
            'hue': cap.get(cv2.CAP_PROP_HUE) != -1,
            'gain': cap.get(cv2.CAP_PROP_GAIN) != -1,
            'exposure': cap.get(cv2.CAP_PROP_EXPOSURE) != -1,
        }
    }
    
    cap.release()
    return capabilities


def find_camera_by_name(name: str) -> Optional[int]:
    """
    Find camera ID by name (partial match)
    
    Args:
        name: Camera name to search for
        
    Returns:
        Camera ID or None if not found
    """
    cameras = enumerate_cameras()
    name_lower = name.lower()
    
    for camera in cameras:
        if name_lower in camera.name.lower():
            return camera.id
    
    return None


def is_camera_available(camera_id: int) -> bool:
    """
    Check if a camera is available using MSMF
    
    Args:
        camera_id: Camera ID to check
        
    Returns:
        True if camera is available
    """
    cap = cv2.VideoCapture(camera_id, cv2.CAP_MSMF)
    available = cap.isOpened()
    cap.release()
    return available
