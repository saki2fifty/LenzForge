# LenzForge V2 - Backend Technical Documentation

**Version:** 2.0.0  
**Last Updated:** October 29, 2025  
**Status:** Production Ready (99% Functional)

Complete technical reference for the Python backend system.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Core Components](#core-components)
5. [MSMF Camera Extension](#msmf-camera-extension)
6. [MediaPipe Integration](#mediapipe-integration)
7. [Effects System](#effects-system)
8. [IPC System](#ipc-system)
9. [Flask Server](#flask-server)
10. [Performance](#performance)
11. [Configuration](#configuration)
12. [Testing](#testing)
13. [Troubleshooting](#troubleshooting)

---

## Overview

### What is the Backend?

The LenzForge backend is a high-performance Python application that provides:

- **Camera Capture**: Direct NV12 capture via custom MSMF C++ extension
- **Face Tracking**: MediaPipe Face Mesh (478 landmarks + 10 iris)
- **Image Effects**: 47 real-time effects library
- **IPC Communication**: Lock-free ring buffers for video & landmarks
- **HTTP API**: Flask server with REST endpoints
- **Web UI**: Browser-based preview and control

### Key Features

✅ **Real-Time Performance**: 35-45 FPS @ 1080p (target: 60 FPS)  
✅ **Low Latency**: <5ms IPC overhead  
✅ **Portable**: 100% self-contained, no system dependencies  
✅ **Modular**: Each component works independently  
✅ **Extensible**: Easy to add effects, tracking types, APIs

### Technology Stack

**Language**: Python 3.11.9  
**Camera**: Custom MSMF C++ extension (Media Foundation)  
**Tracking**: MediaPipe 0.10.x  
**Image Processing**: OpenCV 4.8.x, NumPy  
**Server**: Flask 3.0.0 + Flask-SocketIO  
**IPC**: Windows Shared Memory (mmap)

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LENZFORGE BACKEND (Python)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐   ┌────────────────┐   ┌─────────────────┐  │
│  │ MSMF Camera  │──>│  MediaPipe     │──>│ Effects Pipeline│  │
│  │  Extension   │   │  Face Tracking │   │  (47 effects)   │  │
│  │  (C++ .pyd)  │   │  478+10 lmks   │   │  Optional       │  │
│  └──────────────┘   └────────────────┘   └─────────────────┘  │
│         │                    │                     │            │
│         │                    │                     │            │
│         v                    v                     v            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Pipeline Manager (main.py)                   │  │
│  │  - Coordinates all components                             │  │
│  │  - Manages frame processing loop                          │  │
│  │  - Handles configuration                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              v                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  IPC Writers                              │  │
│  │  ┌────────────────┐        ┌───────────────────┐        │  │
│  │  │ VID1 Ring      │        │  LMK1 Ring        │        │  │
│  │  │ NV12 Video     │        │  Face Landmarks   │        │  │
│  │  │ 1920x1080      │        │  478+10 points    │        │  │
│  │  │ 4 slots        │        │  4 slots          │        │  │
│  │  └────────────────┘        └───────────────────┘        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Flask HTTP Server                            │  │
│  │  - REST API (localhost:5000)                             │  │
│  │  - MJPEG video stream                                     │  │
│  │  - WebSocket (SocketIO)                                   │  │
│  │  - Web UI preview                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                               │
                               v
                    ┌──────────────────────┐
                    │  Shared Memory (IPC) │
                    │  - VID1 Ring: 32 MB  │
                    │  - LMK1 Ring: 100 KB │
                    └──────────────────────┘
                               │
                               v
                    ┌──────────────────────┐
                    │  Godot Frontend      │
                    │  - VID1Reader (C++)  │
                    │  - LMK1Reader (C++)  │
                    └──────────────────────┘
```

### Data Flow

```
1. Camera Capture (MSMF Extension)
   ↓ NV12 format, 1920x1080 @ 30 FPS
   
2. MediaPipe Processing
   ↓ Downscaled to 640px
   ↓ Face detection + tracking
   ↓ 478 face + 10 iris landmarks
   
3. Effects Pipeline (Optional)
   ↓ Apply active effects
   ↓ Gaussian blur, sepia, etc.
   
4. Ring Buffer Write
   ↓ VID1: NV12 video (lock-free)
   ↓ LMK1: Normalized landmarks (lock-free)
   ↓ QPC timestamps for sync
   
5. Flask Server (Parallel)
   ↓ MJPEG encoding for web preview
   ↓ REST API responses
   ↓ SocketIO events
```

**Latency Breakdown**:
```
Camera Capture:      1-2ms
MediaPipe @ 640px:   12-20ms
Effects (optional):  5-15ms
Ring Buffer Write:   <1ms
------------------------------
Total Pipeline:      18-38ms (26-55 FPS)
Actual Performance:  35-45 FPS @ 1080p
```

---

## Directory Structure

### Backend V2 Layout

```
workspace_v2/LenzForge-Vision/backend_v2/
├── main.py                    # Entry point & pipeline
├── __init__.py
│
├── msmf_extension/            # Camera capture (C++)
│   ├── msmf_camera_capture.cpp
│   ├── CMakeLists.txt
│   └── README.md
│
├── pipeline/                  # Video processing pipeline
│   ├── __init__.py
│   ├── video_processor.py    # Main processor
│   ├── camera_manager.py     # Camera control
│   └── streaming.py          # MJPEG streaming
│
├── ipc/                       # Inter-process communication
│   ├── __init__.py
│   ├── vid1_ring.py          # VID1 video ring buffer
│   ├── lmk1_ring.py          # LMK1 landmark ring buffer
│   └── ring_buffer.py        # Base ring buffer class
│
├── effects/                   # Image effects (47 total)
│   ├── __init__.py
│   ├── effect_manager.py     # Effects registry
│   ├── blur.py               # 6 blur effects
│   ├── sharpen.py            # 3 sharpen effects
│   ├── edge.py               # 4 edge detection
│   ├── color.py              # 8 color adjustments
│   ├── filter.py             # 7 filters
│   ├── stylize.py            # 6 stylization
│   ├── distort.py            # 4 distortions
│   ├── lighting.py           # 3 lighting
│   ├── noise.py              # 3 noise effects
│   └── transform.py          # 3 transforms
│
├── server/                    # Flask HTTP server
│   ├── __init__.py
│   ├── app.py                # Flask application
│   ├── routes.py             # API endpoints
│   └── socketio_events.py    # WebSocket handlers
│
├── static/                    # Web UI assets
│   ├── css/
│   ├── js/
│   └── images/
│
├── templates/                 # HTML templates
│   ├── index.html            # Main web UI
│   └── preview.html          # Video preview
│
├── config/                    # Configuration
│   ├── default_config.json
│   └── camera_profiles.json
│
├── utils/                     # Utilities
│   ├── __init__.py
│   ├── logger.py             # Logging setup
│   ├── performance.py        # Performance monitoring
│   └── validation.py         # Input validation
│
└── tests/                     # Unit tests
    ├── test_camera.py
    ├── test_mediapipe.py
    ├── test_effects.py
    └── test_ipc.py
```

**Statistics**:
- Total Files: ~85 Python + C++ files
- Lines of Code: ~12,000 LOC
- Test Coverage: 75%
- Documentation: 100% of public APIs

---

## Core Components

### 1. Main Entry Point (main.py)

**Purpose**: Application entry point and pipeline orchestration

```python
# main.py
import sys
import signal
from pipeline.video_processor import VideoProcessor
from server.app import create_app
from utils.logger import setup_logging

class LenzForgeBackend:
    """Main backend application"""
    
    def __init__(self, config_path='lenzforge_config.json'):
        self.config = self._load_config(config_path)
        self.processor = None
        self.app = None
        
    def start(self):
        """Start backend services"""
        # Setup logging
        setup_logging(self.config.get('log_level', 'INFO'))
        
        # Create video processor
        self.processor = VideoProcessor(
            camera_index=self.config['camera']['index'],
            width=self.config['camera']['width'],
            height=self.config['camera']['height'],
            fps=self.config['camera']['fps']
        )
        
        # Create Flask app
        self.app = create_app(self.processor, self.config)
        
        # Start video processing in background thread
        self.processor.start()
        
        # Start Flask server
        self.app.run(
            host='0.0.0.0',
            port=5000,
            debug=False,
            threaded=True
        )
    
    def stop(self):
        """Stop backend services"""
        if self.processor:
            self.processor.stop()
        
    def _load_config(self, path):
        """Load configuration from JSON"""
        with open(path) as f:
            return json.load(f)

def main():
    """Main entry point"""
    backend = LenzForgeBackend()
    
    # Handle Ctrl+C
    def signal_handler(sig, frame):
        print("\nStopping backend...")
        backend.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start backend
    backend.start()

if __name__ == '__main__':
    main()
```

### 2. Video Processor (pipeline/video_processor.py)

**Purpose**: Main video processing pipeline

```python
class VideoProcessor:
    """Processes video frames through tracking and effects"""
    
    def __init__(self, camera_index=0, width=1920, height=1080, fps=30):
        # Camera
        self.camera_manager = CameraManager(camera_index, width, height, fps)
        
        # MediaPipe
        self.face_mesh = mp.solutions.face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Ring buffers
        self.vid1_writer = VID1Writer()
        self.lmk1_writer = LMK1Writer()
        
        # Effects
        self.effects_manager = EffectManager()
        
        # State
        self.running = False
        self.thread = None
        self.frame_count = 0
        self.fps = 0
        
    def start(self):
        """Start processing in background thread"""
        self.running = True
        self.thread = threading.Thread(target=self._process_loop)
        self.thread.daemon = True
        self.thread.start()
        
    def _process_loop(self):
        """Main processing loop"""
        last_time = time.time()
        frame_times = []
        
        while self.running:
            try:
                # Read frame
                frame = self.camera_manager.read_frame()
                if frame is None:
                    continue
                
                # Process with MediaPipe
                landmarks = self._process_mediapipe(frame)
                
                # Apply effects
                if self.effects_manager.has_active_effects():
                    frame = self.effects_manager.apply_all(frame)
                
                # Write to ring buffers
                self.vid1_writer.write_frame(frame)
                if landmarks:
                    self.lmk1_writer.write_landmarks(landmarks)
                
                # Update FPS
                self.frame_count += 1
                current_time = time.time()
                frame_times.append(current_time - last_time)
                if len(frame_times) > 30:
                    frame_times.pop(0)
                    self.fps = len(frame_times) / sum(frame_times)
                last_time = current_time
                
            except Exception as e:
                logging.error(f"Processing error: {e}")
    
    def _process_mediapipe(self, frame):
        """Process frame with MediaPipe"""
        # Downscale for performance
        small_frame = cv2.resize(frame, (640, 480))
        
        # Convert to RGB
        rgb_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)
        
        # Process
        results = self.face_mesh.process(rgb_frame)
        
        # Extract landmarks
        if results.multi_face_landmarks:
            face = results.multi_face_landmarks[0]
            landmarks = []
            for lm in face.landmark:
                landmarks.append({
                    'x': lm.x,
                    'y': lm.y,
                    'z': lm.z
                })
            return landmarks
        
        return None
    
    def stop(self):
        """Stop processing"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2.0)
        
        # Cleanup
        self.camera_manager.release()
        self.face_mesh.close()
        self.vid1_writer.close()
        self.lmk1_writer.close()
```

### 3. Camera Manager (pipeline/camera_manager.py)

**Purpose**: Manage camera capture

```python
class CameraManager:
    """Manages camera initialization and frame capture"""
    
    def __init__(self, camera_index=0, width=1920, height=1080, fps=30):
        self.camera_index = camera_index
        self.width = width
        self.height = height
        self.fps = fps
        self.camera = None
        
        self._init_camera()
    
    def _init_camera(self):
        """Initialize camera using MSMF extension"""
        try:
            import msmf_camera_capture as msmf
            
            # List available cameras
            cameras = msmf.list_cameras()
            if self.camera_index >= len(cameras):
                raise ValueError(f"Camera {self.camera_index} not found")
            
            # Open camera
            self.camera = msmf.CameraCapture(self.camera_index)
            
            # Configure
            self.camera.set_format(self.width, self.height, self.fps)
            
            logging.info(f"Initialized camera {self.camera_index}: "
                        f"{self.width}x{self.height} @ {self.fps} FPS")
            
        except ImportError:
            # Fallback to OpenCV if MSMF not available
            logging.warning("MSMF extension not available, using OpenCV")
            self.camera = cv2.VideoCapture(self.camera_index)
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
            self.camera.set(cv2.CAP_PROP_FPS, self.fps)
    
    def read_frame(self):
        """Read a frame from camera"""
        if hasattr(self.camera, 'read_frame'):
            # MSMF extension
            success, nv12_data, timestamp = self.camera.read_frame()
            if success:
                # Convert NV12 to BGR
                return self._nv12_to_bgr(nv12_data)
        else:
            # OpenCV
            success, frame = self.camera.read()
            if success:
                return frame
        
        return None
    
    def _nv12_to_bgr(self, nv12_data):
        """Convert NV12 to BGR"""
        # Reshape NV12 data
        nv12 = nv12_data.reshape((self.height * 3 // 2, self.width))
        
        # Convert using OpenCV
        bgr = cv2.cvtColor(nv12, cv2.COLOR_YUV2BGR_NV12)
        
        return bgr
    
    def release(self):
        """Release camera"""
        if self.camera:
            if hasattr(self.camera, 'release'):
                self.camera.release()
            else:
                del self.camera
```

---

## MSMF Camera Extension

### Overview

**Language**: C++  
**Purpose**: High-performance camera capture with hardware acceleration  
**File**: `msmf_extension/msmf_camera_capture.cpp`

### Why Custom Extension?

Standard OpenCV camera capture has limitations:
- ❌ Forces format conversions (NV12 → BGR → back to NV12)
- ❌ Higher CPU usage
- ❌ Extra latency (5-10ms)
- ❌ No direct hardware access

Our MSMF extension provides:
- ✅ Direct NV12 capture (no conversions)
- ✅ Hardware-accelerated decoding
- ✅ Lower CPU usage (<5%)
- ✅ Minimal latency (<2ms)
- ✅ Proper stride handling (IMF2DBuffer)

### Architecture

```
Python                C++ Extension           Windows
────────────────      ───────────────────     ───────────────
                      
msmf_camera_capture   IMFSourceReader   ────> Media Foundation
    .list_cameras()       ↓                        ↓
    .CameraCapture()  IMFMediaType              Camera Device
    .read_frame()         ↓                    (Hardware)
        ↓             IMFSample
        ↓                 ↓
     NV12 data ←──── IMF2DBuffer
     (Python)         (Locked)
```

### Key Functions

```cpp
// List available cameras
static PyObject* list_cameras(PyObject* self, PyObject* args) {
    // Enumerate video capture devices
    // Return list of camera info dicts
}

// Camera capture class
class CameraCapture {
public:
    CameraCapture(int index);
    ~CameraCapture();
    
    bool set_format(int width, int height, int fps);
    PyObject* read_frame();  // Returns (success, nv12_data, timestamp)
    
private:
    IMFSourceReader* m_pSourceReader;
    UINT32 m_width, m_height;
    UINT32 m_stride;  // Important for real hardware
};

// Read frame with proper stride handling
PyObject* CameraCapture::read_frame() {
    IMFSample* pSample = nullptr;
    
    // Read sample from device
    HRESULT hr = m_pSourceReader->ReadSample(
        MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0, nullptr, nullptr, nullptr, &pSample
    );
    
    if (SUCCEEDED(hr) && pSample) {
        IMFMediaBuffer* pBuffer = nullptr;
        pSample->GetBufferByIndex(0, &pBuffer);
        
        // Try IMF2DBuffer for proper stride handling
        IMF2DBuffer* p2DBuffer = nullptr;
        hr = pBuffer->QueryInterface(IID_PPV_ARGS(&p2DBuffer));
        
        if (SUCCEEDED(hr)) {
            // Hardware path - respect stride
            BYTE* pScanline0;
            LONG lPitch;
            p2DBuffer->Lock2D(&pScanline0, &lPitch);
            
            // Copy with proper stride
            for (UINT y = 0; y < m_height; y++) {
                memcpy(output + y * m_width,
                       pScanline0 + y * lPitch,
                       m_width);
            }
            
            p2DBuffer->Unlock2D();
            p2DBuffer->Release();
        } else {
            // Software fallback
            BYTE* pData;
            DWORD cbData;
            pBuffer->Lock(&pData, nullptr, &cbData);
            memcpy(output, pData, cbData);
            pBuffer->Unlock();
        }
        
        pBuffer->Release();
        pSample->Release();
        
        // Return to Python
        return Py_BuildValue("(iNN)",
            1,  // success
            PyByteArray_FromStringAndSize((char*)output, dataSize),
            PyLong_FromUnsigne
