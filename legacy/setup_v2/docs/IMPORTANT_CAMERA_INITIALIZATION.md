# IMPORTANT: Camera Initialization Behavior

**Last Updated:** October 29, 2025  
**Status:** Critical Information for Users

---

## TL;DR - Quick Start

**Before running Godot scene, you must start the camera:**

1. Start backend: `.\Start-Backend.ps1`
2. Open browser: http://localhost:5000/viewer
3. **Wait 2-3 seconds** for camera to initialize
4. Then run Godot scene (F5)

**Why?** Backend uses lazy camera initialization - it doesn't start capture until someone requests video.

---

## Why This Happens

### Lazy Camera Initialization

The LenzForge backend uses **lazy initialization** for camera capture:

```
Backend Startup:
├── Flask server starts ✅
├── Ring buffers created (empty) ✅
├── MediaPipe loaded ✅
└── Camera: NOT STARTED ❌ (waiting for request)

First Video Request (e.g., /video_feed):
├── Camera capture starts
├── MediaPipe pipeline activates
├── Ring buffer writers activate
└── Video becomes available to all consumers
```

**Design Rationale:**
- Don't waste CPU/power when no one is watching
- Allow backend to start quickly
- Support multiple consumers (web, Godot, Python scripts)
- Explicit control over when camera runs

### What Godot Sees

**Scenario 1: Godot Started First (No Video)**
```
1. Backend running, camera idle
2. Godot starts → VID1Reader.start_reading()
3. VID1Reader opens ring buffer ✅
4. VID1Reader reads ring buffer → No new data ❌
5. No frames received
6. Black screen in Godot
```

**Scenario 2: Web Viewer Opened First (Video Works!)**
```
1. Backend running, camera idle
2. Open http://localhost:5000/viewer
3. Backend receives /video_feed request
4. Camera capture starts ✅
5. MediaPipe processes frames ✅
6. VID1 ring buffer receives frames ✅
7. Godot VID1Reader receives frames ✅
8. Ultra-smooth video in Godot! 🎥
```

### Log Evidence

**VID1Reader Success:**
```
[VID1Reader] Ready
[VID1Reader] Opened VID1 ring: 1280x720 (8 slots) ← Ring buffer exists
[VID1Reader] Started reading at 1280x720            ← Reader connected
```

This means:
- ✅ Ring buffer exists in shared memory
- ✅ VID1Reader connected successfully
- ⚠️  But camera may not be running yet

**To confirm camera is running, check backend logs:**
```
[Camera] Initialized camera 0: 1280x720 @ 30 FPS
[MediaPipe] Face mesh initialized
[Pipeline] Processing started
```

---

## Solutions

### Current Workflow (Recommended)

**Keep lazy initialization, document the requirement:**

**Step-by-Step:**
```powershell
# 1. Start backend
.\Start-Backend.ps1

# 2. Open web viewer (starts camera)
start http://localhost:5000/viewer

# 3. Wait for camera to initialize (2-3 seconds)
# You'll see video in browser

# 4. Run Godot scene
# In Godot: Press F5
# Video will appear immediately
```

**Advantages:**
- ✅ No code changes needed
- ✅ Explicit control
- ✅ Can develop backend without camera
- ✅ Works as designed

**Disadvantages:**
- ❌ Extra manual step
- ❌ Not obvious to new users
- ❌ Can forget and wonder why no video

### Alternative: Auto-Start Camera (Future Enhancement)

**Modify backend to start camera on startup:**

**Implementation:**
```python
# In backend_v2/main.py
def start_backend():
    # ... existing setup ...
    
    # Auto-start camera
    logging.info("Auto-starting camera capture...")
    processor.start()  # Start camera immediately
    
    # Start Flask server
    app.run(...)
```

**Advantages:**
- ✅ Godot works immediately
- ✅ No manual web viewer step
- ✅ Better user experience

**Disadvantages:**
- ❌ Uses CPU even when not needed
- ❌ Camera runs even for API-only use
- ❌ Less flexible for development

**Decision:** User prefers current behavior (explicit control)

### Alternative: Godot Triggers Camera Start (Advanced)

**Have Godot call API to start camera:**

**Implementation:**
```gdscript
# In VideoManager._ready()
func _init_camera_trigger():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_camera_started)
    http.request("http://localhost:5000/api/camera/start")
    print("[VideoManager] Triggering camera start...")

func _on_camera_started(result, response_code, headers, body):
    if response_code == 200:
        print("[VideoManager] Camera started successfully")
    else:
        push_error("[VideoManager] Failed to start camera")
```

**Advantages:**
- ✅ Godot controls camera lifecycle
- ✅ No manual web viewer step
- ✅ Clean separation of concerns

**Disadvantages:**
- ❌ Requires API endpoint implementation
- ❌ More complex
- ❌ Tight coupling between Godot and backend

---

## Performance Impact

### With Web Viewer Running

**CPU Usage:**
- Backend (camera + MediaPipe): 30-40%
- Godot (display only): 5-10%
- **Total: 35-50%** CPU usage

**Benefits:**
- Ultra-smooth video (50-60 FPS in Godot)
- Low latency (<20ms end-to-end)
- Both systems can see video simultaneously

### Without Web Viewer (Camera Idle)

**CPU Usage:**
- Backend (idle): 5-10%
- Godot (no video): 1-2%
- **Total: 6-12%** CPU usage

**Benefits:**
- Minimal resource usage
- Good for development
- Backend can run in background

---

## Troubleshooting

### Problem: No Video in Godot

**Symptom:**
```
[VID1Reader] Opened VID1 ring: 1280x720 (8 slots)
[VID1Reader] Started reading at 1280x720
(but no video appears)
```

**Solution:**
1. Check if web viewer is open: http://localhost:5000/viewer
2. If not, open it and wait 2-3 seconds
3. Video should appear in Godot

### Problem: "Failed to open shared memory"

**Symptom:**
```
[VID1Reader] Failed to open shared memory
```

**Causes:**
1. Backend not running at all
2. Ring buffer not created yet
3. Incorrect ring buffer name

**Solution:**
1. Verify backend is running: `curl http://localhost:5000/api/status`
2. Check backend logs for errors
3. Restart backend if needed

### Problem: Video Stutters

**Symptom:**
- Video appears but is choppy
- FPS drops below 30

**Solution:**
1. Close other applications
2. Check backend CPU usage (should be <40%)
3. Consider lowering resolution (720p instead of 1080p)

---

## Best Practices

### Development Workflow

**Recommended setup:**

1. **Terminal 1:** Backend
   ```powershell
   .\Start-Backend.ps1
   ```

2. **Browser:** Web viewer
   ```
   http://localhost:5000/viewer
   ```
   Keep this open during development

3. **Godot:** AR scene
   Press F5 to run/test

**Benefits:**
- Always have video available
- Can monitor backend in browser
- See landmarks and effects in browser
- Godot works immediately

### Production Deployment

**For end users:**

**Option A: Keep current behavior**
- Document the requirement
- Include in quick start guide
- Show in tutorial video

**Option B: Implement auto-start**
- Modify backend to start camera on launch
- Better user experience
- Trade-off: always uses resources

**Recommendation:** Current behavior is fine for development. Consider auto-start for production releases.

---

## Technical Details

### Ring Buffer Lifecycle

**Creation:**
```python
# Backend creates ring buffers on startup
vid1_writer = VID1Writer()
lmk1_writer = LMK1Writer()

# Ring buffers exist in shared memory
# But no data is written until camera starts
```

**Writing:**
```python
# Camera starts → frames written to ring
def camera_loop():
    while running:
        frame = camera.read()
        vid1_writer.write_frame(frame)  # Only when camera active
```

**Reading:**
```cpp
// Godot can connect any time
// But only gets frames when camera is writing
bool VID1Reader::read_latest() {
    if (wr_seq == 0) return false;  // No data yet
    // Read from ring buffer...
}
```

### Shared Memory Details

**VID1 Ring Buffer:**
- Name: `"LenzForge_Video_NV12"`
- Size: ~32 MB (4 slots × 1920×1080 NV12)
- Created: On backend startup
- Active: Only when camera is running

**LMK1 Ring Buffer:**
- Name: `"LenzForge_Landmarks_NV12"`
- Size: ~100 KB (4 slots × 488 landmarks)
- Created: On backend startup
- Active: Only when MediaPipe is processing

---

## Summary

**Current Behavior:**
- Backend creates ring buffers on startup (empty)
- Camera starts when someone requests video
- Web viewer triggers camera start
- Godot can then receive video

**This is intentional and beneficial for:**
- Resource management
- Development flexibility
- Multiple consumers
- Explicit control

**To use Godot:**
1. Start backend
2. Open web viewer (starts camera)
3. Run Godot scene
4. Enjoy ultra-smooth video! 🎥

---

## Future Enhancements

**Planned:**
1. API endpoint to start/stop camera
2. Configuration option for auto-start
3. Camera status indicator in Godot
4. Automatic
