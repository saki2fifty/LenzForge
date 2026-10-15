"""
MSMF Camera Capture Wrapper
Uses native MSMF extension if available, falls back to OpenCV

Pure Media Foundation - NO DirectShow!
"""
import numpy as np
import cv2
import logging
import os
import sys
from typing import List, Optional, Tuple
from dataclasses import dataclass

# Setup module logger
logger = logging.getLogger('CAMERA')

# Add capture directory to sys.path and DLL search path
capture_dir = os.path.dirname(os.path.abspath(__file__))

# Add to sys.path so Python can find msmf_capture.pyd
if capture_dir not in sys.path:
    sys.path.insert(0, capture_dir)
    logger.debug(f"Added to sys.path: {capture_dir}")

# Add to DLL search path (for MinGW DLLs on Windows)
if sys.platform == 'win32' and hasattr(os, 'add_dll_directory'):
    try:
        os.add_dll_directory(capture_dir)
        logger.debug(f"Added DLL directory: {capture_dir}")
    except Exception as e:
        logger.warning(f"Could not add DLL directory: {e}")

# Try to import MSMF extension
try:
    import msmf_capture
    MSMF_AVAILABLE = True
    logger.info("MSMF extension loaded successfully")
except ImportError as e:
    MSMF_AVAILABLE = False
    logger.warning(f"MSMF extension not available: {e}, OpenCV fallback disabled")


@dataclass
class ResolutionInfo:
    """Resolution information"""
    width: int
    height: int
    fps_options: List[int]


@dataclass
class CameraInfo:
    """Camera information"""
    index: int
    name: str
    backend: str
    supported_resolutions: List[ResolutionInfo] = None


def enumerate_cameras() -> List[CameraInfo]:
    """
    Enumerate available cameras using MSMF ONLY
    
    Uses Microsoft's MFEnumDeviceSources API - returns ALL cameras instantly!
    NO FALLBACK to OpenCV - MSMF extension required.
    
    Returns:
        List of CameraInfo objects
        
    Raises:
        RuntimeError: If MSMF extension not available
    """
    logger.info("=== Starting camera enumeration ===")
    
    if not MSMF_AVAILABLE:
        logger.error("MSMF extension not available!")
        raise RuntimeError(
            "MSMF extension not available! "
            "Build it with: cd setup_v2 && .\\020-Build-MSMF-Extension.ps1"
        )
    
    # Use native MSMF extension - FAST! (uses MFEnumDeviceSources internally)
    # This returns ALL cameras at once - no looping needed!
    try:
        logger.info("Calling MSMF enumerate_cameras()...")
        cameras_native = msmf_capture.enumerate_cameras()
        logger.info(f"MSMF returned {len(cameras_native)} camera(s)")
        
        cameras = []
        for cam in cameras_native:
            logger.info(f"  Camera {cam.index}: {cam.name}")
            logger.debug(f"    Symbolic link: {cam.symbolic_link}")
            
            # Extract supported resolutions if available
            resolutions = []
            if hasattr(cam, 'supported_resolutions') and cam.supported_resolutions:
                for res in cam.supported_resolutions:
                    resolutions.append(ResolutionInfo(
                        width=res.width,
                        height=res.height,
                        fps_options=list(res.fps_options)
                    ))
                logger.debug(f"    Found {len(resolutions)} supported resolutions")
            
            cameras.append(CameraInfo(
                index=cam.index,
                name=cam.name,
                backend="MSMF",
                supported_resolutions=resolutions if resolutions else None
            ))
        
        logger.info(f"=== Enumeration complete: {len(cameras)} camera(s) ===")
        return cameras
        
    except Exception as e:
        logger.error(f"MSMF enumeration failed: {e}")
        raise RuntimeError(f"MSMF camera enumeration failed: {e}")


class Camera:
    """
    Camera capture class
    Uses MSMF extension if available, falls back to OpenCV
    """
    
    def __init__(self, camera_index: int, width: int = 640, height: int = 480, 
                 fps: int = 30, format: str = "NV12"):
        """
        Initialize camera
        
        Args:
            camera_index: Camera device index
            width: Frame width
            height: Frame height
            fps: Target FPS
            format: Pixel format ("NV12" or "BGR")
        """
        self.camera_index = camera_index
        self.width = width
        self.height = height
        self.fps = fps
        self.format = format
        self.backend = None
        self.capture = None
        
        self.open()
    
    def open(self) -> bool:
        """Open camera"""
        if MSMF_AVAILABLE and self.format == "NV12":
            # Use MSMF extension for NV12 (no conversion needed!)
            try:
                self.capture = msmf_capture.Camera(
                    self.camera_index,
                    self.width,
                    self.height,
                    self.fps,
                    "NV12"
                )
                self.backend = "MSMF"
                return True
            except Exception as e:
                print(f"[WARN] MSMF camera open failed: {e}, falling back to OpenCV")
                # Fall through to OpenCV
        
        # Fallback: OpenCV
        self.capture = cv2.VideoCapture(self.camera_index)
        if not self.capture.isOpened():
            return False
        
        self.capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        self.capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        self.capture.set(cv2.CAP_PROP_FPS, self.fps)
        
        # Update to actual values
        self.width = int(self.capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(self.capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        self.backend = "OpenCV"
        return True
    
    def read(self) -> Optional[np.ndarray]:
        """
        Read frame from camera
        
        Returns:
            Frame as numpy array or None if failed
            - MSMF: NV12 as flat uint8 array
            - OpenCV: BGR as HxWx3 array
        """
        if self.backend == "MSMF":
            try:
                return self.capture.read()
            except Exception as e:
                print(f"[ERROR] MSMF read failed: {e}")
                return None
        
        elif self.backend == "OpenCV":
            ret, frame = self.capture.read()
            return frame if ret else None
        
        return None
    
    def close(self):
        """Close camera"""
        if self.capture is not None:
            if self.backend == "MSMF":
                self.capture.close()
            elif self.backend == "OpenCV":
                self.capture.release()
            self.capture = None
    
    def is_opened(self) -> bool:
        """Check if camera is opened"""
        if self.backend == "MSMF":
            return self.capture is not None
        elif self.backend == "OpenCV":
            return self.capture is not None and self.capture.isOpened()
        return False
    
    def get_backend(self) -> str:
        """Get active backend name"""
        return self.backend or "None"
    
    def __del__(self):
        """Cleanup on destruction"""
        self.close()
