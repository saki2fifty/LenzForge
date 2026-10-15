"""
Video Streaming Routes
Provides real-time video feed with landmark overlay
"""
import cv2
import numpy as np
from flask import Blueprint, Response, render_template, jsonify
import time
import logging
from pipeline.performance_config import get_performance_config

streaming_bp = Blueprint('streaming', __name__)
logger = logging.getLogger(__name__)

# Global state (will be managed by pipeline)
_active_camera = None
_landmark_data = None
_last_frame_time = 0
_fps = 0
_processor = None
_active_effects = []  # Will be shared with effects.py

def set_camera_source(camera):
    """Set the active camera source for streaming"""
    global _active_camera, _processor
    _active_camera = camera
    
    # Initialize processor if camera is set and not already initialized
    if camera is not None and _processor is None:
        try:
            from pipeline.web_processor import WebProcessor
            _processor = WebProcessor()
            # Enable face tracking by default
            _processor.enable_tracking('face', True)
            logger.info("WebProcessor initialized with face tracking enabled")
        except Exception as e:
            logger.error(f"Failed to initialize WebProcessor: {e}")

def set_landmark_data(landmarks):
    """Set the latest landmark data for overlay"""
    global _landmark_data
    _landmark_data = landmarks

def get_processor():
    """Get the MediaPipe processor instance"""
    return _processor

def set_processor(processor):
    """Set the MediaPipe processor instance"""
    global _processor
    _processor = processor

def generate_frames():
    """Generate frames for MJPEG streaming with landmark overlay"""
    global _last_frame_time, _fps
    frame_count = 0
    fps_start_time = time.time()
    last_yield_time = 0
    
    # Get performance config
    perf_config = get_performance_config()
    
    while True:
        if _active_camera is None:
            # No camera active, send blank frame
            blank = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(blank, "No Camera Active", (200, 240),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
            
            ret, buffer = cv2.imencode('.jpg', blank)
            if ret:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
            time.sleep(0.1)
            continue
        
        # Read frame from camera
        ret, frame = _active_camera.read()
        if not ret or frame is None:
            logger.warning("Failed to read frame from camera")
            time.sleep(0.033)  # ~30 FPS
            continue
        
        # Apply effects BEFORE processing
        if _active_effects:
            for effect in _active_effects:
                if effect.is_enabled():
                    try:
                        frame = effect.apply(frame)
                    except Exception as e:
                        logger.error(f"Effect {effect.__class__.__name__} error: {e}")
        
        # Process frame through MediaPipe if processor is available
        if _processor is not None:
            try:
                landmarks = _processor.process(frame)
                if landmarks:
                    frame = overlay_landmarks(frame, landmarks)
            except Exception as e:
                logger.error(f"MediaPipe processing error: {e}")
        
        # Fallback: use manually set landmark data if available
        elif _landmark_data is not None:
            frame = overlay_landmarks(frame, _landmark_data)
        
        # Calculate FPS
        frame_count += 1
        if frame_count >= 10:
            current_time = time.time()
            elapsed = current_time - fps_start_time
            if elapsed > 0:
                _fps = frame_count / elapsed
            frame_count = 0
            fps_start_time = current_time
        
        # FPS throttling - limit preview stream to configured FPS
        current_time = time.time()
        min_frame_interval = 1.0 / perf_config.preview_max_fps
        time_since_last_yield = current_time - last_yield_time
        
        if time_since_last_yield < min_frame_interval:
            # Skip this frame to maintain target FPS
            time.sleep(0.001)  # Small sleep to prevent busy loop
            continue
        
        # Preview scaling - downscale before JPEG encoding
        preview_w, preview_h = perf_config.get_preview_resolution(frame.shape[1], frame.shape[0])
        if preview_w != frame.shape[1] or preview_h != frame.shape[0]:
            display_frame = cv2.resize(frame, (preview_w, preview_h), interpolation=cv2.INTER_LINEAR)
        else:
            display_frame = frame
        
        # Add FPS overlay (scale text size for smaller previews)
        text_scale = preview_w / 640.0
        cv2.putText(display_frame, f"FPS: {_fps:.1f}", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7 * text_scale, (0, 255, 0), 2)
        
        # Encode frame as JPEG with configurable quality
        ret, buffer = cv2.imencode('.jpg', display_frame, 
                                   [cv2.IMWRITE_JPEG_QUALITY, perf_config.preview_quality])
        if not ret:
            logger.warning("Failed to encode frame")
            continue
        
        # Yield frame in MJPEG format
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
        
        last_yield_time = current_time
        
        _last_frame_time = time.time()

def overlay_landmarks(frame, landmark_data):
    """Overlay landmarks on frame"""
    if not landmark_data:
        return frame
    
    h, w = frame.shape[:2]
    
    # Draw face mesh landmarks
    if 'face' in landmark_data and landmark_data['face']:
        for lm in landmark_data['face']:
            x = int(lm['x'] * w)
            y = int(lm['y'] * h)
            
            # Color based on confidence
            confidence = lm.get('confidence', 1.0)
            if confidence > 0.8:
                color = (0, 255, 0)  # Green for high confidence
            elif confidence > 0.5:
                color = (0, 255, 255)  # Yellow for medium
            else:
                color = (0, 0, 255)  # Red for low
            
            cv2.circle(frame, (x, y), 1, color, -1)
    
    # Draw iris landmarks
    if 'iris' in landmark_data:
        for eye_name in ['left', 'right']:
            if eye_name in landmark_data['iris']:
                iris = landmark_data['iris'][eye_name]
                if iris:
                    for lm in iris:
                        x = int(lm['x'] * w)
                        y = int(lm['y'] * h)
                        cv2.circle(frame, (x, y), 2, (255, 0, 255), -1)  # Magenta
    
    # Draw hand landmarks
    if 'hands' in landmark_data:
        for hand_name in ['left', 'right']:
            if hand_name in landmark_data['hands']:
                hand = landmark_data['hands'][hand_name]
                if hand:
                    # Draw connections
                    connections = get_hand_connections()
                    for start_idx, end_idx in connections:
                        if start_idx < len(hand) and end_idx < len(hand):
                            start = hand[start_idx]
                            end = hand[end_idx]
                            x1, y1 = int(start['x'] * w), int(start['y'] * h)
                            x2, y2 = int(end['x'] * w), int(end['y'] * h)
                            cv2.line(frame, (x1, y1), (x2, y2), (0, 255, 255), 2)
                    
                    # Draw landmarks
                    for lm in hand:
                        x = int(lm['x'] * w)
                        y = int(lm['y'] * h)
                        cv2.circle(frame, (x, y), 3, (255, 255, 0), -1)
    
    # Draw pose landmarks
    if 'pose' in landmark_data and landmark_data['pose']:
        # Draw connections
        connections = get_pose_connections()
        for start_idx, end_idx in connections:
            if start_idx < len(landmark_data['pose']) and end_idx < len(landmark_data['pose']):
                start = landmark_data['pose'][start_idx]
                end = landmark_data['pose'][end_idx]
                
                # Only draw if both visible
                if start.get('visibility', 0) > 0.5 and end.get('visibility', 0) > 0.5:
                    x1, y1 = int(start['x'] * w), int(start['y'] * h)
                    x2, y2 = int(end['x'] * w), int(end['y'] * h)
                    cv2.line(frame, (x1, y1), (x2, y2), (255, 0, 0), 2)
        
        # Draw landmarks
        for lm in landmark_data['pose']:
            if lm.get('visibility', 0) > 0.5:
                x = int(lm['x'] * w)
                y = int(lm['y'] * h)
                cv2.circle(frame, (x, y), 3, (0, 165, 255), -1)  # Orange
    
    return frame

def get_hand_connections():
    """Get hand landmark connections for drawing skeleton"""
    return [
        # Thumb
        (0, 1), (1, 2), (2, 3), (3, 4),
        # Index finger
        (0, 5), (5, 6), (6, 7), (7, 8),
        # Middle finger
        (0, 9), (9, 10), (10, 11), (11, 12),
        # Ring finger
        (0, 13), (13, 14), (14, 15), (15, 16),
        # Pinky
        (0, 17), (17, 18), (18, 19), (19, 20),
        # Palm
        (5, 9), (9, 13), (13, 17)
    ]

def get_pose_connections():
    """Get pose landmark connections for drawing skeleton"""
    return [
        # Face
        (0, 1), (1, 2), (2, 3), (3, 7),
        (0, 4), (4, 5), (5, 6), (6, 8),
        # Torso
        (9, 10),
        (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
        (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
        (11, 23), (12, 24), (23, 24),
        # Legs
        (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
        (24, 26), (26, 28), (28, 30), (28, 32), (30, 32)
    ]

@streaming_bp.route('/video_feed')
def video_feed():
    """Video streaming route - returns MJPEG stream"""
    return Response(generate_frames(),
                   mimetype='multipart/x-mixed-replace; boundary=frame')

@streaming_bp.route('/viewer')
def viewer():
    """Video viewer page"""
    return render_template('viewer.html')

@streaming_bp.route('/stream_stats')
def stream_stats():
    """Get streaming statistics including system metrics, camera stats, and ring buffer info"""
    import psutil
    
    # System metrics
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory = psutil.virtual_memory()
    memory_mb = memory.used / (1024 * 1024)
    
    # Camera/stream metrics
    frame_time = 0
    latency = 0
    drop_rate = 0
    width = 0
    height = 0
    
    if _active_camera is not None:
        # Get camera resolution
        width = getattr(_active_camera, 'width', 0)
        height = getattr(_active_camera, 'height', 0)
        
        # Calculate frame time from FPS
        if _fps > 0:
            frame_time = (1000.0 / _fps)  # ms per frame
        
        # Get camera stats if available
        if hasattr(_active_camera, 'get_stats'):
            try:
                cam_stats = _active_camera.get_stats()
                drop_rate = cam_stats.get('drop_rate', 0)
                latency = cam_stats.get('latency', 0)
            except:
                pass
        
        # Try to get ring buffer stats
        if hasattr(_active_camera, 'ring_writer'):
            try:
                ring_stats = _active_camera.ring_writer.get_stats()
                # Calculate latency from write sequence if available
                if 'wr_seq' in ring_stats:
                    # Rough estimate: dropped frames as a percentage
                    wr_seq = ring_stats.get('wr_seq', 0)
                    if wr_seq > 100:  # Only after some frames
                        # This is a simple estimate
                        pass
            except:
                pass
    
    # MediaPipe stats
    mediapipe_fps = 0
    face_detected = False
    landmark_count = 0
    
    if _processor is not None:
        try:
            if hasattr(_processor, 'get_stats'):
                mp_stats = _processor.get_stats()
                mediapipe_fps = mp_stats.get('fps', 0)
                face_detected = mp_stats.get('face_detected', False)
                landmark_count = mp_stats.get('landmark_count', 0)
        except:
            pass
    
    # Check if we have landmark data
    if _landmark_data:
        if 'face' in _landmark_data and _landmark_data['face']:
            face_detected = True
            landmark_count = len(_landmark_data['face'])
    
    return jsonify({
        # Stream stats
        'fps': round(_fps, 1),
        'active': _active_camera is not None,
        'landmarks': _landmark_data is not None,
        'last_frame': _last_frame_time,
        'width': width,
        'height': height,
        
        # System stats (for performance card)
        'cpu': round(cpu_percent, 1),
        'memory': round(memory_mb, 1),
        'frame_time': round(frame_time, 1),
        'latency': round(latency, 0),
        'drop_rate': round(drop_rate, 2),
        
        # MediaPipe stats
        'mediapipe_fps': round(mediapipe_fps, 1),
        'face_detected': face_detected,
        'landmark_count': landmark_count
    })
