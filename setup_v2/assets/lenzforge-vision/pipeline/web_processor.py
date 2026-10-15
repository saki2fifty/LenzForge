"""
Web-focused MediaPipe processor

Simplified processor for web streaming (no ring buffers).
Processes camera frames and returns landmark data for overlay.
"""
import cv2
import mediapipe as mp
import numpy as np
from typing import Optional, Dict, List, Any
import logging

logger = logging.getLogger(__name__)


class WebProcessor:
    """
    MediaPipe processor for web streaming
    
    Handles face mesh, iris, hands, and pose tracking
    with simplified configuration for web display.
    """
    
    def __init__(self):
        """Initialize processor"""
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_hands = mp.solutions.hands
        self.mp_pose = mp.solutions.pose
        
        # MediaPipe solutions
        self.face_mesh: Optional[Any] = None
        self.hands: Optional[Any] = None
        self.pose: Optional[Any] = None
        
        # Tracking configuration
        self.tracking_enabled = {
            'face': False,
            'iris': False,
            'hands': False,
            'pose': False
        }
        
        # Statistics
        self.frames_processed = 0
        
        # Monotonic timestamp for MediaPipe (microseconds)
        self.last_timestamp_us = 0
    
    def enable_tracking(self, tracking_type: str, enabled: bool = True):
        """
        Enable/disable a tracking type
        
        Args:
            tracking_type: 'face', 'iris', 'hands', or 'pose'
            enabled: True to enable, False to disable
        """
        if tracking_type not in self.tracking_enabled:
            logger.warning(f"Unknown tracking type: {tracking_type}")
            return
        
        self.tracking_enabled[tracking_type] = enabled
        
        # Initialize or cleanup models as needed
        if enabled:
            self._init_model(tracking_type)
        else:
            self._cleanup_model(tracking_type)
    
    def _init_model(self, tracking_type: str):
        """Initialize a MediaPipe model"""
        try:
            if tracking_type == 'face' or tracking_type == 'iris':
                if self.face_mesh is None:
                    self.face_mesh = self.mp_face_mesh.FaceMesh(
                        static_image_mode=False,
                        max_num_faces=1,
                        refine_landmarks=True,  # Includes iris
                        min_detection_confidence=0.5,
                        min_tracking_confidence=0.5
                    )
                    logger.info("Face Mesh initialized")
            
            if tracking_type == 'hands':
                if self.hands is None:
                    self.hands = self.mp_hands.Hands(
                        static_image_mode=False,
                        max_num_hands=2,
                        min_detection_confidence=0.5,
                        min_tracking_confidence=0.5
                    )
                    logger.info("Hands initialized")
            
            if tracking_type == 'pose':
                if self.pose is None:
                    self.pose = self.mp_pose.Pose(
                        static_image_mode=False,
                        min_detection_confidence=0.5,
                        min_tracking_confidence=0.5
                    )
                    logger.info("Pose initialized")
        
        except Exception as e:
            logger.error(f"Failed to initialize {tracking_type}: {e}")
    
    def _get_monotonic_timestamp_us(self) -> int:
        """
        Get monotonic timestamp for MediaPipe (microseconds)
        
        Ensures timestamps are strictly increasing to avoid MediaPipe errors.
        Returns timestamp in microseconds since epoch.
        """
        import time
        
        # Get current time in microseconds
        current_timestamp = int(time.time() * 1000000)
        
        # Ensure strictly increasing (each frame MUST have higher timestamp)
        if current_timestamp <= self.last_timestamp_us:
            current_timestamp = self.last_timestamp_us + 1
        
        self.last_timestamp_us = current_timestamp
        return current_timestamp
    
    def _cleanup_model(self, tracking_type: str):
        """Cleanup a MediaPipe model"""
        # Only cleanup if no other tracking types need it
        if tracking_type == 'face' or tracking_type == 'iris':
            # Keep face mesh if either face or iris is enabled
            if not (self.tracking_enabled['face'] or self.tracking_enabled['iris']):
                if self.face_mesh is not None:
                    self.face_mesh.close()
                    self.face_mesh = None
                    logger.info("Face Mesh cleaned up")
        
        if tracking_type == 'hands':
            if self.hands is not None:
                self.hands.close()
                self.hands = None
                logger.info("Hands cleaned up")
        
        if tracking_type == 'pose':
            if self.pose is not None:
                self.pose.close()
                self.pose = None
                logger.info("Pose cleaned up")
    
    def process(self, frame: np.ndarray) -> Dict[str, Any]:
        """
        Process frame through enabled MediaPipe models
        
        Args:
            frame: BGR frame from camera
            
        Returns:
            Dictionary containing landmark data for enabled tracking types
        """
        if frame is None:
            return {}
        
        # Convert BGR to RGB for MediaPipe
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # MediaPipe will use its own internal timestamp tracking
        # We just need to ensure we don't process the same frame twice
        landmarks = {}
        
        # Process face mesh (includes iris if refine_landmarks=True)
        if (self.tracking_enabled['face'] or self.tracking_enabled['iris']) and self.face_mesh is not None:
            try:
                results = self.face_mesh.process(frame_rgb)
                
                if results.multi_face_landmarks:
                    face_landmarks = []
                    for landmark in results.multi_face_landmarks[0].landmark:
                        face_landmarks.append({
                            'x': landmark.x,
                            'y': landmark.y,
                            'z': landmark.z,
                            'confidence': 1.0  # Face mesh doesn't provide per-landmark confidence
                        })
                    
                    if self.tracking_enabled['face']:
                        landmarks['face'] = face_landmarks
                    
                    # Extract iris landmarks (indices 468-477 for left, 473-477 for right)
                    if self.tracking_enabled['iris']:
                        landmarks['iris'] = {
                            'left': face_landmarks[468:473] if len(face_landmarks) > 477 else [],
                            'right': face_landmarks[473:478] if len(face_landmarks) > 477 else []
                        }
            
            except Exception as e:
                logger.error(f"Face mesh processing error: {e}")
        
        # Process hands
        if self.tracking_enabled['hands'] and self.hands is not None:
            try:
                results = self.hands.process(frame_rgb)
                
                if results.multi_hand_landmarks and results.multi_handedness:
                    hands_data = {'left': [], 'right': []}
                    
                    for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                        # Determine which hand (left or right)
                        hand_type = handedness.classification[0].label.lower()
                        
                        hand_data = []
                        for landmark in hand_landmarks.landmark:
                            hand_data.append({
                                'x': landmark.x,
                                'y': landmark.y,
                                'z': landmark.z
                            })
                        
                        hands_data[hand_type] = hand_data
                    
                    landmarks['hands'] = hands_data
            
            except Exception as e:
                logger.error(f"Hands processing error: {e}")
        
        # Process pose
        if self.tracking_enabled['pose'] and self.pose is not None:
            try:
                results = self.pose.process(frame_rgb)
                
                if results.pose_landmarks:
                    pose_landmarks = []
                    for landmark in results.pose_landmarks.landmark:
                        pose_landmarks.append({
                            'x': landmark.x,
                            'y': landmark.y,
                            'z': landmark.z,
                            'visibility': landmark.visibility
                        })
                    
                    landmarks['pose'] = pose_landmarks
            
            except Exception as e:
                logger.error(f"Pose processing error: {e}")
        
        self.frames_processed += 1
        return landmarks
    
    def get_enabled_tracking(self) -> Dict[str, bool]:
        """Get current tracking configuration"""
        return self.tracking_enabled.copy()
    
    def cleanup(self):
        """Cleanup all MediaPipe models"""
        if self.face_mesh is not None:
            self.face_mesh.close()
            self.face_mesh = None
        
        if self.hands is not None:
            self.hands.close()
            self.hands = None
        
        if self.pose is not None:
            self.pose.close()
            self.pose = None
        
        logger.info("WebProcessor cleaned up")
