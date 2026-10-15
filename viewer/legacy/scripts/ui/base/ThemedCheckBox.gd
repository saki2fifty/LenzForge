# ================================================================================================
# ThemedCheckBox.gd
# ================================================================================================
# Theme-aware checkbox component with smooth animations and custom styling
# Automatically updates styling when theme changes via ThemeManager
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends CheckBox

# ================================================================================================
# EXPORTS
# ================================================================================================

@export_group("CheckBox Appearance")
## Size of the checkbox square (pixels)
@export_range(16, 48) var checkbox_size: int = 24

## Enable smooth check/uncheck animation
@export var animate_state_change: bool = true

## Duration of check/uncheck animation (seconds)
@export_range(0.1, 0.5) var animation_duration: float = 0.2

## Enable glow effect when checked
@export var enable_glow: bool = true

## Glow intensity (0.0 to 1.0)
@export_range(0.0, 1.0) var glow_intensity: float = 0.5

@export_group("CheckBox Behavior")
## Enable hover scale effect
@export var enable_hover_effect: bool = true

## Hover scale multiplier
@export_range(1.0, 1.2) var hover_scale: float = 1.05

## Enable click feedback animation
@export var enable_click_feedback: bool = true

# ================================================================================================
# INTERNAL STATE
# ================================================================================================

var _checkbox_unchecked_style: StyleBoxFlat = null
var _checkbox_checked_style: StyleBoxFlat = null
var _checkbox_hover_style: StyleBoxFlat = null
var _checkbox_pressed_style: StyleBoxFlat = null
var _checkbox_disabled_style: StyleBoxFlat = null

var _checkmark_icon: TextureRect = null
var _is_hovering: bool = false
var _animation_tween: Tween = null

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_setup_checkbox_styles()
	_setup_checkmark_icon()
	_connect_signals()
	_apply_current_theme()
	_update_checkmark_visibility()
	print("[ThemedCheckBox] Initialized: %s" % name)

func _exit_tree() -> void:
	_disconnect_signals()

# ================================================================================================
# SETUP
# ================================================================================================

func _setup_checkbox_styles() -> void:
	"""Create StyleBox resources for checkbox states"""
	
	# Unchecked state
	_checkbox_unchecked_style = StyleBoxFlat.new()
	_checkbox_unchecked_style.corner_radius_top_left = 4
	_checkbox_unchecked_style.corner_radius_top_right = 4
	_checkbox_unchecked_style.corner_radius_bottom_left = 4
	_checkbox_unchecked_style.corner_radius_bottom_right = 4
	_checkbox_unchecked_style.border_width_left = 2
	_checkbox_unchecked_style.border_width_right = 2
	_checkbox_unchecked_style.border_width_top = 2
	_checkbox_unchecked_style.border_width_bottom = 2
	_checkbox_unchecked_style.content_margin_left = 4
	_checkbox_unchecked_style.content_margin_right = 4
	_checkbox_unchecked_style.content_margin_top = 4
	_checkbox_unchecked_style.content_margin_bottom = 4
	
	# Checked state
	_checkbox_checked_style = StyleBoxFlat.new()
	_checkbox_checked_style.corner_radius_top_left = 4
	_checkbox_checked_style.corner_radius_top_right = 4
	_checkbox_checked_style.corner_radius_bottom_left = 4
	_checkbox_checked_style.corner_radius_bottom_right = 4
	_checkbox_checked_style.border_width_left = 2
	_checkbox_checked_style.border_width_right = 2
	_checkbox_checked_style.border_width_top = 2
	_checkbox_checked_style.border_width_bottom = 2
	_checkbox_checked_style.content_margin_left = 4
	_checkbox_checked_style.content_margin_right = 4
	_checkbox_checked_style.content_margin_top = 4
	_checkbox_checked_style.content_margin_bottom = 4
	
	# Hover state
	_checkbox_hover_style = StyleBoxFlat.new()
	_checkbox_hover_style.corner_radius_top_left = 4
	_checkbox_hover_style.corner_radius_top_right = 4
	_checkbox_hover_style.corner_radius_bottom_left = 4
	_checkbox_hover_style.corner_radius_bottom_right = 4
	_checkbox_hover_style.border_width_left = 2
	_checkbox_hover_style.border_width_right = 2
	_checkbox_hover_style.border_width_top = 2
	_checkbox_hover_style.border_width_bottom = 2
	_checkbox_hover_style.shadow_size = 4
	_checkbox_hover_style.shadow_offset = Vector2(0, 2)
	_checkbox_hover_style.content_margin_left = 4
	_checkbox_hover_style.content_margin_right = 4
	_checkbox_hover_style.content_margin_top = 4
	_checkbox_hover_style.content_margin_bottom = 4
	
	# Pressed state
	_checkbox_pressed_style = StyleBoxFlat.new()
	_checkbox_pressed_style.corner_radius_top_left = 4
	_checkbox_pressed_style.corner_radius_top_right = 4
	_checkbox_pressed_style.corner_radius_bottom_left = 4
	_checkbox_pressed_style.corner_radius_bottom_right = 4
	_checkbox_pressed_style.border_width_left = 2
	_checkbox_pressed_style.border_width_right = 2
	_checkbox_pressed_style.border_width_top = 2
	_checkbox_pressed_style.border_width_bottom = 2
	_checkbox_pressed_style.content_margin_left = 4
	_checkbox_pressed_style.content_margin_right = 4
	_checkbox_pressed_style.content_margin_top = 4
	_checkbox_pressed_style.content_margin_bottom = 4
	
	# Disabled state
	_checkbox_disabled_style = StyleBoxFlat.new()
	_checkbox_disabled_style.corner_radius_top_left = 4
	_checkbox_disabled_style.corner_radius_top_right = 4
	_checkbox_disabled_style.corner_radius_bottom_left = 4
	_checkbox_disabled_style.corner_radius_bottom_right = 4
	_checkbox_disabled_style.border_width_left = 2
	_checkbox_disabled_style.border_width_right = 2
	_checkbox_disabled_style.border_width_top = 2
	_checkbox_disabled_style.border_width_bottom = 2
	_checkbox_disabled_style.content_margin_left = 4
	_checkbox_disabled_style.content_margin_right = 4
	_checkbox_disabled_style.content_margin_top = 4
	_checkbox_disabled_style.content_margin_bottom = 4
	
	# Apply styles to checkbox
	add_theme_stylebox_override("normal", _checkbox_unchecked_style)
	add_theme_stylebox_override("checked", _checkbox_checked_style)
	add_theme_stylebox_override("hover", _checkbox_hover_style)
	add_theme_stylebox_override("pressed", _checkbox_pressed_style)
	add_theme_stylebox_override("disabled", _checkbox_disabled_style)
	
	# Set checkbox icon size
	custom_minimum_size = Vector2(checkbox_size, checkbox_size)

func _setup_checkmark_icon() -> void:
	"""Create checkmark visual indicator using a Label with custom character"""
	# Note: In production, you'd use a proper icon/texture
	# For now, we'll use a simple Label with a checkmark character
	_checkmark_icon = TextureRect.new()
	_checkmark_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_checkmark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_checkmark_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Position centered in checkbox
	_checkmark_icon.position = Vector2(4, 4)
	_checkmark_icon.size = Vector2(checkbox_size - 8, checkbox_size - 8)
	_checkmark_icon.modulate = Color.WHITE
	
	add_child(_checkmark_icon)
	
	# Initially hidden until checked
	_checkmark_icon.visible = button_pressed

# ================================================================================================
# SIGNAL CONNECTIONS
# ================================================================================================

func _connect_signals() -> void:
	"""Connect to relevant signals"""
	if ThemeManager:
		if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.connect(_on_theme_changed)
	
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _disconnect_signals() -> void:
	"""Disconnect signals on cleanup"""
	if ThemeManager:
		if ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.disconnect(_on_theme_changed)
	
	if toggled.is_connected(_on_toggled):
		toggled.disconnect(_on_toggled)
	
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)

# ================================================================================================
# THEME APPLICATION
# ================================================================================================

func _apply_current_theme() -> void:
	"""Apply current theme colors to checkbox states"""
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
	
	# Unchecked state: transparent background with border
	_checkbox_unchecked_style.bg_color = Color(secondary_color, 0.1)
	_checkbox_unchecked_style.border_color = Color(accent_color, 0.5)
	
	# Checked state: filled with accent color
	_checkbox_checked_style.bg_color = accent_color
	_checkbox_checked_style.border_color = accent_color
	
	if enable_glow:
		_checkbox_checked_style.shadow_size = 8
		_checkbox_checked_style.shadow_color = Color(accent_color, glow_intensity)
	
	# Hover state: highlight color
	_checkbox_hover_style.bg_color = Color(accent_color, 0.2)
	_checkbox_hover_style.border_color = highlight_color
	_checkbox_hover_style.shadow_color = Color(highlight_color, 0.3)
	
	# Pressed state: full highlight
	_checkbox_pressed_style.bg_color = Color(highlight_color, 0.3)
	_checkbox_pressed_style.border_color = highlight_color
	
	# Disabled state: muted colors
	_checkbox_disabled_style.bg_color = Color(secondary_color, 0.3)
	_checkbox_disabled_style.border_color = Color(secondary_color, 0.5)
	
	# Apply text color
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", highlight_color)
	add_theme_color_override("font_pressed_color", highlight_color)
	add_theme_color_override("font_disabled_color", Color(text_color, 0.5))
	
	# Apply UI scale to font size
	var base_font_size := 14
	var scaled_font_size := int(base_font_size * ui_scale)
	add_theme_font_size_override("font_size", scaled_font_size)
	
	# Update checkmark color
	if _checkmark_icon:
		_checkmark_icon.modulate = Color.WHITE

func _on_theme_changed(_theme_id: String) -> void:
	"""Handle theme changes"""
	_apply_current_theme()

# ================================================================================================
# STATE MANAGEMENT
# ================================================================================================

func _update_checkmark_visibility() -> void:
	"""Update checkmark icon visibility based on checked state"""
	if not _checkmark_icon:
		return
	
	if animate_state_change:
		_animate_checkmark(button_pressed)
	else:
		_checkmark_icon.visible = button_pressed
		_checkmark_icon.scale = Vector2(1.0, 1.0) if button_pressed else Vector2(0.0, 0.0)

func _animate_checkmark(should_show: bool) -> void:
	"""Animate checkmark appearance/disappearance"""
	if _animation_tween and _animation_tween.is_running():
		_animation_tween.kill()
	
	_checkmark_icon.visible = true
	
	_animation_tween = create_tween()
	_animation_tween.set_ease(Tween.EASE_OUT)
	_animation_tween.set_trans(Tween.TRANS_BACK)
	
	if should_show:
		# Scale from 0 to 1 (pop in)
		_checkmark_icon.scale = Vector2(0.0, 0.0)
		_animation_tween.tween_property(_checkmark_icon, "scale", Vector2(1.0, 1.0), animation_duration)
	else:
		# Scale from 1 to 0 (pop out)
		_animation_tween.tween_property(_checkmark_icon, "scale", Vector2(0.0, 0.0), animation_duration)
		_animation_tween.tween_callback(func(): _checkmark_icon.visible = false)

# ================================================================================================
# INTERACTION HANDLERS
# ================================================================================================

func _on_toggled(toggled_on: bool) -> void:
	"""Handle checkbox toggle"""
	_update_checkmark_visibility()
	
	if enable_click_feedback:
		_play_click_feedback()

func _on_mouse_entered() -> void:
	"""Handle mouse enter"""
	_is_hovering = true
	
	if enable_hover_effect and not disabled:
		_play_hover_animation(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exit"""
	_is_hovering = false
	
	if enable_hover_effect:
		_play_hover_animation(false)

# ================================================================================================
# ANIMATIONS
# ================================================================================================

func _play_hover_animation(hovering: bool) -> void:
	"""Play hover scale animation"""
	var target_scale := Vector2(hover_scale, hover_scale) if hovering else Vector2(1.0, 1.0)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", target_scale, 0.15)

func _play_click_feedback() -> void:
	"""Play click feedback animation (quick bounce)"""
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

# ================================================================================================
# PUBLIC API
# ================================================================================================

func set_checked(checked: bool, animate: bool = true) -> void:
	"""
	Set checkbox state programmatically
	
	Args:
		checked: Whether checkbox should be checked
		animate: Whether to animate the change (default: true)
	"""
	var old_animate_setting := animate_state_change
	animate_state_change = animate
	
	button_pressed = checked
	_update_checkmark_visibility()
	
	animate_state_change = old_animate_setting

func get_checked() -> bool:
	"""Get checkbox checked state"""
	return button_pressed

func toggle_animated() -> void:
	"""Toggle checkbox with animation"""
	set_checked(not button_pressed, true)

func flash_checkbox(flash_color: Color, duration: float = 0.3) -> void:
	"""
	Flash checkbox with a color briefly (useful for feedback)
	
	Args:
		flash_color: Color to flash
		duration: Duration of flash effect
	"""
	var style := _checkbox_checked_style if button_pressed else _checkbox_unchecked_style
	var original_color := style.bg_color
	
	var tween := create_tween()
	tween.tween_property(style, "bg_color", flash_color, duration / 2)
	tween.tween_property(style, "bg_color", original_color, duration / 2)

func pulse_checkbox(duration: float = 0.5) -> void:
	"""
	Create a subtle pulse animation (useful for drawing attention)
	
	Args:
		duration: Duration of one pulse cycle
	"""
	var tween := create_tween()
	tween.set_loops(2)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), duration / 2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration / 2)

# ================================================================================================
# OVERRIDES
# ================================================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _checkmark_icon:
			_checkmark_icon.position = Vector2(4, 4)
			_checkmark_icon.size = Vector2(checkbox_size - 8, checkbox_size - 8)
