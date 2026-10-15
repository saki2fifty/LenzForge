"""
MediaPipe Pose tracking graph

33 body landmarks (shoulders, hips, knees, etc.).
"""
import struct
from typing import Optional, List
import numpy as np
import mediapipe as mp

from .base import GraphBase
from ..ipc.ring_landmarks import LandmarkBlock, STREAM_POSE, FLAG_HAS_CONFIDENCE


class PoseGraph(GraphBase):
    """
    Pose tracking graph
    
    Detects and tracks 33 body landmarks with visibility and presence scores.
    """
    
    def __init__(self, config):
        """
        Initialize pose graph
        
        Args:
            config: PoseConfig object
        """
        super().__init__(config)
        self.mp_pose = mp.solutions.pose
    
    def initialize(self) -> bool:
        """Initialize MediaPipe Pose"""
        try:
            self.solution = self.mp_pose.Pose(
                model_complexity=self.config.model_complexity,
                enable_segmentation=self.config.enable_segmentation,
                smooth_landmarks=self.config.smooth_landmarks,
                min_detection_confidence=self.config.min_detection_confidence,
                min_tracking_confidence=self.config.min_tracking_confidence
            )
            return True
        except Exception as e:
            print(f"[Pose] Failed to initialize: {e}")
            return False
    
    def process(self, frame: np.ndarray) -> Optional[List[LandmarkBlock]]:
        """
        Process frame and extract pose landmarks
        
        Args:
            frame: Input frame (BGR format)
            
        Returns:
            List of LandmarkBlocks (one block with 33 landmarks) or None
        """
        if not self.enabled or self.solution is None:
            return None
        
        # Convert BGR to RGB
        rgb_frame = frame[:, :, ::-1]
        
        # Process frame
        results = self.solution.process(rgb_frame)
        
        if not results.pose_landmarks:
            return None
        
        # Pack landmarks as binary data
        data = bytearray()
        
        for landmark in results.pose_landmarks.landmark:
            # Pack as x, y, z, visibility (use visibility as confidence)
            # MediaPipe pose provides visibility which indicates if landmark is visible
            data.extend(struct.pack('<ffff',
                landmark.x,
                landmark.y,
                landmark.z,
                landmark.visibility  # Use visibility as confidence
            ))
        
        # Create landmark block
        block = LandmarkBlock(
            stream_id=STREAM_POSE,
            elem_stride=16,  # 4 floats × 4 bytes
            elem_count=len(results.pose_landmarks.landmark),
            flags=FLAG_HAS_CONFIDENCE,
            data=bytes(data)
        )
        
        return [block]
