# LenzForge Camera-to-Display Technical Flow

**Complete End-to-End Pipeline Architecture**

---

## Overview

This document describes the complete technical flow from camera hardware capture through to browser display, including all data transformations, processing stages, and architectural components.

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HARDWARE LAYER                               │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  Physical Camera (NexiGo N960E / Snap Cam)   │
    │  - Captures at native resolution             │
    │  - Outputs raw YUV/NV12 format               │
    └──────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MSMF EXTENSION LAYER (C++)                      │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  msmf_capture.pyd (Python C++ Extension)     │
    │  File: msmf_capture.cpp                      │
    │                                              │
    │  1. Opens camera via Media Foundation        │
    │  2. Configures capture format (NV12)         │
    │  3. Reads frames into buffer                 │
    │  4. Returns numpy array (1D, dtype=uint8)    │
    └──────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PYTHON CAPTURE LAYER                            │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  cap_msmf.py (MSMF Wrapper)                  │
    │  Class: MSMFCamera                           │
    │                                              │
    │  - Loads msmf_capture.pyd                    │
    │  - Manages DLL dependencies (MinGW)          │
    │  - Provides .read() method                   │
    │  Output: 1D numpy array (NV12 format)        │
    └──────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  camera.py (High-Level Camera Class)         │
    │  Class: Camera                               │
    │                                              │
    │  STEP 1: Camera Opening                      │
    │  - Creates MSMFCamera instance               │
    │  - Retries frame read (warm-up logic)        │
    │  - Detects actual resolution from frame size │
    │                                              │
    │  STEP 2: Frame Capture Loop                  │
    │  - Calls msmf_camera.read()                  │
    │  - Receives NV12 1D array                    │
    │  - Reshapes: (height*1.5, width)             │
    │  - Converts: NV12 → BGR (cv2.cvtColor)       │
    │  - Returns: BGR numpy array (H, W, 3)        │
    └──────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FLASK BACKEND LAYER                               │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  camera.py Routes (API Endpoints)            │
    │  File: server/routes/camera.py               │
    │                                              │
    │  GET /api/camera/list                        │
    │  - Enumerates available cameras              │
    │  - Returns JSON: [{id, name, backend}]       │
    │                                              │
    │  POST /api/camera/select                     │
    │  - Creates Camera(camera_id)                 │
    │  - Calls camera.open()                       │
    │  - Sets global camera_instance               │
    │  - Returns: {success: true}                  │
    └──────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  streaming.py (Video Stream Generator)       │
    │  File: server/routes/streaming.py            │
    │                                              │
    │  GET /video_feed (MJPEG Stream)              │
    │  Function: generate_frames()                 │
    │                                              │
    │  LOOP FOREVER:                               │
    │    1. ret, frame = camera.read()             │
    │       → Gets BGR frame (H, W, 3)             │
    │                                              │
    │    2. [OPTIONAL] Process with MediaPipe      │
    │       → Face mesh detection                  │
    │       → Landmark overlay                     │
    │       → Effects application                  │
    │                                              │
    │    3. ret, buffer = cv2.imencode('.jpg')     │
    │       → Compress BGR → JPEG                  │
    │                                              │
    │    4. yield multipart response               │
    │       → "Content-Type: image/jpeg"           │
    │       → JPEG binary data                     │
    │       → Frame boundary marker                │
    └──────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      WEB FRONTEND LAYER                              │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  JavaScript (Browser Client)                 │
    │  File: server/static/js/modules.js           │
    │                                              │
    │  CameraModule.select(camera_id):             │
    │    1. POST to /api/camera/select             │
    │    2. Wait for response                      │
    │    3. Update video element src               │
    │       → <img src="/video_feed">              │
    └──────────────────────────────────────────────┘
                                ▼
    ┌──────────────────────────────────────────────┐
    │  HTML Video Element                          │
    │  File: server/templates/index.html           │
    │                                              │
    │  <img id="videoFeed" src="/video_feed">      │
    │                                              │
    │  - Browser requests /video_feed              │
    │  - Receives MJPEG stream                     │
    │  - Decodes JPEG frames                       │
    │  - Displays in <img> element                 │
    │  - Auto-updates as new frames arrive         │
    └──────────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         DISPLAY OUTPUT                               │
└─────────────────────────────────────────────────────────────────────┘
                                ▼
              User sees live video in browser!
```

---

## Detailed Data Flow

### 1. Camera Initialization

```python
# User clicks SELECT button in browser
# JavaScript sends POST request
POST /api/camera/select
Body: {"camera_index": 0}

# Backend (camera.py routes)
camera_instance = Camera(camera_id=0, width=640, height=480, fps=30)
success = camera_instance.open()

# Camera.open() flow:
1. msmf_camera = MSMFCamera(0, 640, 480, 30, "NV12")
2. Retry loop (10 attempts):
   - test_frame = msmf_camera.read()
   - Wait 0.1s if None
3. Detect resolution from frame size:
   - frame_size = test_frame.shape[0]  # e.g., 2764800
   - actual_pixels = frame_size / 1.5  # e.g., 1843200
   - Calculate width × height          # e.g., 1280 × 1440
4. Update self.width, self.height
5. Return True

# Response to browser
{"success": true, "message": "Camera 0 opened successfully"}
```

### 2. Frame Capture (Per Frame)

```python
# Camera.read() - Called ~30 times per second

# STEP 1: Read from MSMF
frame_nv12 = self.msmf_camera.read()
# Returns: 1D numpy array, dtype=uint8, shape=(2764800,)
# Contains: NV12 encoded image data

# STEP 2: Reshape for OpenCV
nv12_height = int(self.height * 1.5)  # 1440 * 1.5 = 2160
frame_shaped = frame_nv12.reshape((nv12_height, self.width))
# Now: 2D array, shape=(2160, 1280)
# Layout: Y plane (1440 rows) + UV plane (720 rows)

# STEP 3: Color Conversion
frame_bgr = cv2.cvtColor(frame_shaped, cv2.COLOR_YUV2BGR_NV12)
# Output: 3D array, shape=(1440, 1280, 3), dtype=uint8
# Format: BGR color channels
# Range: 0-255 per channel

# STEP 4: Return
return True, frame_bgr
```

### 3. Video Streaming (MJPEG)

```python
# Browser requests /video_feed
# Flask calls generate_frames()

def generate_frames():
    while True:
        # Get frame from camera
        ret, frame = camera_instance.read()
        # frame: BGR numpy array (1440, 1280, 3)
        
        if not ret:
            continue
            
        # [OPTIONAL] MediaPipe Processing
        # - Face detection
        # - Landmark extraction
        # - Effects overlay
        # frame = processor.process(frame)
        
        # Encode to JPEG
        ret, buffer = cv2.imencode('.jpg', frame)
        # buffer: JPEG compressed data, ~20-50KB per frame
        
        # Yield as multipart HTTP response
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + 
               buffer.tobytes() + 
               b'\r\n')
```

### 4. Browser Display

```javascript
// HTML
<img id="videoFeed" src="/video_feed">

// Browser behavior:
1. Sends HTTP GET /video_feed
2. Receives multipart/x-mixed-replace response
3. For each JPEG frame:
   - Decode JPEG → RGB bitmap
   - Update <img> element display
   - Repeat automatically (MJPEG protocol)
```

---

## Data Format Transformations

### NV12 Format (From Camera)

```
Memory Layout (1280×1440 resolution):
┌────────────────────────────────────┐
│  Y Plane (Luminance)               │  1280 × 1440 = 1,843,200 bytes
│  1280 width × 1440 height          │
│  Grayscale intensity per pixel     │
├────────────────────────────────────┤
│  UV Plane (Chrominance)            │  1280 × 720 = 921,600 bytes
│  1280 width × 720 height           │  (subsampled 2:1 vertically)
│  Interleaved U,V pairs             │
│  U0,V0,U1,V1,U2,V2...              │
└────────────────────────────────────┘
Total: 1,843,200 + 921,600 = 2,764,800 bytes

Arrives as 1D array:
numpy.array([Y0, Y1, Y2, ..., Y1843199, U0, V0, U1, V1, ...])
Shape: (2764800,)
dtype: uint8

After reshape to (2160, 1280):
Row 0-1439: Y values (luminance, grayscale)
Row 1440-2159: UV pairs (chrominance, color info)
```

### BGR Format (After Conversion)

```
3D Array Structure (1280×1440×3):
┌────────────────────────────────────┐
│  Pixel [0,0]: [B, G, R]            │
│  Pixel [0,1]: [B, G, R]            │
│  ...                               │
│  Pixel [1439,1279]: [B, G, R]      │
└────────────────────────────────────┘

Shape: (1440, 1280, 3)
dtype: uint8
Total size: 1440 × 1280 × 3 = 5,529,600 bytes

Each pixel has 3 channels:
- Channel 0: Blue (0-255)
- Channel 1: Green (0-255)
- Channel 2: Red (0-255)
```

### JPEG Format (For Streaming)

```
After cv2.imencode('.jpg', frame):
- Compressed binary data
- Size: ~20-50KB per frame (vs 5.5MB uncompressed)
- Compression ratio: ~100:1
- Quality: Adjustable (default ~95%)
- Format: Standard JPEG/JFIF
```

---

## Performance Characteristics

### Latency Breakdown (Estimated)

```
Camera Capture:       ~33ms   (30 FPS)
├─ MSMF Read:         ~30ms   (hardware)
└─ NV12→BGR Convert:  ~3ms    (CPU)

Processing:           ~10ms   (optional)
├─ MediaPipe:         ~8ms    (face detection)
└─ Effects:           ~2ms    (overlay)

Encoding:             ~5ms    (JPEG compression)

Network:              ~5ms    (local connection)

Total Latency:        ~53ms   (without MediaPipe)
                      ~63ms   (with MediaPipe)
```

### Throughput

```
Frame Rate:           30 FPS
Data Rate (Raw):      5.5MB × 30 = 165 MB/s
Data Rate (JPEG):     30KB × 30 = 0.9 MB/s
Compression Ratio:    183:1
```

---

## Key Technical Decisions

### 1. Why MSMF Over OpenCV?

**OpenCV VideoCapture Issues:**
- Doesn't enumerate cameras with real names
- Unreliable camera opening on Windows
- Limited format control
- Poor error handling

**MSMF Advantages:**
- Native Windows Media Foundation API
- Real camera names and metadata
- Reliable camera access
- Direct format control (NV12)
- Better performance

### 2. Why NV12 Format?

**Benefits:**
- Native format from most cameras
- Efficient memory usage (1.5 bytes per pixel)
- Hardware-accelerated on many systems
- Standard format for video pipelines

**Trade-off:**
- Requires conversion to BGR for OpenCV
- More complex than RGB/BGR direct capture
- But: Higher quality, lower latency overall

### 3. Why MJPEG Streaming?

**Benefits:**
- Simple HTTP protocol
- Works with <img> tags (no JavaScript needed)
- Compatible with all browsers
- Easy debugging (view in curl)
- No codec dependencies

**Trade-offs:**
- Higher bandwidth than H.264/WebRTC
- No bidirectional communication
- But: Perfect for local network, simple setup

---

## Error Handling Strategy

### Camera Opening Failures

```python
# Retry logic handles:
1. Camera warm-up delay (first frame null)
2. Temporary hardware busy
3. Format negotiation

# Fallback strategy:
1. Try MSMF first (best)
2. Fall back to OpenCV if MSMF fails
3. Return clear error to user
```

### Frame Read Failures

```python
# Handle per-frame:
1. Skip bad frames (don't crash)
2. Log warnings
3. Continue streaming
4. Track dropped frame count

# Recovery:
- Camera usually recovers automatically
- If persistent, user can reselect camera
```

### Resolution Mismatch

```python
# Auto-detection handles:
1. Camera opens at different resolution
2. Calculate from frame size
3. Update Camera object properties
4. Log detected resolution
5. Continue normally

# No user intervention needed!
```

---

## File Structure Reference

```
workspace_v2/cpp-viewer/backend_v2/
│
├── capture/
│   ├── msmf_capture.pyd          # C++ extension (compiled)
│   ├── msmf_capture.cpp          # Source code
│   ├── cap_msmf.py               # Python wrapper
│   ├── camera.py                 # High-level Camera class
│   └── enumerator.py             # Camera enumeration
│
├── server/
│   ├── routes/
│   │   ├── camera.py             # /api/camera/* endpoints
│   │   └── streaming.py          # /video_feed endpoint
│   │
│   ├── static/
│   │   └── js/
│   │       └── modules.js        # CameraModule JavaScript
│   │
│   └── templates/
│       └── index.html            # Main UI
│
└── run_server.py                 # Flask application entry
```

---

## Current Implementation Status

### ✅ Implemented & Working
1. Camera enumeration (MSMF)
2. Camera opening with retry logic
3. Resolution auto-detection
4. NV12 → BGR conversion
5. Frame capture loop
6. Error handling & logging
7. Camera API endpoints
8. Backend auto-reload

### 🔄 Ready for Implementation
1. Video streaming connection
2. Browser video display
3. MediaPipe face detection
4. Effects processing
5. UI controls for effects

### 📋 Future Enhancements
1. H.264 streaming (lower bandwidth)
2. WebRTC (bidirectional, lower latency)
3. Multi-camera support
4. Recording functionality
5. Snapshot capture

---

## Testing the Flow

### 1. Test Camera Enumeration
```powershell
Invoke-RestMethod -Uri "http://localhost:5000/api/camera/list"
```

Expected response:
```json
{
  "cameras": [
    {"index": 0, "name": "Snap Camera", "backend": "MSMF"},
    {"index": 1, "name": "NexiGo N960E FHD Webcam", "backend": "MSMF"}
  ]
}
```

### 2. Test Camera Opening
```powershell
$body = @{camera_index = 0} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:5000/api/camera/select" -Method POST -Body $body -ContentType "application/json"
```

Expected response:
```json
{
  "success": true,
  "message": "Camera 0 opened successfully"
}
```

### 3. Test Video Stream (Future)
```
Open browser: http://localhost:5000
Camera should stream to video element
```

---

## Debugging Tools

### View Backend Logs
```powershell
# In backend terminal window
# Shows all camera operations, errors, frame reads
```

### Check Frame Capture
```powershell
# Add to camera.py temporarily:
cv2.imwrite(f'frame_{time.time()}.jpg', frame_bgr)
# Saves frames to disk for inspection
```

### Monitor Performance
```python
# Add to generate_frames():
import time
start = time.time()
ret, frame = camera.read()
print(f"Frame capture: {(time.time()-start)*1000:.1f}ms")
```

---

## Summary

This technical flow document covers:
- Complete end-to-end pipeline from camera hardware to browser display
- All data format transformations (NV12 → BGR → JPEG)
- Detailed code flow for each stage
- Performance characteristics and optimizations
- Error handling strategies
- Current implementation status

The camera capture system is **fully functional** and ready for video streaming integration.

---

**Next Step:** Connect Camera.read() to /video_feed endpoint for live streaming.
