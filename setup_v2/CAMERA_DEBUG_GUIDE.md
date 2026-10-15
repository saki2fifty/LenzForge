# Camera Integration Debugging Guide

**Date:** October 26, 2025  
**Status:** Code Complete - Needs Testing & Debugging

---

## Quick Test

### 1. Test Camera API Directly
```powershell
# While backend is running, open PowerShell:
Invoke-WebRequest -Uri "http://localhost:5000/api/camera/list" | Select-Object -ExpandProperty Content
```

**Expected:** JSON with list of cameras  
**If Error:** Check console logs in backend terminal

### 2. Check Browser Console
1. Open browser: `http://localhost:5000`
2. Press `F12` → Console tab
3. Look for errors related to:
   - Camera API calls
   - Module loading
   - JavaScript errors

### 3. Check Backend Logs
Look in backend terminal for:
- Import errors
- Camera enumeration errors
- API endpoint errors

---

## Common Issues & Fixes

### Issue 1: "Loading cameras..." Never Completes

**Symptom:** UI shows "Loading cameras..." forever

**Possible Causes:**
1. JavaScript not calling API
2. API returning error
3. Import errors in backend

**Debug Steps:**
```javascript
// In browser console (F12):
fetch('http://localhost:5000/api/camera/list')
  .then(r => r.json())
  .then(d => console.log(d))
  .catch(e => console.error(e));
```

**Expected:** `{cameras: [...]}`  
**If Error:** Check backend terminal for Python errors

### Issue 2: Import Errors

**Symptom:** Backend logs show `ImportError` or `ModuleNotFoundError`

**Fix:** The camera routes use absolute imports. Check if paths are correct:
```python
# In camera.py, these imports might fail:
from backend_v2.capture.enumerator import enumerate_cameras
from backend_v2.capture.camera import Camera
```

**Solution:** Ensure backend is run from correct directory:
```powershell
# From project root:
.\buildtools\python\python.exe .\workspace_v2\cpp-viewer\backend_v2\run_server.py
```

### Issue 3: Camera Enumeration Returns Empty

**Symptom:** API returns `{cameras: []}`

**Possible Causes:**
1. No cameras connected
2. Camera permissions denied
3. Enumeration function not working

**Test Enumeration Directly:**
```powershell
cd workspace_v2\cpp-viewer\backend_v2
..\..\..\..\buildtools\python\python.exe -c "from capture.enumerator import enumerate_cameras; print(enumerate_cameras())"
```

**Expected:** List of camera objects  
**If Empty:** Check Windows camera permissions

### Issue 4: MSMF Extension Not Loading

**Symptom:** Only OpenCV cameras, no MSMF cameras

**Check Extension:**
```powershell
dir workspace_v2\cpp-viewer\backend_v2\capture\msmf_extension\*.pyd
```

**Expected:** `msmf_capture.cp311-win_amd64.pyd`  
**If Missing:** Extension not built or deployed

**Rebuild:**
```powershell
cd setup_v2
.\020-Build-MSMF-Extension.ps1
.\030-Deploy-Backend.ps1
```

---

## Frontend Integration Check

### Check modules.js

The frontend code in `modules.js` should have a camera loading function. Check if it exists:

```javascript
// In browser console (F12):
typeof CameraModule !== 'undefined'  // Should be true
CameraModule.loadCameras  // Should be a function
```

If undefined, check if modules.js loaded:
```
Network tab → Look for modules.js → Status should be 200
```

### Manual Camera Load Test

```javascript
// In browser console (F12):
async function testCameras() {
  try {
    const response = await fetch('/api/camera/list');
    const data = await response.json();
    console.log('Cameras:', data);
    return data;
  } catch(e) {
    console.error('Error:', e);
  }
}
testCameras();
```

---

## Backend Testing

### Test Each Endpoint

1. **List Cameras:**
```powershell
curl http://localhost:5000/api/camera/list
```

2. **Select Camera:**
```powershell
curl -X POST http://localhost:5000/api/camera/select `
  -H "Content-Type: application/json" `
  -d '{\"camera_index\": 0, \"resolution\": [640, 480], \"fps\": 30}'
```

3. **Start Camera:**
```powershell
curl -X POST http://localhost:5000/api/camera/start
```

4. **Check Current:**
```powershell
curl http://localhost:5000/api/camera/current
```

---

## MediaPipe Integration Check

### Verify MediaPipe Installation
```powershell
.\buildtools\python\python.exe -c "import mediapipe; print(mediapipe.__version__)"
```

**Expected:** Version number (e.g., `0.10.9`)  
**If Error:** MediaPipe not installed

### Test MediaPipe Processor
```powershell
cd workspace_v2\cpp-viewer\backend_v2
..\..\..\..\buildtools\python\python.exe -c "from pipeline.web_processor import WebProcessor; print('OK')"
```

**Expected:** `OK`  
**If Error:** Check pipeline/web_processor.py for issues

---

## Video Streaming Check

### Test Video Feed Endpoint

While backend running:
```
Open browser: http://localhost:5000/video_feed
```

**Expected:** 
- Should show video stream or placeholder
- Content-Type: `multipart/x-mixed-replace`

**If 404:** Streaming route not registered  
**If 500:** Check backend terminal for errors

---

## Step-by-Step Debug Process

### Step 1: Backend Health
```powershell
# Test backend is running:
curl http://localhost:5000/health
```
**Expected:** `{"status": "healthy", ...}`

### Step 2: Camera API Available
```powershell
curl http://localhost:5000/api/camera/list
```
**Expected:** `{"cameras": [...]}`  
**If Error:** Check import errors in backend terminal

### Step 3: Frontend Loading
```
1. Open: http://localhost:5000
2. F12 → Network tab
3. Look for:
   - modules.js (Status: 200)
   - console.js (Status: 200)
   - docs.js (Status: 200)
```

### Step 4: JavaScript Execution
```javascript
// In browser console:
console.log(typeof CameraModule);  // Should be "object"
console.log(typeof API);            // Should be "object"
```

### Step 5: API Calls
```javascript
// In browser console:
API.listCameras().then(console.log).catch(console.error);
```
**Expected:** Cameras list

### Step 6: Camera Selection
```javascript
// In browser console:
API.selectCamera(0).then(console.log).catch(console.error);
```

### Step 7: Camera Start
```javascript
// In browser console:
API.startCamera().then(console.log).catch(console.error);
```

---

## Known Working Configuration

**What Works:**
- ✅ Backend starts successfully
- ✅ All APIs registered
- ✅ Console logging system
- ✅ Documentation viewer
- ✅ Effects system

**What Needs Testing:**
- ⏳ Camera enumeration
- ⏳ Camera selection
- ⏳ Video streaming
- ⏳ MediaPipe processing
- ⏳ Landmark overlay

---

## If All Else Fails

### Option 1: Use Mock Data

The camera routes have fallback to return mock data. If enumeration fails, it returns:
```json
{
  "cameras": [
    {"index": 0, "name": "Default Camera", "backend": "DirectShow"}
  ]
}
```

This lets you test the UI even without working camera enumeration.

### Option 2: Simplify Imports

If import issues persist, modify `camera.py` routes to use relative imports:
```python
# Change from:
from backend_v2.capture.enumerator import enumerate_cameras

# To:
from capture.enumerator import enumerate_cameras
```

### Option 3: Add Debug Logging

Add print statements to track execution:
```python
# In camera.py list_cameras():
print("DEBUG: Attempting to list cameras")
print(f"DEBUG: Found {len(cameras)} cameras")
```

---

## Success Criteria

Camera integration is working when:
- [ ] UI shows list of available cameras (not "Loading...")
- [ ] Can click to select a camera
- [ ] Video feed displays in `/video_feed`
- [ ] Can see landmarks overlay on video
- [ ] Can toggle tracking modes
- [ ] FPS counter shows actual frame rate

---

## Need More Help?

1. **Copy backend terminal output** - All errors shown there
2. **Copy browser console logs** (F12 → Console tab)
3. **Test each API endpoint** with PowerShell commands above
4. **Check logs in console panel** - Real-time debugging!

The console system we just built will help debug these issues!
