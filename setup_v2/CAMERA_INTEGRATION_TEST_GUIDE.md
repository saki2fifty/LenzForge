# Camera Integration Test Guide

**Date:** October 26, 2025  
**Status:** ✅ READY FOR TESTING  
**Version:** Backend v2 with MediaPipe Integration

---

## What Was Built

### Complete Camera Integration System
- ✅ Camera enumeration (MSMF-backed)
- ✅ Camera selection and configuration
- ✅ Camera start/stop controls
- ✅ Live video streaming (MJPEG)
- ✅ MediaPipe processing (Face/Iris/Hands/Pose)
- ✅ Real-time landmark overlay
- ✅ Tracking toggles

---

## Files Modified/Created

### New Files:
1. `setup_v2/assets/backend_v2/pipeline/web_processor.py` - MediaPipe processor for web streaming

### Modified Files:
1. `setup_v2/assets/backend_v2/capture/camera.py` - Fixed constructor, added compatibility
2. `setup_v2/assets/backend_v2/server/routes/camera.py` - Added start/stop endpoints
3. `setup_v2/assets/backend_v2/server/routes/streaming.py` - Integrated MediaPipe processing
4. `setup_v2/assets/backend_v2/server/routes/tracking.py` - Connected to processor

---

## Testing Steps

### 1. Start the Backend

```powershell
cd d:\temp\_LenzForge
.\Start-Backend.ps1
```

**Expected Output:**
```
Starting LenzForge Backend...
...
 * Running on http://127.0.0.1:5000
 * Running on http://192.168.x.x:5000
```

### 2. Open the Web UI

Open browser and navigate to:
```
http://localhost:5000/viewer
```

**Expected:** Beautiful purple gradient UI loads with:
- System stats panel (FPS, CPU, Memory, Uptime)
- Camera selection dropdown (should show "Loading cameras...")
- Pipeline control buttons (START/STOP/RESTART)
- Tracking toggles (Face/Iris/Hand/Pose)
- Configuration panel

---

## API Testing Sequence

### Test 1: List Cameras

**Request:**
```bash
curl http://localhost:5000/api/camera/list
```

**Expected Response:**
```json
{
  "cameras": [
    {
      "index": 0,
      "name": "Integrated Camera",
      "backend": "MSMF"
    },
    {
      "index": 1,
      "name": "USB Camera",
      "backend": "MSMF"
    }
  ]
}
```

**UI Effect:** Camera dropdown should populate with camera names

---

### Test 2: Select Camera

**Request:**
```bash
curl -X POST http://localhost:5000/api/camera/select ^
  -H "Content-Type: application/json" ^
  -d "{\"camera_index\": 0, \"resolution\": [640, 480], \"fps\": 30}"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Camera selected",
  "camera": {
    "index": 0,
    "name": "Integrated Camera",
    "resolution": [640, 480],
    "fps": 30
  }
}
```

**Result:** Camera is created and opened

---

### Test 3: Start Camera

**Request:**
```bash
curl -X POST http://localhost:5000/api/camera/start
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Camera started",
  "camera": {
    "index": 0,
    "name": "Camera 0",
    "resolution": [640, 480],
    "fps": 30
  }
}
```

**Result:** 
- Camera starts capturing
- Video feed begins streaming
- Face mesh tracking starts automatically
- Green dots appear on your face in the video

---

### Test 4: View Video Stream

Open in browser:
```
http://localhost:5000/video_feed
```

**Expected:** 
- Live video stream from camera
- Green dots overlay on detected face (478 landmarks)
- FPS counter in top-left corner
- Smooth streaming at ~30 FPS

---

### Test 5: Enable Hand Tracking

**Request:**
```bash
curl -X POST http://localhost:5000/api/tracking/enable ^
  -H "Content-Type: application/json" ^
  -d "{\"hands\": true}"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Tracking configuration updated",
  "enabled": ["hands"]
}
```

**Result:**
- Hand landmarks appear when you show your hands to camera
- Yellow dots on hand joints
- Cyan lines connecting joints
- Works for both hands simultaneously

---

### Test 6: Enable Pose Tracking

**Request:**
```bash
curl -X POST http://localhost:5000/api/tracking/enable ^
  -H "Content-Type: application/json" ^
  -d "{\"pose\": true}"
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Tracking configuration updated",
  "enabled": ["pose"]
}
```

**Result:**
- Body pose skeleton appears
- Orange dots on body landmarks
- Blue lines for body connections
- Tracks full body if visible

---

### Test 7: Stop Camera

**Request:**
```bash
curl -X POST http://localhost:5000/api/camera/stop
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Camera stopped"
}
```

**Result:**
- Camera capture stops
- Video feed shows "No Camera Active" message
- Landmark processing pauses

---

## Landmark Color Guide

When streaming with landmarks enabled:

- **Green dots (1px)**: Face mesh landmarks (478 points)
- **Magenta dots (2px)**: Iris landmarks (5 per eye)
- **Yellow dots (3px)**: Hand landmarks (21 per hand)
- **Orange dots (3px)**: Pose landmarks (33 body points)

**Lines:**
- **Cyan lines**: Hand skeleton
- **Blue lines**: Pose skeleton

---

## Expected Performance

### Good Performance:
- **FPS:** 25-30 FPS
- **CPU:** 40-60% (one core)
- **Memory:** ~500 MB
- **Latency:** <100ms

### With All Tracking Enabled:
- **FPS:** 15-20 FPS
- **CPU:** 60-80% (one core)
- **Memory:** ~700 MB
- **Latency:** <150ms

---

## UI Testing

### Camera Panel:
1. Click camera dropdown
2. Select a camera
3. Click "START" button
4. Verify video appears
5. Click "STOP" button
6. Verify video stops

### Tracking Toggles:
1. Toggle "Face Mesh" on/off
2. Toggle "Iris" on/off  
3. Toggle "Hand Tracking" on/off
4. Toggle "Pose Detection" on/off
5. Verify landmarks appear/disappear accordingly

### System Stats:
1. Watch FPS counter update
2. Verify CPU percentage changes
3. Check memory usage increases when tracking enabled
4. Confirm uptime counter increments

---

## Common Issues & Solutions

### Issue 1: "No cameras found"
**Cause:** Camera enumeration failed  
**Solution:**
- Check if camera is connected
- Test with Windows Camera app
- Try different camera index (0, 1, 2)

### Issue 2: "Failed to open camera"
**Cause:** Camera in use by another application  
**Solution:**
- Close other apps using camera (Teams, Skype, etc.)
- Restart backend
- Try different camera

### Issue 3: Low FPS (<15)
**Cause:** Too many tracking types enabled  
**Solution:**
- Disable unused tracking (pose is most expensive)
- Reduce camera resolution
- Lower camera FPS

### Issue 4: No landmarks appear
**Cause:** MediaPipe not initialized  
**Solution:**
- Check console for errors
- Verify mediapipe package installed
- Restart backend

### Issue 5: Video feed blank
**Cause:** Camera not started or stream disconnected  
**Solution:**
- Call `/api/camera/start` endpoint
- Refresh browser page
- Check console logs

---

## Advanced Testing

### Multiple Tracking Types:
```bash
curl -X POST http://localhost:5000/api/tracking/enable ^
  -H "Content-Type: application/json" ^
  -d "{\"face_mesh\": true, \"hands\": true, \"pose\": true}"
```

**Result:** All three tracking types active simultaneously

### Custom Resolution:
```bash
curl -X POST http://localhost:5000/api/camera/select ^
  -H "Content-Type: application/json" ^
  -d "{\"camera_index\": 0, \"resolution\": [1280, 720], \"fps\": 30}"
```

**Result:** Higher quality video (but lower FPS)

### Stream Stats:
```bash
curl http://localhost:5000/stream_stats
```

**Response:**
```json
{
  "fps": 28.5,
  "active": true,
  "landmarks": false,
  "last_frame": 1698345678.123
}
```

---

## Success Criteria

### ✅ Camera Integration Complete When:
- [ ] UI shows list of cameras (not "Loading cameras...")
- [ ] Can select and start camera
- [ ] Video stream shows in browser
- [ ] Face mesh landmarks overlay on video
- [ ] Can toggle tracking on/off
- [ ] Can stop camera cleanly
- [ ] No crashes or memory leaks
- [ ] FPS counter shows actual frame rate
- [ ] All API endpoints respond correctly

---

## Next Steps

### Phase 2: Advanced Features
1. Recording functionality
2. Configuration persistence
3. Export landmark data
4. Virtual camera output
5. Multi-camera support

### Phase 3: Optimization
1. GPU acceleration
2. Frame skipping for better FPS
3. Adaptive quality
4. Threaded processing
5. Memory pooling

---

## Technical Architecture

### Data Flow:
```
Camera (OpenCV)
    ↓
Camera.read() → (ret, frame)
    ↓
WebProcessor.process(frame)
    ↓
MediaPipe (Face/Hands/Pose)
    ↓
Landmark Data (dict)
    ↓
overlay_landmarks(frame, landmarks)
    ↓
MJPEG Encoding
    ↓
HTTP Stream (/video_feed)
    ↓
Browser Display
```

### Module Relationships:
```
capture/
  ├── enumerator.py   - List cameras (MSMF)
  ├── camera.py       - Camera class (OpenCV)
  └── cap_msmf.py     - MSMF wrapper

pipeline/
  └── web_processor.py - MediaPipe orchestration

server/routes/
  ├── camera.py       - Camera API (list/select/start/stop)
  ├── streaming.py    - Video streaming (MJPEG + landmarks)
  └── tracking.py     - Tracking control (enable/disable)
```

---

## Debugging

### Enable Debug Logging:
Add to `run
