extends Node
## Render Manager
## Handles CPU/GPU rendering toggle for video and landmarks
## Keyboard shortcuts: V (video), L (landmarks), G (both GPU)

signal rendering_mode_changed(video_mode: String, landmark_mode: String)

# Rendering modes
enum VideoMode { CPU, GPU }
enum LandmarkMode { CPU, GPU }

var current_video_mode: VideoMode = VideoMode.GPU
var current_landmark_mode: LandmarkMode = LandmarkMode.GPU

# Dependencies
var video_manager: Node
var landmark_manager: Node
var gpu_compositor: Node

# Display nodes
var video_display: Node  # Sprite2D or TextureRect
var landmark_canvas: Node  # CanvasLayer for CPU landmark drawing

# CPU rendering components
var cpu_video_texture: ImageTexture
var cpu_landmark_layer: CanvasLayer

# Performance tracking
var last_render_time_ms: float = 0.0
var frame_count: int = 0

func _ready() -> void:
	print("[RenderManager] Initializing dual-mode renderer...")
	
	# Find dependencies
	if not _find_dependencies():
		push_error("[RenderManager] Failed to find dependencies!")
		return
	
	# Always default to GPU mode (best performance)
	# Note: Preference loading disabled - CPU video mode not yet supported
	# _load_preferences()
	current_video_mode = VideoMode.GPU
	current_landmark_mode = LandmarkMode.GPU
	
	# Note: _setup_rendering() is called by _create_gpu_compositor() after compositor is ready
	
	print("[RenderManager] Ready - Video:%s Landmarks:%s" % [
		"GPU" if current_video_mode == VideoMode.GPU else "CPU",
		"GPU" if current_landmark_mode == LandmarkMode.GPU else "CPU"
	])

func _find_dependencies() -> bool:
	"""Find required managers and nodes"""
	video_manager = get_node_or_null("../VideoManager")
	landmark_manager = get_node_or_null("../LandmarkManager")
	
	if not video_manager:
		push_error("[RenderManager] VideoManager not found!")
		return false
	
	if not landmark_manager:
		push_error("[RenderManager] LandmarkManager not found!")
		return false
	
	# Find or create GPU compositor (deferred to avoid "busy" error)
	gpu_compositor = get_node_or_null("../GPUCompositor")
	if not gpu_compositor:
		print("[RenderManager] Creating GPU compositor...")
		call_deferred("_create_gpu_compositor")
	
	# Find video display (exists in scene at Layers/VideoLayer/VideoDisplay)
	video_display = get_node_or_null("../../Layers/VideoLayer/VideoDisplay")
	if not video_display:
		push_error("[RenderManager] VideoDisplay not found in scene!")
		return false
	
	# Create base texture for shader to render on (deferred to allow video_manager to init)
	call_deferred("_setup_video_display_texture")
	
	# Find CPU landmark layer (exists in scene at Layers/LandmarkLayer/LandmarkCanvas)
	landmark_canvas = get_node_or_null("../../Layers/LandmarkLayer/LandmarkCanvas")
	if not landmark_canvas:
		push_error("[RenderManager] LandmarkCanvas not found in scene!")
		return false
	
	return true

func _create_gpu_compositor() -> void:
	"""Deferred creation of GPU compositor"""
	gpu_compositor = preload("res://scripts/managers/gpu_compositor.gd").new()
	gpu_compositor.name = "GPUCompositor"
	get_parent().add_child(gpu_compositor)
	
	# Wait for compositor to fully initialize before applying shader
	# Double-deferred ensures compositor's _ready() completes first
	call_deferred("_wait_for_compositor_ready")
	print("[RenderManager] GPU compositor created, waiting for initialization...")

func _wait_for_compositor_ready() -> void:
	"""Wait one more frame to ensure GPU compositor is fully ready"""
	call_deferred("_setup_rendering")

func _create_video_display() -> void:
	"""Deferred creation of video display"""
	video_display = Sprite2D.new()
	video_display.name = "VideoDisplay"
	video_display.centered = false
	get_tree().root.add_child(video_display)
	
	# Wait for video manager to get dimensions, then create properly sized texture
	call_deferred("_setup_video_display_texture")

func _create_landmark_canvas() -> void:
	"""Deferred creation of landmark canvas"""
	landmark_canvas = preload("res://scenes/components/landmark_layer.gd").new()
	landmark_canvas.name = "LandmarkCanvas"
	get_tree().root.add_child(landmark_canvas)

func _setup_video_display_texture() -> void:
	"""Setup video display with proper dimensions"""
	if not video_display or not video_manager:
		return
	
	# Get video dimensions from VideoManager
	var video_width = video_manager.get("video_width")
	var video_height = video_manager.get("video_height")
	
	# Default to common resolution if not available yet
	if video_width == null or video_width == 0:
		video_width = 1280
		video_height = 720
		# Retry after a short delay if dimensions aren't ready
		await get_tree().create_timer(0.1).timeout
		_setup_video_display_texture()
		return
	
	print("[RenderManager] Setting up video display: %dx%d" % [video_width, video_height])
	
	# Create properly sized base texture for shader to render on
	var img = Image.create(video_width, video_height, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)  # Black background
	video_display.texture = ImageTexture.create_from_image(img)
	
	# Apply current video mode (now that texture is ready)
	_apply_video_mode(current_video_mode)

func _setup_rendering() -> void:
	"""Setup rendering based on current mode"""
	_apply_video_mode(current_video_mode)
	_apply_landmark_mode(current_landmark_mode)

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				toggle_video_mode()
			KEY_L:
				toggle_landmark_mode()
			KEY_G:
				set_all_gpu()
			KEY_C:
				set_all_cpu()

# ============================================================================
# Video Rendering Toggle
# ============================================================================

func toggle_video_mode() -> void:
	"""Toggle between CPU and GPU video rendering"""
	if current_video_mode == VideoMode.CPU:
		set_video_mode(VideoMode.GPU)
	else:
		set_video_mode(VideoMode.CPU)

func set_video_mode(mode: VideoMode) -> void:
	"""Set video rendering mode"""
	if current_video_mode == mode:
		return
	
	current_video_mode = mode
	_apply_video_mode(mode)
	_save_preferences()
	
	print("[RenderManager] Video mode: %s" % ("GPU" if mode == VideoMode.GPU else "CPU"))
	rendering_mode_changed.emit(
		"GPU" if mode == VideoMode.GPU else "CPU",
		"GPU" if current_landmark_mode == LandmarkMode.GPU else "CPU"
	)

func _apply_video_mode(mode: VideoMode) -> void:
	"""Apply video rendering mode to display"""
	# Null check - video_display may not be ready yet (deferred creation)
	if not video_display:
		print("[RenderManager] video_display not ready yet, skipping...")
		return
	
	if mode == VideoMode.GPU:
		# GPU: Use shader material
		if gpu_compositor:
			var shader_mat = gpu_compositor.get_shader_material()
			if shader_mat:
				video_display.material = shader_mat
				print("[RenderManager] ✓ Shader material applied to VideoDisplay")
			else:
				push_warning("[RenderManager] GPU compositor shader material is null!")
		else:
			push_warning("[RenderManager] GPU compositor not available!")
			
			# Connect to GPU compositor for video frames
			if video_manager.has_signal("nv12_frame_ready") and not video_manager.nv12_frame_ready.is_connected(_on_gpu_video_frame):
				video_manager.nv12_frame_ready.connect(_on_gpu_video_frame)
			
			# Disconnect CPU path
			if video_manager.has_signal("frame_ready") and video_manager.frame_ready.is_connected(_on_cpu_video_frame):
				video_manager.frame_ready.disconnect(_on_cpu_video_frame)
	else:
		# CPU: Use regular texture
		video_display.material = null
		
		# Connect to CPU path
		if video_manager.has_signal("frame_ready") and not video_manager.frame_ready.is_connected(_on_cpu_video_frame):
			video_manager.frame_ready.connect(_on_cpu_video_frame)
		
		# Disconnect GPU path
		if video_manager.has_signal("nv12_frame_ready") and video_manager.nv12_frame_ready.is_connected(_on_gpu_video_frame):
			video_manager.nv12_frame_ready.disconnect(_on_gpu_video_frame)

func _on_cpu_video_frame(texture: ImageTexture, frame_id: int) -> void:
	"""CPU video frame received"""
	if current_video_mode == VideoMode.CPU:
		video_display.texture = texture
		
		# Auto-size display to match video
		if texture and frame_count < 5:
			var size = Vector2(texture.get_width(), texture.get_height())
			if video_display is Sprite2D:
				video_display.scale = size / video_display.texture.get_size()

func _on_gpu_video_frame(y_texture: ImageTexture, uv_texture: ImageTexture, frame_id: int, timestamp: int) -> void:
	"""GPU video frame received - handled by GPU compositor"""
	# GPU compositor handles this automatically via shader
	pass

# ============================================================================
# Landmark Rendering Toggle
# ============================================================================

func toggle_landmark_mode() -> void:
	"""Toggle between CPU and GPU landmark rendering"""
	if current_landmark_mode == LandmarkMode.CPU:
		set_landmark_mode(LandmarkMode.GPU)
	else:
		set_landmark_mode(LandmarkMode.CPU)

func set_landmark_mode(mode: LandmarkMode) -> void:
	"""Set landmark rendering mode"""
	if current_landmark_mode == mode:
		return
	
	current_landmark_mode = mode
	_apply_landmark_mode(mode)
	_save_preferences()
	
	print("[RenderManager] Landmark mode: %s" % ("GPU" if mode == LandmarkMode.GPU else "CPU"))
	rendering_mode_changed.emit(
		"GPU" if current_video_mode == VideoMode.GPU else "CPU",
		"GPU" if mode == LandmarkMode.GPU else "CPU"
	)

func _apply_landmark_mode(mode: LandmarkMode) -> void:
	"""Apply landmark rendering mode"""
	if mode == LandmarkMode.GPU:
		# GPU: Enable shader landmarks
		if gpu_compositor:
			gpu_compositor.set_show_landmarks(true)
		
		# Hide CPU canvas
		if landmark_canvas:
			landmark_canvas.visible = false
	else:
		# CPU: Use canvas layer
		if landmark_canvas:
			landmark_canvas.visible = true
		
		# Disable GPU landmarks
		if gpu_compositor:
			gpu_compositor.set_show_landmarks(false)

# ============================================================================
# Convenience Methods
# ============================================================================

func set_all_gpu() -> void:
	"""Set both video and landmarks to GPU"""
	set_video_mode(VideoMode.GPU)
	set_landmark_mode(LandmarkMode.GPU)
	print("[RenderManager] All GPU mode enabled")

func set_all_cpu() -> void:
	"""Set both video and landmarks to CPU"""
	set_video_mode(VideoMode.CPU)
	set_landmark_mode(LandmarkMode.CPU)
	print("[RenderManager] All CPU mode enabled")

func get_video_mode_string() -> String:
	return "GPU" if current_video_mode == VideoMode.GPU else "CPU"

func get_landmark_mode_string() -> String:
	return "GPU" if current_landmark_mode == LandmarkMode.GPU else "CPU"

# ============================================================================
# Preferences
# ============================================================================

func _load_preferences() -> void:
	"""Load saved rendering preferences"""
	var config = ConfigFile.new()
	var err = config.load("user://lenzforge_settings.cfg")
	
	if err == OK:
		current_video_mode = config.get_value("rendering", "video_mode", VideoMode.GPU)
		current_landmark_mode = config.get_value("rendering", "landmark_mode", VideoMode.GPU)
		print("[RenderManager] Loaded preferences: Video=%s Landmarks=%s" % [
			get_video_mode_string(), get_landmark_mode_string()
		])
	else:
		print("[RenderManager] No saved preferences, using defaults (GPU for best performance)")

func _save_preferences() -> void:
	"""Save rendering preferences"""
	var config = ConfigFile.new()
	config.set_value("rendering", "video_mode", current_video_mode)
	config.set_value("rendering", "landmark_mode", current_landmark_mode)
	config.save("user://lenzforge_settings.cfg")

# ============================================================================
# Stats & Info
# ============================================================================

func get_stats() -> Dictionary:
	"""Get rendering statistics"""
	var stats = {
		"video_mode": get_video_mode_string(),
		"landmark_mode": get_landmark_mode_string(),
		"frame_count": frame_count,
		"last_render_time_ms": last_render_time_ms
	}
	
	# Add GPU compositor stats if in GPU mode
	if current_video_mode == VideoMode.GPU and gpu_compositor:
		stats["gpu"] = gpu_compositor.get_stats()
	
	return stats

func print_controls() -> void:
	"""Print keyboard controls to console"""
	print("==================================================")
	print("  RENDERING CONTROLS")
	print("==================================================")
	print("  V - Toggle video (CPU/GPU)")
	print("  L - Toggle landmarks (CPU/GPU)")
	print("  G - Enable all GPU")
	print("  C - Enable all CPU")
	print("==================================================")
	print("  Current: Video=%s Landmarks=%s" % [get_video_mode_string(), get_landmark_mode_string()])
	print("==================================================")
