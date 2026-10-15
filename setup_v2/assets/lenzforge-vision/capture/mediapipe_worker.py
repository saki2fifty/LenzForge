"""
MediaPipe Worker Thread

Async worker for MediaPipe processing that doesn't block camera capture.

Architecture:
- Camera thread: Capture → VID1 ring → Queue frame
- MP worker thread: Dequeue → Resize → MediaPipe → LMK1 ring

This ensures camera maintains 30 FPS even if MediaPipe takes 15-20ms.
"""
import logging
import threading
import queue
import time
from typing import Optional, Tuple
import numpy as np
import cv2

from graphs.facemesh_cpu import FaceMeshCPU, calculate_mp_resolution
from ipc.ring_landmarks import LMK1Writer, GRAPH_FACEMESH

logger = logging.getLogger(__name__)

class MediaPipeWorker(threading.Thread):
    """
    Async MediaPipe processing worker thread
    
    Processes frames in background without blocking camera capture.
    Maintains timing synchronization via QPC timestamps.
    """
    
    def __init__(self, 
                 lmk1_writer: LMK1Writer,
                 mp_width: int,
                 mp_height: int,
                 camera_width: int,
                 camera_height: int,
                 queue_size: int = 3):
        """
        Initialize MediaPipe worker
        
        Args:
            lmk1_writer: LMK1 ring writer for landmarks
            mp_width: MediaPipe input width
            mp_height: MediaPipe input height
            camera_width: Camera resolution width
            camera_height: Camera resolution height
            queue_size: Max frames in queue (small = low latency)
        """
        super().__init__(daemon=True, name="MediaPipe-Worker")
        
        self.lmk1_writer = lmk1_writer
        self.mp_width = mp_width
        self.mp_height = mp_height
        self.camera_width = camera_width
        self.camera_height = camera_height
        
        # Frame queue (camera → worker)
        self.frame_queue = queue.Queue(maxsize=queue_size)
        
        # Control flags
        self.running = False
        self.enabled = True
        
        # Performance tracking
        self.frames_processed = 0
        self.last_inference_time = 0.0
        self.total_inference_time = 0.0
        
        # Initialize FaceMesh
        try:
            self.facemesh = FaceMeshCPU()
            logger.info(f"MediaPipe worker initialized: MP resolution={mp_width}×{mp_height}")
        except Exception as e:
            logger.error(f"Failed to initialize FaceMesh: {e}")
            raise
    
    def queue_frame(self, frame_bgr: np.ndarray, ts_qpc: int, frame_id: int):
        """
        Queue frame for processing
        
        Called by camera thread. Non-blocking if queue full (drops frame).
        
        Args:
            frame_bgr: BGR frame (camera resolution)
            ts_qpc: QPC timestamp (synchronized with VID1)
            frame_id: Monotonic frame counter
        """
        if not self.running or not self.enabled:
            return
        
        try:
            # Non-blocking put (drop frame if queue full)
            self.frame_queue.put_nowait((frame_bgr.copy(), ts_qpc, frame_id))
        except queue.Full:
            # Queue full - drop frame to maintain real-time
            logger.warning("MediaPipe queue full, dropping frame")
    
    def run(self):
        """Worker thread main loop"""
        self.running = True
        logger.info("MediaPipe worker thread started")
        
        try:
            while self.running:
                try:
                    # Get frame from queue (blocking with timeout)
                    frame_bgr, ts_qpc, frame_id = self.frame_queue.get(timeout=1.0)
                    
                    # Process frame
                    self._process_frame(frame_bgr, ts_qpc, frame_id)
                    
                except queue.Empty:
                    # No frames - continue waiting
                    continue
                    
        except Exception as e:
            logger.error(f"MediaPipe worker thread error: {e}", exc_info=True)
        finally:
            logger.info("MediaPipe worker thread stopped")
    
    def _process_frame(self, frame_bgr: np.ndarray, ts_qpc: int, frame_id: int):
        """
        Process single frame
        
        Args:
            frame_bgr: BGR frame (camera resolution)
            ts_qpc: QPC timestamp
            frame_id: Frame counter
        """
        try:
            start_time = time.perf_counter()
            
            # Resize frame to MediaPipe resolution if needed
            if (frame_bgr.shape[1] != self.mp_width or 
                frame_bgr.shape[0] != self.mp_height):
                frame_mp = cv2.resize(frame_bgr, (self.mp_width, self.mp_height))
            else:
                frame_mp = frame_bgr
            
            # MediaPipe inference
            landmarks = self.facemesh.process(frame_mp)
            
            # Write to LMK1 ring (landmarks or empty marker)
            if landmarks and len(landmarks) > 0:
                self.lmk1_writer.write_landmarks(landmarks, ts_qpc, frame_id)
            else:
                self.lmk1_writer.write_empty(ts_qpc, frame_id)
            
            # Track performance
            inference_time = (time.perf_counter() - start_time) * 1000  # ms
            self.last_inference_time = inference_time
            self.total_inference_time += inference_time
            self.frames_processed += 1
            
        except Exception as e:
            logger.error(f"Error processing frame: {e}")
    
    def get_stats(self) -> dict:
        """Get worker statistics"""
        avg_inference_time = (
            self.total_inference_time / self.frames_processed 
            if self.frames_processed > 0 else 0.0
        )
        
        return {
            'enabled': self.enabled,
            'running': self.running,
            'frames_processed': self.frames_processed,
            'last_inference_ms': round(self.last_inference_time, 2),
            'avg_inference_ms': round(avg_inference_time, 2),
            'queue_size': self.frame_queue.qsize()
        }
    
    def set_enabled(self, enabled: bool):
        """Enable/disable processing (keeps thread alive)"""
        self.enabled = enabled
        logger.info(f"MediaPipe processing {'enabled' if enabled else 'disabled'}")
    
    def stop(self):
        """Stop worker thread gracefully"""
        logger.info("Stopping MediaPipe worker...")
        self.running = False
        
        # Wait for thread to finish (with timeout)
        self.join(timeout=2.0)
        
        # Close FaceMesh
        if hasattr(self, 'facemesh'):
            self.facemesh.close()
        
        logger.info("MediaPipe worker stopped")
