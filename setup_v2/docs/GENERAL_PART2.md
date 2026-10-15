# LenzForge V2 - Complete Technical Documentation (Part 2)

**Continuation of GENERAL.md**

---

## Installation & Setup

### Prerequisites

**System Requirements**:
- Windows 10/11 (64-bit)
- 8 GB RAM minimum (16 GB recommended)
- 5 GB free disk space
- Webcam (720p minimum, 1080p recommended)
- Internet connection (initial setup only)

**No Admin Rights Required**: Everything installs to project folder

### Quick Start (10 Minutes)

#### Step 1: Extract Project
```powershell
# Extract to any location (example: D:\projects\)
# No C: drive access needed!
cd D:\projects\_LenzForge
```

#### Step 2: Run Setup
```powershell
cd setup_v2
.\000-Setup.ps1
```

**What it does**:
1. Downloads Python 3.11.9 portable (20 MB)
2. Downloads MinGW GCC 15.2.0 (150 MB)
3. Downloads CMake 3.31.1 (40 MB)
4. Downloads Godot 4.3-stable (80 MB)
5. Installs Python packages (50 MB)
6. Builds MSMF extension (~2 min)
7. Builds GDExtension (~3 min)
8. Deploys all components
9. Verifies installation (99 checks)

**Total Time**: 8-12 minutes (depends on internet speed)
**Total Size**: ~2.5 GB installed

#### Step 3: Start Backend
```powershell
cd ..
.\Start-Backend.ps1
```

Opens browser to http://localhost:5000 with live preview

#### Step 4: Open Godot Scene
```powershell
buildtools\godot\Godot_v4.3-stable_win64.exe
```
- Open Project: `workspace_v2\LenzForge-AR\project.godot`
- Press F5 to run
- See live video with face tracking!

### Detailed Setup Steps

#### Manual Installation (Advanced)

If automated setup fails, follow these steps:

**1. Download Tools**:
```powershell
cd setup_v2

# Python
.\050-Download-Python.ps1

# MinGW
.\051-Download-MinGW.ps1

# CMake
.\052-Download-CMake.ps1

# Godot
.\060-Download-Godot.ps1
.\061-Extract-Godot.ps1
.\062-Install-Export-Templates.ps1
.\063-Configure-Godot-Settings.ps1
```

**2. Extract Tools**:
```powershell
.\053-Extract-Python.ps1
.\054-Extract-MinGW.ps1
.\055-Extract-CMake.ps1
```

**3. Install Packages**:
```powershell
.\005-Install-Packages.ps1
```

**4. Build Extensions**:
```powershell
# MSMF Camera Extension
.\020-Build-MSMF-Extension.ps1

# Godot GDExtension
.\083-Build-LenzForge-GDExtension.ps1
```

**5. Deploy Components**:
```powershell
.\030-Deploy-Backend.ps1
.\081-Deploy-Godot-Project.ps1
```

**6. Verify**:
```powershell
.\099-Verify-Installation.ps1
```

Should show 98/99 checks passing (1 false negative is OK)

### Troubleshooting Setup

**Python packages fail to install**:
```powershell
# Use system Python to build wheels
python -m pip install --upgrade pip
python -m pip wheel -r requirements.txt -w wheels
# Then copy wheels to portable Python site-packages
```

**MSMF extension build fails**:
- Ensure Windows SDK installed (comes with Visual Studio)
- Check `setup_v2/logs/020-build-msmf.log`
- Verify MinGW extracted correctly

**GDExtension build fails**:
- Check SCons installed: `buildtools\python\python.exe -m pip show scons`
- Verify godot-cpp submodule: `workspace_v2\LenzForge-AR\gdextension\lenzforge\godot-cpp\`
- Check build log: `setup_v2/logs/083-build-gdextension.log`

**Godot can't find GDExtension**:
- Verify DLLs copied: `workspace_v2\LenzForge-AR\addons\lenzforge\bin\`
- Check `.gdextension` file: `workspace_v2\LenzForge-AR\addons\lenzforge\lenzforge.gdextension`
- Delete `.godot\` folder and reimport project

---

## Usage Guide

### Starting the Backend

**Method 1: PowerShell Script** (Recommended)
```powershell
.\Start-Backend.ps1
```
- Starts Flask server
- Opens browser to http://localhost:5000
- Logs to `logs/backend.log`
- Press Ctrl+C to stop

**Method 2: Direct Python**
```powershell
buildtools\python\python.exe workspace_v2\LenzForge-Vision\backend_v2\main.py
```

**Method 3: Web Interface Only**
```powershell
# If backend already running, just open browser
start http://localhost:5000
```

### Using the Web Interface

**Preview Tab**:
- Live MJPEG video stream
- FPS counter
- Face detection indicator
- Landmark overlay (optional)

**Camera Tab**:
- Select camera from dropdown
- Adjust resolution (720p, 1080p)
- Set FPS (15, 30, 60)
- View camera capabilities

**Effects Tab**:
- Browse 47 effects by category
- Apply effects in real-time
- Adjust effect parameters
- Chain multiple effects

**Settings Tab**:
- MediaPipe confidence thresholds
- Preview quality settings
- Performance options
- Export/import configuration

### Using Godot Visualization

**Launch Godot**:
```powershell
buildtools\godot\Godot_v4.3-stable_win64.exe
```

**Open Project**:
- File → Open Project
- Navigate to `workspace_v2\LenzForge-AR\project.godot`
- Click "Open & Edit"

**Run Scene**:
- Press F5 (or click Play button)
- Should see live video feed
- Face mesh overlay (if face detected)
- FPS overlay (top-left)

**Scene Structure**:
```
ar_main (Node)
├── VideoManager (Node)
│   └── VID1Reader (C++ GDExtension)
├── LandmarkManager (Node)
│   └── LMK1Reader (C++ GDExtension)
├── EffectsManager (Node)
└── UIManager (Node)
    └── CanvasLayer
        ├── VideoDisplay (TextureRect)
        ├── LandmarkOverlay (Node2D)
        └── FPSLabel (Label)
```

**Customization**:
- Edit `scenes/ar_main.gd` for main logic
- Edit `scripts/managers/*.gd` for component behavior
- Add effects in `scripts/effects/` directory
- Modify UI in `scenes/ar_main.tscn`

### Command Line Usage

**Check Backend Status**:
```powershell
curl http://localhost:5000/api/status
```

**Get Statistics**:
```powershell
curl http://localhost:5000/api/stats
```

**Apply Effect**:
```powershell
curl -X POST http://localhost:5000/api/effects/apply `
  -H "Content-Type: application/json" `
  -d '{\"effect\": \"gaussian_blur\", \"params\": {\"kernel_size\": 15}}'
```

**Select Camera**:
```powershell
curl -X POST http://localhost:5000/api/camera/select `
  -H "Content-Type: application/json" `
  -d '{\"camera_index\": 0}'
```

### Python Integration

**Basic Usage**:
```python
import sys
sys.path.append('workspace_v2/LenzForge-Vision/backend_v2')

from ipc.vid1_ring import VID1Reader
from ipc.lmk1_ring import LMK1Reader

# Create readers
vid_reader = VID1Reader()
lmk_reader = LMK1Reader()

# Open buffers
vid_reader.open("LenzForge_Video_NV12")
lmk_reader.open("LenzForge_Landmarks_NV12")

# Read frames
while True:
    # Get latest video frame
    frame_data = vid_reader.read_latest()
    if frame_data:
        nv12_data = frame_data['nv12_data']
        frame_id = frame_data['frame_id']
        timestamp = frame_data['timestamp']
        
        # Convert NV12 to BGR
        bgr = nv12_to_bgr(nv12_data, width, height)
        
    # Get latest landmarks
    lmk_data = lmk_reader.read_latest()
    if lmk_data:
        landmarks = lmk_data['landmarks']  # NumPy array (488, 2)
        has_face = lmk_data['has_face']
        
    # Your processing here
    process_frame(bgr, landmarks)
```

**Advanced: Custom Processing**:
```python
from pipeline.video_processor import VideoProcessor
from effects.effect_manager import EffectManager

# Create processor
processor = VideoProcessor(
    camera_index=0,
    width=1920,
    height=1080,
    fps=30
)

# Create effect manager
effects = EffectManager()

# Start capture
processor.start()

while processor.is_running():
    # Get frame
    frame = processor.get_latest_frame()
    
    # Apply effects
    processed = effects.apply_effect(frame, "cartoon", {
        "edge_threshold": 100,
        "num_bilateral": 7
    })
    
    # Do something with processed frame
    cv2.imshow("Processed", processed)
    
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

processor.stop()
```

---

## Development Guide

### Building From Source

**Prerequisites**:
- Windows SDK (for MSMF)
- MinGW GCC 15.2.0
- CMake 3.31.1
- Python 3.11.9
- SCons (for GDExtension)

**Build MSMF Extension**:
```powershell
cd workspace_v2\LenzForge-Vision\backend_v2\msmf_extension
cmake -G "MinGW Makefiles" -B build
cmake --build build --config Release
# Output: build/msmf_camera_capture.pyd
```

**Build GDExtension**:
```powershell
cd workspace_v2\LenzForge-AR\gdextension\lenzforge

# Initialize godot-cpp (first time only)
git submodule update --init --recursive

# Build godot-cpp
cd godot-cpp
scons platform=windows target=template_release

# Build extension
cd ..
scons platform=windows target=template_release

# Output: bin/lenzforge.windows.template_release.x86_64.dll
```

**Hot Reload** (Godot):
- Modify GDScript: Save file → Auto-reloads
- Modify GDExtension: Rebuild → Restart Godot
- Modify assets: Save → Auto-reimports

### Project Structure

```
_LenzForge/
├── buildtools/              # Portable dev environment
│   ├── python/              # Python 3.11.9 portable
│   ├── mingw64/             # MinGW GCC 15.2.0
│   ├── cmake/               # CMake 3.31.1
│   └── godot/               # Godot 4.3-stable
│
├── workspace_v2/            # Main workspace
│   ├── LenzForge-Vision/    # Backend (Python)
│   │   └── backend_v2/
│   │       ├── main.py               # Flask server entry
│   │       ├── pipeline/             # Video processing
│   │       ├── ipc/                  # Ring buffers
│   │       ├── effects/              # 47 effects
│   │       ├── msmf_extension/       # Camera capture (C++)
│   │       ├── static/               # Web UI assets
│   │       └── templates/            # Web UI HTML
│   │
│   └── LenzForge-AR/        # Frontend (Godot)
│       ├── project.godot             # Godot project file
│       ├── scenes/                   # Godot scenes
│       │   ├── ar_main.tscn          # Main scene
│       │   └── ar_main.gd            # Main script
│       ├── scripts/                  # GDScript files
│       │   ├── managers/             # System managers
│       │   ├── effects/              # Effect implementations
│       │   └── utils/                # Utility scripts
│       ├── addons/                   # Godot plugins
│       │   └── lenzforge/            # GDExtension plugin
│       │       ├── lenzforge.gdextension
│       │       └── bin/              # Compiled DLLs
│       └── gdextension/              # GDExtension source
│           └── lenzforge/
│               ├── src/              # C++ source
│               ├── godot-cpp/        # Godot C++ bindings
│               └── SConstruct        # Build config
│
├── setup_v2/                # Setup system
│   ├── assets/              # Source assets
│   │   ├── backend_v2/      # Backend source (copied to workspace)
│   │   └── lenzforge-ar/    # Godot project source
│   ├── docs/                # Documentation (THIS FILE!)
│   ├── logs/                # Setup logs
│   └── *.ps1                # Setup scripts (000-099)
│
├── logs/                    # Runtime logs
├── downloads/               # Downloaded installers
├── lenzforge_config.json    # Project configuration
└── Start-Backend.ps1        # Quick start script
```

### Adding New Features

**Add New Effect**:

1. Create effect file:
```python
# workspace_v2/LenzForge-Vision/backend_v2/effects/my_effect.py
import cv2
import numpy as np

def apply_my_effect(image, strength=1.0, **kwargs):
    """
    My custom effect
    
    Args:
        image: Input image (BGR)
        strength: Effect intensity (0.0-2.0)
    
    Returns:
        Processed image
    """
    # Your processing here
    result = image.copy()
    
    # Example: Adjust brightness
    result = cv2.convertScaleAbs(result, alpha=strength, beta=0)
    
    return result

# Register effect
EFFECT_INFO = {
    "name": "my_effect",
    "category": "custom",
    "description": "My custom effect",
    "parameters": {
        "strength": {
            "type": "float",
            "default": 1.0,
            "min": 0.0,
            "max": 2.0,
            "step": 0.1
        }
    }
}
```

2. Register in effect manager:
```python
# workspace_v2/LenzForge-Vision/backend_v2/effects/effect_manager.py
from effects.my_effect import apply_my_effect, EFFECT_INFO

class EffectManager:
    def __init__(self):
        self.effects = {
            # ... existing effects ...
            "my_effect": {
                "function": apply_my_effect,
                "info": EFFECT_INFO
            }
        }
```

3. Test via API:
```powershell
curl -X POST http://localhost:5000/api/effects/apply `
  -H "Content-Type: application/json" `
  -d '{\"effect\": \"my_effect\", \"params\": {\"strength\": 1.5}}'
```

**Add New Ring Buffer**:

1. Define protocol:
```python
# workspace_v2/LenzForge-Vision/backend_v2/ipc/my_ring.py
import struct
from ipc.ring_buffer import RingBufferWriter

MY_MAGIC = 0x4D595231  # "MYR1"
MY_VERSION = 1

class MyRingWriter(RingBufferWriter):
    def __init__(self, name="LenzForge_MyData", slot_count=4):
        # Calculate slot size for your data
        header_size = 64  # Slot header
        data_size = 1024  # Your data
        slot_size = header_size + data_size
        
        super().__init__(name, slot_count, slot_size)
        
    def write_data(self, my_data):
        """Write custom data to ring buffer"""
        with self.get_write_slot() as slot:
            # Pack your data
            slot.write(struct.pack('<I', len(my_data)))
            slot.write(my_data)
```

2. Create C++ reader:
```cpp
// workspace_v2/LenzForge-AR/gdextension/lenzforge/src/my_reader.h
class MyReader : public godot::Node {
    GDCLASS(MyReader, godot::Node)
    
public:
    bool start_reading();
    Array get_data();
    
protected:
    static void _bind_methods();
    
private:
    SharedMemory memory;
    bool open_shared_memory();
    void read_latest_data();
};
```

3. Register in GDExtension:
```cpp
// workspace_v2/LenzForge-AR/gdextension/lenzforge/src/register_types.cpp
#include "my_reader.h"

void initialize_lenzforge_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<VID1Reader>();
    ClassDB::register_class<LMK1Reader>();
    ClassDB::register_class<MyReader>();  // Add your reader
}
```

### Debugging

**Backend (Python)**:
```python
# Enable debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

# Or use VS Code debugger
# .vscode/launch.json:
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Backend",
            "type": "python",
            "request": "launch",
            "program": "${workspaceFolder}/workspace_v2/LenzForge-Vision/backend_v2/main.py",
            "console": "integratedTerminal"
        }
    ]
}
```

**GDExtension (C++)**:
```cpp
// Add print statements
godot::UtilityFunctions::print("[MyClass] Debug message");

// Or use debugger
// 1. Build with debug symbols: scons target=template_debug
// 2. Attach Visual Studio debugger to Godot.exe
// 3. Set breakpoints in C++ code
```

**Godot (GDScript)**:
```gdscript
# Print statements
print("[MyScript] Debug:", my_variable)

# Debugger
# 1. Set breakpoint (click left of line number)
# 2. Run scene (F5)
# 3. Debugger panel shows variables, call stack
```

**Ring Buffers**:
```python
# Check if ring buffer exists
import mmap
try:
    mapping = mmap.mmap(-1, 1024, "LenzForge_Video_NV12")
    print("Ring buffer exists!")
    mapping.close()
except:
    print("Ring buffer not found!")

# Monitor write sequence
from ipc.vid1_ring import VID1Reader
reader = VID1Reader()
reader.open("LenzForge_Video_NV12")
for i in range(100):
    time.sleep(0.1)
    print(f"wr_seq: {reader.header.wr_seq}")
```

---

## Performance

### Current Performance

**Video Pipeline** (1080p):
- Camera capture: 1-2ms
- MediaPipe @ 640px: 12-20ms
- Ring buffer write: <1ms
- Ring buffer read: 1-2ms
- NV12 decode: 1-2ms
- **Total: 16-28ms (35-62 FPS theoretical, 35-45 FPS actual)**

**Bottleneck**: MediaPipe face tracking (60-80% of time)

### Optimization Strategies

**1. Downscale MediaPipe Input** (Implemented, Not Yet Applied):
```python
# Current: 640px (12-20ms)
# Optimized: 480px (5-10ms) - 50% faster!

# File: workspace_v2/LenzForge-Vision/backend_v2/pipeline/performance_config.py
config = {
    "mediapipe_resolution": 480,  # Down from 640
    "preview_fps": 30,             # Throttle preview
    "jpeg_quality": 80             # Reduce encoding time
}
```

**Impact**: 35-45 FPS → 50-60 FPS

**2. Skip Preview Frames**:
```python
# Don't encode JPEG for every frame
frame_count = 0
if frame_count % 2 == 0:  # Every other frame
    jpeg_encoded = encode_jpeg(frame)
    send_to_browser(jpeg_encoded)
```

**Impact**: Saves 5ms every other frame

**3. GPU Acceleration** (Future):
- Use MediaPipe GPU backend
- CUDA for effects
- Vulkan for rendering

**Estimated Impact**: 2-3x faster (15-20ms → 5-8ms)

**4. Model Optimization** (Future):
- Quantize MediaPipe model (INT8)
- Prune unnecessary landmarks
- Custom lightweight model

**Estimated Impact**: 1.5-2x faster (12-20ms → 6-10ms)

### Memory Usage

**Baseline**:
- Python backend: ~200 MB
- Godot frontend: ~150 MB
- Ring buffers: ~35 MB
- **Total: ~385 MB**

**With Video Loaded**:
- Additional textures: ~25 MB
- Landmark history: ~5 MB
- **Total: ~415 MB**

**Optimization**:
- Use texture compression
- Limit history buffer size
- Pool objects instead of allocating

### CPU Usage

**Idle** (no face):
- Backend: 5-10%
- Frontend: 1-2%
- **Total: 6-12%**

**Active** (face tracking):
- Backend: 30-40%
- Frontend: 5-10%
- **Total: 35-50%**

**Target** (with optimizations):
- Backend: 20-30%
- Frontend: 5-10%
- **Total: 25-40%**

### Benchmark Results

**Test System**:
- CPU: AMD Ryzen 9 5950X
- RAM: 32 GB DDR4-3600
- GPU: AMD Radeon RX 7900 XTX
- Camera: Logitech C920 Pro
- Resolution: 1920x1080 @ 30 FPS

**Results**:
```
Component               | Time (ms) | FPS
------------------------|-----------|-----
Camera Capture          | 1.2       | 833
MediaPipe (640px)       | 16.8      | 60
Ring VID1 Write         | 0.4       | 2500
Ring VID1 Read          | 1.5       | 667
NV12 Decode             | 1.8       | 556
Godot Render            | 0.8       | 1250
------------------------|-----------|-----
End-to-End Pipeline     | 22.5      | 44
```

**Bottleneck Analysis**:
- MediaPipe: 74.7% of total time
- NV12 Decode: 8.0%
- Ring Read: 6.7%
- Camera: 5.3%
- Ring Write: 1.8%
- Render: 3.6%

---

## Troubleshooting

### Common Issues

#### 1. "Backend not starting"

**Symptoms**:
- `Start-Backend.ps1` errors
- Browser doesn't open
- Port 5000 already in use

**Solutions**:
```powershell
# Check if port in use
netstat -ano | findstr :5000

# Kill process using port
taskkill /PID <PID> /F

# Try different port
$env:FLASK_PORT = "5001"
.\Start-Backend.ps1

# Check logs
cat logs\backend.log
```

#### 2. "No video in Godot"

**Symptoms**:
- Godot window opens
- FPS shows 60
- Video area is black
- Errors about VID1Reader

**Solutions**:
```powershell
# 1. Ensure backend running
curl http://localhost:5000/api/status

# 2. Check ring buffer exists
# In Python:
import mmap
try:
    m = mmap.mmap(-1, 1024, "LenzForge_Video_NV12")
    print("✓ Ring buffer exists")
except:
    print("✗ Ring buffer missing - start backend!")

# 3. Verify GDExtension loaded
# In Godot console, should see:
# [VID1Reader] Ready
# [LMK1Reader] Ready

# 4. Delete import cache
Remove-Item -Recurse workspace_v2\LenzForge-AR\.godot
# Restart Godot, let it reimport

# 5. Check DLL paths
dir workspace_v2\LenzForge-AR\addons\lenzforge\bin\
# Should see:
# lenzforge.windows.template_release.x86_64.dll
# libgcc_s_seh-1.dll
# libstdc++-6.dll
# libwinpthread-1.dll
```

#### 3. "Face not detected"

**Symptoms**:
- Video shows in preview
- No landmarks appear
- "No face detected" message

**Solutions**:
- **Lighting**: Ensure good, even lighting on face
- **Angle**: Face camera directly (±30° max)
- **Distance**: 30-100cm from camera
- **Settings**: Lower MediaPipe confidence thresholds
  ```python
  # In backend_v2/pipeline/video_processor.py
  face_mesh = mp_face_mesh.FaceMesh(
      min_detection_confidence=0.3,  # Lower from 0.5
      min_tracking_confidence=0.3     # Lower from 0.5
  )
  ```

#### 4. "Low FPS / Stuttering"

**Symptoms**:
- FPS < 25
- Video stutters
- High CPU usage

**Solutions**:
```python
# 1. Reduce MediaPipe resolution
# backend_v2/pipeline/video_processor.py
MEDIAPIPE_WIDTH = 480  # Down from 640

# 2. Skip preview frames
# Only encode JPEG every 2nd frame
if self.frame_count % 2 == 0:
    self._encode_preview(frame)

# 3. Disable effects
# Effects add 5-50ms per frame

# 4. Lower camera resolution
# 720p instead of 1080p (test in web UI)
```

#### 5. "Build errors"

**MSMF Extension**:
```
Error: "windows.h not found"
Solution: Install Windows SDK (comes with Visual Studio)

Error: "IMFSourceReader not defined"
Solution: Link against mf.lib, mfplat.lib, mfreadwrite.lib

Error: "undefined reference to '_imp__'"
Solution: Use MinGW-w64, not MinGW-32
```

**GDExtension**:
```
Error: "SCons not found"
Solution: pip install scons

Error: "godot-cpp not found"
Solution: git submodule update --init --recursive

Error: "undefined symbol: _ZN5godot..."
Solution: Rebuild godot-cpp matching Godot version (4.3)

Error: "cannot open lenzforge.dll"
Solution: Close Godot before rebuilding
```

### Log Files

**Location**: `logs/` directory

**Backend Log**:
```powershell
# Real-time monitoring
Get-Content logs\backend.log -Wait -Tail 50

# Search for errors
Select-String -Path logs\backend.log -Pattern "ERROR"

# Filter by component
Select-String -Path logs\backend.log -Pattern "\[MediaPipe\]"
```

**Setup Logs**:
```
logs/
├── 000-setup.log           # Main setup orchestrator
├── 020-build-msmf.log      # MSMF build output
├── 083-build-gdext.log     # GDExtension build output
└── 099-verify.log          # Verification results
```

### Performance Profiling

**Python (cProfile)**:
```python
import cProfile
import pstats

# Profile backend
profiler = cProfile.Profile()
profiler.enable()

# Run code
process_video_pipeline()

profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats('cumulative')
stats.print_stats(20)  # Top 20 functions
```

**Godot (Built-in Profiler)**:
1. Run scene (F5)
2. Debug → Profiler
3. Enable monitors:
   - FPS
   - Process time
   - Physics time
   - Memory usage
4. Identify bottlenecks

**Ring Buffer Performance**:
```python
import time
from ipc.vid1_ring import VID1Writer

writer = VID1Writer()
writer.open("LenzForge_Video_NV12", 1920, 1080)

# Measure write time
times = []
for i in range(1000):
    dummy_data = b'\x00' * (1920 * 1080 * 3 // 2)
    start = time.perf_counter()
    writer.write_frame(dummy_data)
    end = time.perf_counter()
    times.append((end - start) * 1000)

print(f"Avg: {sum(times)/len(times):.2f}ms")
print(f"Min: {min(times):.2f}ms")
print(f"Max: {max(times):.2f}ms")
```

---

## Roadmap

### Version 2.1 (Performance)
- [ ] Implement MediaPipe downscaling to 480px
- [ ] Add performance configuration API
- [ ] GPU-accelerated effects (select few)
- [ ] Preview frame throttling
- [ ] Achieve 60 FPS @ 1080p target

**Target Date**: November 2025  
**Effort**: 2-3 weeks

### Version 2.2 (Features)
- [ ] Multi-face tracking (up to 4 faces)
- [ ] Hand tracking integration (MediaPipe Hands)
- [ ] Pose tracking (33 body landmarks)
- [ ] Virtual camera output (OBS integration)
- [ ] Effect presets & favorites

**Target Date**: December 2025  
**Effort**: 3-4 weeks

### Version 2.3 (Stability)
- [ ] Auto-
