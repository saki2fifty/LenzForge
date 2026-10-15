"""
Camera capture module

Uses MSMF extension for robust camera handling.
"""
import cv2
import numpy as np
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass
from capture.cap_msmf import Camera as MSMFCamera
from capture.mediapipe_worker import MediaPipeWorker
from ipc.ring_nv12 import NV12RingWriter
from ipc.ring_landmarks import LMK1Writer, GRAPH_FACEMESH
from ipc.qpc import get_qpc_ticks
from graphs.facemesh_cpu import calculate_mp_resolution
from pipeline.performance_config import get_performance_config

logger = logging.getLogger('CAMERA')


@dataclass
class CameraStats:
    """Camera statistics"""
    frames_captured: int = 0
    frames_dropped: int = 0
    is_opened: bool = False


class Camera:
    """
    Camera capture wrapper
    
    Provides robust camera capture with error handling and statistics.
    """
    
    def __init__(self, camera_id: int, width: int = 640, height: int = 480, fps: int = 30,
                 mp_enabled: bool = True, mp_max_width: int = None):
        """
        Initialize camera
        
        Args:
            camera_id: Camera device ID
            width: Frame width (default: 640)
            height: Frame height (default: 480)
            fps: Target FPS (default: 30)
            mp_enabled: Enable MediaPipe processing (default: True)
            mp_max_width: MediaPipe max input width (None = use config, 0 = full-res)
        """
        self.camera_id = camera_id
        self.index = camera_id
        self.name = f"Camera {camera_id}"
        self.width = width
        self.height = height
        self.fps = fps
        
        # Get performance config
        perf_config = get_performance_config()
        
        # MediaPipe config
        self.mp_enabled = mp_enabled
        self.mp_max_width = mp_max_width if mp_max_width is not None else perf_config.mediapipe_max_width
        self.mp_width = 0
        self.mp_height = 0
        
        # Camera and ring resources
        self.msmf_camera: Optional[MSMFCamera] = None
        self.stats = CameraStats()
        self.ring_writer: Optional[NV12RingWriter] = None
        self.lmk1_writer: Optional[LMK1Writer] = None
        self.mp_worker: Optional[MediaPipeWorker] = None
        self.negotiated_format: Optional[Dict[str, Any]] = None
        self.frame_count = 0
        
        # Double-buffering for tear-free frame delivery
        self.current_frame: Optional[np.ndarray] = None
        self.previous_frame: Optional[np.ndarray] = None
    
    def open(self) -> bool:
        """
        Open camera using MSMF extension
        
        Returns:
            True if camera opened successfully
        """
        import time
        
        try:
            logger.info(f"Opening camera {self.camera_id} with MSMF extension...")
            self.msmf_camera = MSMFCamera(
                self.camera_id,
                self.width,
                self.height,
                self.fps,
                "NV12"
            )
            
            # Camera needs warm-up - retry reading first frame up to 10 times
            test_frame = None
            for attempt in range(10):
                test_frame = self.msmf_camera.read()
                if test_frame is not None:
                    break
                logger.debug(f"Frame read attempt {attempt + 1}/10 failed, retrying...")
                time.sleep(0.1)
            
            if test_frame is None:
                logger.error("MSMF extension: Failed to read test frame after 10 attempts")
                self.msmf_camera = None
                return False
            
            logger.info(f"MSMF extension: Camera opened successfully, frame shape: {test_frame.shape}")
            
            # Detect format from frame shape
            if len(test_frame.shape) == 3:
                # BGR format (OpenCV fallback): shape is (height, width, 3)
                self.width = test_frame.shape[1]
                self.height = test_frame.shape[0]
                actual_pixels = self.width * self.height
                logger.info(f"Detected BGR format from OpenCV fallback: {self.width}x{self.height}")
            else:
                # NV12 format: total size = width * height * 1.5
                # So: width * height = frame_size / 1.5
                frame_size = test_frame.shape[0]
                actual_pixels = int(frame_size / 1.5)
            
            # Try to detect actual resolution from common formats
            # Common resolutions: 1920x1080, 1280x720, 640x480, etc.
            common_resolutions = [
                (1920, 1080),  # Full HD
                (1280, 960),   # 4:3 HD
                (1280, 720),   # HD
                (960, 720),    # 4:3
                (800, 600),    # SVGA
                (640, 480),    # VGA
            ]
            
            # Check if frame matches a common resolution
            resolution_found = False
            for w, h in common_resolutions:
                if w * h == actual_pixels:
                    self.width = w
                    self.height = h
                    resolution_found = True
                    break
            
            # If no match, try to infer width/height from aspect ratio
            if not resolution_found:
                # Assume 16:9 or 4:3 aspect ratio
                # Try 16:9 first
                import math
                width_16_9 = int(math.sqrt(actual_pixels * 16 / 9))
                height_16_9 = actual_pixels // width_16_9
                if width_16_9 * height_16_9 == actual_pixels:
                    self.width = width_16_9
                    self.height = height_16_9
                else:
                    # Try 4:3
                    width_4_3 = int(math.sqrt(actual_pixels * 4 / 3))
                    height_4_3 = actual_pixels // width_4_3
                    if width_4_3 * height_4_3 == actual_pixels:
                        self.width = width_4_3
                        self.height = height_4_3
                    else:
                        # Fall back to square-ish resolution
                        self.width = int(math.sqrt(actual_pixels))
                        self.height = actual_pixels // self.width
            
            logger.info(f"Detected resolution: {self.width}x{self.height} ({actual_pixels} pixels)")
            
            # Create VID1 ring writer (critical path)
            try:
                self.ring_writer = NV12RingWriter(
                    "LenzForge_Video_NV12",
                    self.width,
                    self.height
                )
                logger.info(f"VID1 ring writer created: {self.width}x{self.height}")
            except Exception as e:
                logger.error(f"Failed to create VID1 ring writer: {e}")
                self.msmf_camera = None
                return False
            
            # Store negotiated format info
            self.negotiated_format = {
                'format': 'NV12',
                'width': self.width,
                'height': self.height,
                'fps': self.fps,
                'y_stride': self.width,
                'uv_stride': self.width
            }
            
            # Initialize MediaPipe worker if enabled
            if self.mp_enabled:
                try:
                    # Calculate MediaPipe resolution
                    self.mp_width, self.mp_height = calculate_mp_resolution(
                        self.width, self.height, self.mp_max_width
                    )
                    logger.info(f"MediaPipe resolution: {self.mp_width}×{self.mp_height}")
                    
                    # Create LMK1 ring writer
                    self.lmk1_writer = LMK1Writer(
                        "LenzForge_Landmarks",
                        self.mp_width,
                        self.mp_height,
                        graph_id=GRAPH_FACEMESH
                    )
                    logger.info(f"LMK1 ring writer created: {self.mp_width}×{self.mp_height}")
                    
                    # Create and start MediaPipe worker thread
                    self.mp_worker = MediaPipeWorker(
                        self.lmk1_writer,
                        self.mp_width,
                        self.mp_height,
                        self.width,
                        self.height
                    )
                    self.mp_worker.start()
                    logger.info("MediaPipe worker thread started")
                    
                except Exception as e:
                    logger.error(f"Failed to initialize MediaPipe: {e}")
                    # Continue without MediaPipe
                    self.mp_enabled = False
                    if self.lmk1_writer:
                        self.lmk1_writer.close()
                        self.lmk1_writer = None
            
            self.stats.is_opened = True
            return True
            
        except Exception as e:
            logger.error(f"Failed to open camera with MSMF extension: {e}")
            self.msmf_camera = None
            return False
    
    def close(self):
        """Close camera"""
        # Stop MediaPipe worker
        if self.mp_worker is not None:
            self.mp_worker.stop()
            self.mp_worker = None
        
        # Close LMK1 ring
        if self.lmk1_writer is not None:
            self.lmk1_writer.close()
            self.lmk1_writer = None
        
        # Close VID1 ring
        if self.ring_writer is not None:
            self.ring_writer.close()
            self.ring_writer = None
        
        # Close camera
        if self.msmf_camera is not None:
            self.msmf_camera = None
            self.stats.is_opened = False
    
    def read(self) -> tuple[bool, Optional[np.ndarray]]:
        """
        Read frame from camera
        
        Returns:
            Tuple of (success, frame) where frame is BGR numpy array or None
        """
        if self.msmf_camera is None:
            return False, None
        
        try:
            frame_data = self.msmf_camera.read()
            if frame_data is not None:
                # Detect format from shape
                is_bgr = len(frame_data.shape) == 3
                
                if is_bgr:
                    # BGR format from OpenCV fallback - already in correct format
                    frame_bgr = frame_data
                    
                    # Convert BGR to NV12 for VID1 ring
                    if self.ring_writer:
                        try:
                            # Convert BGR to YUV I420 first
                            yuv_i420 = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2YUV_I420)
                            
                            # Flatten to 1D array
                            yuv_flat = yuv_i420.ravel()
                            
                            # Extract planes
                            y_size = self.width * self.height
                            uv_size = y_size // 4
                            
                            # Y plane is same in both I420 and NV12
                            y_plane = yuv_flat[:y_size].tobytes()
                            
                            # Interleave U and V planes for NV12
                            u_plane = yuv_flat[y_size:y_size + uv_size]
                            v_plane = yuv_flat[y_size + uv_size:y_size + 2*uv_size]
                            
                            # Create interleaved UV plane
                            uv_interleaved = np.empty(y_size // 2, dtype=np.uint8)
                            uv_interleaved[0::2] = u_plane
                            uv_interleaved[1::2] = v_plane
                            
                            # Write to ring with QPC timestamp
                            ts_qpc = get_qpc_ticks()
                            self.ring_writer.write_frame(y_plane, uv_interleaved.tobytes(), ts_qpc)
                        except Exception as e:
                            logger.error(f"Error writing BGR to VID1 ring: {e}")
                else:
                    # NV12 format from MSMF - need to convert to BGR for MJPEG
                    # CRITICAL PATH: Write to VID1 ring FIRST
                    if self.ring_writer:
                        try:
                            # Split NV12 into Y and UV planes
                            y_size = self.width * self.height
                            y_plane = frame_data[:y_size].tobytes()
                            uv_plane = frame_data[y_size:].tobytes()
                            
                            # Write to ring with QPC timestamp
                            ts_qpc = get_qpc_ticks()
                            self.ring_writer.write_frame(y_plane, uv_plane, ts_qpc)
                        except Exception as e:
                            logger.error(f"Error writing NV12 to VID1 ring: {e}")
                    
                    # Convert NV12 to BGR
                    # C++ extension now has MemoryBarrier() to ensure DMA completion
                    nv12_height = int(self.height * 1.5)
                    frame_shaped = frame_data.reshape((nv12_height, self.width))
                    frame_bgr = cv2.cvtColor(frame_shaped, cv2.COLOR_YUV2BGR_NV12)
                
                # Queue frame to MediaPipe worker (async, non-blocking)
                ts_qpc = get_qpc_ticks()
                if self.mp_worker and self.mp_worker.running:
                    self.mp_worker.queue_frame(frame_bgr, ts_qpc, self.frame_count)
                
                self.stats.frames_captured += 1
                self.frame_count += 1
                
                # Return frame (now guaranteed to be a complete independent copy)
                return True, frame_bgr
            else:
                self.stats.frames_dropped += 1
                return False, None
        except Exception as e:
            logger.error(f"Error reading frame: {e}")
            self.stats.frames_dropped += 1
            return False, None
    
    def is_opened(self) -> bool:
        """Check if camera is opened"""
        return self.msmf_camera is not None
    
    def get_properties(self) -> Dict[str, Any]:
        """Get camera properties"""
        return {
            'camera_id': self.camera_id,
            'width': self.width,
            'height': self.height,
            'fps': self.fps,
        }
    
    def set_property(self, prop: str, value: Any) -> bool:
        """
        Set camera property (limited support with MSMF extension)
        
        Args:
            prop: Property name
            value: Property value
            
        Returns:
            True if property was set successfully
        """
        if prop in ['width', 'height', 'fps']:
            setattr(self, prop, value)
            return True
        return False
    
    def get_stats(self) -> CameraStats:
        """Get camera statistics"""
        return self.stats
    
    def reset_stats(self):
        """Reset camera statistics"""
        self.stats = CameraStats(is_opened=self.is_opened())
    
    def release(self):
        """Alias for close() for compatibility"""
        self.close()
