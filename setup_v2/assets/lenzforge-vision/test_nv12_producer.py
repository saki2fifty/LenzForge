"""
Test producer for VID1 NV12 video ring

Generates synthetic video frames with moving gradient pattern.
Use this to test the NV12 ring buffer before camera integration.

Usage:
    python test_nv12_producer.py
    (Press Ctrl+C to stop)
"""
import sys
import time
import math
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend_v2.ipc.ring_nv12 import NV12RingWriter
from backend_v2.ipc.qpc import get_qpc_ticks

def generate_nv12_frame(frame_num: int, width: int, height: int) -> tuple[bytes, bytes]:
    """
    Generate synthetic NV12 frame with moving gradient
    
    Args:
        frame_num: Current frame number (for animation)
        width: Frame width
        height: Frame height
        
    Returns:
        Tuple of (y_plane, uv_plane) as bytes
    """
    # Y plane - luminance gradient that moves
    offset = (frame_num * 2) % 255
    y_data = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            val = ((x + y + offset) % 256)
            y_data[y * width + x] = val
    
    # UV plane - chroma (half resolution, interleaved)
    # Create a diagonal color sweep
    uv_data = bytearray(width * (height // 2))
    for y in range(height // 2):
        for x in range(width // 2):
            u_val = ((x * 2 + offset) % 256)
            v_val = ((y * 2 + offset) % 256)
            # Interleave U and V
            uv_data[y * width + x * 2] = u_val
            uv_data[y * width + x * 2 + 1] = v_val
    
    return bytes(y_data), bytes(uv_data)

def main():
    """Run test producer"""
    print("=" * 60)
    print("  LenzForge RT-AR - NV12 Video Ring Test Producer")
    print("=" * 60)
    print()
    
    # Configuration
    width = 640
    height = 480
    fps = 30
    
    # Create ring buffer
    print("[INFO] Creating NV12 video ring buffer...")
    print(f"[INFO] Name: 'LenzForge_Video_Test'")
    print(f"[INFO] Resolution: {width}x{height}")
    
    try:
        writer = NV12RingWriter("LenzForge_Video_Test", width, height)
    except Exception as e:
        print(f"[ERROR] Failed to create ring buffer: {e}")
        return 1
    
    # Print stats
    stats = writer.get_stats()
    print(f"[OK] Ring buffer created")
    print(f"     - Slots: {stats['slot_count']}")
    print(f"     - Slot stride: {stats['slot_stride']:,} bytes")
    print(f"     - Frame size: {stats['frame_size']:,} bytes ({stats['frame_size']/1024:.1f} KB)")
    print(f"     - Total size: {stats['total_size']:,} bytes ({stats['total_size']/1024/1024:.2f} MB)")
    print(f"     - QPC frequency: {stats['qpc_freq']:,} ticks/sec")
    print(f"     - Y plane: {stats['y_size']:,} bytes")
    print(f"     - UV plane: {stats['uv_size']:,} bytes")
    print()
    
    print(f"[INFO] Producing frames at {fps} FPS...")
    print("[INFO] Press Ctrl+C to stop")
    print()
    
    frame_num = 0
    start_time = time.time()
    last_report = start_time
    
    try:
        while True:
            # Generate synthetic NV12 frame
            y_plane, uv_plane = generate_nv12_frame(frame_num, width, height)
            
            # Get timestamp
            ts = get_qpc_ticks()
            
            # Write to ring
            writer.write_frame(y_plane, uv_plane, ts)
            
            # Report every second
            current_time = time.time()
            if current_time - last_report >= 1.0:
                elapsed = current_time - start_time
                actual_fps = frame_num / elapsed if elapsed > 0 else 0
                
                # Calculate bandwidth
                bytes_per_sec = stats['frame_size'] * actual_fps
                mb_per_sec = bytes_per_sec / (1024 * 1024)
                
                print(f"[STATS] Frame {frame_num:6d} | FPS: {actual_fps:5.1f} | "
                      f"wr_seq: {writer.wr_seq} | BW: {mb_per_sec:.1f} MB/s | ts: {ts}")
                last_report = current_time
            
            frame_num += 1
            time.sleep(1/fps)
            
    except KeyboardInterrupt:
        print()
        print("[INFO] Stopping...")
    finally:
        # Final stats
        elapsed = time.time() - start_time
        actual_fps = frame_num / elapsed if elapsed > 0 else 0
        total_data = frame_num * stats['frame_size']
        avg_bandwidth = total_data / elapsed if elapsed > 0 else 0
        
        print()
        print("=" * 60)
        print("  Statistics")
        print("=" * 60)
        print(f"Total frames: {frame_num}")
        print(f"Elapsed time: {elapsed:.1f} seconds")
        print(f"Average FPS: {actual_fps:.1f}")
        print(f"Total data: {total_data / (1024*1024):.1f} MB")
        print(f"Avg bandwidth: {avg_bandwidth / (1024*1024):.1f} MB/s")
        print(f"Final wr_seq: {writer.wr_seq}")
        print()
        
        writer.close()
        print("[OK] Ring buffer closed")
        print("[OK] Test complete")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
