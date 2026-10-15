extends Node
## LenzForge AR - Main Scene Controller
## High-performance AR scene with video, landmarks, effects, and modern UI
## Target: 60 FPS @ 1080p

# Performance metrics
var frame_count: int = 0
var fps_timer: float = 0.0
var current_fps: float = 0.0
var frame_times: Array[float] = []
const FPS_HISTORY_SIZE: int = 60

# Managers
var video_manager: Node
var landmark_manager: Node
var effects_manager: Node
var ui_manager: Node
var render_manager: Node

# Video texture
var current_video_texture: ImageTexture

# State
var is_paused: bool = false
var show_landmarks: bool = true
var show_fps_overlay: bool = true

# Performance
var last_frame_time: float = 0.0

func _ready() -> void:
	print("[LenzForge AR] Initializing high-performance AR scene...")
	
	# Set up window
	get_window().title = "LenzForge AR - Real-time Face Tracking"
	get_window().min_size = Vector2i(1280, 720)
	
	# Initialize managers
	_init_video_manager()
	_init_landmark_manager()
	_init_effects_manager()
	_init_ui_manager()
	_init_render_manager()
	_init_video_settings_manager()
	
	# Connect signals
	_connect_signals()
	
	# Start performance monitoring
	last_frame_time = Time.get_ticks_usec() / 1000000.0
	
	print("[LenzForge AR] Initialization complete!")
	print("[LenzForge AR] Target: 60 FPS @ 1080p")

func _init_video_manager() -> void:
	"""Initialize video stream manager"""
	# Check if VideoManager already exists in scene
	video_manager = $Managers.get_node_or_null("VideoManager")
	
	if not video_manager:
		# Create if it doesn't exist
		video_manager = Node.new()
		video_manager.name = "VideoManager"
		video_manager.set_script(preload("res://scripts/managers/video_manager.gd"))
		$Managers.add_child(video_manager)
	
	print("[LenzForge AR] Video manager initialized")

func _init_landmark_manager() -> void:
	"""Initialize landmark processing manager"""
	# Check if LandmarkManager already exists in scene
	landmark_manager = $Managers.get_node_or_null("LandmarkManager")
	
	if not landmark_manager:
		# Create if it doesn't exist
		landmark_manager = Node.new()
		landmark_manager.name = "LandmarkManager"
		landmark_manager.set_script(preload("res://scripts/managers/landmark_manager.gd"))
		$Managers.add_child(landmark_manager)
	
	print("[LenzForge AR] Landmark manager initialized")

func _init_effects_manager() -> void:
	"""Initialize effects system manager"""
	# Check if EffectsManager already exists in scene
	effects_manager = $Managers.get_node_or_null("EffectsManager")
	
	if not effects_manager:
		# Create if it doesn't exist
		effects_manager = Node.new()
		effects_manager.name = "EffectsManager"
		effects_manager.set_script(preload("res://scripts/managers/effects_manager.gd"))
		$Managers.add_child(effects_manager)
	
	print("[LenzForge AR] Effects manager initialized")

func _init_ui_manager() -> void:
	"""Initialize UI system manager"""
	# Check if UIManager already exists in scene
	ui_manager = $Managers.get_node_or_null("UIManager")
	
	if not ui_manager:
		# Create if it doesn't exist
		ui_manager = Node.new()
		ui_manager.name = "UIManager"
		ui_manager.set_script(preload("res://scripts/managers/ui_manager.gd"))
		$Managers.add_child(ui_manager)
	
	print("[LenzForge AR] UI manager initialized")

func _init_render_manager() -> void:
	"""Initialize GPU/CPU render controller"""
	# Check if RenderManager already exists in scene
	render_manager = $Managers.get_node_or_null("RenderManager")
	
	if not render_manager:
		# Create if it doesn't exist
		render_manager = Node.new()
		render_manager.name = "RenderManager"
		render_manager.set_script(preload("res://scripts/managers/render_manager.gd"))
		$Managers.add_child(render_manager)
	
	print("[LenzForge AR] Render manager initialized - GPU acceleration active!")
	print("[LenzForge AR] Keyboard shortcuts: V=video, L=landmarks, G=all GPU, C=all CPU")

func _init_video_settings_manager() -> void:
	"""Initialize video settings manager"""
	var video_settings_manager = Node.new()
	video_settings_manager.name = "VideoSettingsManager"
	video_settings_manager.set_script(preload("res://scripts/managers/video_settings_manager.gd"))
	$Managers.add_child(video_settings_manager)
	
	print("[LenzForge AR] Video settings manager initialized")

func _connect_signals() -> void:
	"""Connect inter-manager signals"""
	# Video → Landmark sync
	if video_manager.has_signal("frame_ready"):
		video_manager.frame_ready.connect(_on_video_frame_ready)
	
	# Landmark → Effects sync
	if landmark_manager.has_signal("landmarks_ready"):
		landmark_manager.landmarks_ready.connect(_on_landmarks_ready)
	
	# UI → Manager communication
	if ui_manager.has_signal("effect_selected"):
		ui_manager.effect_selected.connect(_on_effect_selected)
	
	print("[LenzForge AR] Signals connected")

func _process(delta: float) -> void:
	"""Main processing loop - optimized for 60 FPS"""
	# Performance tracking
	_update_performance_metrics(delta)
	
	# Update managers (they handle their own _process internally)
	# UI updates happen here to ensure smooth 60 FPS
	if ui_manager and ui_manager.has_method("update_performance_display"):
		ui_manager.update_performance_display(current_fps, _get_frame_time_ms())

func _update_performance_metrics(delta: float) -> void:
	"""Track FPS and frame times"""
	# Calculate frame time
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	var frame_time: float = (current_time - last_frame_time) * 1000.0  # Convert to ms
	last_frame_time = current_time
	
	# Store frame time history
	frame_times.append(frame_time)
	if frame_times.size() > FPS_HISTORY_SIZE:
		frame_times.pop_front()
	
	# Calculate FPS
	frame_count += 1
	fps_timer += delta
	
	if fps_timer >= 1.0:
		current_fps = frame_count / fps_timer
		frame_count = 0
		fps_timer = 0.0
		
		# Log performance warnings
		if current_fps < 55.0:
			push_warning("[LenzForge AR] Performance degraded: %.1f FPS" % current_fps)

func _get_frame_time_ms() -> float:
	"""Get average frame time in milliseconds"""
	if frame_times.is_empty():
		return 0.0
	
	var total: float = 0.0
	for ft in frame_times:
		total += ft
	return total / frame_times.size()

func _on_video_frame_ready(texture: ImageTexture, frame_id: int) -> void:
	"""Called when new video frame is available (CPU path)"""
	# This is for CPU rendering path - texture already converted to RGB
	# GPU path handles video via GPUCompositor + shader automatically
	
	# Update video display texture (only used in CPU mode)
	$Layers/VideoLayer/VideoDisplay.texture = texture
	current_video_texture = texture
	
	# Trigger landmark processing
	if landmark_manager and landmark_manager.has_method("process_frame"):
		landmark_manager.process_frame(frame_id)

func _on_landmarks_ready(landmarks: Dictionary) -> void:
	"""Called when landmark data is ready"""
	# Update landmark visualization
	var landmark_canvas = $Layers/LandmarkLayer/LandmarkCanvas
	if show_landmarks and landmark_canvas and landmark_canvas.has_method("update_landmarks"):
		landmark_canvas.update_landmarks(landmarks)
	
	# Apply effects with landmark data
	if effects_manager and effects_manager.has_method("apply_current_effect"):
		effects_manager.apply_current_effect(current_video_texture, landmarks)

func _on_effect_selected(effect_name: String) -> void:
	"""Called when user selects an effect"""
	if effects_manager and effects_manager.has_method("set_active_effect"):
		effects_manager.set_active_effect(effect_name)
		print("[LenzForge AR] Effect selected: %s" % effect_name)

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:
				# Toggle FPS overlay
				show_fps_overlay = !show_fps_overlay
				if ui_manager and ui_manager.has_method("toggle_fps_overlay"):
					ui_manager.toggle_fps_overlay(show_fps_overlay)
			
			KEY_E:
				# Toggle effects panel
				if ui_manager and ui_manager.has_method("toggle_effects_panel"):
					ui_manager.toggle_effects_panel()
			
			KEY_S:
				# Toggle settings
				if ui_manager and ui_manager.has_method("toggle_settings"):
					ui_manager.toggle_settings()
			
			KEY_SPACE:
				# Play/Pause
				is_paused = !is_paused
				if video_manager and video_manager.has_method("set_paused"):
					video_manager.set_paused(is_paused)
			
			KEY_L:
				# Toggle landmark visualization
				show_landmarks = !show_landmarks
				$Layers/LandmarkLayer.visible = show_landmarks
			
			KEY_ESCAPE:
				# Exit application
				_on_exit_requested()
			
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Quick effect selection (1-9)
				var effect_index: int = event.keycode - KEY_1
				if ui_manager and ui_manager.has_method("select_effect_by_index"):
					ui_manager.select_effect_by_index(effect_index)

func _on_exit_requested() -> void:
	"""Clean shutdown"""
	print("[LenzForge AR] Shutting down...")
	
	# Stop all managers
	if video_manager and video_manager.has_method("stop"):
		video_manager.stop()
	
	if landmark_manager and landmark_manager.has_method("stop"):
		landmark_manager.stop()
	
	if effects_manager and effects_manager.has_method("cleanup"):
		effects_manager.cleanup()
	
	# Exit
	get_tree().quit()

func _notification(what: int) -> void:
	"""Handle window notifications"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_exit_requested()
