extends Control
class_name LenzForgeMainUI

## Five-panel glassmorphism UI for LenzForge AR
## Implements Dark theme with smooth animations
## Includes live video feed integration with GPU rendering

# Panel references
@onready var left_panel: Panel = $LeftPanel
@onready var top_panel: Panel = $TopPanel
@onready var center_panel: Panel = $CenterPanel
@onready var bottom_panel: Panel = $BottomPanel
@onready var right_panel: Panel = $RightPanel
@onready var video_placeholder: ColorRect = $CenterPanel/MarginContainer/VBoxContainer/VideoPlaceholder
@onready var landmark_overlay: Control = $CenterPanel/MarginContainer/VBoxContainer/VideoPlaceholder/LandmarkOverlay

# Video rendering
var video_display: TextureRect  # Changed from Sprite2D to TextureRect for Control hierarchy
var shader_material: ShaderMaterial
var video_manager: Node
var landmark_manager: Node

# Landmark rendering
var current_landmarks: PackedVector2Array = PackedVector2Array()
var landmark_color: Color = Color(0, 1, 0, 0.8)  # Green with transparency
var landmark_size: float = 3.0
var show_landmarks: bool = true

# Performance tracking
var frame_count: int = 0
var fps: float = 0.0
var last_fps_update: float = 0.0
var current_video_resolution: Vector2 = Vector2(1280, 720)  # Track actual video resolution

# Phase 1 Part B: Timestamp Pairing (for perfect temporal sync)
const TIMESTAMP_MATCH_THRESHOLD_US: int = 16000  # 16ms = 16000 microseconds (QPC timestamps are in microseconds)
const MAX_QUEUE_SIZE: int = 5  # Maximum frames to buffer (prevent memory bloat)
var video_frame_queue: Array[Dictionary] = []  # {y_texture, uv_texture, frame_id, timestamp}
var landmark_frame_queue: Array[Dictionary] = []  # {data, timestamp}
var frames_matched: int = 0
var frames_dropped_video: int = 0
var frames_dropped_landmarks: int = 0

# Animation
var panel_tween: Tween
const FADE_DURATION := 0.3
const SLIDE_DURATION := 0.4
const PANEL_GAP := 8  # Gap between panels in pixels

func _ready():
	# Initialize panels with glassmorphism styling
	setup_glassmorphism()
	
	# Setup video rendering
	setup_video_display()
	
	# Setup landmark overlay
	setup_landmark_overlay()
	
	# Connect to managers
	connect_to_managers()
	
	# Animate panels on startup
	animate_panels_in()
	
	# Phase 1 Part B: Log timestamp pairing configuration
	print("[LenzForgeMainUI] ========================================")
	print("[LenzForgeMainUI] PHASE 1 PART B: TIMESTAMP PAIRING ENABLED")
	print("[LenzForgeMainUI]   Threshold: %dus (%.1fms)" % [TIMESTAMP_MATCH_THRESHOLD_US, TIMESTAMP_MATCH_THRESHOLD_US / 1000.0])
	print("[LenzForgeMainUI]   Max Queue Size: %d frames" % MAX_QUEUE_SIZE)
	print("[LenzForgeMainUI] ========================================")
	print("[LenzForgeMainUI] Ready - landmarks initially: %s" % ("visible" if show_landmarks else "hidden"))
	
	# Defer video finalization until after first layout pass (fixes size 0x0 issue)
	call_deferred("_finalize_video_setup")

func _finalize_video_setup():
	"""Complete video setup after layout is calculated (fixes TextureRect size 0x0 issue)."""
	if video_display:
		print("[LenzForgeMainUI] ========================================")
		print("[LenzForgeMainUI] POST-LAYOUT VIDEO DISPLAY:")
		print("[LenzForgeMainUI]   Size: %v (should NOT be 0x0)" % video_display.size)
		print("[LenzForgeMainUI]   Position: %v" % video_display.position)
		print("[LenzForgeMainUI]   Global Position: %v" % video_display.global_position)
		print("[LenzForgeMainUI]   Parent Size: %v" % video_placeholder.size)
		print("[LenzForgeMainUI]   Texture Size: %v" % video_display.texture.get_size())
		print("[LenzForgeMainUI] ========================================")

func setup_glassmorphism():
	"""Apply glassmorphism effect to all panels."""
	apply_panel_style(left_panel)
	apply_panel_style(top_panel)
	apply_panel_style(center_panel)
	apply_panel_style(bottom_panel)
	apply_panel_style(right_panel)

func apply_panel_style(panel: Panel):
	"""Apply Dark theme glassmorphism styling to a panel."""
	if not panel:
		return
	
	# Create StyleBoxFlat for glassmorphism effect
	var style = StyleBoxFlat.new()
	
	# Dark theme colors from MODERNIZATION_THEMES.md
	# panel_bg: rgba(255, 255, 255, 0.05) - 5% white overlay
	style.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	
	# panel_border: rgba(255, 255, 255, 0.15) - 15% white border
	style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	
	# corner_radius: 12px
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	# Shadow effect (simulated with border)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	
	# Apply style to panel
	panel.add_theme_stylebox_override("panel", style)

func setup_video_display():
	"""Setup GPU-accelerated video display using TextureRect (Control node compatible)."""
	# Create TextureRect for video rendering (Control node - works in Control hierarchy)
	video_display = TextureRect.new()
	video_display.name = "VideoDisplay"
	video_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # Allow custom sizing
	video_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Maintain aspect ratio
	video_display.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to landmarks
	
	# Add as first child (render behind landmark overlay)
	video_placeholder.add_child(video_display)
	video_placeholder.move_child(video_display, 0)
	
	# Set size to fill placeholder using size_flags (more reliable than anchors)
	video_display.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	video_display.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	video_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_display.custom_minimum_size = video_placeholder.size
	
	# Create initial BRIGHT MAGENTA texture for testing visibility
	var dummy_image := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	dummy_image.fill(Color(1.0, 0.0, 1.0))  # BRIGHT MAGENTA - unmissable!
	video_display.texture = ImageTexture.create_from_image(dummy_image)
	
	print("[LenzForgeMainUI] ========================================")
	print("[LenzForgeMainUI] VIDEO DISPLAY SETUP:")
	print("[LenzForgeMainUI]   Type: TextureRect (Control node)")
	print("[LenzForgeMainUI]   Texture: %dx%d MAGENTA" % [1280, 720])
	print("[LenzForgeMainUI]   Size: %v" % video_display.size)
	print("[LenzForgeMainUI]   Position: %v" % video_display.position)
	print("[LenzForgeMainUI]   Visible: %s" % video_display.visible)
	print("[LenzForgeMainUI]   Parent: %s (size: %v)" % [video_placeholder.name, video_placeholder.size])
	print("[LenzForgeMainUI] ========================================")
	
	# Load NV12 shader but DON'T apply it yet - wait for first frame
	var shader := load("res://shaders/nv12_composite.gdshader") as Shader
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		# DON'T apply shader yet: video_display.material = shader_material
		print("[LenzForgeMainUI] GPU shader loaded (not applied yet - waiting for video frames)")
	else:
		push_error("[LenzForgeMainUI] Failed to load nv12_composite.gdshader!")

func setup_landmark_overlay():
	"""Setup landmark overlay for drawing face mesh."""
	if landmark_overlay:
		landmark_overlay.draw.connect(_draw_landmarks)
		print("[LenzForgeMainUI] Landmark overlay configured")
	else:
		push_error("[LenzForgeMainUI] LandmarkOverlay node not found!")

func connect_to_managers():
	"""Connect to VideoManager and LandmarkManager signals."""
	# Find VideoManager (scene child)
	video_manager = get_node_or_null("Managers/VideoManager")
	if video_manager:
		if video_manager.has_signal("nv12_frame_ready"):
			video_manager.nv12_frame_ready.connect(_on_video_frame_ready)
			print("[LenzForgeMainUI] Connected to VideoManager")
		else:
			push_warning("[LenzForgeMainUI] VideoManager missing nv12_frame_ready signal")
	else:
		push_warning("[LenzForgeMainUI] VideoManager not found - video will not display")
	
	# Find LandmarkManager (scene child)
	landmark_manager = get_node_or_null("Managers/LandmarkManager")
	if landmark_manager:
		if landmark_manager.has_signal("landmarks_ready"):
			landmark_manager.landmarks_ready.connect(_on_landmarks_ready)
			print("[LenzForgeMainUI] Connected to LandmarkManager")
		else:
			push_warning("[LenzForgeMainUI] LandmarkManager missing landmarks_ready signal")
	else:
		push_warning("[LenzForgeMainUI] LandmarkManager not found")

func _on_video_frame_ready(y_texture: ImageTexture, uv_texture: ImageTexture, frame_id: int, timestamp: int):
	"""Handle incoming video frame from VideoManager - Phase 1 Part B: Queue for timestamp matching."""
	if not shader_material:
		return
	
	# Apply shader material on first frame
	if not video_display.material:
		video_display.material = shader_material
		print("[LenzForgeMainUI] GPU shader applied to video_display")
	
	# Create placeholder texture if display has no texture yet
	if not video_display.texture:
		var dummy_image := Image.create(1280, 720, false, Image.FORMAT_RGB8)
		video_display.texture = ImageTexture.create_from_image(dummy_image)
		print("[LenzForgeMainUI] Placeholder texture created for video_display")
	
	# Phase 1 Part B: Queue video frame for timestamp pairing
	video_frame_queue.append({
		"y_texture": y_texture,
		"uv_texture": uv_texture,
		"frame_id": frame_id,
		"timestamp": timestamp
	})
	
	# Enforce queue size limit (drop oldest frames)
	while video_frame_queue.size() > MAX_QUEUE_SIZE:
		video_frame_queue.pop_front()
		frames_dropped_video += 1
		print("[LenzForgeMainUI] Video queue full - dropped oldest frame (total dropped: %d)" % frames_dropped_video)
	
	# Try to match and render paired frames
	_try_match_frames()
	
	# Update FPS counter
	frame_count += 1
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - last_fps_update >= 1.0:
		fps = frame_count / (current_time - last_fps_update)
		frame_count = 0
		last_fps_update = current_time
		_update_status_label()

func _on_landmarks_ready(data: Dictionary, timestamp: int):
	"""Handle landmark updates from LandmarkManager - Phase 1 Part B: Queue for timestamp matching."""
	# Phase 1 Part B: Queue landmark frame for timestamp pairing
	landmark_frame_queue.append({
		"data": data,
		"timestamp": timestamp
	})
	
	# Enforce queue size limit (drop oldest frames)
	while landmark_frame_queue.size() > MAX_QUEUE_SIZE:
		landmark_frame_queue.pop_front()
		frames_dropped_landmarks += 1
		print("[LenzForgeMainUI] Landmark queue full - dropped oldest frame (total dropped: %d)" % frames_dropped_landmarks)
	
	# Try to match and render paired frames
	_try_match_frames()

func _try_match_frames():
	"""Phase 1 Part B: Best-match timestamp pairing algorithm."""
	# Need at least one frame in each queue
	if video_frame_queue.is_empty() or landmark_frame_queue.is_empty():
		return
	
	# Find best match between all queued video and landmark frames
	var best_video_idx: int = -1
	var best_landmark_idx: int = -1
	var best_time_diff: int = TIMESTAMP_MATCH_THRESHOLD_US + 1  # Start above threshold
	
	for v_idx in range(video_frame_queue.size()):
		for l_idx in range(landmark_frame_queue.size()):
			var time_diff = abs(video_frame_queue[v_idx].timestamp - landmark_frame_queue[l_idx].timestamp)
			if time_diff < best_time_diff:
				best_time_diff = time_diff
				best_video_idx = v_idx
				best_landmark_idx = l_idx
	
	# If best match is within threshold, render the pair
	if best_time_diff <= TIMESTAMP_MATCH_THRESHOLD_US:
		var video_frame = video_frame_queue[best_video_idx]
		var landmark_frame = landmark_frame_queue[best_landmark_idx]
		
		# Render video frame
		shader_material.set_shader_parameter("y_texture", video_frame.y_texture)
		shader_material.set_shader_parameter("uv_texture", video_frame.uv_texture)
		
		# Render landmarks
		_render_landmarks(landmark_frame.data)
		
		# Remove matched frames from queues
		video_frame_queue.remove_at(best_video_idx)
		landmark_frame_queue.remove_at(best_landmark_idx)
		
		frames_matched += 1
		
		# Log every 30th match
		if frames_matched % 30 == 0:
			print("[LenzForgeMainUI] ✓ Frame pair matched (time_diff=%dus, total_matched=%d)" % [best_time_diff, frames_matched])
	else:
		# No good match - drop the older frame
		var video_ts = video_frame_queue[0].timestamp
		var landmark_ts = landmark_frame_queue[0].timestamp
		
		if video_ts < landmark_ts:
			video_frame_queue.pop_front()
			frames_dropped_video += 1
			print("[LenzForgeMainUI] ✗ Dropped old video frame (time_diff=%dus > threshold, total_dropped=%d)" % [best_time_diff, frames_dropped_video])
		else:
			landmark_frame_queue.pop_front()
			frames_dropped_landmarks += 1
			print("[LenzForgeMainUI] ✗ Dropped old landmark frame (time_diff=%dus > threshold, total_dropped=%d)" % [best_time_diff, frames_dropped_landmarks])

func _render_landmarks(data: Dictionary):
	"""Render landmarks from queued data (Phase 1 Part B helper)."""
	var frame_id: int = data.get("frame_id", 0)
	var face_landmarks: PackedVector2Array = data.get("face", PackedVector2Array())
	
	if not show_landmarks:
		return
	
	if not landmark_overlay or not video_display:
		push_error("[LenzForgeMainUI] landmark_overlay or video_display is null!")
		return
	
	# Transform landmarks from normalized coordinates to overlay display coordinates
	current_landmarks.clear()
	
	# Get overlay size
	var overlay_size = landmark_overlay.get_rect().size
	
	# Check if overlay has valid size (layout has completed)
	if overlay_size.x <= 0 or overlay_size.y <= 0:
		return
	
	# Calculate ACTUAL rendered video size with STRETCH_KEEP_ASPECT_CENTERED
	var control_rect = video_display.get_rect()
	var control_size = control_rect.size
	var control_pos = video_display.position
	
	# Get texture dimensions (video source dimensions)
	var texture = video_display.texture
	if not texture:
		return
	var texture_size = texture.get_size()
	
	# Calculate rendered video dimensions maintaining aspect ratio
	var texture_aspect = texture_size.x / texture_size.y
	var control_aspect = control_size.x / control_size.y
	
	var actual_video_size: Vector2
	var actual_video_offset: Vector2  # Offset within the control
	
	if texture_aspect > control_aspect:
		# Texture is wider - fit to width, letterbox top/bottom
		actual_video_size.x = control_size.x
		actual_video_size.y = control_size.x / texture_aspect
		actual_video_offset.x = 0
		actual_video_offset.y = (control_size.y - actual_video_size.y) / 2.0
	else:
		# Texture is taller - fit to height, pillarbox left/right
		actual_video_size.y = control_size.y
		actual_video_size.x = control_size.y * texture_aspect
		actual_video_offset.x = (control_size.x - actual_video_size.x) / 2.0
		actual_video_offset.y = 0
	
	# Final video position in overlay coordinates
	var video_pos_in_overlay = control_pos + actual_video_offset
	
	# Transform landmarks: normalized (0-1) → actual video coordinates → overlay coordinates
	for landmark in face_landmarks:
		# Scale landmark to ACTUAL video dimensions, then offset by video position
		var overlay_pos = Vector2(
			landmark.x * actual_video_size.x + video_pos_in_overlay.x,
			landmark.y * actual_video_size.y + video_pos_in_overlay.y
		)
		current_landmarks.append(overlay_pos)
	
	# Request redraw of overlay
	landmark_overlay.queue_redraw()

func _draw_landmarks():
	"""Draw landmarks on overlay (called by landmark_overlay's draw signal)."""
	# Debug: Confirm this function is being called
	if current_landmarks.size() > 0:
		print("[LenzForgeMainUI] _draw_landmarks() CALLED - drawing %d landmarks (show_landmarks=%s)" % [current_landmarks.size(), show_landmarks])
	
	if not show_landmarks or current_landmarks.is_empty():
		print("[LenzForgeMainUI] _draw_landmarks() SKIPPED - show_landmarks=%s, landmarks_empty=%s" % [show_landmarks, current_landmarks.is_empty()])
		return
	
	# Draw each landmark as a small circle
	for point in current_landmarks:
		landmark_overlay.draw_circle(point, landmark_size, landmark_color)
	
	print("[LenzForgeMainUI] _draw_landmarks() COMPLETED - drew %d circles" % current_landmarks.size())

func _update_status_label():
	"""Update status label with current FPS and mode."""
	var status_label = get_node_or_null("TopPanel/MarginContainer/HBoxContainer/StatusLabel")
	if status_label:
		var mode := "GPU Mode" if shader_material else "CPU Mode"
		var resolution := "%dx%d" % [current_video_resolution.x, current_video_resolution.y]
		status_label.text = "Ready • %s • %s • %.0f FPS" % [mode, resolution, fps]

func animate_panels_in():
	"""Animate panels sliding in on startup."""
	# Start panels off-screen
	left_panel.position.x -= 320
	right_panel.position.x += 320
	top_panel.position.y -= 60
	bottom_panel.position.y += 60
	center_panel.modulate.a = 0.0
	
	# Create animation sequence
	await get_tree().create_timer(0.1).timeout
	
	# Animate panels
	if panel_tween:
		panel_tween.kill()
	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Left panel slides in from left
	panel_tween.tween_property(left_panel, "position:x", 0, SLIDE_DURATION)
	
	# Right panel slides in from right
	panel_tween.tween_property(right_panel, "position:x", 
		get_viewport_rect().size.x - 320, SLIDE_DURATION)
	
	# Top panel slides down from top
	panel_tween.tween_property(top_panel, "position:y", 0, SLIDE_DURATION)
	
	# Bottom panel slides up from bottom
	panel_tween.tween_property(bottom_panel, "position:y", 
		get_viewport_rect().size.y - 60, SLIDE_DURATION)
	
	# Center panel fades in
	panel_tween.tween_property(center_panel, "modulate:a", 1.0, FADE_DURATION)

func toggle_left_panel():
	"""Slide left panel in/out."""
	if left_panel.position.x < -300:
		# Slide in
		if panel_tween:
			panel_tween.kill()
		panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_OUT)
		panel_tween.set_trans(Tween.TRANS_CUBIC)
		panel_tween.tween_property(left_panel, "position:x", 0, SLIDE_DURATION)
	else:
		# Slide out
		if panel_tween:
			panel_tween.kill()
		panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_IN)
		panel_tween.set_trans(Tween.TRANS_CUBIC)
		panel_tween.tween_property(left_panel, "position:x", -320, SLIDE_DURATION)

func toggle_right_panel():
	"""Slide right panel in/out."""
	var viewport_width = get_viewport_rect().size.x
	if right_panel.position.x > viewport_width:
		# Slide in
		if panel_tween:
			panel_tween.kill()
		panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_OUT)
		panel_tween.set_trans(Tween.TRANS_CUBIC)
		panel_tween.tween_property(right_panel, "position:x", 
			viewport_width - 320, SLIDE_DURATION)
	else:
		# Slide out
		if panel_tween:
			panel_tween.kill()
		panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_IN)
		panel_tween.set_trans(Tween.TRANS_CUBIC)
		panel_tween.tween_property(right_panel, "position:x", 
			viewport_width + 320, SLIDE_DURATION)

func toggle_landmarks():
	"""Toggle landmark visibility."""
	show_landmarks = !show_landmarks
	print("[LenzForgeMainUI] Landmarks toggled: %s" % ("VISIBLE" if show_landmarks else "HIDDEN"))
	if landmark_overlay:
		landmark_overlay.queue_redraw()
	else:
		push_error("[LenzForgeMainUI] landmark_overlay is null in toggle!")

func _input(event):
	"""Handle keyboard input."""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			toggle_landmarks()

func _on_window_resized():
	"""Handle window resize to reposition panels."""
	if right_panel:
		right_panel.position.x = get_viewport_rect().size.x - 320
	if bottom_panel:
		bottom_panel.position.y = get_viewport_rect().size.y - 60
