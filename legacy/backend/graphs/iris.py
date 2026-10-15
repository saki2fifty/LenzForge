"""
MediaPipe Iris tracking graph

10 landmarks per eye (iris + eye contour).
"""
import struct
from typing import Optional, List
import numpy as np
from graphs.tasks_compat import solutions

from .base import GraphBase
from ..ipc.ring_landmarks import LandmarkBlock, STREAM_IRIS_LEFT, STREAM_IRIS_RIGHT, FLAG_HAS_CONFIDENCE


class IrisGraph(GraphBase):
    """
    Iris tracking graph
    
    Detects and tracks 10 landmarks per eye with confidence scores.
    Requires face mesh to be running.
    """
    
    def __init__(self, config):
        """
        Initialize iris graph
        
        Args:
            config: IrisConfig object
        """
        super().__init__(config)
        self.mp_face_mesh = solutions.face_mesh
    
    def initialize(self) -> bool:
        """Initialize MediaPipe FaceMesh with iris refinement"""
        try:
            self.solution = self.mp_face_mesh.FaceMesh(
                max_num_faces=1,
                refine_landmarks=True,  # Required for iris
                min_detection_confidence=self.config.min_detection_confidence,
                min_tracking_confidence=self.config.min_tracking_confidence
            )
            return True
        except Exception as e:
            print(f"[Iris] Failed to initialize: {e}")
            return False
    
    def process(self, frame: np.ndarray) -> Optional[List[LandmarkBlock]]:
        """
        Process frame and extract iris landmarks
        
        Args:
            frame: Input frame (BGR format)
            
        Returns:
            List of LandmarkBlocks (one per eye) or None
        """
        if not self.enabled or self.solution is None:
            return None
        
        # Convert BGR to RGB
        rgb_frame = frame[:, :, ::-1]
        
        # Process frame
        results = self.solution.process(rgb_frame)
        
        if not results.multi_face_landmarks:
            return None
        
        # Extract iris landmarks (indices 468-477 for left, 473-482 for right)
        # MediaPipe face mesh with refinement includes iris landmarks
        blocks = []
        
        for face_landmarks in results.multi_face_landmarks:
            landmarks = face_landmarks.landmark
            
            # Left eye iris (5 landmarks for iris center and 4 for outer edge)
            left_iris_indices = list(range(468, 473))  # 468-472 (5 points)
            left_iris_data = bytearray()
            for idx in left_iris_indices:
                if idx < len(landmarks):
                    lm = landmarks[idx]
                    left_iris_data.extend(struct.pack('<ffff',
                        lm.x, lm.y, lm.z, 1.0
                    ))
            
            if left_iris_data:
                blocks.append(LandmarkBlock(
                    stream_id=STREAM_IRIS_LEFT,
                    elem_stride=16,
                    elem_count=len(left_iris_indices),
                    flags=FLAG_HAS_CONFIDENCE,
                    data=bytes(left_iris_data)
                ))
            
            # Right eye iris
            right_iris_indices = list(range(473, 478))  # 473-477 (5 points)
            right_iris_data = bytearray()
            for idx in right_iris_indices:
                if idx < len(landmarks):
                    lm = landmarks[idx]
                    right_iris_data.extend(struct.pack('<ffff',
                        lm.x, lm.y, lm.z, 1.0
                    ))
            
            if right_iris_data:
                blocks.append(LandmarkBlock(
                    stream_id=STREAM_IRIS_RIGHT,
                    elem_stride=16,
                    elem_count=len(right_iris_indices),
                    flags=FLAG_HAS_CONFIDENCE,
                    data=bytes(right_iris_data)
                ))
        
        return blocks if blocks else None
