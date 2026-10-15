"""
MediaPipe FaceMesh CPU Graph

Optimized FaceMesh wrapper with:
- CPU inference via XNNPACK delegate
- 478 refined landmarks
- Smart thread count (CPU cores / 2)
- Normalized coordinate output [0, 1]
"""
import logging
import multiprocessing
from typing import List, Tuple, Optional
import numpy as np
from graphs.tasks_compat import solutions

logger = logging.getLogger(__name__)

class FaceMeshCPU:
    """
    MediaPipe FaceMesh CPU inference wrapper
    
    Returns 478 facial landmarks in normalized coordinates [0, 1]
    relative to input image dimensions.
    """
    
    def __init__(self, 
                 max_num_faces: int = 1,
                 refine_landmarks: bool = True,
                 min_detection_confidence: float = 0.5,
                 min_tracking_confidence: float = 0.5,
                 num_threads: Optional[int] = None):
        """
        Initialize FaceMesh graph
        
        Args:
            max_num_faces: Maximum number of faces to detect (1 for best perf)
            refine_landmarks: Use refined mesh (478 vs 468 landmarks)
            min_detection_confidence: Detection threshold [0, 1]
            min_tracking_confidence: Tracking threshold [0, 1]
            num_threads: Thread count (None = auto: CPU cores / 2)
        """
        # Auto-detect thread count
        if num_threads is None:
            cpu_count = multiprocessing.cpu_count()
            num_threads = max(1, cpu_count // 2)
        
        self.num_threads = num_threads
        self.max_num_faces = max_num_faces
        
        logger.info(f"Initializing FaceMesh: threads={num_threads}, refine={refine_landmarks}")
        
        # Initialize MediaPipe FaceMesh
        try:
            self.mp_face_mesh = solutions.face_mesh
            self.face_mesh = self.mp_face_mesh.FaceMesh(
                static_image_mode=False,  # Video mode (faster)
                max_num_faces=max_num_faces,
                refine_landmarks=refine_landmarks,  # 478 points
                min_detection_confidence=min_detection_confidence,
                min_tracking_confidence=min_tracking_confidence
            )
            
            logger.info("FaceMesh initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize FaceMesh: {e}")
            raise
    
    def process(self, bgr_frame: np.ndarray) -> Optional[List[Tuple[float, float, float]]]:
        """
        Process BGR frame and extract facial landmarks
        
        Args:
            bgr_frame: Input image as numpy array (H, W, 3) in BGR format
        
        Returns:
            List of 478 (x, y, z) tuples in normalized coordinates [0, 1]
            None if no face detected
        
        Notes:
            - x, y are normalized to image dimensions [0, 1]
            - z is depth relative to face center (approximate)
            - MediaPipe internally converts BGR → RGB
        """
        if bgr_frame is None or bgr_frame.size == 0:
            return None
        
        try:
            # Convert BGR to RGB (MediaPipe expects RGB)
            rgb_frame = bgr_frame[:, :, ::-1]
            
            # Process frame
            results = self.face_mesh.process(rgb_frame)
            
            # Extract landmarks if face detected
            if results.multi_face_landmarks:
                # Get first face (max_num_faces=1)
                face_landmarks = results.multi_face_landmarks[0]
                
                # Convert to list of (x, y, z) tuples
                landmarks = []
                for landmark in face_landmarks.landmark:
                    landmarks.append((landmark.x, landmark.y, landmark.z))
                
                return landmarks
            else:
                # No face detected
                return None
                
        except Exception as e:
            logger.error(f"Error processing frame: {e}")
            return None
    
    def close(self):
        """Release MediaPipe resources"""
        if hasattr(self, 'face_mesh') and self.face_mesh:
            self.face_mesh.close()
            self.face_mesh = None
            logger.info("FaceMesh closed")
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def __del__(self):
        self.close()


def calculate_mp_resolution(camera_w: int, camera_h: int, 
                           max_width: int = 640) -> Tuple[int, int]:
    """
    Calculate optimal MediaPipe input resolution
    
    Rules:
    - Maintain aspect ratio
    - Cap at max_width for performance
    - Ensure even dimensions (NV12 requirement)
    
    Args:
        camera_w: Camera width
        camera_h: Camera height
        max_width: Maximum width for MediaPipe input
    
    Returns:
        (width, height) tuple with even dimensions
    
    Examples:
        640×480 → 640×480 (no resize)
        1280×720 → 640×360
        1920×1080 → 640×360
        1920×1080 @ max_width=960 → 960×540
    """
    if camera_w <= max_width:
        # Use camera resolution as-is
        mp_w, mp_h = camera_w, camera_h
    else:
        # Scale down to max_width, maintain aspect ratio
        scale = max_width / camera_w
        mp_w = max_width
        mp_h = int(camera_h * scale)
    
    # Ensure even dimensions (required for NV12)
    mp_w = (mp_w // 2) * 2
    mp_h = (mp_h // 2) * 2
    
    return mp_w, mp_h


def get_smart_mp_defaults(camera_w: int, camera_h: int) -> dict:
    """
    Get smart MediaPipe defaults based on camera resolution
    
    Recommendations:
    - ≤720p camera → MP at 640px width
    - 1080p camera → MP at 640-960px width (start 640)
    - Ultrawide → Scale to even dims, preserve AR
    
    Args:
        camera_w: Camera width
        camera_h: Camera height
    
    Returns:
        dict with 'max_width', 'mp_w', 'mp_h'
    """
    if camera_w <= 720:
        # Low resolution camera - use as-is
        max_width = camera_w
    elif camera_w <= 1280:
        # 720p - use 640px
        max_width = 640
    else:
        # 1080p+ - use 640px (can bump to 960 if CPU headroom)
        max_width = 640
    
    mp_w, mp_h = calculate_mp_resolution(camera_w, camera_h, max_width)
    
    return {
        'max_width': max_width,
        'mp_w': mp_w,
        'mp_h': mp_h
    }
