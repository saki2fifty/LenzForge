extends Button

## ThemedButton.gd
## Themed button with automatic style updates for all states
## Supports normal, hover, pressed, disabled, and active states

@export var enable_hover_effects: bool = true
@export var hover_scale: float = 1.05
@export var enable_glow: bool = false
@export var transition_duration: float = 0.15

## Button style resources for each state
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var pressed_style: StyleBoxFlat
var disabled_style: StyleBoxFlat

## Animation tween
var style_tween: Tween


func _ready() -> void:
	# Create button styles
	_create_button_styles()
	
	# Connect to theme manager
	if ThemeManager:
		ThemeManager.theme_changed.connect(_on_theme_changed)
		
		# Apply current theme immediately
		_apply_current_theme()
	
	# Connect to settings manager
	if SettingsManager:
		SettingsManager.setting_changed.connect(_on_setting_changed)
	
	# Connect to button signals for hover effects
	if enable_hover_effects:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


func _create_button_styles() -> void:
	# Create StyleBoxFlat for each button state
	normal_style = _create_stylebox()
	hover_style = _create_stylebox()
	pressed_style = _create_stylebox()
	disabled_style = _create_stylebox()
	
	# Apply styles to button
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)


func _create_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	
	# Set corner radius
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	# Enable anti-aliasing
	style.anti_aliasing = true
	style.anti_aliasing_size = 1
	
	# Set content margin (padding)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	return style


func _apply_current_theme() -> void:
	if not ThemeManager:
		return
	
	# Get button colors from theme
	var normal_color := ThemeManager.get_button_color("normal")
	var hover_color := ThemeManager.get_button_color("hover")
	var pressed_color := ThemeManager.get_button_color("pressed")
	var disabled_color := ThemeManager.get_button_color("disabled")
	var border_color := ThemeManager.get_button_color("border")
	
	# Apply colors to styles
	_apply_style_colors(normal_style, normal_color, border_color, 1)
	_apply_style_colors(hover_style, hover_color, border_color, 2)
	_apply_style_colors(pressed_style, pressed_color, border_color, 1)
	_apply_style_colors(disabled_style, disabled_color, border_color.darkened(0.3), 1)
	
	# Update text color
	var text_color := ThemeManager.get_color("text", "primary")
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", text_color)
	add_theme_color_override("font_pressed_color", text_color)
	add_theme_color_override("font_disabled_color", text_color.darkened(0.5))


func _apply_style_colors(style: StyleBoxFlat, bg_color: Color, border_color: Color, border_width: int) -> void:
	# Set background color
	style.bg_color = bg_color
	
	# Set border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	
	# Add subtle shadow for depth
	if style == normal_style or style == hover_style:
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
		style.shadow_color = Color(0, 0, 0, 0.2)
	
	# Glow effect for hover
	if style == hover_style and enable_glow:
		style.shadow_size = 8
		style.shadow_color = bg_color
		style.shadow_color.a = 0.6


func _on_theme_changed(theme_id: String) -> void:
	# Theme changed - update button styling
	_apply_current_theme()


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	# React to relevant settings changes
	match section:
		"ui":
			match key:
				"enable_animations":
					var animations_enabled: bool = value
					enable_hover_effects = animations_enabled


func _on_mouse_entered() -> void:
	if not enable_hover_effects or disabled:
		return
	
	# Animate scale up
	_animate_scale(hover_scale)


func _on_mouse_exited() -> void:
	if not enable_hover_effects:
		return
	
	# Animate scale back to normal
	_animate_scale(1.0)


func _animate_scale(target_scale: float) -> void:
	# Kill existing tween
	if style_tween:
		style_tween.kill()
	
	# Create new tween
	style_tween = create_tween()
	style_tween.set_ease(Tween.EASE_OUT)
	style_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate scale
	style_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), transition_duration)


## Set button as "active" state (like a toggle button)
func set_active(active: bool) -> void:
	if active:
		# Use hover style for active state
		add_theme_stylebox_override("normal", hover_style)
	else:
		# Use normal style
		add_theme_stylebox_override("normal", normal_style)


## Set custom button color (overrides theme)
func set_button_color(state: String, color: Color) -> void:
	match state:
		"normal":
			if normal_style:
				normal_style.bg_color = color
		"hover":
			if hover_style:
				hover_style.bg_color = color
		"pressed":
			if pressed_style:
				pressed_style.bg_color = color
		"disabled":
			if disabled_style:
				disabled_style.bg_color = color


## Set button corner radius
func set_corner_radius(radius: int) -> void:
	radius = clamp(radius, 0, 16)
	
	for style in [normal_style, hover_style, pressed_style, disabled_style]:
		if style:
			style.corner_radius_top_left = radius
			style.corner_radius_top_right = radius
			style.corner_radius_bottom_left = radius
			style.corner_radius_bottom_right = radius


## Enable/disable glow effect
func set_glow_enabled(enabled: bool) -> void:
	enable_glow = enabled
	_apply_current_theme()


## Set hover scale multiplier
func set_hover_scale(scale: float) -> void:
	hover_scale = clamp(scale, 1.0, 1.5)
