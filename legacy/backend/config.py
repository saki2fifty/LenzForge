"""
Configuration management for LenzForge backend v2

Handles loading, validation, and access to configuration settings.
"""
import json
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass, field, asdict


@dataclass
class CameraConfig:
    """Camera configuration"""
    id: int = 0
    width: int = 640
    height: int = 480
    fps: int = 30
    backend: str = "DSHOW"  # DirectShow on Windows


@dataclass
class TrackingConfig:
    """Base tracking configuration"""
    enabled: bool = False
    min_detection_confidence: float = 0.5
    min_tracking_confidence: float = 0.5


@dataclass
class FaceMeshConfig(TrackingConfig):
    """Face mesh tracking configuration"""
    max_num_faces: int = 1
    refine_landmarks: bool = True
    enabled: bool = True  # Default enabled


@dataclass
class IrisConfig(TrackingConfig):
    """Iris tracking configuration"""
    pass


@dataclass
class HandsConfig(TrackingConfig):
    """Hand tracking configuration"""
    max_num_hands: int = 2
    model_complexity: int = 1  # 0=lite, 1=full


@dataclass
class PoseConfig(TrackingConfig):
    """Pose tracking configuration"""
    model_complexity: int = 1  # 0=lite, 1=full, 2=heavy
    enable_segmentation: bool = False
    smooth_landmarks: bool = True


@dataclass
class HolisticConfig(TrackingConfig):
    """Holistic tracking configuration"""
    model_complexity: int = 1
    enable_segmentation: bool = False
    smooth_landmarks: bool = True
    refine_face_landmarks: bool = True


@dataclass
class EffectConfig:
    """Base effect configuration"""
    enabled: bool = False


@dataclass
class BlurConfig(EffectConfig):
    """Blur effect configuration"""
    amount: int = 5  # Kernel size (must be odd)


@dataclass
class RingConfig:
    """Ring buffer configuration"""
    landmarks_name: str = "LenzForge_Landmarks"
    video_name: str = "LenzForge_Video"
    enable_video: bool = False


@dataclass
class ServerConfig:
    """HTTP API server configuration"""
    host: str = "127.0.0.1"
    port: int = 5001
    cors_origins: list = field(default_factory=lambda: ["http://localhost:3000"])


@dataclass
class Config:
    """Main configuration container"""
    camera: CameraConfig = field(default_factory=CameraConfig)
    face_mesh: FaceMeshConfig = field(default_factory=FaceMeshConfig)
    iris: IrisConfig = field(default_factory=IrisConfig)
    hands: HandsConfig = field(default_factory=HandsConfig)
    pose: PoseConfig = field(default_factory=PoseConfig)
    holistic: HolisticConfig = field(default_factory=HolisticConfig)
    blur: BlurConfig = field(default_factory=BlurConfig)
    rings: RingConfig = field(default_factory=RingConfig)
    server: ServerConfig = field(default_factory=ServerConfig)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Config':
        """Create Config from dictionary"""
        return cls(
            camera=CameraConfig(**data.get('camera', {})),
            face_mesh=FaceMeshConfig(**data.get('face_mesh', {})),
            iris=IrisConfig(**data.get('iris', {})),
            hands=HandsConfig(**data.get('hands', {})),
            pose=PoseConfig(**data.get('pose', {})),
            holistic=HolisticConfig(**data.get('holistic', {})),
            blur=BlurConfig(**data.get('blur', {})),
            rings=RingConfig(**data.get('rings', {})),
            server=ServerConfig(**data.get('server', {}))
        )
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert Config to dictionary"""
        return {
            'camera': asdict(self.camera),
            'face_mesh': asdict(self.face_mesh),
            'iris': asdict(self.iris),
            'hands': asdict(self.hands),
            'pose': asdict(self.pose),
            'holistic': asdict(self.holistic),
            'blur': asdict(self.blur),
            'rings': asdict(self.rings),
            'server': asdict(self.server)
        }
    
    @classmethod
    def load(cls, path: Optional[Path] = None) -> 'Config':
        """Load configuration from JSON file"""
        if path is None:
            path = Path("backend_v2_config.json")
        
        if path.exists():
            with open(path, 'r') as f:
                data = json.load(f)
            return cls.from_dict(data)
        else:
            # Return default config
            return cls()
    
    def save(self, path: Optional[Path] = None):
        """Save configuration to JSON file"""
        if path is None:
            path = Path("backend_v2_config.json")
        
        with open(path, 'w') as f:
            json.dump(self.to_dict(), f, indent=2)
    
    def update(self, updates: Dict[str, Any]):
        """Update configuration from dictionary"""
        for section, values in updates.items():
            if hasattr(self, section):
                config_obj = getattr(self, section)
                for key, value in values.items():
                    if hasattr(config_obj, key):
                        setattr(config_obj, key, value)


# Global configuration instance
_config: Optional[Config] = None


def get_config() -> Config:
    """Get global configuration instance"""
    global _config
    if _config is None:
        _config = Config.load()
    return _config


def reload_config():
    """Reload configuration from file"""
    global _config
    _config = Config.load()
    return _config
