"""
MediaPipe Face Mesh graph

478-point facial landmark tracking.
"""
import struct
from typing import Optional, List
import numpy as np
import mediapipe as mp

from .base import GraphBase
from ..ipc.ring_landmarks import LandmarkBlock, STREAM_FACE, FLAG_HAS_CONFIDENCE


class FaceMeshGraph(GraphBase):
    """
    Face Mesh tracking graph
    
    Detects and tracks 478 facial landmarks with confidence scores.
    """
    
    def __init__(self, config):
        """
        Initialize face mesh graph
        
        Args:
            config: FaceMeshConfig object
        """
        super().__init__(config)
        self.mp_face_mesh = mp.solutions.face_mesh
    
    def initialize(self) -> bool:
        """Initialize MediaPipe FaceMesh"""
        try:
            self.solution = self.mp_face_mesh.FaceMesh(
                max_num_faces=self.config.max_num_faces,
                refine_landmarks=self.config.refine_landmarks,
                min_detection_confidence=self.config.min_detection_confidence,
                min_tracking_confidence=self.config.min_tracking_confidence
            )
            return True
        except Exception as e:
            print(f"[FaceMesh] Failed to initialize: {e}")
            return False
    
    def process(self, frame: np.ndarray) -> Optional[List[LandmarkBlock]]:
        """
        Process frame and extract face landmarks
        
        Args:
            frame: Input frame (BGR format)
            
        Returns:
            List of LandmarkBlocks (one per detected face) or None
        """
        if not self.enabled or self.solution is None:
            return None
        
        # Convert BGR to RGB for MediaPipe
        rgb_frame = frame[:, :, ::-1]
        
        # Process frame
        results = self.solution.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return None
        
        # Convert to LandmarkBlocks
        blocks = []
        
        for face_landmarks in results.multi_face_landmarks:
            # Pack landmarks as binary data
            data = bytearray()
            
            for landmark in face_landmarks.landmark:
                # Pack as x, y, z, confidence (4 floats = 16 bytes)
                # Note: MediaPipe landmarks don't have per-point confidence
                # We use 1.0 as default confidence
                data.extend(struct.pack('<ffff', 
                    landmark.x, 
                    landmark.y, 
                    landmark.z,
                    1.0  # Default confidence
                ))
            
            # Create landmark block
            block = LandmarkBlock(
                stream_id=STREAM_FACE,
                elem_stride=16,  # 4 floats × 4 bytes
                elem_count=len(face_landmarks.landmark),
                flags=FLAG_HAS_CONFIDENCE,
                data=bytes(data)
            )
            
            blocks.append(block)
        
        return blocks
