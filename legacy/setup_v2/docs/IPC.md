# IPC Documentation - Ring Buffers

## Overview

LenzForge uses lock-free Single Producer Single Consumer (SPSC) ring buffers for high-performance inter-process communication. This document describes the VID1 (video) and LMK1 (landmarks) ring buffer protocols.

---

## VID1: Video Ring Buffer

### Purpose
Streams NV12 video frames from Python camera capture to C++ consumers (e.g., Godot GDExtension).

### Specifications

**Protocol:** VID1 v1  
**Format:** NV12 (Y plane + UV plane)  
**Memory:** Named shared memory (`LenzForge_Video_NV12`)  
**Slots:** 16 (configurable)  
**Timestamps:** QPC (QueryPerformanceCounter) high-resolution

### Header Structure (64 bytes)

```c
struct VID1Header {
    char magic[4];           // "VID1"
    uint32_t version;        // 1
    uint32_t slot_count;     // 16
    uint32_t slot_stride;    // Calculated
    uint32_t wr_seq;         // Write sequence (increments)
    uint32_t rd_seq;         // Read sequence
    uint32_t width;          // Frame width
    uint32_t height;         // Frame height
    uint32_t y_stride;       // Y plane stride (= width)
    uint32_t uv_stride;      // UV plane stride (= width)
    uint64_t qpc_freq;       // QPC frequency
    uint8_t reserved[16];    // Future use
};
```

### Slot Structure

```c
struct VID1SlotHeader {
    uint64_t ts_qpc;         // QPC timestamp
    uint32_t frame_id;       // Monotonic frame ID
    uint32_t valid;          // 1 = valid frame
    uint8_t reserved[16];    // Future use
};

struct VID1Slot {
    VID1SlotHeader header;   // 32 bytes
    uint8_t y_plane[...];    // width × height
    uint8_t uv_plane[...];   // width × height/2
};
```

### Memory Layout

```
┌─────────────────────────────────────┐
│ VID1Header (64 bytes)               │
├─────────────────────────────────────┤
│ Slot 0                              │
│   ├── VID1SlotHeader (32 bytes)    │
│   ├── Y plane (width × height)     │
│   └── UV plane (width × height/2)  │
├─────────────────────────────────────┤
│ Slot 1                              │
│   ...                               │
├─────────────────────────────────────┤
│ ...                                 │
├─────────────────────────────────────┤
│ Slot 15                             │
│   ...                               │
└─────────────────────────────────────┘
```

### Size Calculations

For 640×480 resolution:
- Y plane: 640 × 480 = 307,200 bytes
- UV plane: 640 × 240 = 153,600 bytes
- Slot header: 32 bytes
- Slot total: 460,832 bytes
- Ring total: 64 + (460,832 × 16) = 7,373,376 bytes (~7 MB)

### Producer (Python)

```python
from ipc.ring_nv12 import NV12RingWriter
from ipc.qpc import get_qpc_ticks

# Create ring
writer = NV12RingWriter("LenzForge_Video_NV12", width=640, height=480)

# Write frame
y_plane = ...  # width × height bytes
uv_plane = ... # width × height/2 bytes
ts_qpc = get_qpc_ticks()
writer.write_frame(y_plane, uv_plane, ts_qpc)

# Cleanup
writer.close()
```

### Consumer (C++)

```cpp
#include "vid1_header.h"

// Open ring
HANDLE hMapFile = OpenFileMappingA(FILE_MAP_READ, FALSE, "LenzForge_Video_NV12");
VID1Header* header = (VID1Header*)MapViewOfFile(hMapFile, FILE_MAP_READ, 0, 0, 0);

// Read loop
while (true) {
    uint32_t rd_seq = header->rd_seq;
    uint32_t wr_seq = header->wr_seq;
    
    if (wr_seq > rd_seq) {
        // Read slot
        uint32_t slot_idx = rd_seq % header->slot_count;
        VID1SlotHeader* slot = (VID1SlotHeader*)((uint8_t*)header + 64 + slot_idx * header->slot_stride);
        
        if (slot->valid) {
            // Process frame
            uint8_t* y_plane = (uint8_t*)slot + 32;
            uint8_t* uv_plane = y_plane + (header->width * header->height);
            
            // ... use frame data ...
        }
        
        // Advance read sequence
        header->rd_seq = rd_seq + 1;
    }
}
```

### Performance

- **Throughput:** 30 FPS sustained
- **Latency:** <33ms per frame
- **Delivery:** 100% (no drops in testing)
- **Validated:** 1800 frames over 60 seconds

---

## LMK1: Landmarks Ring Buffer

### Purpose
Streams MediaPipe facial landmarks from Python to C++ consumers.

### Specifications

**Protocol:** LMK1 v2  
**Format:** Float xyz coordinates (normalized [0, 1])  
**Memory:** Named shared memory (`LenzForge_Landmarks`)  
**Slots:** 16 (configurable)  
**Landmarks:** 478 points (MediaPipe FaceMesh refined)  
**Timestamps:** QPC (synchronized with VID1)

### Header Structure (64 bytes)

```c
struct LMK1Header {
    char magic[4];           // "LMK1"
    uint32_t version;        // 2
    uint32_t slot_count;     // 16
    uint32_t slot_stride;    // 5824 (64-byte aligned)
    uint32_t wr_seq;         // Write sequence
    uint32_t rd_seq;         // Read sequence
    uint8_t coord_space;     // 0 = normalized [0,1]
    uint8_t reserved1[3];    // Alignment
    uint32_t src_w;          // Source resolution width
    uint32_t src_h;          // Source resolution height
    uint32_t session_id;     // Session ID (for hot reload)
    uint8_t reserved2[28];   // Future use
};
```

### Slot Structure

```c
struct LMK1SlotHeader {
    uint64_t ts_qpc;         // QPC timestamp
    uint32_t frame_id;       // Frame ID (matches VID1)
    uint16_t graph_id;       // Graph type (1 = FaceMesh)
    uint16_t flags;          // Reserved
    uint8_t reserved[16];    // Future use
};

struct LMK1BlockHeader {
    uint32_t block_count;    // Number of landmark blocks
    uint32_t reserved;       // Alignment
};

struct LMK1Landmark {
    float x;                 // Normalized [0, 1]
    float y;                 // Normalized [0, 1]
    float z;                 // Normalized depth
};

struct LMK1Slot {
    LMK1SlotHeader header;   // 32 bytes
    LMK1BlockHeader block;   // 8 bytes
    LMK1Landmark lmks[478];  // 5736 bytes (478 × 12)
    uint8_t padding[48];     // Align to 64 bytes
};
```

### Memory Layout

```
┌─────────────────────────────────────┐
│ LMK1Header (64 bytes)               │
├─────────────────────────────────────┤
│ Slot 0 (5824 bytes)                 │
│   ├── LMK1SlotHeader (32 bytes)    │
│   ├── LMK1BlockHeader (8 bytes)    │
│   ├── Landmarks[478] (5736 bytes)  │
│   └── Padding (48 bytes)           │
├─────────────────────────────────────┤
│ Slot 1 (5824 bytes)                 │
│   ...                               │
├─────────────────────────────────────┤
│ ...                                 │
├─────────────────────────────────────┤
│ Slot 15 (5824 bytes)                │
│   ...                               │
└─────────────────────────────────────┘
```

### Size Calculations

- Slot header: 32 bytes
- Block header: 8 bytes
- Landmarks: 478 × 12 bytes = 5,736 bytes
- Padding: 48 bytes
- Slot total: 5,824 bytes (64-byte aligned)
- Ring total: 64 + (5,824 × 16) = 93,248 bytes (~93 KB)

### Empty Markers

When no face is detected, an empty marker is written:
- `block_count = 0` (no landmarks)
- Timestamp and frame_id still valid
- Keeps timing steady for consumers

### Producer (Python)

```python
from ipc.ring_landmarks import LMK1Writer, GRAPH_FACEMESH
from ipc.qpc import get_qpc_ticks

# Create ring
writer = LMK1Writer("LenzForge_Landmarks", width=640, height=360, graph_id=GRAPH_FACEMESH)

# Write landmarks
landmarks = [(x, y, z), ...]  # 478 tuples
ts_qpc = get_qpc_ticks()
frame_id = 1234
writer.write_landmarks(landmarks, ts_qpc, frame_id)

# Write empty (no face)
writer.write_empty(ts_qpc, frame_id)

# Cleanup
writer.close()
```

### Consumer (C++)

```cpp
#include "lmk1_header.h"

// Open ring
HANDLE hMapFile = OpenFileMappingA(FILE_MAP_READ, FALSE, "LenzForge_Landmarks");
LMK1Header* header = (LMK1Header*)MapViewOfFile(hMapFile, FILE_MAP_READ, 0, 0, 0);

// Read loop
while (true) {
    uint32_t rd_seq = header->rd_seq;
    uint32_t wr_seq = header->wr_seq;
    
    if (wr_seq > rd_seq) {
        // Read slot
        uint32_t slot_idx = rd_seq % header->slot_count;
        uint8_t* slot_ptr = (uint8_t*)header + 64 + slot_idx * header->slot_stride;
        
        LMK1SlotHeader* slot = (LMK1SlotHeader*)slot_ptr;
        LMK1BlockHeader* block = (LMK1BlockHeader*)(slot_ptr + 32);
        
        if (block->block_count > 0) {
            // Has landmarks
            LMK1Landmark* lmks = (LMK1Landmark*)(slot_ptr + 40);
            
            for (int i = 0; i < 478; i++) {
                float x = lmks[i].x * header->src_w;  // Denormalize
                float y = lmks[i].y * header->src_h;
                float z = lmks[i].z;
                // ... use landmark ...
            }
        } else {
            // No face detected (empty marker)
        }
        
        // Advance read sequence
        header->rd_seq = rd_seq + 1;
    }
}
```

### Performance

- **Throughput:** 25-30 FPS async
- **Inference:** 12-20ms @ 640px MediaPipe
- **Latency:** <30ms total (non-blocking)
- **Architecture:** Async worker thread

---

## Synchronization

### QPC Timestamps

Both VID1 and LMK1 use QueryPerformanceCounter (QPC) timestamps for synchronization:

```python
from ipc.qpc import get_qpc_ticks, get_qpc_frequency

# Get current timestamp
ts_qpc = get_qpc_ticks()

# Convert to seconds
freq = get_qpc_frequency()
ts_seconds = ts_qpc / freq
```

### Frame ID Matching

Both rings include frame_id in slot headers:
- VID1: Monotonic counter from camera
- LMK1: Matches corresponding video frame

Consumers can match landmarks to video frames:

```cpp
// Read VID1 frame
uint32_t video_frame_id = vid1_slot->frame_id;
uint64_t video_ts = vid1_slot->ts_qpc;

// Find matching LMK1 landmarks
for each lmk1_slot:
    if (lmk1_slot->frame_id == video_frame_id) {
        // Matched! These go together
        // Can also verify timestamps are close
    }
```

---

## Best Practices

### Producer Side

1. **Always set valid flag** before writing data
2. **Use QPC timestamps** for all frames
3. **Increment frame_id** monotonically
4. **Flush mmap** after writing (Python: `mmap.flush()`)
5. **Write empty markers** when appropriate (LMK1)
6. **Close rings** on shutdown

### Consumer Side

1. **Check wr_seq > rd_seq** before reading
2. **Validate slot data** (check valid flag, timestamps)
3. **Advance rd_seq** after processing
4. **Handle empty markers** gracefully (LMK1)
5. **Use modulo** for slot indexing: `slot_idx = seq % slot_count`
6. **Memory barriers** as needed (C++ compiler handles this)

### Threading

- **VID1:** Single producer (camera), single consumer (Godot)
- **LMK1:** Single producer (MediaPipe worker), single consumer (Godot)
- **Lock-free:** No mutexes needed (SPSC design)
- **Wait-free:** Consumers can drop frames if needed

---

## Debugging

### Python Tools

```python
# Check if ring exists
import mmap
try:
    mm = mmap.mmap(-1, 0, tagname="LenzForge_Video_NV12", access=mmap.ACCESS_READ)
    print("VID1 ring exists")
    mm.close()
except:
    print("VID1 ring not found")

# Read header
import struct
mm = mmap.mmap(-1, 0, tagname="LenzForge_Video_NV12", access=mmap.ACCESS_READ)
mm.seek(0)
data = mm.read(64)
header = struct.unpack('<4sIIIIII', data[:28])
print(f"Magic: {header[0]}, wr_seq: {header[4]}, rd_seq: {header[5]}")
```

### C++ Test Readers

- **VID1:** `setup_v2/assets/backend_v2/tools/test_vid1_reader.cpp`
- **LMK1:** Future implementation

### Common Issues

**Ring not found:**
- Producer not running
- Wrong ring name
- Permissions issue

**No data appearing:**
- Check wr_seq is incrementing
- Verify valid flag is set
- Check timestamp is reasonable

**Performance issues:**
- Too many slots (increase to 16 or 32)
- Consumer not keeping up (check rd_seq)
- Memory barriers missing (shouldn't happen with mmap.flush())

---

## Future Enhancements

### Planned Features
- LMK1 for hands (21 landmarks × 2 hands)
- LMK1 for pose (33 landmarks)
- LMK1 for iris (5 landmarks × 2 eyes)
- VID2 for depth streams
- Session management (hot reload)

### Optimization Opportunities
- GPU-based NV12 conversion
- Zero-copy from MSMF
- Larger slots for higher resolutions
- Adaptive slot count

---

## References

- **VID1 Header:** `setup_v2/assets/backend_v2/ipc/vid1_header.h`
- **VID1 Writer:** `setup_v2/assets/backend_v2/ipc/ring_nv12.py`
- **LMK1 Header:** `setup_v2/assets/backend_v2/ipc/lmk1_header.h`
- **LMK1 Writer:** `setup_v2/assets/backend_v2/ipc/ring_landmarks.py`
- **QPC Utilities:** `setup_v2/assets/backend_v2/ipc/qpc.py`
- **Test Reader:** `setup_v2/assets/backend_v2/tools/test_vid1_reader.cpp`

---

Last Updated: 2025-10-28  
Status: Phase 1 (VID1) & Phase 2 (LMK1) Complete
