# ================================================================================================
# ThemedSlider.gd
# ================================================================================================
# Theme-aware slider component with value display and smooth interactions
# Automatically updates styling when theme changes via ThemeManager
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends HSlider

# ================================================================================================
# EXPORTS
# ================================================================================================

@export_group("Slider Appearance")
## Whether to show value label next to slider
@export var show_value_label: bool = true

## Format string for value display (e.g., "%.1f", "%.0f%%", "%d")
@export var value_format: String = "%.1f"

## Label position relative to slider
@export_enum("Right", "Left", "Above", "Below") var label_position: String = "Right"

## Spacing between slider and label (pixels)
@export_range(4, 32) var label_spacing: float = 8.0

@export_group("Slider Behavior")
## Enable smooth value changes with animation
@export var smooth_value_changes: bool = false

## Duration of smooth value animation (seconds)
@export_range(0.05, 0.5) var smooth_duration: float = 0.15

## Enable haptic feedback on value change (visual bounce effect)
@export var enable_haptic_feedback: bool = true

# ================================================================================================
# INTERNAL STATE
# ================================================================================================

var _value_label: Label = null
var _grabber_style: StyleBoxFlat = null
var _grabber_highlight_style: StyleBoxFlat = null
var _slider_style: StyleBoxFlat = null
var _grabber_area_style: StyleBoxFlat = null
var _grabber_area_highlight_style: StyleBoxFlat = null

var _is_dragging: bool = false
var _smooth_tween: Tween = null

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_setup_slider_styles()
	_setup_value_label()
	_connect_signals()
	_apply_current_theme()
	print("[ThemedSlider] Initialized: %s" % name)

func _exit_tree() -> void:
	_disconnect_signals()

# ================================================================================================
# SETUP
# ================================================================================================

func _setup_slider_styles() -> void:
	"""Create StyleBox resources for slider components"""
	
	# Grabber (the draggable handle)
	_grabber_style = StyleBoxFlat.new()
	_grabber_style.corner_radius_top_left = 8
	_grabber_style.corner_radius_top_right = 8
	_grabber_style.corner_radius_bottom_left = 8
	_grabber_style.corner_radius_bottom_right = 8
	_grabber_style.content_margin_left = 0
	_grabber_style.content_margin_right = 0
	_grabber_style.content_margin_top = 0
	_grabber_style.content_margin_bottom = 0
	
	# Grabber highlight (when hovering/dragging)
	_grabber_highlight_style = StyleBoxFlat.new()
	_grabber_highlight_style.corner_radius_top_left = 8
	_grabber_highlight_style.corner_radius_top_right = 8
	_grabber_highlight_style.corner_radius_bottom_left = 8
	_grabber_highlight_style.corner_radius_bottom_right = 8
	_grabber_highlight_style.shadow_size = 4
	_grabber_highlight_style.shadow_offset = Vector2(0, 2)
	
	# Slider background (unfilled portion)
	_slider_style = StyleBoxFlat.new()
	_slider_style.corner_radius_top_left = 4
	_slider_style.corner_radius_top_right = 4
	_slider_style.corner_radius_bottom_left = 4
	_slider_style.corner_radius_bottom_right = 4
	_slider_style.content_margin_left = 0
	_slider_style.content_margin_right = 0
	_slider_style.content_margin_top = 4
	_slider_style.content_margin_bottom = 4
	
	# Grabber area (filled portion showing progress)
	_grabber_area_style = StyleBoxFlat.new()
	_grabber_area_style.corner_radius_top_left = 4
	_grabber_area_style.corner_radius_top_right = 4
	_grabber_area_style.corner_radius_bottom_left = 4
	_grabber_area_style.corner_radius_bottom_right = 4
	_grabber_area_style.content_margin_left = 0
	_grabber_area_style.content_margin_right = 0
	_grabber_area_style.content_margin_top = 4
	_grabber_area_style.content_margin_bottom = 4
	
	# Grabber area highlight (when hovering/dragging)
	_grabber_area_highlight_style = StyleBoxFlat.new()
	_grabber_area_highlight_style.corner_radius_top_left = 4
	_grabber_area_highlight_style.corner_radius_top_right = 4
	_grabber_area_highlight_style.corner_radius_bottom_left = 4
	_grabber_area_highlight_style.corner_radius_bottom_right = 4
	_grabber_area_highlight_style.content_margin_left = 0
	_grabber_area_highlight_style.content_margin_right = 0
	_grabber_area_highlight_style.content_margin_top = 4
	_grabber_area_highlight_style.content_margin_bottom = 4
	
	# Apply styles to slider
	add_theme_stylebox_override("slider", _slider_style)
	add_theme_stylebox_override("grabber_area", _grabber_area_style)
	add_theme_stylebox_override("grabber_area_highlight", _grabber_area_highlight_style)
	add_theme_stylebox_override("grabber", _grabber_style)
	add_theme_stylebox_override("grabber_highlight", _grabber_highlight_style)

func _setup_value_label() -> void:
	"""Create and position value label"""
	if not show_value_label:
		return
	
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size = Vector2(60, 0)
	
	add_child(_value_label)
	_update_label_position()
	_update_value_label()

func _update_label_position() -> void:
	"""Position label based on label_position setting"""
	if not _value_label:
		return
	
	match label_position:
		"Right":
			_value_label.position = Vector2(size.x + label_spacing, (size.y - _value_label.size.y) / 2)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		"Left":
			_value_label.position = Vector2(-_value_label.size.x - label_spacing, (size.y - _value_label.size.y) / 2)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"Above":
			_value_label.position = Vector2((size.x - _value_label.size.x) / 2, -_value_label.size.y - label_spacing)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"Below":
			_value_label.position = Vector2((size.x - _value_label.size.x) / 2, size.y + label_spacing)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ================================================================================================
# SIGNAL CONNECTIONS
# ================================================================================================

func _connect_signals() -> void:
	"""Connect to relevant signals"""
	if ThemeManager:
		if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.connect(_on_theme_changed)
	
	if not value_changed.is_connected(_on_value_changed):
		value_changed.connect(_on_value_changed)
	
	if not drag_started.is_connected(_on_drag_started):
		drag_started.connect(_on_drag_started)
	
	if not drag_ended.is_connected(_on_drag_ended):
		drag_ended.connect(_on_drag_ended)

func _disconnect_signals() -> void:
	"""Disconnect signals on cleanup"""
	if ThemeManager:
		if ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.disconnect(_on_theme_changed)
	
	if value_changed.is_connected(_on_value_changed):
		value_changed.disconnect(_on_value_changed)
	
	if drag_started.is_connected(_on_drag_started):
		drag_started.disconnect(_on_drag_started)
	
	if drag_ended.is_connected(_on_drag_ended):
		drag_ended.disconnect(_on_drag_ended)

# ================================================================================================
# THEME APPLICATION
# ================================================================================================

func _apply_current_theme() -> void:
	"""Apply current theme colors to slider components"""
	if not ThemeManager:
		return
	
	var ui_scale: float = 1.0
	if SettingsManager:
		ui_scale = SettingsManager.get_setting("ui", "ui_scale", 1.0)
	
	# Get theme colors
	var accent_color := ThemeManager.get_base_color("accent")
	var highlight_color := ThemeManager.get_base_color("highlight")
	var secondary_color := ThemeManager.get_base_color("secondary")
	var text_color := ThemeManager.get_base_color("text_primary")
	var background_color := ThemeManager.get_base_color("background")
	
	# Apply grabber colors
	_grabber_style.bg_color = accent_color
	_grabber_highlight_style.bg_color = highlight_color
	_grabber_highlight_style.shadow_color = Color(highlight_color, 0.5)
	
	# Apply slider background
	_slider_style.bg_color = Color(secondary_color, 0.3)
	
	# Apply grabber area (filled portion)
	_grabber_area_style.bg_color = Color(accent_color, 0.5)
	_grabber_area_highlight_style.bg_color = Color(highlight_color, 0.7)
	
	# Apply label colors
	if _value_label:
		_value_label.add_theme_color_override("font_color", text_color)
		
		# Apply UI scale to label font size
		var base_font_size := 14
		var scaled_font_size := int(base_font_size * ui_scale)
		_value_label.add_theme_font_size_override("font_size", scaled_font_size)

func _on_theme_changed(_theme_id: String) -> void:
	"""Handle theme changes"""
	_apply_current_theme()

# ================================================================================================
# VALUE MANAGEMENT
# ================================================================================================

func set_value_smooth(new_value: float) -> void:
	"""
	Set slider value with smooth animation
	
	Args:
		new_value: Target value to animate to
	"""
	if not smooth_value_changes:
		value = new_value
		return
	
	# Cancel existing tween
	if _smooth_tween and _smooth_tween.is_running():
		_smooth_tween.kill()
	
	_smooth_tween = create_tween()
	_smooth_tween.set_ease(Tween.EASE_OUT)
	_smooth_tween.set_trans(Tween.TRANS_CUBIC)
	_smooth_tween.tween_property(self, "value", new_value, smooth_duration)

func _update_value_label() -> void:
	"""Update label text with current value"""
	if not _value_label:
		return
	
	_value_label.text = value_format % value

func _on_value_changed(new_value: float) -> void:
	"""Handle value changes"""
	_update_value_label()
	
	# Haptic feedback animation
	if enable_haptic_feedback and _is_dragging:
		_play_haptic_feedback()

# ================================================================================================
# DRAG HANDLING
# ================================================================================================

func _on_drag_started() -> void:
	"""Handle drag start"""
	_is_dragging = true
	
	# Apply highlight styles
	remove_theme_stylebox_override("grabber")
	add_theme_stylebox_override("grabber", _grabber_highlight_style)
	
	remove_theme_stylebox_override("grabber_area")
	add_theme_stylebox_override("grabber_area", _grabber_area_highlight_style)

func _on_drag_ended(_value_changed: bool) -> void:
	"""Handle drag end"""
	_is_dragging = false
	
	# Restore normal styles
	remove_theme_stylebox_override("grabber")
	add_theme_stylebox_override("grabber", _grabber_style)
	
	remove_theme_stylebox_override("grabber_area")
	add_theme_stylebox_override("grabber_area", _grabber_area_style)

# ================================================================================================
# HAPTIC FEEDBACK
# ================================================================================================

func _play_haptic_feedback() -> void:
	"""Play subtle visual haptic feedback on value change"""
	if not _grabber_style:
		return
	
	# Quick scale bounce animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

# ================================================================================================
# PUBLIC API
# ================================================================================================

func set_value_range(min_val: float, max_val: float, step_val: float = 1.0) -> void:
	"""
	Set slider range and step in one call
	
	Args:
		min_val: Minimum value
		max_val: Maximum value
		step_val: Step increment (default: 1.0)
	"""
	min_value = min_val
	max_value = max_val
	step = step_val

func get_value_percentage() -> float:
	"""
	Get current value as percentage (0.0 to 1.0)
	
	Returns:
		Value normalized to 0.0-1.0 range
	"""
	if max_value == min_value:
		return 0.0
	return (value - min_value) / (max_value - min_value)

func set_value_percentage(percentage: float) -> void:
	"""
	Set value from percentage (0.0 to 1.0)
	
	Args:
		percentage: Value as percentage (0.0 to 1.0)
	"""
	var new_value := min_value + (percentage * (max_value - min_value))
	if smooth_value_changes:
		set_value_smooth(new_value)
	else:
		value = new_value

func animate_value_to(target_value: float, duration: float = 0.3) -> void:
	"""
	Animate slider value to target over duration
	
	Args:
		target_value: Target value to animate to
		duration: Animation duration in seconds
	"""
	if _smooth_tween and _smooth_tween.is_running():
		_smooth_tween.kill()
	
	_smooth_tween = create_tween()
	_smooth_tween.set_ease(Tween.EASE_IN_OUT)
	_smooth_tween.set_trans(Tween.TRANS_CUBIC)
	_smooth_tween.tween_property(self, "value", target_value, duration)

func flash_slider(flash_color: Color, duration: float = 0.2) -> void:
	"""
	Flash slider with a color briefly (useful for feedback)
	
	Args:
		flash_color: Color to flash
		duration: Duration of flash effect
	"""
	var original_color := _grabber_area_style.bg_color
	
	var tween := create_tween()
	tween.tween_property(_grabber_area_style, "bg_color", flash_color, duration / 2)
	tween.tween_property(_grabber_area_style, "bg_color", original_color, duration / 2)

# ================================================================================================
# OVERRIDES
# ================================================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_label_position()
