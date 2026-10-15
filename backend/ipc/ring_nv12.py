"""
VID1 - NV12 video frame ring buffer (SPSC, lock-free)

This implements a Single Producer Single Consumer (SPSC) lock-free ring buffer
for streaming NV12 video frames from Python backend to Godot frontend.

NV12 format:
- Y plane: Full resolution luminance (w × h bytes)
- UV plane: Half resolution chroma (w × h/2 bytes, interleaved U and V)
- Total per frame: w × h × 1.5 bytes

Key features:
- Fixed resolution per session (no dynamic resize)
- Versioned protocol (VID1 v1)
- QPC timestamps for synchronization with landmarks
- Named shared memory (no disk files)
- Lock-free for maximum performance
"""
import mmap
from .atomic import publish_u32
import struct
from typing import Optional
from .qpc import get_qpc_frequency, get_qpc_ticks

# Protocol constants
MAGIC_VID1 = b'VID1'
VERSION = 1
DEFAULT_SLOT_COUNT = 8  # Fewer slots than landmarks (video is bigger)
HEADER_SIZE = 64  # bytes
SLOT_HEADER_SIZE = 32  # bytes

class NV12RingWriter:
    """
    Writer for VID1 NV12 video ring buffer

    Thread-safe for single writer (SPSC model).
    Creates named shared memory that C++ consumers can open.

    Resolution is FIXED per session - cannot change without recreating buffer.
    """

    def __init__(self, name: str, width: int, height: int,
                 slot_count: int = DEFAULT_SLOT_COUNT):
        """
        Initialize NV12 video ring buffer writer

        Args:
            name: Named shared memory identifier (e.g., "LenzForge_Video_NV12")
            width: Frame width in pixels (must be even)
            height: Frame height in pixels (must be even)
            slot_count: Number of ring buffer slots (typically 8)
        """
        if width % 2 != 0 or height % 2 != 0:
            raise ValueError("Width and height must be even for NV12 format")

        self.name = name
        self.width = width
        self.height = height
        self.slot_count = slot_count

        # Calculate strides (typically same as width, but can be aligned)
        self.y_stride = width  # Y plane stride
        self.uv_stride = width  # UV plane stride (interleaved UV, so same as width)

        # Calculate sizes
        self.y_size = self.y_stride * height
        self.uv_size = self.uv_stride * (height // 2)
        self.frame_size = self.y_size + self.uv_size

        # Slot stride (header + frame data), 64-byte aligned
        raw_slot_size = SLOT_HEADER_SIZE + self.frame_size
        self.slot_stride = ((raw_slot_size + 63) // 64) * 64

        # Total size
        total_size = HEADER_SIZE + (self.slot_stride * slot_count)

        # Create named shared memory (page-file backed, no disk file)
        try:
            self.mmap = mmap.mmap(-1, total_size, tagname=name)
        except Exception as e:
            raise RuntimeError(f"Failed to create shared memory '{name}': {e}")

        # Initialize state BEFORE writing header
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
            '<4sIIIIIIIIIQIIII',
            MAGIC_VID1,          # magic (4 bytes)
            VERSION,             # version (4 bytes)
            self.slot_count,     # slot_count (4 bytes)
            self.slot_stride,    # slot_stride (4 bytes)
            0,                   # wr_seq (4 bytes, will update)
            0,                   # rd_seq (4 bytes, not used by writer)
            self.width,          # width (4 bytes)
            self.height,         # height (4 bytes)
            self.y_stride,       # y_stride (4 bytes)
            self.uv_stride,      # uv_stride (4 bytes)
            self.qpc_freq,       # qpc_freq (8 bytes)
            0, 0, 0, 0           # reserved[4] (16 bytes)
        )
        self.mmap.seek(0)
        self.mmap.write(header)
        # Publication is ordered by InterlockedExchange; no page-file flush needed.

    def _update_header_seqs(self):
        """Update wr_seq in header"""
        publish_u32(self.mmap, 16, self.wr_seq)
        # Publication is ordered by InterlockedExchange; no page-file flush needed.

    def _set_slot_valid(self, slot_idx: int, valid: bool):
        """Set slot valid flag atomically"""
        offset = HEADER_SIZE + (slot_idx * self.slot_stride) + 12  # offset to 'valid' field
        publish_u32(self.mmap, offset, 1 if valid else 0)
        # Publication is ordered by InterlockedExchange; no page-file flush needed.

    def write_frame(self, y_plane: bytes, uv_plane: bytes, ts_qpc: Optional[int] = None):
        """
        Write an NV12 frame to ring buffer

        Protocol:
        1. Mark slot invalid
        2. Write slot header
        3. Write Y plane
        4. Write UV plane
        5. Release barrier through InterlockedExchange
        6. Mark slot valid
        7. Increment wr_seq

        Args:
            y_plane: Y (luminance) plane data (width × height bytes)
            uv_plane: UV (chroma) plane data (width × height/2 bytes, interleaved)
            ts_qpc: QPC timestamp (if None, uses current time)
        """
        if ts_qpc is None:
            ts_qpc = get_qpc_ticks()

        # Validate sizes
        if len(y_plane) != self.y_size:
            raise ValueError(f"Y plane size mismatch: {len(y_plane)} != {self.y_size}")
        if len(uv_plane) != self.uv_size:
            raise ValueError(f"UV plane size mismatch: {len(uv_plane)} != {self.uv_size}")

        # Get slot index
        slot_idx = self.wr_seq % self.slot_count
        slot_offset = HEADER_SIZE + (slot_idx * self.slot_stride)

        # Mark slot as invalid while writing
        self._set_slot_valid(slot_idx, False)

        # Write slot header
        slot_header = struct.pack(
            '<QIIIIII',
            ts_qpc,              # ts_qpc (8 bytes)
            self.frame_id,       # frame_id (4 bytes)
            0,                   # valid (4 bytes, will set after)
            0,                   # reserved (4 bytes)
            0, 0, 0              # remaining reserved padding (12 bytes)
        )
        self.mmap.seek(slot_offset)
        self.mmap.write(slot_header)

        # Write Y plane
        y_offset = slot_offset + SLOT_HEADER_SIZE
        self.mmap.seek(y_offset)
        self.mmap.write(y_plane)

        # Write UV plane
        uv_offset = y_offset + self.y_size
        self.mmap.seek(uv_offset)
        self.mmap.write(uv_plane)

        # Publication is ordered by InterlockedExchange; no page-file flush needed.

        # Mark slot as valid (atomic write)
        self._set_slot_valid(slot_idx, True)

        # Increment sequences
        self.wr_seq += 1
        self.frame_id += 1
        self._update_header_seqs()

    def get_stats(self) -> dict:
        """Get ring buffer statistics"""
        return {
            'name': self.name,
            'resolution': (self.width, self.height),
            'slot_count': self.slot_count,
            'slot_stride': self.slot_stride,
            'frame_size': self.frame_size,
            'total_size': HEADER_SIZE + (self.slot_stride * self.slot_count),
            'wr_seq': self.wr_seq,
            'frame_id': self.frame_id,
            'qpc_freq': self.qpc_freq,
            'y_size': self.y_size,
            'uv_size': self.uv_size
        }

    def close(self):
        """Close ring buffer"""
        if self.mmap:
            self.mmap.close()
            self.mmap = None
