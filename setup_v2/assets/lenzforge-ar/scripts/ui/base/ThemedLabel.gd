extends Label

## ThemedLabel.gd
## Themed label with automatic color and font updates
## Supports primary, secondary, and accent text styles

@export_enum("primary", "secondary", "accent", "warning", "error") var text_style: String = "primary"
@export var enable_shadow: bool = false
@export var shadow_offset: Vector2 = Vector2(1, 1)
@export var shadow_color: Color = Color(0, 0, 0, 0.5)

## Font size multiplier for different styles
const FONT_SIZE_MULTIPLIERS := {
	"heading": 1.5,
	"subheading": 1.2,
	"body": 1.0,
	"caption": 0.85,
	"small": 0.75
}

@export_enum("heading", "subheading", "body", "caption", "small") var font_size_style: String = "body"


func _ready() -> void:
	# Connect to theme manager
	if ThemeManager:
		ThemeManager.theme_changed.connect(_on_theme_changed)
		
		# Apply current theme immediately
		_apply_current_theme()
	
	# Connect to settings manager
	if SettingsManager:
		SettingsManager.setting_changed.connect(_on_setting_changed)


func _apply_current_theme() -> void:
	if not ThemeManager:
		return
	
	# Get text color based on style
	var text_color: Color
	match text_style:
		"primary":
			text_color = ThemeManager.get_base_color("text_primary")
		"secondary":
			text_color = ThemeManager.get_base_color("text_secondary")
		"accent":
			text_color = ThemeManager.get_base_color("accent")
		"warning":
			text_color = Color(1.0, 0.8, 0.0)  # Yellow/orange
		"error":
			text_color = Color(1.0, 0.3, 0.3)  # Red
		_:
			text_color = ThemeManager.get_base_color("text_primary")
	
	# Apply color
	add_theme_color_override("font_color", text_color)
	
	# Apply shadow if enabled
	if enable_shadow:
		add_theme_color_override("font_shadow_color", shadow_color)
		add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
		add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))
		add_theme_constant_override("shadow_outline_size", 1)
	
	# Apply font size based on style
	_apply_font_size()


func _apply_font_size() -> void:
	if not SettingsManager:
		return
	
	# Get base UI scale (use explicit type to avoid inference issues)
	var ui_scale: float = SettingsManager.get_setting("ui", "ui_scale", 1.0)
	
	# Get font size multiplier for this style
	var size_multiplier: float = FONT_SIZE_MULTIPLIERS.get(font_size_style, 1.0)
	
	# Calculate final font size (base 16px)
	var final_size := int(16.0 * ui_scale * size_multiplier)
	
	# Apply font size
	add_theme_font_size_override("font_size", final_size)


func _on_theme_changed(theme_id: String) -> void:
	# Theme changed - update label styling
	_apply_current_theme()


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	# React to UI scale changes
	match section:
		"ui":
			match key:
				"ui_scale":
					_apply_font_size()


## Set text style (primary, secondary, accent, warning, error)
func set_text_style(style: String) -> void:
	text_style = style
	_apply_current_theme()


## Set font size style (heading, subheading, body, caption, small)
func set_font_size_style(style: String) -> void:
	if FONT_SIZE_MULTIPLIERS.has(style):
		font_size_style = style
		_apply_font_size()


## Enable/disable text shadow
func set_shadow_enabled(enabled: bool) -> void:
	enable_shadow = enabled
	_apply_current_theme()


## Set shadow offset
func set_shadow_offset(offset: Vector2) -> void:
	shadow_offset = offset
	if enable_shadow:
		add_theme_constant_override("shadow_offset_x", int(offset.x))
		add_theme_constant_override("shadow_offset_y", int(offset.y))


## Set shadow color
func set_shadow_color(color: Color) -> void:
	shadow_color = color
	if enable_shadow:
		add_theme_color_override("font_shadow_color", color)


## Set custom text color (overrides theme)
func set_custom_color(color: Color) -> void:
	add_theme_color_override("font_color", color)


## Animate color change
func animate_color_to(target_color: Color, duration: float = 0.3) -> void:
	var current_color := get_theme_color("font_color", "Label")
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Create property animation callback
	tween.tween_method(func(color: Color): add_theme_color_override("font_color", color), 
		current_color, target_color, duration)


## Flash text (useful for notifications or errors)
func flash_text(flash_color: Color, duration: float = 0.5) -> void:
	var original_color := get_theme_color("font_color", "Label")
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Flash to color and back
	tween.tween_method(func(color: Color): add_theme_color_override("font_color", color), 
		original_color, flash_color, duration * 0.5)
	tween.tween_method(func(color: Color): add_theme_color_override("font_color", color), 
		flash_color, original_color, duration * 0.5)
