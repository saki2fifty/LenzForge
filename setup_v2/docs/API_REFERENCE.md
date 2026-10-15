# LenzForge V2 - API Reference

**Version:** 2.0.0  
**Last Updated:** October 29, 2025  
**Base URL:** http://localhost:5000

Complete HTTP REST API documentation for LenzForge backend server.

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [System Endpoints](#system-endpoints)
4. [Camera Endpoints](#camera-endpoints)
5. [Tracking Endpoints](#tracking-endpoints)
6. [Effects Endpoints](#effects-endpoints)
7. [Configuration Endpoints](#configuration-endpoints)
8. [Streaming Endpoints](#streaming-endpoints)
9. [Error Handling](#error-handling)
10. [Rate Limiting](#rate-limiting)

---

## Overview

### Server Configuration

```
Protocol: HTTP/1.1
Base URL: http://localhost:5000
Port: 5000 (configurable via FLASK_PORT env var)
Content-Type: application/json (for API endpoints)
```

### CORS Configuration

```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

### API Versioning

Current API version is included in all responses:
```json
{
  "version": "2.0.0",
  "api_version": "v1"
}
```

---

## Authentication

**Current Status:** No authentication required (localhost only)

**Future:** JWT-based authentication planned for remote access

```http
Authorization: Bearer <token>
```

---

## System Endpoints

### GET /api/status

Get current system status and health metrics.

**Status:** ✅ Implemented

**Request:**
```http
GET /api/status HTTP/1.1
Host: localhost:5000
```

**Response:** `200 OK`
```json
{
  "status": "running",
  "version": "2.0.0",
  "uptime_seconds": 3600,
  "backend": {
    "active": true,
    "fps": 29.7,
    "camera_active": true,
    "tracking_active": true,
    "face_detected": true
  },
  "performance": {
    "avg_process_time_ms": 22.5,
    "frame_count": 53640,
    "dropped_frames": 12
  },
  "memory_usage_mb": 385.2,
  "cpu_usage_percent": 35.5
}
```

**cURL Example:**
```bash
curl http://localhost:5000/api/status
```

**Python Example:**
```python
import requests

response = requests.get('http://localhost:5000/api/status')
status = response.json()
print(f"FPS: {status['backend']['fps']}")
```

---

### GET /api/health

Simple health check endpoint.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "status": "healthy",
  "timestamp": "2025-10-29T14:30:00Z"
}
```

---

### GET /api/stats

Get detailed performance statistics.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "session": {
    "start_time": "2025-10-29T10:15:00Z",
    "duration_seconds": 15300,
    "total_frames_processed": 459000
  },
  "performance": {
    "current_fps": 29.8,
    "average_fps": 29.5,
    "min_fps": 25.2,
    "max_fps": 31.1,
    "frame_times_ms": {
      "avg": 22.5,
      "min": 18.2,
      "max": 35.7,
      "p50": 22.0,
      "p95": 28.5,
      "p99": 32.1
    }
  },
  "tracking": {
    "face_detection_rate": 99.7,
    "iris_detection_rate": 98.5,
    "avg_landmarks_per_frame": 488
  },
  "camera": {
    "resolution": [1920, 1080],
    "actual_fps": 30.0,
    "frames_captured": 459500,
    "frames_dropped": 12
  },
  "resources": {
    "memory_mb": 385.2,
    "memory_peak_mb": 412.8,
    "cpu_percent": 35.5,
    "cpu_peak_percent": 48.2
  }
}
```

---

### POST /api/start

Start or resume the tracking pipeline.

**Status:** ✅ Implemented

**Request:**
```http
POST /api/start HTTP/1.1
Host: localhost:5000
Content-Type: application/json
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Pipeline started",
  "fps": 30,
  "resolution": [1920, 1080]
}
```

---

### POST /api/stop

Stop the tracking pipeline (camera remains allocated).

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Pipeline stopped"
}
```

---

### POST /api/restart

Restart the tracking pipeline.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Pipeline restarted",
  "fps": 30
}
```

---

## Camera Endpoints

### GET /api/cameras

List all available cameras with capabilities.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "cameras": [
    {
      "index": 0,
      "name": "Integrated Camera",
      "backend": "MSMF",
      "supported_resolutions": [
        [640, 480],
        [1280, 720],
        [1920, 1080]
      ],
      "supported_fps": [15, 30, 60],
      "current": true
    },
    {
      "index": 1,
      "name": "OBS Virtual Camera",
      "backend": "DSHOW",
      "supported_resolutions": [
        [1920, 1080]
      ],
      "supported_fps": [30, 60],
      "current": false
    }
  ],
  "count": 2
}
```

**cURL Example:**
```bash
curl http://localhost:5000/api/cameras
```

---

### GET /api/camera/current

Get current camera configuration.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "index": 0,
  "name": "Integrated Camera",
  "resolution": {
    "width": 1920,
    "height": 1080
  },
  "fps": 30,
  "format": "NV12",
  "active": true,
  "capabilities": {
    "auto_focus": true,
    "auto_exposure": true,
    "auto_white_balance": true
  }
}
```

---

### POST /api/camera/select

Select and activate a different camera.

**Status:** ✅ Implemented

**Request:**
```json
{
  "camera_index": 1
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Camera selected",
  "camera": {
    "index": 1,
    "name": "OBS Virtual Camera",
    "resolution": [1920, 1080],
    "fps": 30
  }
}
```

**Error Response:** `404 Not Found`
```json
{
  "success": false,
  "error": "Camera index 5 not found",
  "available_cameras": [0, 1]
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:5000/api/camera/select \
  -H "Content-Type: application/json" \
  -d '{"camera_index": 1}'
```

---

### POST /api/camera/configure

Configure camera resolution and FPS.

**Status:** ✅ Implemented

**Request:**
```json
{
  "width": 1280,
  "height": 720,
  "fps": 60
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Camera configured",
  "configuration": {
    "resolution": [1280, 720],
    "fps": 60,
    "format": "NV12"
  }
}
```

**Error Response:** `400 Bad Request`
```json
{
  "success": false,
  "error": "Resolution 3840x2160 not supported",
  "supported_resolutions": [
    [640, 480],
    [1280, 720],
    [1920, 1080]
  ]
}
```

---

### GET /api/camera/capabilities

Get detailed camera capabilities.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "camera_index": 0,
  "name": "Integrated Camera",
  "formats": ["NV12", "YUY2", "MJPEG"],
  "resolutions": [
    {
      "width": 640,
      "height": 480,
      "fps_options": [15, 30]
    },
    {
      "width": 1280,
      "height": 720,
      "fps_options": [15, 30, 60]
    },
    {
      "width": 1920,
      "height": 1080,
      "fps_options": [15, 30]
    }
  ],
  "controls": {
    "brightness": {"min": 0, "max": 255, "step": 1, "default": 128},
    "contrast": {"min": 0, "max": 255, "step": 1, "default": 128},
    "saturation": {"min": 0, "max": 255, "step": 1, "default": 128},
    "hue": {"min": -180, "max": 180, "step": 1, "default": 0},
    "auto_focus": {"type": "bool", "default": true},
    "focus": {"min": 0, "max": 255, "step": 1, "default": 0},
    "auto_exposure": {"type": "bool", "default": true},
    "exposure": {"min": -11, "max": -1, "step": 1, "default": -6}
  }
}
```

---

## Tracking Endpoints

### GET /api/tracking/status

Get tracking system status for all types.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "face_mesh": {
    "enabled": true,
    "active": true,
    "fps": 29.7,
    "detection_rate": 99.7,
    "landmark_count": 478,
    "avg_confidence": 0.987
  },
  "iris": {
    "enabled": true,
    "active": true,
    "fps": 29.7,
    "detection_rate": 98.5,
    "landmark_count": 10,
    "avg_confidence": 0.953
  },
  "hands": {
    "enabled": false,
    "active": false,
    "fps": 0,
    "detection_rate": 0,
    "landmark_count": 0
  },
  "pose": {
    "enabled": false,
    "active": false,
    "fps": 0,
    "detection_rate": 0,
    "landmark_count": 0
  }
}
```

---

### GET /api/tracking/landmarks

Get current landmark data (snapshot).

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "timestamp": 1698264000.123456,
  "frame_id": 12345,
  "has_face": true,
  "face_mesh": {
    "detected": true,
    "confidence": 0.987,
    "bbox": {
      "x": 0.25,
      "y": 0.15,
      "width": 0.5,
      "height": 0.7
    },
    "landmarks": [
      {"x": 0.5012, "y": 0.4523, "z": -0.0123},
      {"x": 0.5024, "y": 0.4535, "z": -0.0118},
      ...
    ]
  },
  "iris": {
    "left_eye": {
      "center": {"x": 0.45, "y": 0.40},
      "landmarks": [
        {"x": 0.45, "y": 0.40},
        {"x": 0.448, "y": 0.398},
        ...
      ]
    },
    "right_eye": {
      "center": {"x": 0.55, "y": 0.40},
      "landmarks": [...]
    }
  }
}
```

**Query Parameters:**
- `format` (string): "normalized" (default) or "pixel" - Coordinate system
- `include_confidence` (bool): Include per-landmark confidence (default: false)

**Example with pixel coordinates:**
```http
GET /api/tracking/landmarks?format=pixel&include_confidence=true
```

---

### POST /api/tracking/enable

Enable or disable specific tracking types.

**Status:** ✅ Implemented

**Request:**
```json
{
  "face_mesh": true,
  "iris": true,
  "hands": false,
  "pose": false
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Tracking configuration updated",
  "enabled": ["face_mesh", "iris"],
  "disabled": ["hands", "pose"]
}
```

---

### POST /api/tracking/configure

Configure MediaPipe tracking parameters.

**Status:** ✅ Implemented

**Request:**
```json
{
  "face_mesh": {
    "refine_landmarks": true,
    "min_detection_confidence": 0.5,
    "min_tracking_confidence": 0.5,
    "max_num_faces": 1
  },
  "iris": {
    "enabled": true
  },
  "hands": {
    "max_num_hands": 2,
    "min_detection_confidence": 0.5,
    "min_tracking_confidence": 0.5,
    "model_complexity": 1
  },
  "pose": {
    "min_detection_confidence": 0.5,
    "min_tracking_confidence": 0.5,
    "model_complexity": 1,
    "enable_segmentation": false
  }
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Tracking parameters updated",
  "restart_required": true
}
```

---

### GET /api/tracking/statistics

Get detailed tracking statistics.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "session_start": "2025-10-29T10:15:00Z",
  "total_frames": 53640,
  "frames_with_face": 53502,
  "detection_rates": {
    "face_mesh": 99.74,
    "iris": 98.52,
    "hands": 0.0,
    "pose": 0.0
  },
  "processing_times_ms": {
    "face_mesh": {
      "avg": 16.8,
      "min": 12.5,
      "max": 35.2,
      "p95": 22.3
    },
    "iris": {
      "avg": 1.2,
      "min": 0.8,
      "max": 2.5,
      "p95": 1.8
    },
    "total_pipeline": {
      "avg": 22.5,
      "min": 18.2,
      "max": 38.7,
      "p95": 28.5
    }
  },
  "confidence_stats": {
    "face_mesh": {
      "avg": 0.987,
      "min": 0.652,
      "max": 0.999
    }
  }
}
```

---

### POST /api/tracking/reset

Reset tracking system (clears history, resets counters).

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Tracking system reset",
  "statistics_cleared": true
}
```

---

## Effects Endpoints

### GET /api/effects

Get list of all available effects with parameters.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "categories": {
    "Blur": [
      {
        "id": "gaussian_blur",
        "name": "Gaussian Blur",
        "description": "Standard Gaussian blur using OpenCV",
        "real_time": true,
        "avg_time_ms": 8.5,
        "parameters": [
          {
            "name": "kernel_size",
            "type": "int",
            "min": 1,
            "max": 99,
            "default": 15,
            "step": 2,
            "description": "Blur kernel size (must be odd)"
          },
          {
            "name": "sigma",
            "type": "float",
            "min": 0.0,
            "max": 10.0,
            "default": 0.0,
            "step": 0.1,
            "description": "Gaussian standard deviation (0 = auto)"
          }
        ]
      },
      {
        "id": "motion_blur",
        "name": "Motion Blur",
        "description": "Directional motion blur effect",
        "real_time": true,
        "avg_time_ms": 12.3,
        "parameters": [
          {
            "name": "kernel_size",
            "type": "int",
            "min": 5,
            "max": 50,
            "default": 15,
            "description": "Motion blur length"
          },
          {
            "name": "angle",
            "type": "float",
            "min": 0.0,
            "max": 360.0,
            "default": 0.0,
            "description": "Motion direction in degrees"
          }
        ]
      }
    ],
    "Color": [
      {
        "id": "hsv_adjust",
        "name": "HSV Adjust",
        "description": "Adjust hue, saturation, and value",
        "real_time": true,
        "avg_time_ms": 3.2,
        "parameters": [
          {
            "name": "hue_shift",
            "type": "int",
            "min": -180,
            "max": 180,
            "default": 0,
            "description": "Hue rotation in degrees"
          },
          {
            "name": "saturation",
            "type": "float",
            "min": 0.0,
            "max": 2.0,
            "default": 1.0,
            "description": "Saturation multiplier"
          },
          {
            "name": "value",
            "type": "float",
            "min": 0.0,
            "max": 2.0,
            "default": 1.0,
            "description": "Value/brightness multiplier"
          }
        ]
      }
    ],
    "Filter": [
      {
        "id": "sepia",
        "name": "Sepia Tone",
        "description": "Classic sepia/vintage look",
        "real_time": true,
        "avg_time_ms": 2.1,
        "parameters": [
          {
            "name": "intensity",
            "type": "float",
            "min": 0.0,
            "max": 1.0,
            "default": 1.0,
            "description": "Effect intensity"
          }
        ]
      }
    ]
  },
  "summary": {
    "total_effects": 47,
    "total_categories": 10,
    "total_parameters": 147,
    "real_time_capable": 38
  }
}
```

**Query Parameters:**
- `category` (string): Filter by category name
- `real_time_only` (bool): Show only real-time capable effects

---

### GET /api/effects/active

Get currently active effects in the pipeline.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "effects": [
    {
      "id": "gaussian_blur",
      "name": "Gaussian Blur",
      "enabled": true,
      "position": 0,
      "parameters": {
        "kernel_size": 21,
        "sigma": 0.0
      },
      "avg_time_ms": 9.2
    },
    {
      "id": "vignette",
      "name": "Vignette",
      "enabled": true,
      "position": 1,
      "parameters": {
        "strength": 0.5,
        "radius": 0.8
      },
      "avg_time_ms": 4.3
    }
  ],
  "chain_length": 2,
  "total_time_ms": 13.5
}
```

---

### POST /api/effects/apply

Apply an effect to the processing pipeline.

**Status:** ✅ Implemented

**Request:**
```json
{
  "effect_id": "gaussian_blur",
  "parameters": {
    "kernel_size": 21,
    "sigma": 3.0
  },
  "enabled": true,
  "position": 0
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Effect applied",
  "effect": {
    "id": "gaussian_blur",
    "name": "Gaussian Blur",
    "enabled": true,
    "position": 0
  }
}
```

**Error Response:** `404 Not Found`
```json
{
  "success": false,
  "error": "Effect 'unknown_effect' not found",
  "available_effects": ["gaussian_blur", "motion_blur", ...]
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:5000/api/effects/apply \
  -H "Content-Type: application/json" \
  -d '{
    "effect_id": "gaussian_blur",
    "parameters": {"kernel_size": 21}
  }'
```

---

### PUT /api/effects/{effect_id}/configure

Update parameters of an active effect.

**Status:** ✅ Implemented

**Request:**
```http
PUT /api/effects/gaussian_blur/configure HTTP/1.1
Content-Type: application/json

{
  "parameters": {
    "kernel_size": 31,
    "sigma": 5.0
  }
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Effect parameters updated",
  "effect_id": "gaussian_blur",
  "parameters": {
    "kernel_size": 31,
    "sigma": 5.0
  }
}
```

---

### PUT /api/effects/{effect_id}/toggle

Enable or disable an effect without removing it.

**Status:** ✅ Implemented

**Request:**
```json
{
  "enabled": false
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Effect toggled",
  "effect_id": "gaussian_blur",
  "enabled": false
}
```

---

### DELETE /api/effects/{effect_id}

Remove an effect from the pipeline.

**Status:** ✅ Implemented

**Request:**
```http
DELETE /api/effects/gaussian_blur HTTP/1.1
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Effect removed",
  "effect_id": "gaussian_blur"
}
```

---

### DELETE /api/effects

Clear all effects from the pipeline.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "All effects cleared",
  "cleared_count": 3
}
```

---

### POST /api/effects/chain

Set complete effect chain (replaces all existing effects).

**Status:** ✅ Implemented

**Request:**
```json
{
  "effects": [
    {
      "effect_id": "sharpen",
      "parameters": {"strength": 1.5},
      "enabled": true
    },
    {
      "effect_id": "vibrance",
      "parameters": {"amount": 30},
      "enabled": true
    },
    {
      "effect_id": "vignette",
      "parameters": {"strength": 0.6},
      "enabled": true
    }
  ]
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Effect chain configured",
  "chain_length": 3,
  "effects": ["sharpen", "vibrance", "vignette"]
}
```

---

## Configuration Endpoints

### GET /api/config

Get complete system configuration.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "camera": {
    "index": 0,
    "resolution": {
      "width": 1920,
      "height": 1080
    },
    "fps": 30
  },
  "tracking": {
    "face_mesh": {
      "enabled": true,
      "refine_landmarks": true,
      "min_detection_confidence": 0.5,
      "min_tracking_confidence": 0.5
    },
    "iris": {
      "enabled": true
    },
    "hands": {
      "enabled": false
    },
    "pose": {
      "enabled": false
    }
  },
  "ipc": {
    "video_ring_name": "LenzForge_Video_NV12",
    "landmarks_ring_name": "LenzForge_Landmarks_NV12",
    "ring_buffer_slots": 4
  },
  "performance": {
    "target_fps": 30,
    "mediapipe_resolution": 640,
    "preview_fps": 30,
    "jpeg_quality": 85
  }
}
```

---

### PUT /api/config

Update system configuration.

**Status:** ✅ Implemented

**Request:**
```json
{
  "camera": {
    "fps": 60
  },
  "performance": {
    "mediapipe_resolution": 480,
    "jpeg_quality": 75
  }
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Configuration updated",
  "restart_required": true,
  "changes": {
    "camera.fps": {"old": 30, "new": 60},
    "performance.mediapipe_resolution": {"old": 640, "new": 480}
  }
}
```

---

### POST /api/config/save

Save current configuration to file.

**Status:** ✅ Implemented

**Request:**
```json
{
  "filename": "my_config.json",
  "overwrite": true
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Configuration saved",
  "file_path": "configs/my_config.json"
}
```

---

### POST /api/config/load

Load configuration from file.

**Status:** ✅ Implemented

**Request:**
```json
{
  "filename": "my_config.json"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Configuration loaded",
  "restart_required": true
}
```

---

### POST /api/config/reset

Reset configuration to defaults.

**Status:** ✅ Implemented

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Configuration reset to defaults",
  "restart_required": true
}
```

---

## Streaming Endpoints

### GET /video_feed

MJPEG video stream.

**Status:** ✅ Implemented

**Response:** `200 OK`
```http
Content-Type: multipart/x-mixed-replace; boundary=frame

--frame
Content-Type: image/jpeg

<binary JPEG data>
--frame
Content-Type: image/jpeg

<binary JPEG data>
--frame
...
```

**HTML Usage:**
```html
<img src="http://localhost:5000/video_feed" alt="Live Feed">
```

**Query Parameters:**
- `quality` (int): JPEG quality 1-100 (default: 85)
- `scale` (float): Scale factor 0.1-1.0 (default: 1.0)
- `effects` (bool): Apply active effects (default: true)

---

### GET /preview

Web UI preview page.

**Status:** ✅ Implemented

**Response:** `200 OK` (HTML page)

Opens a browser page with:
- Live MJPEG video stream
- FPS counter
- Camera controls
- Effect controls
- Configuration panel

---

### WS /socket.io

WebSocket connection for real-time events.

**Status:** ✅ Implemented

**Events:**

**Client → Server:**
- `connect` - Initial connection
- `request_landmarks` - Request landmark data
- `apply_effect` - Apply effect in real-time
- `configure_camera` - Change camera settings

**Server → Client:**
- `status_update` - Periodic status updates
- `landmarks_data` - Landmark stream (if requested)
- `fps_update` - FPS counter updates
- `error` - Error notifications

**JavaScript Example:**
```javascript
const socket = io('http://localhost:5000');

socket.on('connect', () => {
  console.log('Connected to LenzForge backend');
  socket.emit('request_landmarks', {fps: 30});
});

socket.on('landmarks_data', (data) => {
  console.log(`Frame ${data.frame_id}: ${data.landmarks.length} landmarks`);
  // Draw landmarks on canvas
});

socket.on('fps_update', (data) => {
  document.getElementById('fps').textContent = data.fps.toFixed(1);
});
```

---

## Error Handling

### Standard Error Response

All endpoints return errors in this format:

```json
{
  "success": false,
  "error": {
    "code": "CAMERA_NOT_FOUND",
    "message": "Camera with index 5 not found",
    "details": {
      "requested_index": 5,
      "available_cameras": [0, 1]
    },
    "timestamp": "2025-10-29T14:30:00Z"
  }
}
