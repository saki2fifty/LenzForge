# MSMF Camera Capture - Python Extension

Pure **Microsoft Media Foundation (MSMF)** camera capture for Python.

**NO DirectShow!** Modern Windows camera API only.

## Features

✅ **Real camera names** - Get actual device names (e.g., "Integrated Webcam")  
✅ **Fast enumeration** - No 30+ second hangs like OpenCV MSMF  
✅ **Direct NV12** - Native format, no conversion needed  
✅ **Portable** - Just one .pyd file to include  
✅ **No registry access** - Fully sandboxed  
✅ **Windows 10/11** - Built-in MSMF support  

## Building

### Requirements

- Python 3.7+
- Windows SDK (for MSMF headers)
- C++ compiler (Visual Studio Build Tools)
- pybind11 (auto-installed)

### Quick Build

```powershell
cd setup_v2/assets/backend_v2/capture/msmf_extension
.\build.ps1
```

This will:
1. Install pybind11 if needed
2. Build `msmf_capture.pyd`
3. Copy to parent directory for easy import

### Manual Build

```powershell
python -m pip install pybind11
python setup.py build_ext --inplace
```

## Usage

The extension is wrapped by `cap_msmf.py` which provides automatic fallback to OpenCV if the extension isn't available.

### Enumerate Cameras

```python
from backend_v2.capture.cap_msmf import enumerate_cameras

cameras = enumerate_cameras()
for cam in cameras:
    print(f"{cam.index}: {cam.name} ({cam.backend})")

# Output:
# 0: Integrated Webcam (MSMF)
# 1: USB Camera (MSMF)
```

### Capture Frames

```python
from backend_v2.capture.cap_msmf import Camera

# Open camera with NV12 format (direct from MSMF!)
cam = Camera(0, width=1280, height=720, fps=30, format="NV12")

# Read frames
frame = cam.read()  # Returns numpy array (NV12 bytes)

print(f"Backend: {cam.get_backend()}")  # "MSMF"
print(f"Frame size: {len(frame)}")      # width * height * 1.5 for NV12

cam.close()
```

## Fallback Behavior

If the extension isn't built or fails to load, `cap_msmf.py` automatically falls back to OpenCV:

```python
# Tries MSMF extension first
cameras = enumerate_cameras()

# If MSMF unavailable:
# - Uses OpenCV with CAP_ANY
# - Names will be generic "Camera 0", "Camera 1"
# - Still works, just slower/no real names
```

## API Reference

### `enumerate_cameras() -> List[CameraInfo]`

Returns list of available cameras with real names.

### `class Camera`

**Constructor:**
```python
Camera(camera_index, width=640, height=480, fps=30, format="NV12")
```

**Methods:**
- `read() -> np.ndarray`: Read frame
- `close()`: Release camera
- `is_opened() -> bool`: Check if camera is open
- `get_backend() -> str`: Get backend name ("MSMF" or "OpenCV")

## Integration

The existing `backend_v2/capture/enumerator.py` automatically uses this extension via `cap_msmf.py`.

No code changes needed - just build the extension and it's automatically used!

## Technical Details

### Why Not OpenCV MSMF?

OpenCV's `CAP_MSMF` backend:
- ❌ Hangs 30+ seconds during enumeration
- ❌ "can't capture by index" errors
- ❌ Slow and unreliable

### Why This Extension?

- ✅ Direct MSMF API calls (MFEnumDeviceSources, IMFSourceReader)
- ✅ Fast enumeration (~1 second)
- ✅ Reliable index-based capture
- ✅ Real camera names from MSMF attributes

### NV12 Format

NV12 is a YUV 4:2:0 format:
- Y plane: width × height bytes
- UV plane: (width × height) / 2 bytes
- Total: width × height × 1.5 bytes

Layout: `YYYYYYYY... UVUVUV...`

Perfect for:
- MediaPipe (prefers YUV)
- Hardware encoding (native format)
- Minimal CPU overhead

## Troubleshooting

**"Module not found"**: Run `build.ps1` first  
**"Build failed"**: Install Visual Studio Build Tools  
**Falls back to OpenCV**: Extension not built, but still works!

## License

Part of LenzForge project.
