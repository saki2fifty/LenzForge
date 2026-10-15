# LenzForge Godot Integration

**Version:** 1.0.0  
**Date:** October 28, 2025  
**Status:** Phase 3A - godot-cpp Built Successfully

---

## Overview

LenzForge Godot Integration provides real-time facial tracking and video streaming to Godot 4.x through high-performance C++ GDExtensions. Data is transferred via shared memory ring buffers for sub-5ms latency.

---

## Features

### VID1 Video Stream
- **Resolution:** Up to 1920x1080
- **Frame Rate:** 60 FPS sustained
- **Format:** NV12 → RGB conversion
- **Latency:** <5ms (shared memory)
- **Zero-copy:** Direct memory access

### LMK1 Landmark Stream
- **Points:** 478 facial landmarks (MediaPipe FaceMesh)
- **Update Rate:** 30 FPS
- **Format:** Array of Vector3 (normalized [0,1])
- **Tracking:** Real-time face detection

---

## Architecture

```
LenzForge Backend (Python)
├── Camera Capture (MSMF)
├── MediaPipe FaceMesh
├── VID1 Ring Buffer (Shared Memory)
└── LMK1 Ring Buffer (Shared Memory)
         ↓
Godot C++ GDExtension
├── SharedMemory Reader
├── VID1Reader (Node)
└── LMK1Reader (Node)
         ↓
Godot Scene (GDScript)
├── Video Display (TextureRect)
└── Landmark Overlay (Mesh/Lines)
```

---

## Project Structure

```
godot_demo/
├── addons/lenzforge/          # Plugin files
│   ├── plugin.cfg             # Plugin configuration
│   ├── plugin.gd              # Plugin script
│   ├── core/                  # Core GDScript wrappers
│   ├── video/                 # Video components
│   └── landmarks/             # Landmark components
├── gdextension/               # C++ GDExtension
│   ├── godot-cpp/             # Godot C++ bindings (77MB)
│   ├── lenzforge/             # Our extension source
│   │   ├── src/               # C++ source files
│   │   ├── SConstruct         # Build script
│   │   └── lenzforge.gdextension
│   └── bin/                   # Compiled DLLs
├── scenes/                    # Demo scenes
├── docs/                      # Documentation (this folder)
└── project.godot              # Project configuration
```

---

## Current Status

### ✅ Completed
- [x] Godot project created and configured
- [x] Plugin system set up
- [x] godot-cpp repository cloned
- [x] SCons build system installed
- [x] godot-cpp library built successfully (77MB)
- [x] Build tools verified (MinGW GCC 15.2.0)
- [x] Complete implementation plan documented

### ⏳ In Progress
- [ ] C++ GDExtension source code (4-6 hours)
- [ ] Build extension DLL
- [ ] Test in Godot editor
- [ ] Create demo scenes

---

## Building

### Prerequisites
- Windows 10/11
- Godot 4.3+
- MinGW GCC 15.2.0 (included in buildtools/)
- Python 3.11+ with SCons
- LenzForge backend running

### Build godot-cpp
```bash
cd godot_demo/gdextension
.\build_godot_cpp.ps1
```

### Build LenzForge Extension (Coming Soon)
```bash
cd godot_demo/gdextension/lenzforge
scons platform=windows target=template_debug
```

---

## Usage (Planned)

### VID1 Video Stream

```gdscript
extends Node2D

var video_reader: VID1Reader

func _ready():
    video_reader = VID1Reader.new()
    add_child(video_reader)
    video_reader.frame_ready.connect(_on_frame_ready)
    video_reader.start_reading()

func _on_frame_ready(texture: ImageTexture, timestamp: int):
    $VideoDisplay.texture = texture
    print("FPS: ", Engine.get_frames_per_second())
```

### LMK1 Landmark Stream

```gdscript
extends Node2D

var landmark_reader: LMK1Reader

func _ready():
    landmark_reader = LMK1Reader.new()
    add_child(landmark_reader)
    landmark_reader.landmarks_ready.connect(_on_landmarks_ready)
    landmark_reader.start_reading()

func _on_landmarks_ready(points: Array[Vector3]):
    # points contains 478 Vector3 landmarks
    # Normalized coordinates [0,1]
    draw_landmarks(points)
```

---

## Performance Targets

- **Video Latency:** <5ms
- **Frame Rate:** 60 FPS @ 1080p
- **Landmark Update:** 30 FPS
- **CPU Usage:** <10%
- **Memory:** <50MB
- **Zero tearing or stuttering**

---

## Development Timeline

### Phase 3A: Setup (COMPLETE - 3.5 hours)
- ✅ Project structure
- ✅ Documentation
- ✅ godot-cpp built

### Phase 3B: C++ Implementation (Next - 4-6 hours)
- ⏳ Shared memory wrapper
- ⏳ VID1 Reader class
- ⏳ LMK1 Reader class
- ⏳ Registration & build

### Phase 3C: Testing & Demo (1-2 hours)
- ⏳ Test in Godot editor
- ⏳ Create demo scene
- ⏳ Performance validation
- ⏳ Documentation finalization

---

## Technical Details

### Shared Memory Protocol

**VID1 Ring Buffer:**
- Name: `LenzForge_Video_NV12`
- Size: Calculated based on resolution
- Slots: 3 (triple buffering)
- Format: Header + NV12 pixel data

**LMK1 Ring Buffer:**
- Name: `LenzForge_Landmarks_Face`
- Size: Header + 478 × 12 bytes
- Slots: 3 (triple buffering)
- Format: Header + float array (x,y,z per point)

### Threading Model
- Main thread: Godot rendering
- Backend: Python camera/MediaPipe processing
- Communication: Shared memory (lock-free ring buffers)

---

## Troubleshooting

### Common Issues

**Problem:** Extension doesn't load  
**Solution:** Verify DLL is in `gdextension/bin/` and `lenzforge.gdextension` config is correct

**Problem:** No video appearing  
**Solution:** Ensure LenzForge backend is running and camera is active

**Problem:** Low FPS  
**Solution:** Check backend performance settings, try lower resolution

---

## References

- [Godot GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)
- [godot-cpp Repository](https://github.com/godotengine/godot-cpp)
- [MediaPipe FaceMesh](https://developers.google.com/mediapipe/solutions/vision/face_landmarker)

---

## Support

For issues, refer to:
- `GODOT_PHASE3_STATUS.md` - Complete implementation guide
- `PHASE_3_GDEXTENSION_PLAN.md` - C++ implementation details
- `GODOT_IMPLEMENTATION_REQUIREMENTS.md` - Coding standards

---

**Last Updated:** October 28, 2025  
**Status:** godot-cpp Built, Ready for C++ Implementation
