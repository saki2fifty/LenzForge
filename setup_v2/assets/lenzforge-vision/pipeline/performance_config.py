"""
Performance Configuration for Video Pipeline
Configurable settings for MediaPipe and MJPEG encoding
"""

class PerformanceConfig:
    """
    Centralized performance configuration
    All settings configurable via API/UI
    """
    
    def __init__(self):
        # MediaPipe Resolution Scaling
        self.mediapipe_max_width = 640  # Default: 640px (fast)
        # Options: 480, 640, 960, 0 (full-res)
        
        # MJPEG Preview Settings
        self.preview_max_fps = 30  # Throttle to 30fps
        self.preview_quality = 85  # JPEG quality 70-95
        self.preview_scale = 1.0   # Scale factor (0.25-1.0)
        
        # Buffer Management
        self.enable_triple_buffer = True
        self.max_queue_size = 3
        
    def get_mediapipe_resolution(self, camera_width, camera_height):
        """
        Calculate MediaPipe input resolution
        
        Args:
            camera_width: Camera resolution width
            camera_height: Camera resolution height
            
        Returns:
            (mp_width, mp_height): Scaled resolution for MediaPipe
        """
        if self.mediapipe_max_width == 0:
            # Full resolution
            return camera_width, camera_height
        
        # Scale to max width while preserving aspect ratio
        if camera_width <= self.mediapipe_max_width:
            return camera_width, camera_height
        
        scale = self.mediapipe_max_width / camera_width
        mp_width = self.mediapipe_max_width
        mp_height = int(camera_height * scale)
        
        # Ensure even dimensions (required for NV12/MediaPipe)
        mp_width = (mp_width // 2) * 2
        mp_height = (mp_height // 2) * 2
        
        return mp_width, mp_height
    
    def get_preview_resolution(self, camera_width, camera_height):
        """
        Calculate preview/MJPEG resolution
        
        Returns:
            (preview_width, preview_height): Scaled resolution for preview
        """
        if self.preview_scale >= 1.0:
            return camera_width, camera_height
        
        width = int(camera_width * self.preview_scale)
        height = int(camera_height * self.preview_scale)
        
        # Ensure even dimensions
        width = (width // 2) * 2
        height = (height // 2) * 2
        
        return width, height
    
    def to_dict(self):
        """Export config as dictionary"""
        return {
            'mediapipe_max_width': self.mediapipe_max_width,
            'preview_max_fps': self.preview_max_fps,
            'preview_quality': self.preview_quality,
            'preview_scale': self.preview_scale,
            'enable_triple_buffer': self.enable_triple_buffer,
            'max_queue_size': self.max_queue_size
        }
    
    def from_dict(self, data):
        """Import config from dictionary"""
        self.mediapipe_max_width = data.get('mediapipe_max_width', 640)
        self.preview_max_fps = data.get('preview_max_fps', 30)
        self.preview_quality = data.get('preview_quality', 85)
        self.preview_scale = data.get('preview_scale', 1.0)
        self.enable_triple_buffer = data.get('enable_triple_buffer', True)
        self.max_queue_size = data.get('max_queue_size', 3)


# Global instance
_config = PerformanceConfig()

def get_performance_config():
    """Get global performance config"""
    return _config
