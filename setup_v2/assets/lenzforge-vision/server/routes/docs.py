"""
Documentation API Routes
Serves project documentation and guides
"""
from flask import Blueprint, jsonify, send_from_directory
from pathlib import Path
import json

bp = Blueprint('docs', __name__)

# Documentation structure
DOCS = {
    "quick_start": {
        "title": "Quick Start Guide",
        "category": "Getting Started",
        "content": """
# Quick Start Guide

## Starting the Backend

```powershell
.\\Start-Backend.ps1
```

The backend will start on `http://localhost:5000`

## Opening the Web UI

Navigate to: `http://localhost:5000`

## First Steps

1. **Check System Status** - The header shows FPS, CPU, Memory, and Uptime
2. **Select Camera** - Choose from available cameras in the Camera Selection panel
3. **Enable Tracking** - Toggle Face Mesh, Iris, Hands, or Pose tracking
4. **Apply Effects** - Browse and apply effects from the Effects Studio
5. **Monitor Console** - Watch real-time logs in the System Console

## Keyboard Shortcuts

- `Ctrl+Shift+R` - Hard refresh (reload all assets)
- `F12` - Open browser developer console

## Need Help?

Check the Console panel for error messages and system logs.
"""
    },
    "api_reference": {
        "title": "API Reference",
        "category": "Developer",
        "content": """
# API Reference

## Base URL
`http://localhost:5000/api`

## System Endpoints

### GET /status
Get system status and metrics.

**Response:**
```json
{
  "status": "running",
  "uptime": 123.45,
  "fps": 30.0,
  "cpu_percent": 15.2,
  "memory_mb": 512.3
}
```

### GET /info
Get system information.

### POST /start
Start the processing pipeline.

### POST /stop
Stop the processing pipeline.

### POST /restart
Restart the processing pipeline.

## Camera Endpoints

### GET /camera/list
List available cameras.

**Response:**
```json
{
  "cameras": [
    {"id": 0, "name": "Integrated Camera"},
    {"id": 1, "name": "USB Camera"}
  ]
}
```

### POST /camera/select
Select and configure a camera.

**Request:**
```json
{
  "camera_index": 0,
  "resolution": [1280, 720],
  "fps": 30
}
```

### POST /camera/start
Start camera capture.

### POST /camera/stop
Stop camera capture.

## Tracking Endpoints

### GET /tracking/status
Get tracking status for all modalities.

### POST /tracking/enable
Enable/disable tracking modalities.

**Request:**
```json
{
  "face": true,
  "iris": false,
  "hands": true,
  "pose": false
}
```

### GET /tracking/statistics
Get tracking performance statistics.

## Effects Endpoints

### GET /effects/list
List all available effects.

### GET /effects/active
Get currently active effects.

### POST /effects/apply
Apply an effect.

**Request:**
```json
{
  "effect_name": "blur_background",
  "parameters": {"intensity": 0.8},
  "enabled": true
}
```

### POST /effects/remove
Remove an effect.

### POST /effects/clear
Clear all active effects.

## Logging Endpoints

### GET /logs/status
Get logging system status.

### POST /logs/enable
Enable/disable logging.

**Request:**
```json
{
  "enabled": false
}
```

### GET /logs/recent?limit=100
Get recent logs.

### POST /logs/clear
Clear log buffer.
"""
    },
    "effects_guide": {
        "title": "Effects Guide",
        "category": "Features",
        "content": """
# Effects Guide

## Available Effect Categories

### Background Effects
- **Blur Background** - Blur everything except tracked subject
- **Replace Background** - Replace background with image/video
- **Remove Background** - Make background transparent

### Face Effects
- **Face Filters** - AR face filters and masks
- **Makeup** - Virtual makeup application  
- **Aging/De-aging** - Age transformation effects

### Creative Effects
- **Pixelation** - Pixelate tracked regions
- **Color Grading** - Adjust colors and tones
- **Glitch** - Digital glitch effects

### Hand Effects
- **Virtual Objects** - Hold virtual objects
- **Hand Tracking** - Visual hand tracking overlay
- **Gesture Recognition** - Detect and respond to gestures

## Applying Effects

1. Browse effects in the Effects Studio panel
2. Click an effect card to apply it
3. Active effects appear in the Active Effects panel
4. Click "Remove" to disable an effect
5. Click "Clear All" to remove all effects

## Effect Parameters

Many effects have adjustable parameters:
- **Intensity** - Effect strength (0.0 to 1.0)
- **Threshold** - Detection threshold
- **Color** - Color selection for color-based effects
- **Size** - Size adjustments

## Performance Tips

- Disable unused tracking modalities
- Use lower camera resolution for better FPS
- Limit number of active effects
- Disable logging for ~5-10% CPU savings
"""
    },
    "tracking_guide": {
        "title": "Tracking Guide", 
        "category": "Features",
        "content": """
# Tracking Guide

## MediaPipe Tracking Modalities

### Face Mesh (478 landmarks)
Tracks 478 3D facial landmarks including:
- Face contours
- Eyes and eyebrows
- Nose
- Lips and mouth
- Face oval

**Use Cases:**
- Face filters and effects
- Expression recognition
- Gaze tracking
- Face shape analysis

### Iris Tracking
Precise eye and iris tracking:
- Pupil center
- Iris boundary
- Eye gaze direction

**Use Cases:**
- Gaze-based interaction
- Eye contact detection
- Attention tracking

### Hand Tracking (21 landmarks per hand)
Tracks up to 2 hands with 21 landmarks each:
- Wrist
- Thumb (4 points)
- Index finger (4 points)
- Middle finger (4 points)
- Ring finger (4 points)
- Pinky (4 points)

**Use Cases:**
- Gesture recognition
- Virtual object interaction
- Hand pose estimation
- Sign language recognition

### Pose Estimation (33 landmarks)
Full-body pose tracking:
- Face (6 points)
- Upper body (11 points)
- Lower body (10 points)
- Hands and feet (6 points)

**Use Cases:**
- Fitness applications
- Action recognition
- Body measurement
- Posture analysis

## Configuration

### Detection Confidence
Minimum confidence for initial detection (0.0 to 1.0)
- **Low (0.3)** - More detections, more false positives
- **Medium (0.5)** - Balanced (recommended)
- **High (0.7)** - Fewer false positives, may miss some detections

### Tracking Confidence
Minimum confidence for tracking between frames (0.0 to 1.0)
- **Low (0.3)** - Smooth but less accurate
- **Medium (0.5)** - Balanced (recommended)
- **High (0.7)** - More accurate but may lose track more easily

## Performance Optimization

1. **Enable only needed modalities** - Each adds processing overhead
2. **Lower camera resolution** - Faster processing
3. **Reduce target FPS** - Saves CPU
4. **Increase confidence thresholds** - Fewer detections = faster
"""
    },
    "console_guide": {
        "title": "Console System Guide",
        "category": "Features",
        "content": """
# Console System Guide

## Overview

The System Console provides real-time logging and debugging capabilities with advanced filtering and search features.

## Features

### Real-Time Log Streaming
- Logs appear instantly as they're generated
- WebSocket-based streaming for minimal latency
- Buffer size: 1000 logs (FIFO)
- Maximum display: 5000 logs

### Log Levels
- **DEBUG** - Detailed diagnostic information
- **INFO** - General informational messages
- **WARNING** - Warning messages for potentially problematic situations
- **ERROR** - Error messages for serious problems

### Controls

#### Pause/Resume ⏸️▶️
Freeze log display while keeping buffer active. Useful for:
- Reading specific log messages
- Copying log content
- Investigating issues

#### Compact Mode 📦
Toggle between compact and expanded display modes:
- **Compact** - Single line per log (default)
- **Expanded** - Multi-line with full metadata

#### Clear 🗑️
Clear all logs from display and buffer. Requires confirmation.

#### Copy 📋  
Copy all logs to clipboard in text format.

#### Search 🔍
Real-time search across all log fields:
- Filters as you type
- Case-insensitive
- Searches: level, module, message

### Filters

Enable/disable log levels independently:
- Uncheck DEBUG to hide debug messages
- Uncheck INFO for critical messages only
- Multiple filters can be combined

### Auto-Scroll

Automatically scroll to newest logs:
- **Enabled** - Always shows latest logs
- **Disabled** - Manual scroll control

### Performance Toggle

System Logging toggle:
- **Enabled** - Full logging active
- **Disabled** - Saves ~5-10% CPU

Disabling sets log level to CRITICAL+1, effectively stopping all log processing.

## Tips

1. **Finding Errors** - Uncheck all except ERROR
2. **Debugging** - Enable DEBUG and search for module name
3. **Performance** - Disable logging during intensive operations
4. **Analysis** - Pause, search, copy for detailed analysis
"""
    },
    "troubleshooting": {
        "title": "Troubleshooting",
        "category": "Help",
        "content": """
# Troubleshooting Guide

## Common Issues

### Camera Not Detected

**Symptoms:**
- "Loading cameras..." never completes
- Empty camera list
- Console shows camera errors

**Solutions:**
1. Check camera permissions in Windows Settings
2. Close other applications using the camera
3. Try a different USB port
4. Restart the backend
5. Check console for specific error messages

### Low FPS

**Symptoms:**
- FPS below target (e.g., < 30 FPS)
- Laggy video
- High CPU usage

**Solutions:**
1. Disable unused tracking modalities
2. Lower camera resolution (640×480)
3. Reduce target FPS to 15
4. Remove active effects
5. Disable system logging
6. Close other CPU-intensive applications

### WebSocket Connection Failed

**Symptoms:**
- Console shows "WebSocket connection failed"
- Logs not updating in real-time
- Browser console shows connection errors

**Solutions:**
1. Hard refresh browser (Ctrl+Shift+R)
2. Restart backend
3. Check firewall settings
4. Try different browser
5. Clear browser cache

### Effects Not Working

**Symptoms:**
- Effect applies but doesn't show
- Effect immediately removed
- Console shows effect errors

**Solutions:**
1. Check if camera is running
2. Enable required tracking modality
3. Check effect parameters
4. View console for error messages
5. Try removing and re-applying effect

### Backend Won't Start

**Symptoms:**
- PowerShell error when starting
- Port already in use
- Python errors

**Solutions:**
1. Check if port 5000 is available:
   ```powershell
   netstat -ano | findstr :5000
   ```
2. Stop existing backend process
3. Check Python installation
4. Verify all packages installed
5. Check logs directory permissions

## Getting Help

1. **Check Console** - Most errors appear in real-time logs
2. **Browser Console** - Press F12 for JavaScript errors
3. **Backend Terminal** - Check terminal output for Python errors
4. **Documentation** - Review API Reference and guides

## Debug Mode

Enable verbose logging:
1. Open console panel
2. Enable DEBUG filter
3. Watch for detailed diagnostic messages
4. Copy logs for analysis

## Reporting Issues

When reporting issues, include:
1. Steps to reproduce
2. Console logs (use Copy button)
3. Browser console errors (F12)
4. Backend terminal output
5. System information (from header)
"""
    }
}


@bp.route('/list', methods=['GET'])
def list_docs():
    """List all available documentation"""
    docs_list = []
    for doc_id, doc in DOCS.items():
        docs_list.append({
            'id': doc_id,
            'title': doc['title'],
            'category': doc['category']
        })
    
    # Group by category
    categories = {}
    for doc in docs_list:
        category = doc['category']
        if category not in categories:
            categories[category] = []
        categories[category].append(doc)
    
    return jsonify({
        'categories': categories,
        'docs': docs_list
    })


@bp.route('/<doc_id>', methods=['GET'])
def get_doc(doc_id):
    """Get specific documentation"""
    if doc_id not in DOCS:
        return jsonify({
            'error': 'Documentation not found'
        }), 404
    
    doc = DOCS[doc_id]
    return jsonify({
        'id': doc_id,
        'title': doc['title'],
        'category': doc['category'],
        'content': doc['content']
    })


@bp.route('/search', methods=['GET'])
def search_docs():
    """Search documentation content"""
    from flask import request
    query = request.args.get('q', '').lower()
    
    if not query:
        return jsonify({'results': []})
    
    results = []
    for doc_id, doc in DOCS.items():
        # Search in title and content
        if query in doc['title'].lower() or query in doc['content'].lower():
            # Find matching lines
            lines = doc['content'].split('\n')
            matches = [line for line in lines if query in line.lower()]
            
            results.append({
                'id': doc_id,
                'title': doc['title'],
                'category': doc['category'],
                'matches': matches[:3]  # First 3 matches
            })
    
    return jsonify({'results': results})
