# LenzForge V2 - Integration Guide

**Version:** 2.0.0  
**Last Updated:** October 29, 2025

Complete integration examples for Godot, Unity, C#, Python, C++, and more.

---

## Table of Contents

1. [Overview](#overview)
2. [Godot Integration](#godot-integration)
3. [Unity Integration](#unity-integration)
4. [Python Integration](#python-integration)
5. [C# Integration](#csharp-integration)
6. [C++ Integration](#cpp-integration)
7. [Web Integration](#web-integration)
8. [OBS Integration](#obs-integration)

---

## Overview

### Integration Methods

LenzForge provides multiple integration points:

1. **Ring Buffer IPC** - Direct shared memory access (highest performance)
2. **REST API** - HTTP endpoints for configuration and control
3. **WebSocket** - Real-time events and streaming
4. **Video Feed** - MJPEG stream for web applications

### Ring Buffers Available

**VID1** - Video Stream:
- Name: `"LenzForge_Video_NV12"`
- Format: NV12 (Y plane + interleaved UV)
- Resolution: 1920×1080 (configurable)
- Frame Rate: 30 FPS (configurable)
- Latency: <5ms

**LMK1** - Face Landmarks:
- Name: `"LenzForge_Landmarks_NV12"`  
- Format: Float32 array (normalized 0-1)
- Landmarks: 478 face + 10 iris = 488 points
- Frame Rate: 30 FPS
- Latency: <1ms

---

## Godot Integration

### Method 1: Using GDExtension (Recommended)

**Advantages**:
- Highest performance (C++ native)
- Automatic NV12 decoding
- Signal-based architecture
- Zero-copy texture creation

#### Installation

1. Copy GDExtension to your project:
```
your_project/
└── addons/
    └── lenzforge/
        ├── lenzforge.gdextension
        └── bin/
            ├── lenzforge.windows.template_release.x86_64.dll
            ├── libgcc_s_seh-1.dll
            ├── libstdc++-6.dll
            └── libwinpthread-1.dll
```

2. Enable plugin in Project Settings

#### Basic Usage

```gdscript
extends Node

var vid1_reader: VID1Reader
var lmk1_reader: LMK1Reader

var video_display: TextureRect

func _ready():
    # Create display
    video_display = TextureRect.new()
    add_child(video_display)
    
    # Create readers
    vid1_reader = VID1Reader.new()
    lmk1_reader = LMK1Reader.new()
    add_child(vid1_reader)
    add_child(lmk1_reader)
    
    # Start reading
    if not vid1_reader.start_reading():
        push_error("Failed to connect to video stream!")
        return
    
    if not lmk1_reader.start_reading():
        push_error("Failed to connect to landmark stream!")
        return
    
    # Connect signal
    vid1_reader.frame_ready.connect(_on_frame_ready)
    
    print("Video: %dx%d @ %d FPS" % [
        vid1_reader.get_width(),
        vid1_reader.get_height(),
        vid1_reader.get_fps()
    ])

func _on_frame_ready(texture: ImageTexture, frame_id: int):
    # Display video
    video_display.texture = texture
    
    # Get landmarks if face detected
    if lmk1_reader.has_face():
        var landmarks = lmk1_reader.get_landmarks()
        _draw_face_mesh(landmarks)

func _draw_face_mesh(landmarks: Array):
    # landmarks is Array of Vector3
    # x, y are normalized [0, 1]
    # z is depth (relative)
    
    for lm in landmarks:
        var screen_pos = Vector2(
            lm.x * vid1_reader.get_width(),
            lm.y * vid1_reader.get_height()
        )
        # Draw landmark at screen_pos
        draw_circle(screen_pos, 2, Color.GREEN)
```

#### Advanced: Custom AR Effects

```gdscript
extends Node2D

var vid1_reader: VID1Reader
var lmk1_reader: LMK1Reader

# Virtual objects
var face_mask: Sprite2D
var glasses: Sprite2D
var hat: Sprite2D

func _ready():
    _setup_readers()
    _setup_virtual_objects()
    
    vid1_reader.frame_ready.connect(_on_frame_ready)

func _on_frame_ready(texture: ImageTexture, frame_id: int):
    # Update background
    $Background.texture = texture
    
    # Get face landmarks
    if not lmk1_reader.has_face():
        _hide_virtual_objects()
        return
    
    var landmarks = lmk1_reader.get_landmarks()
    _show_virtual_objects()
    
    # Position virtual objects based on landmarks
    _position_glasses(landmarks)
    _position_hat(landmarks)
    _position_mask(landmarks)

func _position_glasses(landmarks: Array):
    # Get eye positions (MediaPipe indices)
    var left_eye = _get_eye_center(landmarks, true)
    var right_eye = _get_eye_center(landmarks, false)
    
    # Calculate glasses position & rotation
    var center = (left_eye + right_eye) / 2.0
    var angle = atan2(right_eye.y - left_eye.y, 
                      right_eye.x - left_eye.x)
    var distance = left_eye.distance_to(right_eye)
    
    # Apply transform
    glasses.position = center
    glasses.rotation = angle
    glasses.scale = Vector2.ONE * (distance / 100.0)

func _get_eye_center(landmarks: Array, is_left: bool) -> Vector2:
    # MediaPipe eye landmark indices
    var eye_indices = [33, 133, 160, 144, 158, 153] if is_left \
                 else [362, 263, 387, 373, 385, 380]
    
    var sum = Vector2.ZERO
    for idx in eye_indices:
        var lm = landmarks[idx]
        sum += Vector2(
            lm.x * vid1_reader.get_width(),
            lm.y * vid1_reader.get_height()
        )
    return sum / eye_indices.size()
```

### Method 2: Using GDScript Only

**Advantages**:
- No compilation needed
- Easier to modify
- Good for prototyping

**Disadvantages**:
- Lower performance
- Manual NV12 decoding
- No direct shared memory access

```gdscript
extends Node

var http_client: HTTPRequest

func _ready():
    http_client = HTTPRequest.new()
    add_child(http_client)
    http_client.request_completed.connect(_on_request_completed)
    
    # Connect to REST API
    _fetch_frame()

func _fetch_frame():
    http_client.request("http://localhost:5000/api/video/latest")

func _on_request_completed(result, response_code, headers, body):
    if response_code == 200:
        var json = JSON.parse_string(body.get_string_from_utf8())
        
        # Get frame data (base64 encoded)
        var image_data = Marshalls.base64_to_raw(json.frame_data)
        var image = Image.new()
        image.load_png_from_buffer(image_data)
        
        var texture = ImageTexture.create_from_image(image)
        $Display.texture = texture
        
        # Get landmarks
        if json.has("landmarks"):
            _draw_landmarks(json.landmarks)
    
    # Fetch next frame
    await get_tree().create_timer(0.033).timeout  # ~30 FPS
    _fetch_frame()
```

---

## Unity Integration

### Using C# Ring Buffer Reader

#### 1. Create Ring Buffer Interface

```csharp
// RingBufferReader.cs
using System;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;
using UnityEngine;

public class RingBufferReader : IDisposable
{
    private MemoryMappedFile mmf;
    private MemoryMappedViewAccessor accessor;
    
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RingHeader
    {
        public uint magic;
        public uint version;
        public uint width;
        public uint height;
        public uint wr_seq;
        public uint slot_count;
        public uint slot_stride;
        public uint y_stride;
        public uint uv_stride;
    }
    
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SlotHeader
    {
        public uint valid;
        public uint frame_id;
        public ulong timestamp;
    }
    
    public RingHeader Header { get; private set; }
    private uint lastFrameId = 0;
    
    public bool Open(string name)
    {
        try
        {
            mmf = MemoryMappedFile.OpenExisting(name);
            accessor = mmf.CreateViewAccessor();
            
            // Read header
            accessor.Read(0, out RingHeader header);
            Header = header;
            
            Debug.Log($"Opened ring buffer: {name} ({header.width}x{header.height})");
            return true;
        }
        catch (Exception e)
        {
            Debug.LogError($"Failed to open ring buffer: {e.Message}");
            return false;
        }
    }
    
    public byte[] ReadLatestFrame()
    {
        if (accessor == null) return null;
        
        // Read write sequence
        uint wr_seq = accessor.ReadUInt32(16); // Offset of wr_seq in header
        if (wr_seq == 0) return null;
        
        // Calculate slot
        uint slot_idx = (wr_seq - 1) % Header.slot_count;
        long slot_offset = 256 + slot_idx * Header.slot_stride;
        
        // Read slot header
        accessor.Read(slot_offset, out SlotHeader slot);
        
        // Check validity
        if (slot.valid == 0 || slot.frame_id == lastFrameId)
            return null;
        
        // Read frame data
        long data_offset = slot_offset + 64; // Slot header size
        int data_size = (int)(Header.width * Header.height * 3 / 2); // NV12
        
        byte[] data = new byte[data_size];
        accessor.ReadArray(data_offset, data, 0, data_size);
        
        lastFrameId = slot.frame_id;
        return data;
    }
    
    public void Dispose()
    {
        accessor?.Dispose();
        mmf?.Dispose();
    }
}
```

#### 2. Create Video Player Component

```csharp
// LenzForgeVideoPlayer.cs
using UnityEngine;

public class LenzForgeVideoPlayer : MonoBehaviour
{
    private RingBufferReader videoReader;
    private RingBufferReader landmarkReader;
    
    private Texture2D videoTexture;
    private Material displayMaterial;
    
    [SerializeField] private Renderer videoDisplay;
    [SerializeField] private bool showLandmarks = true;
    
    void Start()
    {
        // Open video ring buffer
        videoReader = new RingBufferReader();
        if (!videoReader.Open("LenzForge_Video_NV12"))
        {
            Debug.LogError("Failed to open video ring buffer!");
            return;
        }
        
        // Open landmark ring buffer
        landmarkReader = new RingBufferReader();
        landmarkReader.Open("LenzForge_Landmarks_NV12");
        
        // Create texture
        videoTexture = new Texture2D(
            (int)videoReader.Header.width,
            (int)videoReader.Header.height,
            TextureFormat.RGB24,
            false
        );
        
        // Apply to material
        displayMaterial = videoDisplay.material;
        displayMaterial.mainTexture = videoTexture;
    }
    
    void Update()
    {
        // Read latest frame
        byte[] frameData = videoReader.ReadLatestFrame();
        if (frameData == null) return;
        
        // Convert NV12 to RGB
        ConvertNV12ToRGB(frameData, videoTexture);
        videoTexture.Apply();
        
        // Read landmarks
        if (showLandmarks)
        {
            byte[] landmarkData = landmarkReader.ReadLatestFrame();
            if (landmarkData != null)
            {
                DrawLandmarks(landmarkData);
            }
        }
    }
    
    void ConvertNV12ToRGB(byte[] nv12, Texture2D texture)
    {
        int width = texture.width;
        int height = texture.height;
        
        Color[] pixels = new Color[width * height];
        
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                int yIndex = y * width + x;
                int uvIndex = (y / 2) * width + (x / 2) * 2;
                int uvOffset = width * height;
                
                byte Y = nv12[yIndex];
                byte U = nv12[uvOffset + uvIndex];
                byte V = nv12[uvOffset + uvIndex + 1];
                
                // YUV to RGB conversion
                int C = Y - 16;
                int D = U - 128;
                int E = V - 128;
                
                int R = Mathf.Clamp((298 * C + 409 * E + 128) >> 8, 0, 255);
                int G = Mathf.Clamp((298 * C - 100 * D - 208 * E + 128) >> 8, 0, 255);
                int B = Mathf.Clamp((298 * C + 516 * D + 128) >> 8, 0, 255);
                
                pixels[y * width + x] = new Color(R / 255f, G / 255f, B / 255f);
            }
        }
        
        texture.SetPixels(pixels);
    }
    
    void DrawLandmarks(byte[] landmarkData)
    {
        // Parse landmarks (488 points × 2 floats × 4 bytes)
        int landmarkCount = landmarkData.Length / 8;
        
        for (int i = 0; i < landmarkCount; i++)
        {
            float x = BitConverter.ToSingle(landmarkData, i * 8);
            float y = BitConverter.ToSingle(landmarkData, i * 8 + 4);
            
            // Convert normalized to screen space
            Vector3 screenPos = new Vector3(
                x * videoTexture.width,
                y * videoTexture.height,
                0
            );
            
            // Draw debug sphere
            Debug.DrawLine(screenPos, screenPos + Vector3.up * 2, Color.green);
        }
    }
    
    void OnDestroy()
    {
        videoReader?.Dispose();
        landmarkReader?.Dispose();
    }
}
```

#### 3. AR Face Filter Example

```csharp
// FaceFilter.cs
using UnityEngine;
using System;

public class FaceFilter : MonoBehaviour
{
    [SerializeField] private GameObject glassesPrefab;
    [SerializeField] private GameObject hatPrefab;
    
    private RingBufferReader landmarkReader;
    private GameObject glassesInstance;
    private GameObject hatInstance;
    
    // MediaPipe landmark indices
    private readonly int[] leftEyeIndices = { 33, 133, 160, 144, 158, 153 };
    private readonly int[] rightEyeIndices = { 362, 263, 387, 373, 385, 380 };
    private readonly int[] noseIndices = { 1, 2, 98, 327 };
    
    void Start()
    {
        landmarkReader = new RingBufferReader();
        if (!landmarkReader.Open("LenzForge_Landmarks_NV12"))
        {
            Debug.LogError("Failed to open landmark buffer!");
            return;
        }
        
        glassesInstance = Instantiate(glassesPrefab, transform);
        hatInstance = Instantiate(hatPrefab, transform);
    }
    
    void Update()
    {
        byte[] data = landmarkReader.ReadLatestFrame();
        if (data == null)
        {
            HideObjects();
            return;
        }
        
        Vector2[] landmarks = ParseLandmarks(data);
        PositionGlasses(landmarks);
        PositionHat(landmarks);
    }
    
    Vector2[] ParseLandmarks(byte[] data)
    {
        int count = data.Length / 8;
        Vector2[] landmarks = new Vector2[count];
        
        for (int i = 0; i < count; i++)
        {
            landmarks[i] = new Vector2(
                BitConverter.ToSingle(data, i * 8),
                BitConverter.ToSingle(data, i * 8 + 4)
            );
        }
        
        return landmarks;
    }
    
    void PositionGlasses(Vector2[] landmarks)
    {
        // Calculate eye centers
        Vector2 leftEye = GetAveragePosition(landmarks, leftEyeIndices);
        Vector2 rightEye = GetAveragePosition(landmarks, rightEyeIndices);
        
        // Position & scale glasses
        Vector2 center = (leftEye + rightEye) / 2f;
        float distance = Vector2.Distance(leftEye, rightEye);
        float angle = Mathf.Atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x);
        
        glassesInstance.transform.localPosition = new Vector3(center.x, center.y, 0);
        glassesInstance.transform.localRotation = Quaternion.Euler(0, 0, angle * Mathf.Rad2Deg);
        glassesInstance.transform.localScale = Vector3.one * distance;
        
        glassesInstance.SetActive(true);
    }
    
    void PositionHat(Vector2[] landmarks)
    {
        // Get forehead position (top of nose bridge)
        Vector2 foreheadPos = GetAveragePosition(landmarks, noseIndices);
        foreheadPos.y -= 0.15f; // Offset up
        
        hatInstance.transform.localPosition = new Vector3(foreheadPos.x, foreheadPos.y, 0);
        hatInstance.SetActive(true);
    }
    
    Vector2 GetAveragePosition(Vector2[] landmarks, int[] indices)
    {
        Vector2 sum = Vector2.zero;
        foreach (int idx in indices)
        {
            sum += landmarks[idx];
        }
        return sum / indices.Length;
    }
    
    void HideObjects()
    {
        glassesInstance.SetActive(false);
        hatInstance.SetActive(false);
    }
    
    void OnDestroy()
    {
        landmarkReader?.Dispose();
    }
}
```

---

## Python Integration

### Direct Ring Buffer Access

```python
# lenzforge_client.py
import mmap
import struct
import numpy as np
from typing import Optional, Tuple

class VID1Reader:
    """Read video frames from VID1 ring buffer"""
    
    HEADER_SIZE = 256
    SLOT_HEADER_SIZE = 64
    MAGIC = 0x56494431  # "VID1"
    
    def __init__(self):
        self.mapping = None
        self.width = 0
        self.height = 0
        self.slot_count = 0
        self.slot_stride = 0
        self.y_stride = 0
        self.uv_stride = 0
        self.last_frame_id = 0
    
    def open(self, name: str = "LenzForge_Video_NV12") -> bool:
        """Open shared memory ring buffer"""
        try:
            # Open memory-mapped file
            self.mapping = mmap.mmap(-1, 0, name)
            
            # Read header
            header = self.mapping[:self.HEADER_SIZE]
            magic, version, self.width, self.height, _, self.slot_count, \
            self.slot_stride, self.y_stride, self.uv_stride = \
                struct.unpack('<9I', header[:36])
            
            if magic != self.MAGIC:
                raise ValueError(f"Invalid magic: {hex(magic)}")
            
            print(f"Opened VID1: {self.width}x{self.height}, {self.slot_count} slots")
            return True
            
        except Exception as e:
            print(f"Failed to open VID1: {e}")
            return False
    
    def read_latest(self) -> Optional[Tuple[np.ndarray, int, int]]:
        """Read latest frame
        
        Returns:
            (nv12_data, frame_id, timestamp) or None
        """
        if not self.mapping:
            return None
        
        # Read write sequence
        wr_seq = struct.unpack('<I', self.mapping[16:20])[0]
        if wr_seq == 0:
            return None
        
        # Calculate slot
        slot_idx = (wr_seq - 1) % self.slot_count
        slot_offset = self.HEADER_SIZE + slot_idx * self.slot_stride
        
        # Read slot header
        slot_header = self.mapping[slot_offset:slot_offset + self.SLOT_HEADER_SIZE]
        valid, frame_id, timestamp = struct.unpack('<IIQ', slot_header[:16])
        
        # Check validity
        if valid == 0 or frame_id == self.last_frame_id:
            return None
        
        # Read frame data
        data_offset = slot_offset + self.SLOT_HEADER_SIZE
        data_size = self.width * self.height * 3 // 2  # NV12 format
        
        nv12_data = np.frombuffer(
            self.mapping[data_offset:data_offset + data_size],
            dtype=np.uint8
        ).copy()
        
        self.last_frame_id = frame_id
        return nv12_data, frame_id, timestamp
    
    def nv12_to_bgr(self, nv12_data: np.ndarray) -> np.ndarray:
        """Convert NV12 to BGR format"""
        import cv2
        
        # Reshape NV12 data
        nv12 = nv12_data.reshape((self.height * 3 // 2, self.width))
        
        # Convert to BGR
        bgr = cv2.cvtColor(nv12, cv2.COLOR_YUV2BGR_NV12)
        
        return bgr
    
    def close(self):
        """Close ring buffer"""
        if self.mapping:
            self.mapping.close()
            self.mapping = None


class LMK1Reader:
    """Read face landmarks from LMK1 ring buffer"""
    
    HEADER_SIZE = 256
    SLOT_HEADER_SIZE = 64
    MAGIC = 0x4C4D4B31  # "LMK1"
    LANDMARK_COUNT = 488  # 478 face + 10 iris
    
    def __init__(self):
        self.mapping = None
        self.last_frame_id = 0
    
    def open(self, name: str = "LenzForge_Landmarks_NV12") -> bool:
        """Open shared memory ring buffer"""
        try:
            self.mapping = mmap.mmap(-1, 0, name)
            
            # Read header
            header = self.mapping[:self.HEADER_SIZE]
            magic, version = struct.unpack('<2I', header[:8])
            
            if magic != self.MAGIC:
                raise ValueError(f"Invalid magic: {hex(magic)}")
            
            print(f"Opened LMK1: {self.LANDMARK_COUNT} landmarks")
            return True
            
        except Exception as e:
            print(f"Failed to open LMK1: {e}")
            return False
    
    def read_latest(self) -> Optional[Tuple[np.ndarray, int, bool]]:
        """Read latest landmarks
        
        Returns:
            (landmarks, frame_id, has_face) or None
            landmarks: (N, 2) array of normalized coordinates
        """
        if not self.mapping:
            return None
        
        # Read write sequence
        wr_seq = struct.unpack('<I', self.mapping[16:20])[0]
        if wr_seq == 0:
            return None
        
        # Read slot count from header
        slot_count = struct.unpack('<I', self.mapping[20:24])[0]
        slot_stride = struct.unpack('<I', self.mapping[24:28])[0]
        
        # Calculate slot
        slot_idx = (wr_seq - 1) % slot_count
        slot_offset = self.HEADER_SIZE + slot_idx * slot_stride
        
        # Read slot header
        slot_header = self.mapping[slot_offset:slot_offset + self.SLOT_HEADER_SIZE]
        valid, frame_id, timestamp, has_face = struct.unpack('<IIQI', slot_header[:20])
        
        # Check validity
        if valid == 0 or frame_id == self.last_frame_id:
            return None
        
        # Read landmark data
        data_offset = slot_offset + self.SLOT_HEADER_SIZE
        data_size = self.LANDMARK_COUNT * 2 * 4  # 488 points × 2 coords × 4 bytes
        
        landmarks_flat = np.frombuffer(
            self.mapping[data_offset:data_offset + data_size],
            dtype=np.float32
        ).copy()
        
        landmarks = landmarks_flat.reshape((self.LANDMARK_COUNT, 2))
        
        self.last_frame_id = frame_id
        return landmarks, frame_id, bool(has_face)
    
    def close(self):
        """Close ring buffer"""
        if self.mapping:
            self.mapping.close()
            self.mapping = None


# Example usage
if __name__ == "__main__":
    import cv2
    
    # Create readers
    vid_reader = VID1Reader()
    lmk_reader = LMK1Reader()
    
    # Open buffers
    if not vid_reader.open():
        print("Make sure LenzForge backend is running!")
        exit(1)
    
    lmk_reader.open()
    
    print("Reading frames... Press 'q' to quit")
    
    try:
        while True:
            # Read video
            frame_data = vid_reader.read_latest()
            if frame_data:
                nv12_data, frame_id, timestamp = frame_data
                
                # Convert to BGR
                bgr = vid_reader.nv12_to_bgr(nv12_data)
                
                # Read landmarks
                lmk_data = lmk_reader.read_latest()
                if lmk_data:
                    landmarks, _, has_face = lmk_data
                    
                    if has_face:
                        # Draw landmarks
                        height, width = bgr.shape[:2]
                        for lm in landmarks:
                            x = int(lm[0] * width)
                            y = int(lm[1] * height)
                            cv2.circle(bgr, (x, y), 1, (0, 255, 0), -1)
                
                # Display
                cv2.imshow("LenzForge - Python", bgr)
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    
    finally:
        vid_reader.close()
        lmk_reader.close()
        cv2.destroyAllWindows()
```

### Using REST API

```python
# lenzforge_api_client.py
import requests
import json
from typing import Dict, List, Optional

class LenzForgeAPI:
    """Client for LenzForge REST API"""
    
    def __init__(self, base_url: str = "http://localhost:5000"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def get_status(self) -> Dict:
        """Get backend status"""
        response = self.session.get(f"{self.base_url}/api/status")
        return response.json()
    
    def get_stats(self) -> Dict:
        """Get performance statistics"""
        response = self.session.get(f"{self.base_url}/api/stats")
        return response.json()
    
    def list_cameras(self) -> List[Dict]:
        """List available cameras"""
        response = self.session.get(f"{self.base_url}/api/cameras")
        return response.json()
    
    def select_camera(self, camera_index: int) -> bool:
        """Select camera by index"""
        response = self.session.post(
            f"{self.base_url}/api/camera/select",
            json={"camera_index": camera_index}
        )
        return response.status_code == 200
    
    def configure_camera(self, width: int, height: int, fps: int) -> bool:
        """Configure camera settings"""
        response = self.session.post(
            f"{self.base_url}/api/camera/configure",
            json={
                "width": width,
                "height": height,
                "fps": fps
            }
        )
        return response.status_code == 200
    
    def list_effects(self) -> Dict:
        """List all available effects"""
        response = self.session.get(f"{self.base_url}/api/effects")
        return response.json()
    
    def apply_effect(self, effect_name: str, params: Optional[Dict] = None) -> bool:
        """Apply an effect"""
        response = self.session.post(
            f"{self.base_url}/api/effects/apply",
            json={
                "effect": effect_name,
                "params": params or {}
            }
        )
        return response.status_code == 200
    
    def clear_effects(self) -> bool:
        """Clear all effects"""
        response = self.session.post(f"{self.base_url}/api/effects/clear")
        return response.status_code == 200


# Example usage
if __name__ == "__main__":
    client = LenzForgeAPI()
