"""
GOD1 Ring Buffer - Godot Output Data v1

Reads frames from Godot's viewport capture and makes them available
to the virtual camera system.

Protocol: See docs/reference/GOD1_PROTOCOL_SPEC.md for full specification.
Direction: Godot (Writer) -> Python Backend (Reader) -> Virtual Camera
"""

import mmap
import struct
import time
from typing import Optional, Tuple
import numpy as np
from dataclasses import dataclass
import ctypes


# Constants matching GOD1 protocol specification
GOD1_MAGIC = b"GOD1\x00\x00\x00\x00"
GOD1_VERSION = 1
GOD1_HEADER_SIZE = 256
GOD1_SLOT_HEADER_SIZE = 32
GOD1_NUM_SLOTS = 8

# Pixel format constants
GOD1_FORMAT_RGB24 = 0
GOD1_FORMAT_NV12 = 1

# Slot header flags
GOD1_FLAG_VALID = 0x01
GOD1_FLAG_COMPLETE = 0x02


@dataclass
class GOD1FrameInfo:
    """Information about a captured frame"""
    frame_id: int
    timestamp_qpc: int
    width: int
    height: int
    format: int
    data_size: int
    data: np.ndarray


class GOD1Header:
    """
    Global header for GOD1 ring buffer (256 bytes)
    
    Struct Layout:
        char magic[8]
        uint32_t version
        uint32_t frame_width
        uint32_t frame_height
        uint32_t format
        uint32_t num_slots
        uint32_t slot_size
        uint32_t write_index
        uint64_t total_frames
        uint64_t dropped_frames
        uint32_t read_index
        uint64_t total_reads
        uint64_t avg_write_time_us
        uint64_t max_write_time_us
        uint8_t padding[184]
    """
    
    STRUCT_FORMAT = '<8sIIIIII I Q Q I Q Q Q 184s'
    STRUCT_SIZE = 256
    
    def __init__(self):
        self.magic = GOD1_MAGIC
        self.version = GOD1_VERSION
        self.frame_width = 0
        self.frame_height = 0
        self.format = GOD1_FORMAT_RGB24
        self.num_slots = GOD1_NUM_SLOTS
        self.slot_size = 0
        self.write_index = 0
        self.total_frames = 0
        self.dropped_frames = 0
        self.read_index = 0
        self.total_reads = 0
        self.avg_write_time_us = 0
        self.max_write_time_us = 0
    
    @classmethod
    def from_buffer(cls, buffer: bytes) -> 'GOD1Header':
        """Parse header from buffer"""
        data = struct.unpack(cls.STRUCT_FORMAT, buffer[:cls.STRUCT_SIZE])
        
        header = cls()
        header.magic = data[0]
        header.version = data[1]
        header.frame_width = data[2]
        header.frame_height = data[3]
        header.format = data[4]
        header.num_slots = data[5]
        header.slot_size = data[6]
        header.write_index = data[7]
        header.total_frames = data[8]
        header.dropped_frames = data[9]
        header.read_index = data[10]
        header.total_reads = data[11]
        header.avg_write_time_us = data[12]
        header.max_write_time_us = data[13]
        
        return header
    
    def to_buffer(self) -> bytes:
        """Convert header to bytes for writing"""
        return struct.pack(
            self.STRUCT_FORMAT,
            self.magic,
            self.version,
            self.frame_width,
            self.frame_height,
            self.format,
            self.num_slots,
            self.slot_size,
            self.write_index,
            self.total_frames,
            self.dropped_frames,
            self.read_index,
            self.total_reads,
            self.avg_write_time_us,
            self.max_write_time_us,
            b'\x00' * 184  # padding
        )
    
    def is_valid(self) -> bool:
        """Check if header is valid"""
        return (
            self.magic == GOD1_MAGIC and
            self.version == GOD1_VERSION and
            self.frame_width > 0 and
            self.frame_height > 0 and
            self.num_slots == GOD1_NUM_SLOTS
        )


class GOD1SlotHeader:
    """
    Per-slot header (32 bytes)
    
    Struct Layout:
        uint64_t frame_id
        uint64_t timestamp_qpc
        uint32_t data_size
        uint32_t flags
        uint64_t write_timestamp
        uint8_t padding[8]
    """
    
    STRUCT_FORMAT = '<Q Q I I Q 8s'
    STRUCT_SIZE = 32
    
    def __init__(self):
        self.frame_id = 0
        self.timestamp_qpc = 0
        self.data_size = 0
        self.flags = 0
        self.write_timestamp = 0
    
    @classmethod
    def from_buffer(cls, buffer: bytes) -> 'GOD1SlotHeader':
        """Parse slot header from buffer"""
        data = struct.unpack(cls.STRUCT_FORMAT, buffer[:cls.STRUCT_SIZE])
        
        header = cls()
        header.frame_id = data[0]
        header.timestamp_qpc = data[1]
        header.data_size = data[2]
        header.flags = data[3]
        header.write_timestamp = data[4]
        
        return header
    
    def is_valid(self) -> bool:
        """Check if slot contains valid, complete frame"""
        return (
            (self.flags & GOD1_FLAG_VALID) != 0 and
            (self.flags & GOD1_FLAG_COMPLETE) != 0
        )


class GOD1Reader:
    """
    Reader for GOD1 ring buffer (Python backend side)
    
    Reads frames written by Godot's GOD1Writer for use in virtual camera.
    """
    
    def __init__(self, buffer_name: str = "Global\\LenzForge_GodotOutput"):
        """
        Initialize GOD1 reader
        
        Args:
            buffer_name: Shared memory name (Windows format)
        """
        self.buffer_name = buffer_name
        self.mm = None
        self.header = None
        self.last_read_index = 0
        self.connected = False
        self.stats = {
            'frames_read': 0,
            'frames_dropped': 0,
            'frames_skipped': 0,
            'read_errors': 0,
        }
    
    def connect(self) -> bool:
        """
        Connect to GOD1 shared memory buffer
        
        Returns:
            True if connected successfully
        """
        try:
            # Try to open existing shared memory
            # Windows shared memory format: "Global\\Name"
            shm_name = self.buffer_name.replace("Global\\", "")
            
            # Use mmap to access shared memory
            # Note: This is a simplified version. Full implementation would use
            # ctypes and Windows API for proper shared memory access
            import tempfile
            import os
            
            # For now, simulate with a file-backed mmap
            # Real implementation will use Windows shared memory API
            temp_path = os.path.join(tempfile.gettempdir(), f"{shm_name}.dat")
            
            if not os.path.exists(temp_path):
                print(f"[GOD1Reader] Shared memory not found: {self.buffer_name}")
                return False
            
            # Open file for reading
            self.file_handle = open(temp_path, 'r+b')
            self.mm = mmap.mmap(self.file_handle.fileno(), 0)
            
            # Read and validate header
            header_bytes = self.mm[:GOD1_HEADER_SIZE]
            self.header = GOD1Header.from_buffer(header_bytes)
            
            if not self.header.is_valid():
                print(f"[GOD1Reader] Invalid header: magic={self.header.magic}, version={self.header.version}")
                self.disconnect()
                return False
            
            self.last_read_index = self.header.read_index
            self.connected = True
            
            print(f"[GOD1Reader] Connected to {self.buffer_name}")
            print(f"  Resolution: {self.header.frame_width}x{self.header.frame_height}")
            print(f"  Format: {'RGB24' if self.header.format == GOD1_FORMAT_RGB24 else 'NV12'}")
            print(f"  Slots: {self.header.num_slots}")
            print(f"  Slot Size: {self.header.slot_size} bytes")
            
            return True
            
        except Exception as e:
            print(f"[GOD1Reader] Connection failed: {e}")
            self.disconnect()
            return False
    
    def disconnect(self):
        """Disconnect from shared memory"""
        if self.mm:
            self.mm.close()
            self.mm = None
        
        if hasattr(self, 'file_handle') and self.file_handle:
            self.file_handle.close()
            self.file_handle = None
        
        self.connected = False
    
    def read_frame(self) -> Optional[GOD1FrameInfo]:
        """
        Read latest available frame from ring buffer
        
        Returns:
            GOD1FrameInfo if frame available, None otherwise
        """
        if not self.connected:
            return None
        
        try:
            # Re-read header for current indices
            header_bytes = self.mm[:GOD1_HEADER_SIZE]
            self.header = GOD1Header.from_buffer(header_bytes)
            
            write_idx = self.header.write_index
            read_idx = self.last_read_index
            
            # Check if new data available
            if write_idx == read_idx:
                # No new frames
                return None
            
            # Calculate number of unread frames
            if write_idx > read_idx:
                unread_count = write_idx - read_idx
            else:
                unread_count = (GOD1_NUM_SLOTS - read_idx) + write_idx
            
            # If multiple frames unread, skip to most recent
            if unread_count > 1:
                self.stats['frames_skipped'] += (unread_count - 1)
                read_idx = (write_idx - 1) % GOD1_NUM_SLOTS
            
            # Read slot header
            slot_offset = GOD1_HEADER_SIZE + (read_idx * self.header.slot_size)
            slot_header_bytes = self.mm[slot_offset:slot_offset + GOD1_SLOT_HEADER_SIZE]
            slot_header = GOD1SlotHeader.from_buffer(slot_header_bytes)
            
            # Validate slot
            if not slot_header.is_valid():
                print(f"[GOD1Reader] Invalid slot {read_idx}: flags=0x{slot_header.flags:08x}")
                self.stats['read_errors'] += 1
                self.last_read_index = (read_idx + 1) % GOD1_NUM_SLOTS
                return None
            
            # Read frame data
            data_offset = slot_offset + GOD1_SLOT_HEADER_SIZE
            frame_data = self.mm[data_offset:data_offset + slot_header.data_size]
            
            # Convert to numpy array based on format
            if self.header.format == GOD1_FORMAT_RGB24:
                # RGB24: 3 bytes per pixel
                frame_array = np.frombuffer(frame_data, dtype=np.uint8)
                frame_array = frame_array.reshape(
                    (self.header.frame_height, self.header.frame_width, 3)
                )
            else:
                # NV12 or other format
                frame_array = np.frombuffer(frame_data, dtype=np.uint8)
            
            # Create frame info
            frame_info = GOD1FrameInfo(
                frame_id=slot_header.frame_id,
                timestamp_qpc=slot_header.timestamp_qpc,
                width=self.header.frame_width,
                height=self.header.frame_height,
                format=self.header.format,
                data_size=slot_header.data_size,
                data=frame_array
            )
            
            # Update read index
            self.last_read_index = (read_idx + 1) % GOD1_NUM_SLOTS
            self.stats['frames_read'] += 1
            
            return frame_info
            
        except Exception as e:
            print(f"[GOD1Reader] Read error: {e}")
            self.stats['read_errors'] += 1
            return None
    
    def get_stats(self) -> dict:
        """Get reader statistics"""
        return {
            **self.stats,
            'connected': self.connected,
            'resolution': f"{self.header.frame_width}x{self.header.frame_height}" if self.header else "N/A",
            'format': 'RGB24' if self.header and self.header.format == GOD1_FORMAT_RGB24 else 'NV12',
            'total_frames_written': self.header.total_frames if self.header else 0,
            'total_frames_read': self.header.total_reads if self.header else 0,
            'dropped_frames': self.header.dropped_frames if self.header else 0,
        }
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()


# Test code
if __name__ == "__main__":
    print("GOD1 Ring Buffer Reader Test")
    print("=" * 50)
    
    # Try to connect to GOD1 buffer
    reader = GOD1Reader()
    
    if not reader.connect():
        print("Failed to connect to GOD1 buffer")
        print("Make sure Godot is running with GOD1Writer active")
        exit(1)
    
    print("\nReading frames (Ctrl+C to stop)...")
    frame_count = 0
    
    try:
        while True:
            frame_info = reader.read_frame()
            
            if frame_info:
                frame_count += 1
                print(f"Frame {frame_count}: "
                      f"ID={frame_info.frame_id}, "
                      f"Size={frame_info.width}x{frame_info.height}, "
                      f"Data={frame_info.data_size} bytes")
                
                if frame_count % 30 == 0:
                    stats = reader.get_stats()
                    print(f"Stats: {stats}")
            else:
                time.sleep(0.01)  # 10ms wait if no frame
    
    except KeyboardInterrupt:
        print("\n\nStopped by user")
    
    finally:
        print(f"\nFinal stats:")
        print(reader.get_stats())
        reader.disconnect()
