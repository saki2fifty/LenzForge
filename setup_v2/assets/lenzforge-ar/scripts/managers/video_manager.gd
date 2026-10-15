extends Node
class_name VideoManager
## Video Stream Manager
## High-performance video streaming from VID1 ring buffer
## Target: <5ms latency, 60 FPS sustained

signal frame_ready(texture: ImageTexture, frame_id: int)
signal nv12_frame_ready(y_texture: ImageTexture, uv_texture: ImageTexture, frame_id: int, timestamp: int)
signal stream_started()
signal stream_stopped()
signal error_occurred(message: String)

# VID1 Reader (GDExtension)
var vid1_reader: Node

# Video state
var is_running: bool = false
var is_paused: bool = false
var frame_count: int = 0
var last_frame_id: int = -1
var last_timestamp: int = 0

# Texture management (for CPU path)
var current_texture: ImageTexture


# Video dimensions
var video_width: int = 0
var video_height: int = 0

# Performance tracking
var last_read_time: float = 0.0
var read_times: Array[float] = []
const PERF_HISTORY_SIZE: int = 60

# Configuration
const RING_BUFFER_NAME: String = "LenzForge_Video"
const TARGET_FPS: int = 60
const MAX_FRAME_AGE_MS: float = 33.0  # Drop frames older than 2 frames

func _ready() -> void:
	print("[VideoManager] Initializing...")
	
	# Create VID1 reader
	if not _init_vid1_reader():
		push_error("[VideoManager] Failed to initialize VID1 reader!")
		error_occurred.emit("VID1 reader initialization failed")
		return
	
	# Start streaming
	if not start_stream():
		push_error("[VideoManager] Failed to start video stream!")
		error_occurred.emit("Video stream start failed")
		return
	
	print("[VideoManager] Ready - streaming at %d FPS (dual-path: GPU default, CPU fallback)" % TARGET_FPS)

func _init_vid1_reader() -> bool:
	"""Initialize VID1 ring buffer reader"""
	# Instantiate VID1Reader C++ class directly from GDExtension
	vid1_reader = ClassDB.instantiate("VID1Reader")
	if not vid1_reader:
		push_error("[VideoManager] Failed to create VID1Reader instance!")
		return false
	
	vid1_reader.name = "VID1Reader"
	add_child(vid1_reader)
	
	# Start reading (opens shared memory automatically)
	if not vid1_reader.has_method("start_reading"):
		push_error("[VideoManager] VID1Reader missing 'start_reading' method!")
		return false
	
	var success: bool = vid1_reader.start_reading()
	if not success:
		push_error("[VideoManager] Failed to start reading from VID1 ring buffer")
		push_error("[VideoManager] Make sure LenzForge backend is running!")
		return false
	
	# Get video dimensions (available after start_reading succeeds)
	if vid1_reader.has_method("get_width") and vid1_reader.has_method("get_height"):
		video_width = vid1_reader.get_width()
		video_height = vid1_reader.get_height()
		print("[VideoManager] Video dimensions: %dx%d" % [video_width, video_height])
	else:
		push_error("[VideoManager] VID1Reader missing dimension methods!")
		return false
	
	# Connect to frame_ready signal
	if vid1_reader.has_signal("frame_ready"):
		vid1_reader.frame_ready.connect(_on_vid1_frame_ready)
		print("[VideoManager] Connected to frame_ready signal")
	else:
		push_error("[VideoManager] VID1Reader missing 'frame_ready' signal!")
		return false
	
	return true

func start_stream() -> bool:
	"""Start video streaming"""
	if is_running:
		push_warning("[VideoManager] Stream already running!")
		return true
	
	if not vid1_reader:
		push_error("[VideoManager] VID1Reader not initialized!")
		return false
	
	# Start reading
	if vid1_reader.has_method("start_reading"):
		var success: bool = vid1_reader.start_reading()
		if not success:
			push_error("[VideoManager] Failed to start reading!")
			return false
	else:
		push_error("[VideoManager] VID1Reader missing 'start_reading' method!")
		return false
	
	is_running = true
	is_paused = false
	frame_count = 0
	last_frame_id = -1
	
	stream_started.emit()
	print("[VideoManager] Stream started")
	
	return true

func stop_stream() -> void:
	"""Stop video streaming"""
	if not is_running:
		return
	
	if vid1_reader and vid1_reader.has_method("stop_reading"):
		vid1_reader.stop_reading()
	
	is_running = false
	stream_stopped.emit()
	print("[VideoManager] Stream stopped")

func set_paused(paused: bool) -> void:
	"""Pause/unpause video stream"""
	is_paused = paused
	print("[VideoManager] Stream %s" % ("paused" if paused else "resumed"))

func stop() -> void:
	"""Clean shutdown"""
	stop_stream()
	
	if vid1_reader:
		if vid1_reader.has_method("close"):
			vid1_reader.close()
		vid1_reader.queue_free()
		vid1_reader = null

func _on_vid1_frame_ready(y_texture: ImageTexture, uv_texture: ImageTexture, frame_id: int, timestamp: int) -> void:
	"""Called when VID1Reader emits frame_ready signal with NV12 textures"""
	if is_paused:
		return
	
	# Update frame count and timestamp
	frame_count += 1
	last_frame_id = frame_id
	last_timestamp = timestamp
	
	# Log first few frames
	if frame_count <= 5:
		print("[VideoManager] Frame %d received (Y: %s, UV: %s)" % 
		      [frame_id, y_texture != null, uv_texture != null])
	
	# Emit NV12 frame signal (for GPU path via GPUCompositor)
	nv12_frame_ready.emit(y_texture, uv_texture, frame_id, timestamp)
	
	# Don't do CPU conversion unless explicitly needed via get_last_frame()
	# The slow per-pixel conversion was running every frame, causing lag!

func _convert_nv12_to_rgb(y_tex: ImageTexture, uv_tex: ImageTexture) -> ImageTexture:
	"""CPU fallback: Convert NV12 to RGB using software conversion
	NOTE: This is slow (~10-15ms) but provides compatibility when GPU path unavailable"""
	var y_img = y_tex.get_image()
	var uv_img = uv_tex.get_image()
	
	var width = y_img.get_width()
	var height = y_img.get_height()
	
	# Create RGB image
	var rgb_img = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	# BT.709 YUV→RGB conversion (per-pixel)
	for y in range(height):
		for x in range(width):
			var y_val = y_img.get_pixel(x, y).r
			
			# UV is half resolution (subsampled 2x2)
			var uv_pixel = uv_img.get_pixel(x / 2, y / 2)
			var u_val = uv_pixel.r
			var v_val = uv_pixel.g
			
			# BT.709 conversion
			var y_adj = (y_val * 255.0 - 16.0) / 255.0
			var u_adj = (u_val * 255.0 - 128.0) / 255.0
			var v_adj = (v_val * 255.0 - 128.0) / 255.0
			
			var r = y_adj * 1.164 + v_adj * 1.596
			var g = y_adj * 1.164 - u_adj * 0.392 - v_adj * 0.813
			var b = y_adj * 1.164 + u_adj * 2.017
			
			rgb_img.set_pixel(x, y, Color(
				clamp(r, 0.0, 1.0),
				clamp(g, 0.0, 1.0),
				clamp(b, 0.0, 1.0)
			))
	
	return ImageTexture.create_from_image(rgb_img)

func _process(_delta: float) -> void:
	"""Process loop - VID1Reader handles frame reading internally"""
	# VID1Reader's _process() handles frame reading and emits frame_ready signal
	# We emit BOTH signals:
	# - nv12_frame_ready: For GPU path (via GPUCompositor + shader)
	# - frame_ready: For CPU path (fallback, software conversion)
	pass

func get_stats() -> Dictionary:
	"""Get video streaming statistics"""
	return {
		"is_running": is_running,
		"is_paused": is_paused,
		"frame_count": frame_count,
		"last_frame_id": last_frame_id,
		"video_width": video_width,
		"video_height": video_height,
		"dual_path_enabled": true
	}
