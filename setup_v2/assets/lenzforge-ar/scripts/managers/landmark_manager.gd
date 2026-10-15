extends Node
## Landmark Processing Manager
## High-performance face landmark tracking from LMK1 ring buffer
## Target: <3ms per frame (1ms process + 2ms render)

signal landmarks_ready(landmarks: Dictionary, timestamp: int)
signal tracking_lost()
signal tracking_resumed()
signal visibility_changed(visible: bool)

# LMK1 Reader (GDExtension)
var lmk1_reader: Node

# Landmark state
var is_running: bool = false
var is_tracking: bool = false
var frame_count: int = 0
var last_frame_id: int = -1

# Landmark data (object pooling)
var face_landmarks: PackedVector2Array = PackedVector2Array()
var iris_left_landmarks: PackedVector2Array = PackedVector2Array()
var iris_right_landmarks: PackedVector2Array = PackedVector2Array()

# Video dimensions (for coordinate transformation)
var video_width: int = 1280  # Fixed: Use actual video resolution from VID1
var video_height: int = 720
var display_size: Vector2 = Vector2(1280, 720)

# Performance tracking
var process_times: Array[float] = []
const PERF_HISTORY_SIZE: int = 60

# Configuration
const RING_BUFFER_NAME: String = "LenzForge_Landmarks"
const FACE_LANDMARK_COUNT: int = 478
const IRIS_LANDMARK_COUNT: int = 5  # Per eye

# Visibility
var landmarks_visible: bool = true

# Smoothing
var enable_smoothing: bool = true
var smoothing_factor: float = 0.7  # 0=no smooth, 1=max smooth
var prev_face_landmarks: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	print("[LandmarkManager] Initializing...")
	
	# Pre-allocate landmark arrays (object pooling)
	_init_landmark_arrays()
	
	# Create LMK1 reader
	if not _init_lmk1_reader():
		push_error("[LandmarkManager] Failed to initialize LMK1 reader!")
		return
	
	# Get video dimensions
	_update_video_dimensions()
	
	is_running = true
	print("[LandmarkManager] Ready - tracking %d face + %d iris landmarks" % [FACE_LANDMARK_COUNT, IRIS_LANDMARK_COUNT * 2])

func _init_landmark_arrays() -> void:
	"""Pre-allocate landmark arrays to avoid per-frame allocation"""
	face_landmarks.resize(FACE_LANDMARK_COUNT)
	iris_left_landmarks.resize(IRIS_LANDMARK_COUNT)
	iris_right_landmarks.resize(IRIS_LANDMARK_COUNT)
	prev_face_landmarks.resize(FACE_LANDMARK_COUNT)
	
	# Initialize to zero
	for i in FACE_LANDMARK_COUNT:
		face_landmarks[i] = Vector2.ZERO
		prev_face_landmarks[i] = Vector2.ZERO
	
	for i in IRIS_LANDMARK_COUNT:
		iris_left_landmarks[i] = Vector2.ZERO
		iris_right_landmarks[i] = Vector2.ZERO

func _init_lmk1_reader() -> bool:
	"""Initialize LMK1 ring buffer reader"""
	# Instantiate LMK1Reader C++ class directly from GDExtension
	lmk1_reader = ClassDB.instantiate("LMK1Reader")
	if not lmk1_reader:
		push_error("[LandmarkManager] Failed to create LMK1Reader instance!")
		return false
	
	lmk1_reader.name = "LMK1Reader"
	add_child(lmk1_reader)
	
	# Connect to signals (LMK1Reader uses SIGNALS, not polling methods!)
	if not lmk1_reader.has_signal("landmarks_ready"):
		push_error("[LandmarkManager] LMK1Reader missing 'landmarks_ready' signal!")
		return false
	
	if not lmk1_reader.has_signal("face_lost"):
		push_error("[LandmarkManager] LMK1Reader missing 'face_lost' signal!")
		return false
	
	lmk1_reader.landmarks_ready.connect(_on_landmarks_ready)
	lmk1_reader.face_lost.connect(_on_face_lost)
	print("[LandmarkManager] Connected to LMK1Reader signals")
	
	# Start reading (opens shared memory automatically)
	if not lmk1_reader.has_method("start_reading"):
		push_error("[LandmarkManager] LMK1Reader missing 'start_reading' method!")
		return false
	
	var success: bool = lmk1_reader.start_reading()
	if not success:
		push_error("[LandmarkManager] Failed to start reading from LMK1 ring buffer")
		push_error("[LandmarkManager] Make sure LenzForge backend is running with MediaPipe!")
		return false
	
	print("[LandmarkManager] Started reading landmarks via signals")
	
	return true

func _update_video_dimensions() -> void:
	"""Get video dimensions from parent video manager"""
	var video_mgr = get_parent().get_node_or_null("VideoManager")
	if video_mgr and video_mgr.has_method("get_stats"):
		var stats = video_mgr.get_stats()
		video_width = stats.get("video_width", 1920)
		video_height = stats.get("video_height", 1080)
		print("[LandmarkManager] Video dimensions: %dx%d" % [video_width, video_height])

func _on_landmarks_ready(landmarks: Array, frame_id: int) -> void:
	"""Signal handler: Called when LMK1Reader has new landmarks (replaces polling)"""
	var start_time: float = Time.get_ticks_usec()
	
	# Skip if same frame
	if frame_id == last_frame_id:
		return
	
	# Get real QPC timestamp from LMK1Reader (for timestamp pairing with video)
	var timestamp: int = lmk1_reader.get_timestamp() if lmk1_reader else frame_id
	
	# Update tracking state
	if not is_tracking:
		is_tracking = true
		tracking_resumed.emit()
		print("[LandmarkManager] Tracking resumed (frame %d, %d landmarks)" % [frame_id, landmarks.size()])
		# Get actual display size from window
		var window_size = get_viewport().get_visible_rect().size
		print("[LandmarkManager] Window size: %dx%d" % [window_size.x, window_size.y])
	
	# Keep landmarks in normalized (0-1) coordinates
	# Let the UI layer handle transformation to display coordinates
	face_landmarks.clear()
	for i in range(min(landmarks.size(), FACE_LANDMARK_COUNT)):
		var lm: Vector3 = landmarks[i]
		# Pass through normalized coordinates (0-1)
		var normalized_pos = Vector2(lm.x, lm.y)
		face_landmarks.append(normalized_pos)
	
	# Apply smoothing if enabled
	if enable_smoothing and frame_count > 0 and prev_face_landmarks.size() == face_landmarks.size():
		for i in face_landmarks.size():
			face_landmarks[i] = face_landmarks[i].lerp(prev_face_landmarks[i], smoothing_factor)
	
	# Store for next frame
	prev_face_landmarks = face_landmarks.duplicate()
	
	# Update state
	last_frame_id = frame_id
	frame_count += 1
	
	# Track performance
	var process_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	_track_performance(process_time)
	
	# Emit landmarks for rendering (but only if visible)
	if landmarks_visible:
		landmarks_ready.emit({
			"frame_id": frame_id,
			"face": face_landmarks,
			"iris_left": iris_left_landmarks,
			"iris_right": iris_right_landmarks,
			"is_tracking": is_tracking
		}, timestamp)

func _on_face_lost() -> void:
	"""Signal handler: Called when face tracking is lost"""
	if is_tracking:
		is_tracking = false
		tracking_lost.emit()
		face_landmarks.clear()
		print("[LandmarkManager] Tracking lost")


func _track_performance(process_time_ms: float) -> void:
	"""Track landmark processing performance"""
	process_times.append(process_time_ms)
	if process_times.size() > PERF_HISTORY_SIZE:
		process_times.pop_front()
	
	# Warn if slow
	if process_time_ms > 3.0:
		push_warning("[LandmarkManager] Slow processing: %.2fms" % process_time_ms)

func set_smoothing(enabled: bool, factor: float = 0.7) -> void:
	"""Configure landmark smoothing"""
	enable_smoothing = enabled
	smoothing_factor = clamp(factor, 0.0, 1.0)
	print("[LandmarkManager] Smoothing: %s (factor: %.2f)" % ["ON" if enabled else "OFF", smoothing_factor])

func set_display_size(size: Vector2) -> void:
	"""Update display size for coordinate transformation"""
	display_size = size
	print("[LandmarkManager] Display size: %dx%d" % [size.x, size.y])

func set_visible(visible: bool) -> void:
	"""Show or hide landmarks (still tracks, just doesn't emit for rendering)"""
	if landmarks_visible != visible:
		landmarks_visible = visible
		visibility_changed.emit(visible)
		print("[LandmarkManager] Landmarks %s" % ("visible" if visible else "hidden"))

func is_visible() -> bool:
	"""Check if landmarks are currently visible"""
	return landmarks_visible

func get_all_landmarks() -> Array:
	"""Get all current landmarks (for external use)"""
	var all_landmarks: Array = []
	for lm in face_landmarks:
		all_landmarks.append(lm)
	return all_landmarks

func get_landmark_position(index: int) -> Vector2:
	"""Get position of specific landmark"""
	if index >= 0 and index < face_landmarks.size():
		return face_landmarks[index]
	return Vector2.ZERO

func stop() -> void:
	"""Clean shutdown"""
	is_running = false
	
	if lmk1_reader:
		if lmk1_reader.has_method("close"):
			lmk1_reader.close()
		lmk1_reader.queue_free()
		lmk1_reader = null
	
	print("[LandmarkManager] Stopped")

func get_average_process_time() -> float:
	"""Get average processing time in milliseconds"""
	if process_times.is_empty():
		return 0.0
	
	var total: float = 0.0
	for pt in process_times:
		total += pt
	return total / process_times.size()

func get_stats() -> Dictionary:
	"""Get landmark processing statistics"""
	return {
		"is_running": is_running,
		"is_tracking": is_tracking,
		"frame_count": frame_count,
		"last_frame_id": last_frame_id,
		"face_landmark_count": FACE_LANDMARK_COUNT,
		"iris_landmark_count": IRIS_LANDMARK_COUNT * 2,
		"avg_process_time_ms": get_average_process_time(),
		"smoothing_enabled": enable_smoothing,
		"smoothing_factor": smoothing_factor
	}
