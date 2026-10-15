"""
Test script for Face Mesh integration

Run directly from project root:
  buildtools\python\python.exe setup\assets\backend_v2\test_facemesh.py
"""
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

import time
import signal
from config import Config, get_config
from pipeline.manager import PipelineManager, PipelineState
from capture.enumerator import enumerate_cameras


# Global pipeline instance for signal handling
_pipeline = None


def signal_handler(signum, frame):
    """Handle Ctrl+C gracefully"""
    global _pipeline
    print("\n[INFO] Shutting down...")
    if _pipeline is not None:
        _pipeline.stop()
    sys.exit(0)


def main():
    """Main entry point"""
    print("=" * 60)
    print("  LenzForge Backend v2 - Face Mesh Test")
    print("=" * 60)
    print()
    
    # Register signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    # Load configuration
    print("[INFO] Loading configuration...")
    config = get_config()
    print(f"[OK] Camera: {config.camera.id} @ {config.camera.width}x{config.camera.height}, {config.camera.fps} FPS")
    print(f"[OK] Face Mesh: {config.face_mesh.enabled}")
    print()
    
    # Enumerate cameras
    print("[INFO] Enumerating cameras...")
    cameras = enumerate_cameras()
    if cameras:
        print(f"[OK] Found {len(cameras)} camera(s):")
        for cam in cameras:
            print(f"     - {cam}")
    else:
        print("[WARN] No cameras found")
    print()
    
    # Create pipeline
    print("[INFO] Creating pipeline...")
    global _pipeline
    _pipeline = PipelineManager(config)
    print("[OK] Pipeline created")
    print()
    
    # Start pipeline
    print("[INFO] Starting pipeline...")
    if not _pipeline.start():
        status = _pipeline.get_status()
        print(f"[ERROR] Failed to start pipeline: {status.error_message}")
        return 1
    print("[OK] Pipeline started")
    print("[OK] MediaPipe Face Mesh initialized")
    print("[OK] Writing to ring buffer: {config.rings.landmarks_name}")
    print()
    
    print("[INFO] Processing frames (Ctrl+C to stop)...")
    print("[INFO] Start C++ consumer in another terminal to see landmarks!")
    print()
    
    # Main loop
    last_stats_time = time.time()
    
    try:
        while _pipeline.is_running():
            # Process one frame
            if not _pipeline.process_frame():
                time.sleep(0.001)  # Small delay if frame failed
                continue
            
            # Print statistics every second
            current_time = time.time()
            if current_time - last_stats_time >= 1.0:
                status = _pipeline.get_status()
                print(f"[STATS] Frames: {status.frames_processed:6d} | "
                      f"FPS: {status.fps:5.1f} | "
                      f"Uptime: {status.uptime_seconds:6.1f}s")
                last_stats_time = current_time
    
    except KeyboardInterrupt:
        print("\n[INFO] Keyboard interrupt")
    
    # Stop pipeline
    print()
    print("[INFO] Stopping pipeline...")
    _pipeline.stop()
    print("[OK] Pipeline stopped")
    print()
    
    # Final statistics
    final_status = _pipeline.get_status()
    print("=" * 60)
    print("  Statistics")
    print("=" * 60)
    print(f"Total frames: {final_status.frames_processed}")
    if final_status.uptime_seconds > 0:
        print(f"Average FPS: {final_status.frames_processed / final_status.uptime_seconds:.1f}")
    print(f"Uptime: {final_status.uptime_seconds:.1f} seconds")
    print()
    
    print("[OK] Test complete")
    return 0


if __name__ == '__main__':
    sys.exit(main())
