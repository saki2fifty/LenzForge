# Quick Start Guide

**Get LenzForge V2 running in 10 minutes.**

This guide will get you from zero to tracking in the shortest time possible.

---

## Prerequisites

- Windows 10/11 (64-bit)
- 8 GB RAM minimum
- Webcam
- Internet connection (for initial setup)

---

## Step 1: Initial Setup (3 minutes)

### Run Master Setup Script

```powershell
cd setup_v2
.\00-Setup.ps1
```

This will:
- Download Python 3.11 (embedded)
- Download and extract dependencies
- Install MediaPipe, OpenCV, NumPy
- Set up complete environment

**Wait for**: "Setup complete!" message

---

## Step 2: Deploy Backend (1 minute)

```powershell
.\06-Deploy-Backend.ps1
```

This copies `assets/backend_v2/` → `workspace/cpp-viewer/backend_v2/`

**Verify**: Check that `workspace/cpp-viewer/backend_v2/` exists

---

## Step 3: Test Tracking (2 minutes)

### Quick Camera Test

```powershell
cd ..
python test_backend_v2.py
```

**Expected Output**:
```
Camera: Microsoft® LifeCam HD-3000
Resolution: 640×480 @ 30 FPS
Face Mesh: 29.7 FPS @ 99.7% detection
✅ Backend working!
```

Press `Ctrl+C` to stop.

---

## Step 4: Build GDExtension (3 minutes)

### Download & Build

```powershell
cd setup_v2
.\09-Download-CMake.ps1
.\11-Extract-CMake.ps1
.\20-Build-GDExtension.ps1
```

**Expected**: GDExtension DLL built successfully

---

## Step 5: Run Complete System (1 minute)

### Start Backend + Godot

```powershell
# Terminal 1 - Start backend
cd workspace/cpp-viewer/backend_v2
python main.py
```

```powershell
# Terminal 2 - Launch Godot
cd setup_v2
.\XX-Test-Godot.ps1
```

**You should see**:
- Backend console showing tracking data
- Godot window with face mesh overlay

---

## Quick Verification Checklist

- [ ] Python environment set up
- [ ] Backend deployed
- [ ] Camera test passed
- [ ] GDExtension built
- [ ] Godot launches
- [ ] Face tracking visible

---

## Common Issues

### "Camera not found"
- Check webcam is connected
- Close other apps using camera (Zoom, Teams, etc.)
- Try different camera with `camera_index` in config

### "Module not found"
- Re-run `.\00-Setup.ps1`
- Check `workspace/cpp-viewer/backend_v2/` exists

### "Build failed"
- Ensure CMake downloaded: `.\09-Download-CMake.ps1`
- Check Visual Studio Build Tools installed
- Try `.\20-Build-GDExtension.ps1` again

---

## What's Next?

### Explore Effects

```python
from backend_v2.effects import get_effects_manager

manager = get_effects_manager()
blur = manager.create_effect('BackgroundBlurEffect')
blur.set_parameter('blur_amount', 25)
blur.enable()
```

See [Effects Documentation](EFFECTS.md) for all 47 effects!

### Customize Configuration

Edit `workspace/cpp-viewer/backend_v2/config.json`:

```json
{
  "camera_index": 0,
  "resolution": [640, 480],
  "target_fps": 30,
  "tracking": {
    "enable_face_mesh": true,
    "enable_iris": true,
    "enable_hands": false,
    "enable_pose": false
  }
}
```

### Add HTTP API

Coming soon - see [Integration Guide](INTEGRATION.md)

---

## Performance Tips

### For Higher FPS
- Disable unused tracking (hands, pose)
- Use lower resolution (640×480)
- Close other applications
- Ensure good lighting

### For Better Quality
- Use higher resolution (1280×720)
- Enable iris refinement
- Adjust confidence thresholds
- Use better webcam

---

## Testing Individual Components

### Test IPC Only
```powershell
python workspace/cpp-viewer/backend_v2/test_landmark_producer.py
```

### Test Effects Only
```powershell
python test_effects.py
```

### Test MediaPipe Only
```powershell
python workspace/cpp-viewer/backend_v2/test_facemesh.py
```

---

## Getting Help

1. Check [Troubleshooting](TROUBLESHOOTING.md)
2. Review [Backend Documentation](BACKEND.md)
3. See [FAQ](FAQ.md)

---

## Summary

✅ **You now have**:
- Working Python backend with tracking
- 47 effects ready to use
- GDExtension for Godot integration
- Complete development environment

**Next Steps**:
- Explore [Effects Library](EFFECTS.md)
- Read [Backend Documentation](BACKEND.md)
- Try [Integration Guide](INTEGRATION.md)

---

**Typical Setup Time**: 10 minutes
**First successful tracking**: Priceless! 🎉
