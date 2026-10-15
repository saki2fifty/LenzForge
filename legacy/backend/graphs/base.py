"""
Base class for MediaPipe graphs

Provides common interface for all tracking graphs.
"""
from abc import ABC, abstractmethod
from typing import Optional, List
import numpy as np

from ..ipc.ring_landmarks import LandmarkBlock


class GraphBase(ABC):
    """
    Base class for MediaPipe tracking graphs
    
    All tracking implementations (FaceMesh, Hands, Pose, etc.) inherit from this.
    """
    
    def __init__(self, config):
        """
        Initialize graph
        
        Args:
            config: Configuration for this graph
        """
        self.config = config
        self.enabled = config.enabled
        self.solution = None  # MediaPipe solution instance
    
    @abstractmethod
    def initialize(self) -> bool:
        """
        Initialize the MediaPipe solution
        
        Returns:
            True if initialization successful
        """
        pass
    
    @abstractmethod
    def process(self, frame: np.ndarray) -> Optional[List[LandmarkBlock]]:
        """
        Process frame and extract landmarks
        
        Args:
            frame: Input frame (BGR format)
            
        Returns:
            List of LandmarkBlocks or None if no detection
        """
        pass
    
    def close(self):
        """Close the MediaPipe solution"""
        if self.solution is not None:
            self.solution.close()
            self.solution = None
    
    def is_enabled(self) -> bool:
        """Check if graph is enabled"""
        return self.enabled
    
    def set_enabled(self, enabled: bool):
        """Enable or disable graph"""
        self.enabled = enabled
