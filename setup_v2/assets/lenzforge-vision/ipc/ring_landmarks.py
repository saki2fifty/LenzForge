"""
LMK1 v2 - Landmark data ring buffer (SPSC, lock-free)

Single Producer Single Consumer lock-free ring buffer for streaming
landmark data from MediaPipe (or other tracking graphs) to C++ consumers.

Features:
- Fixed resolution per session (src_w, src_h)
- Versioned protocol (LMK1 v2)
- QPC timestamps synchronized with VID1
- Named shared memory (no disk files)
- Lock-free for maximum performance
- Empty markers when no landmarks detected
- Session ID for hot configuration changes
"""
import mmap
import struct
from dataclasses import dataclass
from typing import List, Tuple, Optional
from .qpc import get_qpc_frequency

# Protocol constants
MAGIC_LMK1 = b'LMK1'
VERSION = 2
DEFAULT_SLOT_COUNT = 16
HEADER_SIZE = 64
SLOT_HEADER_SIZE = 32
BLOCK_HEADER_SIZE = 8

# Graph IDs
GRAPH_FACEMESH = 1
GRAPH_HANDS = 2
GRAPH_POSE = 3
GRAPH_IRIS = 4

# Stream IDs
STREAM_FACE = 0
STREAM_LEFT_HAND = 1
STREAM_RIGHT_HAND = 2
STREAM_POSE = 3
STREAM_IRIS_LEFT = 4
STREAM_IRIS_RIGHT = 5
STREAM_HAND_LEFT = 1  # Alias
STREAM_HAND_RIGHT = 2  # Alias

# Flags
FLAG_HAS_CONFIDENCE = 0x01


@dataclass
class LandmarkBlock:
    """Landmark block for backward compatibility with graph processors"""
    stream_id: int
    elem_stride: int
    elem_count: int
    flags: int
    data: bytes

class LMK1Writer:
    """
    Writer for LMK1 v2 landmark ring buffer
    
    Thread-safe for single writer (SPSC model).
    Creates named shared memory that C++ consumers can open.
    """
    
    def __init__(self, name: str, src_w: int, src_h: int,
                 graph_id: int = GRAPH_FACEMESH,
                 slot_count: int = DEFAULT_SLOT_COUNT,
                 session_id: int = 1):
        """
        Initialize LMK1 landmark ring buffer writer
        
        Args:
            name: Named shared memory identifier (e.g., "LenzForge_Landmarks")
            src_w: Source resolution width (MediaPipe input)
            src_h: Source resolution height (MediaPipe input)
            graph_id: Graph identifier (1=FaceMesh, 2=Hands, etc.)
            slot_count: Number of ring buffer slots (typically 16)
            session_id: Session identifier (increment on config change)
        """
        if src_w % 2 != 0 or src_h % 2 != 0:
            raise ValueError("Source width and height must be even")
        
        self.name = name
        self.src_w = src_w
        self.src_h = src_h
        self.graph_id = graph_id
        self.slot_count = slot_count
        self.session_id = session_id
        
        # Calculate slot size (for FaceMesh: 478 landmarks × 12 bytes)
        self.elem_count = 478 if graph_id == GRAPH_FACEMESH else 0
        self.elem_stride = 12  # x,y,z floats
        
        # Slot stride (header + block header + landmarks), 64-byte aligned
        raw_slot_size = SLOT_HEADER_SIZE + BLOCK_HEADER_SIZE + (self.elem_count * self.elem_stride)
        self.slot_stride = ((raw_slot_size + 63) // 64) * 64
        
        # Total size
        total_size = HEADER_SIZE + (self.slot_stride * slot_count)
        
        # Create named shared memory
        try:
            self.mmap = mmap.mmap(-1, total_size, tagname=name)
        except Exception as e:
            raise RuntimeError(f"Failed to create shared memory '{name}': {e}")
        
        # Initialize state
        self.wr_seq = 0
        self.frame_id = 0
        self.qpc_freq = get_qpc_frequency()
        
        # Write header
        self._write_header()
        
        # Initialize all slots to invalid
        for i in range(slot_count):
            self._set_slot_valid(i, False)
    
    def _write_header(self):
        """Write ring header (64 bytes, little-endian)"""
        header = struct.pack(
            '<4sIIIII4B2IQ3I3I',
            MAGIC_LMK1,          # magic (4 bytes)
            VERSION,             # version (4 bytes)
            self.slot_count,     # slot_count (4 bytes)
            self.slot_stride,    # slot_stride (4 bytes)
            0,                   # wr_seq (4 bytes, will update)
            0,                   # rd_seq (4 bytes, not used by writer)
            1,                   # coord_space (1 byte, 1=normalized)
            0, 0, 0,             # reserved1[3] (3 bytes)
            self.src_w,          # src_w (4 bytes)
            self.src_h,          # src_h (4 bytes)
            self.qpc_freq,       # qpc_freq (8 bytes)
            self.graph_id,       # graph_id (4 bytes)
            1 if self.graph_id == GRAPH_FACEMESH else 0,  # streams_mask (4 bytes)
            self.session_id,     # session_id (4 bytes)
            0, 0, 0              # reserved[3] (12 bytes)
        )
        self.mmap.seek(0)
        self.mmap.write(header)
        self.mmap.flush()
    
    def _update_header_seqs(self):
        """Update wr_seq in header"""
        self.mmap.seek(16)  # Offset to wr_seq
        self.mmap.write(struct.pack('<II', self.wr_seq, 0))
        self.mmap.flush()
    
    def _set_slot_valid(self, slot_idx: int, valid: bool):
        """Set slot valid flag atomically"""
        offset = HEADER_SIZE + (slot_idx * self.slot_stride) + 12  # offset to 'valid' field
        self.mmap.seek(offset)
        self.mmap.write(struct.pack('<I', 1 if valid else 0))
        self.mmap.flush()
    
    def write_landmarks(self, landmarks: List[Tuple[float, float, float]],
                       ts_qpc: int, frame_id: int):
        """
        Write landmarks to ring buffer
        
        Protocol:
        1. Mark slot invalid
        2. Write slot header
        3. Write block header (if landmarks present)
        4. Write landmark data (if landmarks present)
        5. Memory barrier (flush)
        6. Mark slot valid
        7. Increment wr_seq
        
        Args:
            landmarks: List of (x, y, z) tuples (normalized [0,1])
                      Empty list = write empty marker
            ts_qpc: QPC timestamp (synchronized with VID1)
            frame_id: Monotonic frame counter
        """
        # Get slot index
        slot_idx = self.wr_seq % self.slot_count
        slot_offset = HEADER_SIZE + (slot_idx * self.slot_stride)
        
        # Mark slot as invalid while writing
        self._set_slot_valid(slot_idx, False)
        
        # Determine block count
        block_count = 1 if landmarks and len(landmarks) > 0 else 0
        
        # Write slot header
        slot_header = struct.pack(
            '<QIIII',
            ts_qpc,              # ts_qpc (8 bytes)
            frame_id,            # frame_id (4 bytes)
            0,                   # valid (4 bytes, will set after)
            block_count,         # block_count (4 bytes)
            0                    # reserved (4 bytes)
        )
        self.mmap.seek(slot_offset)
        self.mmap.write(slot_header)
        
        # Write block data if landmarks present
        if block_count > 0:
            # Write block header
            block_header = struct.pack(
                '<HHHH',
                STREAM_FACE,         # stream_id (2 bytes)
                len(landmarks),      # elem_count (2 bytes)
                self.elem_stride,    # elem_stride (2 bytes)
                0                    # flags (2 bytes)
            )
            block_offset = slot_offset + SLOT_HEADER_SIZE
            self.mmap.seek(block_offset)
            self.mmap.write(block_header)
            
            # Write landmark data
            data_offset = block_offset + BLOCK_HEADER_SIZE
            self.mmap.seek(data_offset)
            for x, y, z in landmarks:
                self.mmap.write(struct.pack('<fff', x, y, z))
        
        # Memory barrier (flush ensures write ordering)
        self.mmap.flush()
        
        # Mark slot as valid (atomic write)
        self._set_slot_valid(slot_idx, True)
        
        # Increment sequences
        self.wr_seq += 1
        self.frame_id = frame_id + 1
        self._update_header_seqs()
    
    def write_empty(self, ts_qpc: int, frame_id: int):
        """
        Write empty marker (no landmarks detected)
        
        This keeps timing steady and prevents consumer stutter.
        
        Args:
            ts_qpc: QPC timestamp
            frame_id: Monotonic frame counter
        """
        self.write_landmarks([], ts_qpc, frame_id)
    
    def get_stats(self) -> dict:
        """Get ring buffer statistics"""
        return {
            'name': self.name,
            'src_resolution': (self.src_w, self.src_h),
            'graph_id': self.graph_id,
            'session_id': self.session_id,
            'slot_count': self.slot_count,
            'slot_stride': self.slot_stride,
            'elem_count': self.elem_count,
            'elem_stride': self.elem_stride,
            'total_size': HEADER_SIZE + (self.slot_stride * self.slot_count),
            'wr_seq': self.wr_seq,
            'frame_id': self.frame_id,
            'qpc_freq': self.qpc_freq
        }
    
    def close(self):
        """Close ring buffer"""
        if self.mmap:
            self.mmap.close()
            self.mmap = None
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
