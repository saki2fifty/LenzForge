extends Panel

## BasePanel.gd
## Base panel component with glassmorphism effects and theme integration
## Provides semi-transparent background, backdrop blur, and themed styling

@export var blur_amount: int = 10
@export var panel_opacity: float = 0.85
@export var border_thickness: int = 1
@export var corner_radius: int = 8
@export var enable_glassmorphism: bool = true

## Panel style resources
var panel_style: StyleBoxFlat

## Theme update flag
var theme_transition_active: bool = false


func _ready() -> void:
	# Create initial panel style
	_create_panel_style()
	
	# Connect to theme manager
	if ThemeManager:
		ThemeManager.theme_changed.connect(_on_theme_changed)
		ThemeManager.theme_transition_started.connect(_on_theme_transition_started)
		ThemeManager.theme_transition_completed.connect(_on_theme_transition_completed)
		
		# Apply current theme immediately
		_apply_current_theme()
	
	# Listen for settings changes
	if SettingsManager:
		SettingsManager.setting_changed.connect(_on_setting_changed)


func _create_panel_style() -> void:
	# Create StyleBoxFlat for panel
	panel_style = StyleBoxFlat.new()
	
	# Set corner radius
	panel_style.corner_radius_top_left = corner_radius
	panel_style.corner_radius_top_right = corner_radius
	panel_style.corner_radius_bottom_left = corner_radius
	panel_style.corner_radius_bottom_right = corner_radius
	
	# Enable anti-aliasing for smooth corners
	panel_style.anti_aliasing = true
	panel_style.anti_aliasing_size = 2
	
	# Apply to panel
	add_theme_stylebox_override("panel", panel_style)


func _apply_current_theme() -> void:
	if not ThemeManager:
		return
	
	# Get panel colors from theme
	var bg_color := ThemeManager.get_panel_color("background")
	var border_color := ThemeManager.get_panel_color("border")
	
	# Apply opacity to background
	bg_color.a = panel_opacity
	
	# Set panel background
	panel_style.bg_color = bg_color
	
	# Set border
	panel_style.border_width_left = border_thickness
	panel_style.border_width_right = border_thickness
	panel_style.border_width_top = border_thickness
	panel_style.border_width_bottom = border_thickness
	panel_style.border_color = border_color
	
	# Get additional panel properties from theme
	var theme_blur: int = ThemeManager.get_panel_property("blur_amount")
	if theme_blur > 0:
		blur_amount = theme_blur
	
	# Apply glassmorphism if enabled
	if enable_glassmorphism:
		_apply_glassmorphism()


func _apply_glassmorphism() -> void:
	# Glassmorphism effect uses StyleBoxFlat with shadow and subtle effects
	# Note: Real backdrop blur requires shader - this simulates the effect
	
	# Add subtle shadow for depth
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 2)
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	
	# Increase border brightness slightly for glass edge effect
	var border_color := panel_style.border_color
	border_color = border_color.lightened(0.2)
	panel_style.border_color = border_color


func _on_theme_changed(theme_id: String) -> void:
	# Theme changed - update panel styling
	_apply_current_theme()


func _on_theme_transition_started(from_theme: String, to_theme: String) -> void:
	theme_transition_active = true


func _on_theme_transition_completed(theme_id: String) -> void:
	theme_transition_active = false


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	# React to relevant settings changes
	match section:
		"ui":
			match key:
				"panel_opacity":
					set_panel_opacity(value)
				"blur_amount":
					set_blur_amount(value)


## Set panel opacity (0.0 - 1.0)
func set_panel_opacity(opacity: float) -> void:
	panel_opacity = clamp(opacity, 0.0, 1.0)
	
	if panel_style:
		var bg_color := panel_style.bg_color
		bg_color.a = panel_opacity
		panel_style.bg_color = bg_color


## Set blur amount (pixels)
func set_blur_amount(amount: int) -> void:
	blur_amount = clamp(amount, 0, 30)
	# Note: Actual blur requires shader implementation


## Set corner radius
func set_corner_radius(radius: int) -> void:
	corner_radius = clamp(radius, 0, 32)
	
	if panel_style:
		panel_style.corner_radius_top_left = corner_radius
		panel_style.corner_radius_top_right = corner_radius
		panel_style.corner_radius_bottom_left = corner_radius
		panel_style.corner_radius_bottom_right = corner_radius


## Set border thickness
func set_border_thickness(thickness: int) -> void:
	border_thickness = clamp(thickness, 0, 10)
	
	if panel_style:
		panel_style.border_width_left = border_thickness
		panel_style.border_width_right = border_thickness
		panel_style.border_width_top = border_thickness
		panel_style.border_width_bottom = border_thickness


## Enable/disable glassmorphism
func set_glassmorphism_enabled(enabled: bool) -> void:
	enable_glassmorphism = enabled
	
	if enabled:
		_apply_glassmorphism()
	else:
		# Remove glassmorphism effects
		if panel_style:
			panel_style.shadow_size = 0
			panel_style.shadow_offset = Vector2.ZERO


## Get current panel background color
func get_panel_color() -> Color:
	if panel_style:
		return panel_style.bg_color
	return Color.WHITE


## Set custom panel color (overrides theme)
func set_panel_color(color: Color) -> void:
	if panel_style:
		var current_alpha := panel_style.bg_color.a
		color.a = current_alpha  # Preserve opacity
		panel_style.bg_color = color


## Set custom border color (overrides theme)
func set_border_color(color: Color) -> void:
	if panel_style:
		panel_style.border_color = color
