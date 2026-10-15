"""
MediaPipe Hand tracking graph

21 landmarks per hand (knuckles, fingertips, etc.).
"""
import struct
from typing import Optional, List
import numpy as np
import mediapipe as mp

from .base import GraphBase
from ..ipc.ring_landmarks import LandmarkBlock, STREAM_HAND_LEFT, STREAM_HAND_RIGHT, FLAG_HAS_CONFIDENCE


class HandsGraph(GraphBase):
    """
    Hand tracking graph
    
    Detects and tracks 21 landmarks per hand with handedness classification.
    """
    
    def __init__(self, config):
        """
        Initialize hands graph
        
        Args:
            config: HandsConfig object
        """
        super().__init__(config)
        self.mp_hands = mp.solutions.hands
    
    def initialize(self) -> bool:
        """Initialize MediaPipe Hands"""
        try:
            self.solution = self.mp_hands.Hands(
                max_num_hands=self.config.max_num_hands,
                model_complexity=self.config.model_complexity,
                min_detection_confidence=self.config.min_detection_confidence,
                min_tracking_confidence=self.config.min_tracking_confidence
            )
            return True
        except Exception as e:
            print(f"[Hands] Failed to initialize: {e}")
            return False
    
    def process(self, frame: np.ndarray) -> Optional[List[LandmarkBlock]]:
        """
        Process frame and extract hand landmarks
        
        Args:
            frame: Input frame (BGR format)
            
        Returns:
            List of LandmarkBlocks (one per hand) or None
        """
        if not self.enabled or self.solution is None:
            return None
        
        # Convert BGR to RGB
        rgb_frame = frame[:, :, ::-1]
        
        # Process frame
        results = self.solution.process(rgb_frame)
        
        if not results.multi_hand_landmarks:
            return None
        
        # Convert to LandmarkBlocks
        blocks = []
        
        for idx, hand_landmarks in enumerate(results.multi_hand_landmarks):
            # Determine handedness (left or right)
            handedness = None
            if results.multi_handedness and idx < len(results.multi_handedness):
                handedness = results.multi_handedness[idx].classification[0].label
            
            # Choose stream ID based on handedness
            if handedness == "Left":
                stream_id = STREAM_HAND_LEFT
            elif handedness == "Right":
                stream_id = STREAM_HAND_RIGHT
            else:
                # If handedness unknown, use left for first hand, right for second
                stream_id = STREAM_HAND_LEFT if idx == 0 else STREAM_HAND_RIGHT
            
            # Pack landmarks as binary data
            data = bytearray()
            for landmark in hand_landmarks.landmark:
                # Pack as x, y, z, confidence
                data.extend(struct.pack('<ffff',
                    landmark.x,
                    landmark.y,
                    landmark.z,
                    1.0  # MediaPipe hands don't provide per-landmark confidence
                ))
            
            # Create landmark block
            block = LandmarkBlock(
                stream_id=stream_id,
                elem_stride=16,  # 4 floats × 4 bytes
                elem_count=len(hand_landmarks.landmark),
                flags=FLAG_HAS_CONFIDENCE,
                data=bytes(data)
            )
            
            blocks.append(block)
        
        return blocks if blocks else None
