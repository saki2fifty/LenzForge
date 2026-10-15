"""
Test producer for LMK1 v2 landmarks ring

Generates synthetic 478-point face mesh landmarks with circular motion.
Use this to test the ring buffer before implementing MediaPipe integration.

Usage:
    python test_landmark_producer.py
    (Press Ctrl+C to stop)
"""
import sys
import struct
import time
import math
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend_v2.ipc.ring_landmarks import (
    LandmarksRingWriter, LandmarkBlock,
    STREAM_FACE, FLAG_HAS_CONFIDENCE, GRAPH_FACEMESH
)
from backend_v2.ipc.qpc import get_qpc_ticks

def generate_face_mesh_landmarks(frame_num: int) -> LandmarkBlock:
    """
    Generate synthetic 478-point face mesh with circular motion
    
    Args:
        frame_num: Current frame number (for animation)
        
    Returns:
        LandmarkBlock with 478 face landmarks
    """
    elem_count = 478
    elem_stride = 16  # x, y, z, conf (4 floats * 4 bytes = 16 bytes)
    flags = FLAG_HAS_CONFIDENCE
    
    # Generate circular motion (period ~60 frames)
    t = frame_num * 0.1
    offset_x = math.sin(t) * 0.1
    offset_y = math.cos(t) * 0.1
    
    # Pack landmarks as floats
    data = bytearray()
    for i in range(elem_count):
        # Normalized coordinates [0..1]
        # Create a face-like pattern
        row = i // 20
        col = i % 20
        
        x = 0.3 + offset_x + (col * 0.02)  # Spread across face width
        y = 0.3 + offset_y + (row * 0.02)  # Spread across face height
        z = 0.0 + math.sin(i * 0.1) * 0.05  # Slight depth variation
        conf = 0.85 + math.sin(i * 0.5) * 0.1  # Confidence 0.75-0.95
        
        # Pack as little-endian floats
        data.extend(struct.pack('<ffff', x, y, z, conf))
    
    return LandmarkBlock(
        stream_id=STREAM_FACE,
        elem_stride=elem_stride,
        elem_count=elem_count,
        flags=flags,
        data=bytes(data)
    )

def main():
    """Run test producer"""
    print("=" * 60)
    print("  LenzForge RT-AR - Landmarks Ring Test Producer")
    print("=" * 60)
    print()
    
    # Create ring buffer
    print("[INFO] Creating landmarks ring buffer...")
    print("[INFO] Name: 'LenzForge_Landmarks_Test'")
    
    try:
        writer = LandmarksRingWriter("LenzForge_Landmarks_Test")
    except Exception as e:
        print(f"[ERROR] Failed to create ring buffer: {e}")
        return 1
    
    # Configure source
    writer.set_source_size(640, 480)
    writer.set_graph_info(GRAPH_FACEMESH, 0x01)  # FaceMesh, stream 0 only
    
    # Print stats
    stats = writer.get_stats()
    print(f"[OK] Ring buffer created")
    print(f"     - Slots: {stats['slot_count']}")
    print(f"     - Slot stride: {stats['slot_stride']} bytes")
    print(f"     - Total size: {stats['total_size'] / 1024:.1f} KB")
    print(f"     - QPC frequency: {stats['qpc_freq']:,} ticks/sec")
    print(f"     - Source size: {stats['src_size'][0]}x{stats['src_size'][1]}")
    print()
    
    print("[INFO] Producing frames at 30 FPS...")
    print("[INFO] Press Ctrl+C to stop")
    print()
    
    frame_num = 0
    start_time = time.time()
    last_report = start_time
    
    try:
        while True:
            # Generate synthetic landmarks
            face_block = generate_face_mesh_landmarks(frame_num)
            
            # Get timestamp
            ts = get_qpc_ticks()
            
            # Write to ring
            writer.write_frame([face_block], ts)
            
            # Report every second
            current_time = time.time()
            if current_time - last_report >= 1.0:
                elapsed = current_time - start_time
                fps = frame_num / elapsed if elapsed > 0 else 0
                print(f"[STATS] Frame {frame_num:6d} | FPS: {fps:5.1f} | wr_seq: {writer.wr_seq} | ts: {ts}")
                last_report = current_time
            
            frame_num += 1
            time.sleep(1/30)  # 30 FPS
            
    except KeyboardInterrupt:
        print()
        print("[INFO] Stopping...")
    finally:
        # Final stats
        elapsed = time.time() - start_time
        fps = frame_num / elapsed if elapsed > 0 else 0
        
        print()
        print("=" * 60)
        print("  Statistics")
        print("=" * 60)
        print(f"Total frames: {frame_num}")
        print(f"Elapsed time: {elapsed:.1f} seconds")
        print(f"Average FPS: {fps:.1f}")
        print(f"Final wr_seq: {writer.wr_seq}")
        print()
        
        writer.close()
        print("[OK] Ring buffer closed")
        print("[OK] Test complete")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
