"""
Pipeline manager for backend v2

Coordinates camera capture, MediaPipe processing, and ring buffer writing.
"""
import time
from enum import Enum
from typing import Optional, List
from dataclasses import dataclass

from ..config import Config
from ..capture.camera import Camera
from ..graphs.face_mesh import FaceMeshGraph
from ..graphs.iris import IrisGraph
from ..graphs.hands import HandsGraph
from ..graphs.pose import PoseGraph
from ..ipc.ring_landmarks import LMK1Writer, GRAPH_FACEMESH
from ..ipc.ring_nv12 import NV12RingWriter
from ..ipc.qpc import get_qpc_ticks


class PipelineState(Enum):
    """Pipeline states"""
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    ERROR = "error"


@dataclass
class PipelineStatus:
    """Pipeline status information"""
    state: PipelineState
    fps: float = 0.0
    frames_processed: int = 0
    uptime_seconds: float = 0.0
    error_message: str = ""
    faces_detected: int = 0
    hands_detected: int = 0
    poses_detected: int = 0


class PipelineManager:
    """
    Main pipeline manager
    
    Manages the complete processing pipeline from camera to ring buffers.
    Supports Face Mesh, Iris, Hands, and Pose tracking.
    """
    
    def __init__(self, config: Config):
        """
        Initialize pipeline
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.state = PipelineState.STOPPED
        self.camera: Optional[Camera] = None
        
        # Tracking graphs
        self.face_mesh: Optional[FaceMeshGraph] = None
        self.iris: Optional[IrisGraph] = None
        self.hands: Optional[HandsGraph] = None
        self.pose: Optional[PoseGraph] = None
        
        # Ring buffer writers
        self.landmarks_writer: Optional[LMK1Writer] = None
        self.video_writer: Optional[NV12RingWriter] = None
        
        # Statistics
        self.frames_processed = 0
        self.faces_detected = 0
        self.hands_detected = 0
        self.poses_detected = 0
        self.start_time: Optional[float] = None
        self.last_frame_time: Optional[float] = None
        self.current_fps = 0.0
        
        # Error tracking
        self.error_message = ""
    
    def start(self) -> bool:
        """
        Start the pipeline
        
        Returns:
            True if started successfully
        """
        if self.state == PipelineState.RUNNING:
            return True
        
        self.state = PipelineState.STARTING
        
        # Create camera
        cam_config = self.config.camera
        self.camera = Camera(
            cam_config.id,
            cam_config.width,
            cam_config.height,
            cam_config.fps
        )
        
        # Open camera
        if not self.camera.open():
            self.error_message = f"Failed to open camera {cam_config.id}"
            self.state = PipelineState.ERROR
            return False
        
        # Initialize Face Mesh graph
        if self.config.face_mesh.enabled:
            self.face_mesh = FaceMeshGraph(self.config.face_mesh)
            if not self.face_mesh.initialize():
                self.error_message = "Failed to initialize Face Mesh"
                self.state = PipelineState.ERROR
                return False
        
        # Initialize Iris graph (requires face mesh with refinement)
        if self.config.iris.enabled:
            self.iris = IrisGraph(self.config.iris)
            if not self.iris.initialize():
                self.error_message = "Failed to initialize Iris"
                self.state = PipelineState.ERROR
                return False
        
        # Initialize Hands graph
        if self.config.hands.enabled:
            self.hands = HandsGraph(self.config.hands)
            if not self.hands.initialize():
                self.error_message = "Failed to initialize Hands"
                self.state = PipelineState.ERROR
                return False
        
        # Initialize Pose graph
        if self.config.pose.enabled:
            self.pose = PoseGraph(self.config.pose)
            if not self.pose.initialize():
                self.error_message = "Failed to initialize Pose"
                self.state = PipelineState.ERROR
                return False
        
        # Create landmarks ring writer with current camera resolution
        self.landmarks_writer = LMK1Writer(
            name=self.config.rings.landmarks_name,
            src_w=self.camera.width,
            src_h=self.camera.height,
            graph_id=GRAPH_FACEMESH,
            slot_count=16,
            session_id=1  # Increment this if resolution/config changes at runtime
        )
        
        # Create video ring writer (if enabled)
        if self.config.rings.enable_video:
            self.video_writer = NV12RingWriter(
                self.config.rings.video_name,
                self.camera.width,
                self.camera.height
            )
        
        # Initialize statistics
        self.frames_processed = 0
        self.faces_detected = 0
        self.hands_detected = 0
        self.poses_detected = 0
        self.start_time = time.time()
        self.last_frame_time = self.start_time
        
        self.state = PipelineState.RUNNING
        return True
    
    def stop(self):
        """Stop the pipeline"""
        if self.state == PipelineState.STOPPED:
            return
        
        self.state = PipelineState.STOPPING
        
        # Close all graphs
        if self.face_mesh is not None:
            self.face_mesh.close()
            self.face_mesh = None
        
        if self.iris is not None:
            self.iris.close()
            self.iris = None
        
        if self.hands is not None:
            self.hands.close()
            self.hands = None
        
        if self.pose is not None:
            self.pose.close()
            self.pose = None
        
        # Close landmarks writer
        if self.landmarks_writer is not None:
            self.landmarks_writer.close()
            self.landmarks_writer = None
        
        # Close camera
        if self.camera is not None:
            self.camera.close()
            self.camera = None
        
        self.state = PipelineState.STOPPED
    
    def process_frame(self) -> bool:
        """
        Process one frame through all enabled graphs
        
        Returns:
            True if frame was processed successfully
        """
        if self.state != PipelineState.RUNNING:
            return False
        
        if self.camera is None:
            return False
        
        # Read frame from camera
        frame = self.camera.read()
        if frame is None:
            return False
        
        # Collect landmarks from all enabled graphs
        all_landmarks = []
        
        # Process with Face Mesh
        if self.face_mesh is not None and self.face_mesh.is_enabled():
            face_results = self.face_mesh.process(frame)
            if face_results:
                # Extract landmarks from face mesh results
                # Assuming face_results contains the landmark data
                if hasattr(face_results, 'landmarks'):
                    all_landmarks.extend(face_results.landmarks)
                elif isinstance(face_results, list):
                    all_landmarks.extend(face_results)
                self.faces_detected += 1
        
        # Process with Iris (note: iris is included in face mesh with refinement)
        if self.iris is not None and self.iris.is_enabled():
            iris_results = self.iris.process(frame)
            if iris_results:
                if hasattr(iris_results, 'landmarks'):
                    all_landmarks.extend(iris_results.landmarks)
                elif isinstance(iris_results, list):
                    all_landmarks.extend(iris_results)
        
        # Process with Hands
        if self.hands is not None and self.hands.is_enabled():
            hands_results = self.hands.process(frame)
            if hands_results:
                if hasattr(hands_results, 'landmarks'):
                    all_landmarks.extend(hands_results.landmarks)
                elif isinstance(hands_results, list):
                    all_landmarks.extend(hands_results)
                self.hands_detected += 1
        
        # Process with Pose
        if self.pose is not None and self.pose.is_enabled():
            pose_results = self.pose.process(frame)
            if pose_results:
                if hasattr(pose_results, 'landmarks'):
                    all_landmarks.extend(pose_results.landmarks)
                elif isinstance(pose_results, list):
                    all_landmarks.extend(pose_results)
                self.poses_detected += 1
        
        # Get QPC timestamp for synchronization
        ts = get_qpc_ticks()
        
        # Write landmarks to ring buffer
        if all_landmarks and self.landmarks_writer is not None:
            self.landmarks_writer.write_landmarks(all_landmarks, ts, self.frames_processed)
        elif self.landmarks_writer is not None:
            # Write empty marker if no landmarks detected
            self.landmarks_writer.write_empty(ts, self.frames_processed)
        
        # Write video frame to ring buffer (if enabled)
        if self.video_writer is not None:
            self.video_writer.write_frame_bgr(frame, ts)
        
        # Update statistics
        self.frames_processed += 1
        current_time = time.time()
        if self.last_frame_time is not None:
            frame_delta = current_time - self.last_frame_time
            if frame_delta > 0:
                self.current_fps = 1.0 / frame_delta
        self.last_frame_time = current_time
        
        return True
    
    def get_status(self) -> PipelineStatus:
        """Get pipeline status"""
        uptime = 0.0
        if self.start_time is not None and self.state == PipelineState.RUNNING:
            uptime = time.time() - self.start_time
        
        return PipelineStatus(
            state=self.state,
            fps=self.current_fps,
            frames_processed=self.frames_processed,
            uptime_seconds=uptime,
            error_message=self.error_message,
            faces_detected=self.faces_detected,
            hands_detected=self.hands_detected,
            poses_detected=self.poses_detected
        )
    
    def is_running(self) -> bool:
        """Check if pipeline is running"""
        return self.state == PipelineState.RUNNING
