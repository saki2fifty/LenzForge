extends Node
## GPU Compositor Manager
## Pairs video frames with landmarks by timestamp
## Renders using GPU shader for perfect synchronization
## Includes G-H predictor for smooth tracking

signal frame_composited(frame_id: int)

# Dependencies
var video_manager: Node
var landmark_manager: Node

# GPU Shader rendering
var shader_material: ShaderMaterial
var video_sprite: Sprite2D

# Frame ID pairing (both video and landmarks use frame_id)
const FRAME_ID_TOLERANCE: int = 2  # Match within 2 frames
var last_video_frame_id: int = 0
var last_landmark_frame_id: int = 0

# Landmark cache for pairing
var cached_landmarks: PackedVector2Array = []
var cached_landmark_timestamp: int = 0

# G-H Predictor state (per-landmark smoothing)
var predicted_landmarks: PackedVector2Array = []
var landmark_velocities: PackedVector2Array = []
const G_GAIN: float = 0.85  # Tracking gain
const H_GAIN: float = 0.25  # Smoothing gain
var predictor_initialized: bool = false

# Performance tracking
var frame_count: int = 0
var pairing_misses: int = 0
var prediction_time_ms: float = 0.0

# Retry mechanism for signal connections
var connection_retry_timer: Timer
var video_connection_established: bool = false
var landmark_connection_established: bool = false

func _ready() -> void:
	print("[GPUCompositor] Initializing GPU-accelerated compositor...")
	
	# Find dependencies
	if not _find_dependencies():
		push_error("[GPUCompositor] Failed to find required managers!")
		return
	
	# Load shader
	if not _init_shader():
		push_error("[GPUCompositor] Failed to initialize GPU shader!")
		return
	
	# Connect signals
	_connect_signals()
	
	print("[GPUCompositor] Ready - GPU compositor active")

func _find_dependencies() -> bool:
	"""Find VideoManager and LandmarkManager"""
	# Debug: print parent and sibling nodes
	var parent = get_parent()
	if parent:
		print("[GPUCompositor] Parent node: ", parent.name)
		print("[GPUCompositor] Parent's children:")
		for child in parent.get_children():
			print("  - ", child.name, " (type: ", child.get_class(), ")")
	
	video_manager = get_node_or_null("../VideoManager")
	landmark_manager = get_node_or_null("../LandmarkManager")
	
	if not video_manager:
		push_error("[GPUCompositor] VideoManager not found!")
		return false
	
	if not landmark_manager:
		push_error("[GPUCompositor] LandmarkManager not found!")
		return false
	
	# Debug: print signals available on video_manager
	print("[GPUCompositor] VideoManager signals:")
	for sig in video_manager.get_signal_list():
		print("  - ", sig.name)
	
	print("[GPUCompositor] Found dependencies")
	return true

func _init_shader() -> bool:
	"""Initialize GPU shader material"""
	var shader := load("res://shaders/nv12_composite.gdshader") as Shader
	if not shader:
		push_error("[GPUCompositor] Failed to load nv12_composite.gdshader!")
		return false
	
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set default parameters
	shader_material.set_shader_parameter("show_landmarks", true)
	shader_material.set_shader_parameter("landmark_radius", 3.0)
	shader_material.set_shader_parameter("landmark_color", Color(0.0, 1.0, 0.0, 0.8))
	shader_material.set_shader_parameter("show_mesh", false)
	
	print("[GPUCompositor] GPU shader initialized")
	return true

func _connect_signals() -> void:
	"""Connect to video and landmark signals - deferred to allow initialization"""
	# Defer both video and landmark connections
	call_deferred("_connect_video_signals")
	call_deferred("_connect_landmark_signals")

func _connect_video_signals() -> void:
	"""Deferred connection to video signals"""
	# Use string-based connection for dynamic signal access
	if video_manager and is_instance_valid(video_manager):
		var error = video_manager.connect("nv12_frame_ready", _on_nv12_frame_ready)
		if error == OK:
			video_connection_established = true
			print("[GPUCompositor] ✓ Connected to video frames")
			return
		else:
			print("[GPUCompositor] Failed to connect to video signal (error %d), will retry..." % error)
	else:
		print("[GPUCompositor] VideoManager not ready yet, will retry...")
	
	# Setup retry timer if not already running
	if not connection_retry_timer:
		connection_retry_timer = Timer.new()
		connection_retry_timer.wait_time = 0.1  # Retry every 100ms
		connection_retry_timer.timeout.connect(_retry_connections)
		add_child(connection_retry_timer)
		connection_retry_timer.start()
		print("[GPUCompositor] Started connection retry timer")

func _connect_landmark_signals() -> void:
	"""Deferred connection to landmark signals"""
	var lmk1_reader = landmark_manager.get("lmk1_reader")
	if lmk1_reader and is_instance_valid(lmk1_reader):
		# Use string-based connection for dynamic signal access
		var error = lmk1_reader.connect("landmarks_ready", _on_landmarks_ready)
		if error == OK:
			landmark_connection_established = true
			print("[GPUCompositor] ✓ Connected to landmarks")
			# Stop retry timer if both connections established
			if connection_retry_timer and video_connection_established:
				connection_retry_timer.stop()
				print("[GPUCompositor] All connections established, retry timer stopped")
			return
		else:
			print("[GPUCompositor] Failed to connect to landmark signal (error %d), will retry..." % error)
	else:
		print("[GPUCompositor] LMK1Reader not ready yet (exists: %s), will retry..." % (lmk1_reader != null))
	
	# Setup retry timer if not already running
	if not connection_retry_timer:
		connection_retry_timer = Timer.new()
		connection_retry_timer.wait_time = 0.1  # Retry every 100ms
		connection_retry_timer.timeout.connect(_retry_connections)
		add_child(connection_retry_timer)
		connection_retry_timer.start()
		print("[GPUCompositor] Started connection retry timer")

func _retry_connections() -> void:
	"""Retry connecting to video and landmark signals"""
	# Try video connection (string-based for dynamic signal access)
	if not video_connection_established and video_manager and is_instance_valid(video_manager):
		var error = video_manager.connect("nv12_frame_ready", _on_nv12_frame_ready)
		if error == OK:
			video_connection_established = true
			print("[GPUCompositor] ✓ Video connection established after retry")
		else:
			# Only log non-OK errors (could be already connected or other issues)
			print("[GPUCompositor] Video retry failed (error %d)" % error)
	
	# Try landmark connection (string-based for dynamic signal access)
	if not landmark_connection_established:
		var lmk1_reader = landmark_manager.get("lmk1_reader")
		if lmk1_reader and is_instance_valid(lmk1_reader):
			var error = lmk1_reader.connect("landmarks_ready", _on_landmarks_ready)
			if error == OK:
				landmark_connection_established = true
				print("[GPUCompositor] ✓ Landmark connection established after retry")
			else:
				# Only log non-OK errors
				print("[GPUCompositor] Landmark retry failed (error %d)" % error)
		else:
			print("[GPUCompositor] LMK1Reader still not available (exists: %s)" % (lmk1_reader != null))
	
	# Stop timer if both connections established
	if video_connection_established and landmark_connection_established:
		connection_retry_timer.stop()
		print("[GPUCompositor] All signal connections established - retry timer stopped")

func _on_nv12_frame_ready(y_texture: ImageTexture, uv_texture: ImageTexture, frame_id: int, timestamp: int) -> void:
	"""Called when new video frame arrives"""
	last_video_frame_id = frame_id
	
	# DEBUG: Log timing information for first 100 frames
	if frame_count < 100:
		print("[GPUCompositor] Frame %d: video_fid=%d, cached_lm_fid=%d, lm_count=%d" % [
			frame_id, frame_id, cached_landmark_timestamp, cached_landmarks.size()
		])
	
	# Debug first few frames
	if frame_count < 3:
		print("[GPUCompositor] Frame %d: Y=%s UV=%s ts=%d" % [frame_id, y_texture != null, uv_texture != null, timestamp])
		if y_texture:
			print("  Y texture size: %dx%d" % [y_texture.get_width(), y_texture.get_height()])
		if uv_texture:
			print("  UV texture size: %dx%d" % [uv_texture.get_width(), uv_texture.get_height()])
	
	# Set textures in shader
	if y_texture and uv_texture:
		shader_material.set_shader_parameter("y_texture", y_texture)
		shader_material.set_shader_parameter("uv_texture", uv_texture)
		shader_material.set_shader_parameter("video_size", Vector2(y_texture.get_width(), y_texture.get_height()))
	else:
		if frame_count < 5:
			push_warning("[GPUCompositor] Null textures received!")
	
	# Try to pair with landmarks
	var paired_landmarks := _pair_landmarks_by_frame_id(frame_id)
	
	if paired_landmarks.size() > 0:
		# DISABLED G-H prediction to match web UI behavior (no lag)
		# Web UI renders landmarks directly without smoothing
		# var start_time := Time.get_ticks_usec()
		# var predicted := _predict_landmarks(paired_landmarks)
		# prediction_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
		
		# Convert normalized coords directly to screen coordinates
		var screen_landmarks := _convert_to_screen_coords(paired_landmarks)
		
		# Upload to shader (shader expects vec2 array)
		shader_material.set_shader_parameter("landmarks", screen_landmarks)
		shader_material.set_shader_parameter("landmark_count", screen_landmarks.size())
		
		# DEBUG: Log successful pairing
		if frame_count < 100:
			print("  ✓ Paired landmarks for frame %d" % frame_id)
		
		pairing_misses = 0  # Reset miss counter
	else:
		# No landmarks available - keep previous or clear
		pairing_misses += 1
		
		# DEBUG: Log pairing failures
		if frame_count < 100:
			print("  ✗ PAIRING FAILED - miss count: %d" % pairing_misses)
		
		if pairing_misses > 10:
			# Clear landmarks after 10 missed pairings
			shader_material.set_shader_parameter("landmark_count", 0)
	
	frame_count += 1
	frame_composited.emit(frame_id)

func _on_landmarks_ready(landmarks: Array, frame_id: int) -> void:
	"""Called when new landmarks arrive - cache for use"""
	# Note: We don't have direct timestamp access from LMK1Reader
	# Using frame_id for pairing instead
	
	# Convert Array[Vector3] to PackedVector2Array (normalized coords)
	cached_landmarks.clear()
	for lm in landmarks:
		if lm is Vector3:
			cached_landmarks.append(Vector2(lm.x, lm.y))
	
	# Store frame_id for pairing with video frames
	cached_landmark_timestamp = frame_id
	last_landmark_frame_id = frame_id
	
	# DEBUG: Log landmark arrivals
	if frame_count < 100:
		print("[GPUCompositor] Landmarks ready: frame_id=%d, count=%d" % [frame_id, cached_landmarks.size()])

func _pair_landmarks_by_frame_id(video_frame_id: int) -> PackedVector2Array:
	"""Pair landmarks with video frame by frame ID"""
	if cached_landmarks.size() == 0:
		return PackedVector2Array()
	
	# Calculate frame difference
	var frame_diff: int = abs(video_frame_id - cached_landmark_timestamp)
	
	# DEBUG: Log pairing attempts for first 100 frames
	if frame_count < 100:
		print("  Pairing: video_fid=%d, lm_fid=%d, diff=%d frames, tolerance=%d frames" % [
			video_frame_id, cached_landmark_timestamp, frame_diff, FRAME_ID_TOLERANCE
		])
	
	# Check if within tolerance
	if frame_diff <= FRAME_ID_TOLERANCE:
		pairing_misses = 0  # Reset miss counter
		return cached_landmarks
	
	# Outside tolerance - return empty (will use previous or clear)
	return PackedVector2Array()

func _predict_landmarks(current: PackedVector2Array) -> PackedVector2Array:
	"""G-H predictor for smooth landmark tracking"""
	if not predictor_initialized or predicted_landmarks.size() != current.size():
		# Initialize predictor
		predicted_landmarks = current.duplicate()
		landmark_velocities.resize(current.size())
		for i in range(landmark_velocities.size()):
			landmark_velocities[i] = Vector2.ZERO
		predictor_initialized = true
		return current
	
	# Predict one frame ahead
	var dt: float = 1.0 / 60.0  # Assume 60 FPS target
	var result := PackedVector2Array()
	result.resize(current.size())
	
	for i in range(current.size()):
		# Prediction
		var pred := predicted_landmarks[i] + landmark_velocities[i] * dt
		
		# Measurement residual
		var residual := current[i] - pred
		
		# Update position with tracking gain
		predicted_landmarks[i] = pred + residual * G_GAIN
		
		# Update velocity with smoothing gain
		landmark_velocities[i] += residual * (H_GAIN / dt)
		
		result[i] = predicted_landmarks[i]
	
	return result

func _convert_to_screen_coords(normalized: PackedVector2Array) -> PackedVector2Array:
	"""Convert normalized [0,1] coords to screen pixel coordinates"""
	var viewport_size := get_viewport().get_visible_rect().size
	var result := PackedVector2Array()
	result.resize(normalized.size())
	
	for i in range(normalized.size()):
		result[i] = Vector2(
			normalized[i].x * viewport_size.x,
			normalized[i].y * viewport_size.y
		)
	
	return result

func get_shader_material() -> ShaderMaterial:
	"""Get the shader material for attaching to display node"""
	return shader_material

func set_show_landmarks(enabled: bool) -> void:
	"""Toggle landmark visibility"""
	shader_material.set_shader_parameter("show_landmarks", enabled)

func set_landmark_radius(radius: float) -> void:
	"""Set landmark point radius"""
	shader_material.set_shader_parameter("landmark_radius", radius)

func set_landmark_color(color: Color) -> void:
	"""Set landmark point color"""
	shader_material.set_shader_parameter("landmark_color", color)

func get_stats() -> Dictionary:
	"""Get compositor statistics"""
	return {
		"frame_count": frame_count,
		"pairing_misses": pairing_misses,
		"prediction_time_ms": prediction_time_ms,
		"predictor_initialized": predictor_initialized,
		"cached_landmark_count": cached_landmarks.size()
	}
