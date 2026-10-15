# ================================================================================================
# ThemeManager.gd
# ================================================================================================
# Singleton manager for LenzForge AR theme system
# Handles theme presets (Dark, Light, Neon), switching, persistence, and color management
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends Node

# ================================================================================================
# SIGNALS
# ================================================================================================

## Emitted when theme is changed, includes theme_id
signal theme_changed(theme_id: String)

## Emitted when theme transition starts (for UI animations)
signal theme_transition_started(from_theme: String, to_theme: String)

## Emitted when theme transition completes
signal theme_transition_completed(theme_id: String)

# ================================================================================================
# CONSTANTS
# ================================================================================================

const THEME_TRANSITION_DURATION: float = 0.3  # Seconds for smooth transitions
const SETTINGS_FILE: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "ui"
const SETTINGS_KEY: String = "theme"

# ================================================================================================
# THEME DATA
# ================================================================================================

var themes: Dictionary = {}
var current_theme_id: String = "dark"
var _transition_in_progress: bool = false

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_initialize_themes()
	_load_theme_preference()
	print("[ThemeManager] Initialized with theme: %s" % current_theme_id)

# ================================================================================================
# THEME INITIALIZATION
# ================================================================================================

func _initialize_themes() -> void:
	"""Load all three theme presets into memory"""
	themes["dark"] = _create_dark_theme()
	themes["light"] = _create_light_theme()
	themes["neon"] = _create_neon_theme()
	print("[ThemeManager] Loaded %d theme presets" % themes.size())

# ------------------------------------------------------------------------------------------------
# DARK THEME (Professional)
# ------------------------------------------------------------------------------------------------

func _create_dark_theme() -> Dictionary:
	"""Professional dark theme for long sessions and low eye strain"""
	return {
		"name": "Dark (Professional)",
		"id": "dark",
		"colors": {
			"background": _color_from_array([26, 26, 46, 1.0]),
			"secondary": _color_from_array([22, 33, 62, 1.0]),
			"accent": _color_from_array([15, 52, 96, 1.0]),
			"highlight": _color_from_array([233, 69, 96, 1.0]),
			"text_primary": _color_from_array([255, 255, 255, 1.0]),
			"text_secondary": _color_from_array([160, 160, 160, 1.0])
		},
		"panels": {
			"background": _color_from_array([255, 255, 255, 0.05]),
			"border": _color_from_array([255, 255, 255, 0.15]),
			"shadow": _color_from_array([0, 0, 0, 0.5]),
			"blur_amount": 15,
			"corner_radius": 12,
			"border_thickness": 1
		},
		"landmarks": {
			"default": _color_from_array([0, 255, 0, 1.0]),
			"iris": _color_from_array([0, 255, 255, 1.0]),
			"contour": _color_from_array([255, 0, 255, 1.0]),
			"mesh_lines": _color_from_array([255, 255, 255, 0.3]),
			"glow": _color_from_array([0, 255, 0, 0.5]),
			"point_size": 3,
			"line_thickness": 1.5
		},
		"buttons": {
			"normal_bg": _color_from_array([15, 52, 96, 0.8]),
			"normal_border": _color_from_array([15, 52, 96, 1.0]),
			"normal_text": _color_from_array([255, 255, 255, 1.0]),
			"hover_bg": _color_from_array([15, 52, 96, 1.0]),
			"hover_border": _color_from_array([233, 69, 96, 1.0]),
			"hover_text": _color_from_array([255, 255, 255, 1.0]),
			"pressed_bg": _color_from_array([233, 69, 96, 1.0]),
			"pressed_border": _color_from_array([233, 69, 96, 1.0]),
			"pressed_text": _color_from_array([255, 255, 255, 1.0]),
			"disabled_bg": _color_from_array([160, 160, 160, 0.3]),
			"disabled_border": _color_from_array([160, 160, 160, 0.5]),
			"disabled_text": _color_from_array([160, 160, 160, 1.0]),
			"active_bg": _color_from_array([233, 69, 96, 0.9]),
			"active_border": _color_from_array([233, 69, 96, 1.0]),
			"active_text": _color_from_array([255, 255, 255, 1.0])
		},
		"graphs": {
			"fps": _color_from_array([0, 255, 0, 1.0]),
			"cpu": _color_from_array([0, 170, 255, 1.0]),
			"memory": _color_from_array([255, 153, 0, 1.0]),
			"frametime": _color_from_array([255, 0, 255, 1.0]),
			"grid": _color_from_array([255, 255, 255, 0.1]),
			"axis": _color_from_array([255, 255, 255, 0.3])
		}
	}

# ------------------------------------------------------------------------------------------------
# LIGHT THEME (Clean Professional)
# ------------------------------------------------------------------------------------------------

func _create_light_theme() -> Dictionary:
	"""Clean light theme for well-lit environments and daytime work"""
	return {
		"name": "Light (Clean Professional)",
		"id": "light",
		"colors": {
			"background": _color_from_array([245, 245, 245, 1.0]),
			"secondary": _color_from_array([224, 224, 224, 1.0]),
			"accent": _color_from_array([33, 150, 243, 1.0]),
			"highlight": _color_from_array([255, 87, 34, 1.0]),
			"text_primary": _color_from_array([33, 33, 33, 1.0]),
			"text_secondary": _color_from_array([117, 117, 117, 1.0])
		},
		"panels": {
			"background": _color_from_array([255, 255, 255, 0.95]),
			"border": _color_from_array([0, 0, 0, 0.12]),
			"shadow": _color_from_array([0, 0, 0, 0.2]),
			"blur_amount": 10,
			"corner_radius": 8,
			"border_thickness": 1
		},
		"landmarks": {
			"default": _color_from_array([76, 175, 80, 1.0]),
			"iris": _color_from_array([0, 188, 212, 1.0]),
			"contour": _color_from_array([156, 39, 176, 1.0]),
			"mesh_lines": _color_from_array([0, 0, 0, 0.2]),
			"glow": _color_from_array([76, 175, 80, 0.3]),
			"point_size": 3,
			"line_thickness": 1.5
		},
		"buttons": {
			"normal_bg": _color_from_array([33, 150, 243, 0.1]),
			"normal_border": _color_from_array([33, 150, 243, 0.3]),
			"normal_text": _color_from_array([33, 150, 243, 1.0]),
			"hover_bg": _color_from_array([33, 150, 243, 0.2]),
			"hover_border": _color_from_array([33, 150, 243, 0.5]),
			"hover_text": _color_from_array([33, 150, 243, 1.0]),
			"pressed_bg": _color_from_array([33, 150, 243, 1.0]),
			"pressed_border": _color_from_array([33, 150, 243, 1.0]),
			"pressed_text": _color_from_array([255, 255, 255, 1.0]),
			"disabled_bg": _color_from_array([189, 189, 189, 0.3]),
			"disabled_border": _color_from_array([189, 189, 189, 0.5]),
			"disabled_text": _color_from_array([189, 189, 189, 1.0]),
			"active_bg": _color_from_array([255, 87, 34, 0.2]),
			"active_border": _color_from_array([255, 87, 34, 1.0]),
			"active_text": _color_from_array([255, 87, 34, 1.0])
		},
		"graphs": {
			"fps": _color_from_array([76, 175, 80, 1.0]),
			"cpu": _color_from_array([33, 150, 243, 1.0]),
			"memory": _color_from_array([255, 152, 0, 1.0]),
			"frametime": _color_from_array([156, 39, 176, 1.0]),
			"grid": _color_from_array([0, 0, 0, 0.08]),
			"axis": _color_from_array([0, 0, 0, 0.2])
		}
	}

# ------------------------------------------------------------------------------------------------
# NEON THEME (Cyberpunk)
# ------------------------------------------------------------------------------------------------

func _create_neon_theme() -> Dictionary:
	"""Cyberpunk neon theme for dark environments and entertainment"""
	return {
		"name": "Neon (Cyberpunk)",
		"id": "neon",
		"colors": {
			"background": _color_from_array([10, 10, 10, 1.0]),
			"secondary": _color_from_array([21, 21, 21, 1.0]),
			"accent": _color_from_array([0, 255, 255, 1.0]),
			"highlight": _color_from_array([255, 0, 255, 1.0]),
			"text_primary": _color_from_array([0, 255, 255, 1.0]),
			"text_secondary": _color_from_array([0, 255, 0, 1.0])
		},
		"panels": {
			"background": _color_from_array([0, 255, 255, 0.05]),
			"border": _color_from_array([0, 255, 255, 0.5]),
			"shadow": _color_from_array([0, 255, 255, 0.5]),
			"blur_amount": 20,
			"corner_radius": 4,
			"border_thickness": 2
		},
		"landmarks": {
			"default": _color_from_array([0, 255, 0, 1.0]),
			"iris": _color_from_array([255, 0, 255, 1.0]),
			"contour": _color_from_array([255, 255, 0, 1.0]),
			"mesh_lines": _color_from_array([0, 255, 255, 0.8]),
			"glow": _color_from_array([0, 255, 0, 0.8]),
			"point_size": 4,
			"line_thickness": 2
		},
		"buttons": {
			"normal_bg": _color_from_array([0, 255, 255, 0.2]),
			"normal_border": _color_from_array([0, 255, 255, 0.6]),
			"normal_text": _color_from_array([0, 255, 255, 1.0]),
			"hover_bg": _color_from_array([0, 255, 255, 0.4]),
			"hover_border": _color_from_array([0, 255, 255, 1.0]),
			"hover_text": _color_from_array([0, 255, 255, 1.0]),
			"pressed_bg": _color_from_array([255, 0, 255, 1.0]),
			"pressed_border": _color_from_array([255, 0, 255, 1.0]),
			"pressed_text": _color_from_array([255, 255, 255, 1.0]),
			"disabled_bg": _color_from_array([128, 128, 128, 0.2]),
			"disabled_border": _color_from_array([128, 128, 128, 0.4]),
			"disabled_text": _color_from_array([128, 128, 128, 1.0]),
			"active_bg": _color_from_array([255, 0, 255, 0.4]),
			"active_border": _color_from_array([255, 0, 255, 1.0]),
			"active_text": _color_from_array([255, 0, 255, 1.0])
		},
		"graphs": {
			"fps": _color_from_array([0, 255, 0, 1.0]),
			"cpu": _color_from_array([0, 255, 255, 1.0]),
			"memory": _color_from_array([255, 255, 0, 1.0]),
			"frametime": _color_from_array([255, 0, 255, 1.0]),
			"grid": _color_from_array([0, 255, 255, 0.2]),
			"axis": _color_from_array([0, 255, 255, 0.6])
		}
	}

# ================================================================================================
# COLOR UTILITIES
# ================================================================================================

func _color_from_array(arr: Array) -> Color:
	"""Convert [R, G, B, A] array to Godot Color object"""
	return Color(arr[0] / 255.0, arr[1] / 255.0, arr[2] / 255.0, arr[3])

# ================================================================================================
# THEME SWITCHING
# ================================================================================================

func switch_theme(theme_id: String, animated: bool = true) -> void:
	"""
	Switch to a different theme
	
	Args:
		theme_id: ID of theme to switch to ("dark", "light", "neon")
		animated: Whether to use smooth transition animation (default: true)
	"""
	if not themes.has(theme_id):
		push_error("[ThemeManager] Theme not found: %s" % theme_id)
		return
	
	if theme_id == current_theme_id:
		print("[ThemeManager] Already using theme: %s" % theme_id)
		return
	
	if _transition_in_progress:
		push_warning("[ThemeManager] Theme transition already in progress, ignoring")
		return
	
	var old_theme_id = current_theme_id
	current_theme_id = theme_id
	
	if animated:
		_animated_theme_switch(old_theme_id, theme_id)
	else:
		_instant_theme_switch(theme_id)

func _instant_theme_switch(theme_id: String) -> void:
	"""Apply theme immediately without animation"""
	theme_changed.emit(theme_id)
	_save_theme_preference()
	print("[ThemeManager] Switched to theme: %s (instant)" % theme_id)

func _animated_theme_switch(from_theme: String, to_theme: String) -> void:
	"""Apply theme with smooth transition animation"""
	_transition_in_progress = true
	theme_transition_started.emit(from_theme, to_theme)
	
	# Signal is emitted, UI components should fade out and apply new theme
	theme_changed.emit(to_theme)
	
	# Wait for transition duration
	await get_tree().create_timer(THEME_TRANSITION_DURATION).timeout
	
	_transition_in_progress = false
	theme_transition_completed.emit(to_theme)
	_save_theme_preference()
	print("[ThemeManager] Switched to theme: %s (animated)" % to_theme)

func cycle_theme() -> void:
	"""Cycle to next theme in sequence: dark -> light -> neon -> dark"""
	var theme_order := ["dark", "light", "neon"]
	var current_index := theme_order.find(current_theme_id)
	var next_index := (current_index + 1) % theme_order.size()
	switch_theme(theme_order[next_index], true)

# ================================================================================================
# THEME QUERIES
# ================================================================================================

func get_current_theme() -> Dictionary:
	"""Get the complete current theme dictionary"""
	return themes.get(current_theme_id, {})

func get_current_theme_id() -> String:
	"""Get the current theme ID"""
	return current_theme_id

func get_current_theme_name() -> String:
	"""Get the current theme display name"""
	var theme := get_current_theme()
	return theme.get("name", "Unknown")

func get_available_themes() -> Array:
	"""Get list of all available theme IDs"""
	return themes.keys()

# ------------------------------------------------------------------------------------------------
# COLOR ACCESSORS
# ------------------------------------------------------------------------------------------------

func get_color(category: String, property: String) -> Color:
	"""
	Get a specific color from the current theme
	
	Args:
		category: Color category ("colors", "panels", "landmarks", "buttons", "graphs")
		property: Property name (e.g., "background", "accent", "text_primary")
	
	Returns:
		Color object, or WHITE if not found
	"""
	var theme := get_current_theme()
	if theme.is_empty():
		push_warning("[ThemeManager] No theme loaded, returning WHITE")
		return Color.WHITE
	
	if not theme.has(category):
		push_warning("[ThemeManager] Category not found: %s" % category)
		return Color.WHITE
	
	if not theme[category].has(property):
		push_warning("[ThemeManager] Property not found: %s.%s" % [category, property])
		return Color.WHITE
	
	# Use Variant intermediate variable to avoid type inference errors in Godot 4.5+
	var color_variant = theme[category][property]
	return color_variant as Color

func get_base_color(property: String) -> Color:
	"""Get color from 'colors' category (shorthand)"""
	return get_color("colors", property)

func get_panel_color(property: String) -> Color:
	"""Get color from 'panels' category (shorthand)"""
	return get_color("panels", property)

func get_landmark_color(property: String) -> Color:
	"""Get color from 'landmarks' category (shorthand)"""
	return get_color("landmarks", property)

func get_button_color(property: String) -> Color:
	"""Get color from 'buttons' category (shorthand)"""
	return get_color("buttons", property)

func get_graph_color(property: String) -> Color:
	"""Get color from 'graphs' category (shorthand)"""
	return get_color("graphs", property)

# ------------------------------------------------------------------------------------------------
# NUMERIC PROPERTY ACCESSORS
# ------------------------------------------------------------------------------------------------

func get_panel_property(property: String) -> Variant:
	"""
	Get numeric panel property (blur_amount, corner_radius, border_thickness)
	
	Returns:
		int or float value, or 0 if not found
	"""
	var theme := get_current_theme()
	if theme.is_empty() or not theme.has("panels"):
		return 0
	
	return theme["panels"].get(property, 0)

func get_landmark_property(property: String) -> Variant:
	"""
	Get numeric landmark property (point_size, line_thickness)
	
	Returns:
		int or float value, or 0 if not found
	"""
	var theme := get_current_theme()
	if theme.is_empty() or not theme.has("landmarks"):
		return 0
	
	return theme["landmarks"].get(property, 0)

# ================================================================================================
# PERSISTENCE
# ================================================================================================

func _save_theme_preference() -> void:
	"""Save current theme preference to settings file"""
	var config := ConfigFile.new()
	
	# Load existing settings first (don't overwrite other sections)
	var err := config.load(SETTINGS_FILE)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[ThemeManager] Could not load settings file: %d" % err)
	
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, current_theme_id)
	
	err = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("[ThemeManager] Could not save theme preference: %d" % err)
	else:
		print("[ThemeManager] Saved theme preference: %s" % current_theme_id)

func _load_theme_preference() -> void:
	"""Load theme preference from settings file"""
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)
	
	if err != OK:
		if err == ERR_FILE_NOT_FOUND:
			print("[ThemeManager] No settings file found, using default theme: %s" % current_theme_id)
		else:
			push_warning("[ThemeManager] Could not load settings file: %d, using default" % err)
		return
	
	# Use explicit type to avoid type inference errors in Godot 4.5+
	var saved_theme: String = config.get_value(SETTINGS_SECTION, SETTINGS_KEY, current_theme_id)
	
	if themes.has(saved_theme):
		current_theme_id = saved_theme
		print("[ThemeManager] Loaded theme preference: %s" % current_theme_id)
	else:
		push_warning("[ThemeManager] Invalid theme in settings: %s, using default" % saved_theme)

# ================================================================================================
# DEBUG
# ================================================================================================

func print_current_theme() -> void:
	"""Debug: Print current theme structure"""
	print("\n=== Current Theme: %s ===" % get_current_theme_name())
	var theme := get_current_theme()
	for category in theme.keys():
		if category in ["name", "id"]:
			continue
		print("\n[%s]" % category)
		for property in theme[category].keys():
			var value = theme[category][property]
			print("  %s: %s" % [property, value])
	print("\n")
