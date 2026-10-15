extends Control
## Simple Quickbar
## 3 essential buttons: Landmarks, Virtual Camera, CPU/GPU

signal landmark_toggled(visible: bool)
signal vcam_toggled(active: bool)
signal mode_toggled(gpu: bool)

# Button references
var btn_landmarks: Button
var btn_vcam: Button
var btn_mode: Button

# State
var landmarks_visible: bool = true
var vcam_active: bool = false
var gpu_mode: bool = false

# Managers
var render_manager: Node
var landmark_manager: Node

# Colors
const COLOR_BG: Color = Color(0.145, 0.145, 0.145)  # #252525
const COLOR_ACTIVE: Color = Color(0.2, 0.8, 0.4)  # #33cc66
const COLOR_INACTIVE: Color = Color(0.4, 0.4, 0.4)  # #666666
const COLOR_HOVER: Color = Color(0.533, 0.533, 0.533)  # #888888

func _ready() -> void:
	print("[SimpleQuickbar] Initializing...")
	
	# Find managers
	_find_managers()
	
	# Setup UI
	_setup_ui()
	
	# Connect to managers
	_connect_managers()
	
	print("[SimpleQuickbar] Ready")

func _find_managers() -> void:
	"""Find render and landmark managers"""
	var root = get_tree().root.get_node_or_null("ARMain")
	if not root:
		root = get_tree().root
	
	render_manager = root.get_node_or_null("RenderManager")
	if not render_manager:
		push_warning("[SimpleQuickbar] RenderManager not found")
	
	landmark_manager = root.get_node_or_null("LandmarkManager")
	if not landmark_manager:
		push_warning("[SimpleQuickbar] LandmarkManager not found")

func _setup_ui() -> void:
	"""Create the 3-button quickbar"""
	# Container
	var container = HBoxContainer.new()
	container.name = "QuickbarContainer"
	container.custom_minimum_size = Vector2(300, 48)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(container)
	
	# Add spacer for centering
	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer1)
	
	# Button 1: Landmarks
	btn_landmarks = _create_button("L", "Show/Hide Landmarks")
	btn_landmarks.pressed.connect(_on_landmarks_pressed)
	container.add_child(btn_landmarks)
	
	# Separator
	container.add_child(_create_separator())
	
	# Button 2: Virtual Camera (placeholder)
	btn_vcam = _create_button("V", "Virtual Camera (Coming Soon)")
	btn_vcam.pressed.connect(_on_vcam_pressed)
	btn_vcam.disabled = true  # Disabled until implemented
	container.add_child(btn_vcam)
	
	# Separator
	container.add_child(_create_separator())
	
	# Button 3: CPU/GPU Mode
	btn_mode = _create_button("G/C", "CPU/GPU Toggle")
	btn_mode.pressed.connect(_on_mode_pressed)
	container.add_child(btn_mode)
	
	# Add spacer for centering
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer2)
	
	# Initial state
	_update_button_states()

func _create_button(text: String, tooltip: String) -> Button:
	"""Create styled button"""
	var btn = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(80, 40)
	
	# Style
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_BG
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = COLOR_HOVER
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	
	return btn

func _create_separator() -> VSeparator:
	"""Create visual separator between buttons"""
	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 40)
	return sep

func _connect_managers() -> void:
	"""Connect to manager signals"""
	if render_manager:
		if render_manager.has_signal("rendering_mode_changed"):
			render_manager.rendering_mode_changed.connect(_on_rendering_mode_changed)
	
	if landmark_manager:
		if landmark_manager.has_signal("visibility_changed"):
			landmark_manager.visibility_changed.connect(_on_landmark_visibility_changed)

func _on_landmarks_pressed() -> void:
	"""Toggle landmark visibility"""
	landmarks_visible = !landmarks_visible
	
	if landmark_manager and landmark_manager.has_method("set_visible"):
		landmark_manager.set_visible(landmarks_visible)
	
	landmark_toggled.emit(landmarks_visible)
	_update_button_states()
	
	print("[SimpleQuickbar] Landmarks: %s" % ("VISIBLE" if landmarks_visible else "HIDDEN"))

func _on_vcam_pressed() -> void:
	"""Toggle virtual camera (placeholder)"""
	vcam_active = !vcam_active
	vcam_toggled.emit(vcam_active)
	_update_button_states()
	
	print("[SimpleQuickbar] Virtual Camera: %s (placeholder)" % ("ON" if vcam_active else "OFF"))

func _on_mode_pressed() -> void:
	"""Toggle CPU/GPU mode"""
	gpu_mode = !gpu_mode
	
	if render_manager:
		if gpu_mode:
			if render_manager.has_method("set_all_gpu"):
				render_manager.set_all_gpu()
		else:
			if render_manager.has_method("set_all_cpu"):
				render_manager.set_all_cpu()
	
	mode_toggled.emit(gpu_mode)
	_update_button_states()
	
	print("[SimpleQuickbar] Mode: %s" % ("GPU" if gpu_mode else "CPU"))

func _on_rendering_mode_changed(video_mode: String, landmark_mode: String) -> void:
	"""Update GPU mode state when RenderManager changes"""
	gpu_mode = (video_mode == "GPU" and landmark_mode == "GPU")
	_update_button_states()

func _on_landmark_visibility_changed(visible: bool) -> void:
	"""Update landmark button state when visibility changes externally"""
	landmarks_visible = visible
	_update_button_states()

func _update_button_states() -> void:
	"""Update button colors based on state"""
	if btn_landmarks:
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_ACTIVE if landmarks_visible else COLOR_INACTIVE
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn_landmarks.add_theme_stylebox_override("normal", style)
		btn_landmarks.text = "L" if landmarks_visible else "L̶"
	
	if btn_vcam:
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_ACTIVE if vcam_active else COLOR_INACTIVE
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn_vcam.add_theme_stylebox_override("normal", style)
	
	if btn_mode:
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_ACTIVE if gpu_mode else COLOR_INACTIVE
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn_mode.add_theme_stylebox_override("normal", style)
		btn_mode.text = "GPU" if gpu_mode else "CPU"

func print_help() -> void:
	"""Print quickbar usage"""
	print("==================================================")
	print("  SIMPLE QUICKBAR")
	print("==================================================")
	print("  [L] Landmarks: %s" % ("VISIBLE" if landmarks_visible else "HIDDEN"))
	print("  [V] VCam: %s (coming soon)" % ("ON" if vcam_active else "OFF"))
	print("  [G/C] Mode: %s" % ("GPU" if gpu_mode else "CPU"))
	print("==================================================")
