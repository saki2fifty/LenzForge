# ================================================================================================
# CustomizationManager.gd
# ================================================================================================
# Singleton manager for LenzForge AR UI customization system
# Handles property validation, preview/commit workflow, and preset management
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends Node

# ================================================================================================
# SIGNALS
# ================================================================================================

## Emitted when preview mode is started
signal preview_started()

## Emitted when a property is changed in preview mode
signal property_previewed(category: String, property: String, value: Variant)

## Emitted when preview changes are committed
signal preview_committed()

## Emitted when preview changes are cancelled
signal preview_cancelled()

## Emitted when a preset is loaded
signal preset_loaded(preset_name: String)

## Emitted when a preset is saved
signal preset_saved(preset_name: String)

# ================================================================================================
# CONSTANTS
# ================================================================================================

const PRESETS_DIR: String = "user://presets/"
const PRESET_EXTENSION: String = ".preset.json"

# Customizable property categories
enum PropertyCategory {
	THEME,      # Theme colors and styles
	LANDMARKS,  # Landmark appearance (size, colors, glow)
	UI,         # UI scaling, opacity, animations
	GRAPHS,     # Graph colors and styling
	WINDOW      # Window properties
}

# ================================================================================================
# CUSTOMIZATION DATA
# ================================================================================================

var _preview_mode: bool = false
var _original_values: Dictionary = {}  # Backup of values before preview
var _preview_values: Dictionary = {}   # Current preview values
var _available_presets: Array = []     # List of saved preset names

# Property constraints/ranges for validation
var _property_constraints: Dictionary = {}

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_initialize_property_constraints()
	_scan_available_presets()
	print("[CustomizationManager] Initialized")

# ================================================================================================
# INITIALIZATION
# ================================================================================================

func _initialize_property_constraints() -> void:
	"""Define validation constraints for all customizable properties"""
	
	# Landmark properties
	_property_constraints["landmarks.point_size"] = {
		"type": TYPE_INT,
		"min": 1,
		"max": 10,
		"default": 3,
		"description": "Size of landmark points in pixels"
	}
	_property_constraints["landmarks.line_thickness"] = {
		"type": TYPE_FLOAT,
		"min": 0.5,
		"max": 5.0,
		"default": 1.5,
		"description": "Thickness of mesh lines"
	}
	_property_constraints["landmarks.glow_intensity"] = {
		"type": TYPE_FLOAT,
		"min": 0.0,
		"max": 1.0,
		"default": 0.5,
		"description": "Intensity of landmark glow effect"
	}
	
	# UI properties
	_property_constraints["ui.scale"] = {
		"type": TYPE_FLOAT,
		"min": 0.5,
		"max": 2.0,
		"default": 1.0,
		"description": "Overall UI scale factor"
	}
	_property_constraints["ui.panel_opacity"] = {
		"type": TYPE_FLOAT,
		"min": 0.0,
		"max": 1.0,
		"default": 0.85,
		"description": "Opacity of UI panels"
	}
	_property_constraints["ui.animation_speed"] = {
		"type": TYPE_FLOAT,
		"min": 0.1,
		"max": 3.0,
		"default": 1.0,
		"description": "Speed multiplier for UI animations"
	}
	_property_constraints["ui.blur_amount"] = {
		"type": TYPE_INT,
		"min": 0,
		"max": 30,
		"default": 15,
		"description": "Backdrop blur amount for glassmorphism"
	}
	
	# Graph properties
	_property_constraints["graphs.line_thickness"] = {
		"type": TYPE_FLOAT,
		"min": 1.0,
		"max": 5.0,
		"default": 2.0,
		"description": "Thickness of graph lines"
	}
	_property_constraints["graphs.history_duration"] = {
		"type": TYPE_INT,
		"min": 30,
		"max": 300,
		"default": 60,
		"description": "Duration of graph history in seconds"
	}
	
	print("[CustomizationManager] Loaded %d property constraints" % _property_constraints.size())

func _scan_available_presets() -> void:
	"""Scan presets directory for available custom presets"""
	_available_presets.clear()
	
	# Ensure presets directory exists
	if not DirAccess.dir_exists_absolute(PRESETS_DIR):
		DirAccess.make_dir_recursive_absolute(PRESETS_DIR)
		print("[CustomizationManager] Created presets directory: %s" % PRESETS_DIR)
		return
	
	# Scan for preset files
	var dir := DirAccess.open(PRESETS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(PRESET_EXTENSION):
				var preset_name := file_name.trim_suffix(PRESET_EXTENSION)
				_available_presets.append(preset_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	print("[CustomizationManager] Found %d custom presets" % _available_presets.size())

# ================================================================================================
# PROPERTY VALIDATION
# ================================================================================================

func validate_property(property_path: String, value: Variant) -> bool:
	"""
	Validate a property value against defined constraints
	
	Args:
		property_path: Full property path (e.g., "landmarks.point_size")
		value: Proposed value
	
	Returns:
		true if valid, false otherwise
	"""
	if not _property_constraints.has(property_path):
		push_warning("[CustomizationManager] Unknown property: %s" % property_path)
		return false
	
	var constraints: Dictionary = _property_constraints[property_path]
	
	# Type check
	if typeof(value) != constraints.type:
		push_warning("[CustomizationManager] Type mismatch for %s: expected %s, got %s" % [
			property_path,
			type_string(constraints.type),
			type_string(typeof(value))
		])
		return false
	
	# Range check for numeric types
	if constraints.has("min") and value < constraints.min:
		push_warning("[CustomizationManager] Value too small for %s: %s < %s" % [
			property_path, str(value), str(constraints.min)
		])
		return false
	
	if constraints.has("max") and value > constraints.max:
		push_warning("[CustomizationManager] Value too large for %s: %s > %s" % [
			property_path, str(value), str(constraints.max)
		])
		return false
	
	return true

func clamp_property(property_path: String, value: Variant) -> Variant:
	"""
	Clamp a property value to valid range
	
	Args:
		property_path: Full property path
		value: Input value
	
	Returns:
		Clamped value within valid range
	"""
	if not _property_constraints.has(property_path):
		return value
	
	var constraints: Dictionary = _property_constraints[property_path]
	
	if constraints.has("min") and constraints.has("max"):
		match typeof(value):
			TYPE_INT:
				return clampi(value, constraints.min, constraints.max)
			TYPE_FLOAT:
				return clampf(value, constraints.min, constraints.max)
	
	return value

func get_property_default(property_path: String) -> Variant:
	"""Get default value for a property"""
	if not _property_constraints.has(property_path):
		return null
	
	return _property_constraints[property_path].get("default", null)

func get_property_range(property_path: String) -> Dictionary:
	"""
	Get min/max range for a property
	
	Returns:
		Dictionary with "min" and "max" keys, or empty if no range
	"""
	if not _property_constraints.has(property_path):
		return {}
	
	var constraints: Dictionary = _property_constraints[property_path]
	var result := {}
	
	if constraints.has("min"):
		result["min"] = constraints.min
	if constraints.has("max"):
		result["max"] = constraints.max
	
	return result

func get_property_description(property_path: String) -> String:
	"""Get human-readable description for a property"""
	if not _property_constraints.has(property_path):
		return ""
	
	return _property_constraints[property_path].get("description", "")

func get_all_properties() -> Array:
	"""Get list of all customizable property paths"""
	return _property_constraints.keys()

# ================================================================================================
# PREVIEW MODE
# ================================================================================================

func start_preview() -> void:
	"""Start preview mode - changes can be committed or cancelled"""
	if _preview_mode:
		push_warning("[CustomizationManager] Preview mode already active")
		return
	
	_preview_mode = true
	_original_values.clear()
	_preview_values.clear()
	
	preview_started.emit()
	print("[CustomizationManager] Preview mode started")

func preview_property(category: String, property: String, value: Variant) -> bool:
	"""
	Preview a property change without committing
	
	Args:
		category: Property category (e.g., "landmarks", "ui")
		property: Property name within category
		value: New value to preview
	
	Returns:
		true if preview was successful, false if invalid
	"""
	if not _preview_mode:
		push_warning("[CustomizationManager] Not in preview mode")
		return false
	
	var property_path := "%s.%s" % [category, property]
	
	# Validate value
	if not validate_property(property_path, value):
		return false
	
	# Store original value if this is first preview of this property
	if not _original_values.has(property_path):
		var current_value = _get_current_property_value(category, property)
		_original_values[property_path] = current_value
	
	# Store preview value
	_preview_values[property_path] = value
	
	# Apply preview (listeners can respond to this signal)
	property_previewed.emit(category, property, value)
	
	print("[CustomizationManager] Previewing %s = %s" % [property_path, str(value)])
	return true

func commit_preview() -> void:
	"""Commit all preview changes permanently"""
	if not _preview_mode:
		push_warning("[CustomizationManager] Not in preview mode")
		return
	
	# Apply all preview values to actual settings
	for property_path in _preview_values:
		var parts: Array[String] = Array(property_path.split(".", false, 1))
		if parts.size() == 2:
			_apply_property_value(parts[0], parts[1], _preview_values[property_path])
	
	_preview_mode = false
	var changes_count := _preview_values.size()
	_original_values.clear()
	_preview_values.clear()
	
	preview_committed.emit()
	print("[CustomizationManager] Committed %d preview changes" % changes_count)

func cancel_preview() -> void:
	"""Cancel preview and restore original values"""
	if not _preview_mode:
		push_warning("[CustomizationManager] Not in preview mode")
		return
	
	# Restore all original values
	for property_path in _original_values:
		var parts: Array[String] = Array(property_path.split(".", false, 1))
		if parts.size() == 2:
			_apply_property_value(parts[0], parts[1], _original_values[property_path])
			property_previewed.emit(parts[0], parts[1], _original_values[property_path])
	
	_preview_mode = false
	var cancelled_count := _preview_values.size()
	_original_values.clear()
	_preview_values.clear()
	
	preview_cancelled.emit()
	print("[CustomizationManager] Cancelled %d preview changes" % cancelled_count)

func is_in_preview_mode() -> bool:
	"""Check if currently in preview mode"""
	return _preview_mode

func get_preview_changes() -> Dictionary:
	"""Get all pending preview changes"""
	return _preview_values.duplicate()

# ================================================================================================
# PROPERTY ACCESS (INTERNAL)
# ================================================================================================

func _get_current_property_value(category: String, property: String) -> Variant:
	"""Get current value of a property from appropriate manager"""
	match category:
		"ui":
			return SettingsManager.get_setting("ui", property)
		"landmarks":
			return SettingsManager.get_setting("tracking", property)
		"graphs":
			return SettingsManager.get_setting("ui", property)
		_:
			return null

func _apply_property_value(category: String, property: String, value: Variant) -> void:
	"""Apply a property value to appropriate manager"""
	match category:
		"ui":
			SettingsManager.set_setting("ui", property, value)
		"landmarks":
			SettingsManager.set_setting("tracking", property, value)
		"graphs":
			SettingsManager.set_setting("ui", property, value)

# ================================================================================================
# PRESET MANAGEMENT
# ================================================================================================

func save_preset(preset_name: String, include_theme: bool = true) -> bool:
	"""
	Save current customization as a named preset
	
	Args:
		preset_name: Name for the preset (without extension)
		include_theme: Whether to include theme selection in preset
	
	Returns:
		true on success, false on error
	"""
	if preset_name.is_empty():
		push_error("[CustomizationManager] Preset name cannot be empty")
		return false
	
	# Build preset data
	var preset_data := {
		"name": preset_name,
		"created_at": Time.get_datetime_string_from_system(),
		"version": 1,
		"properties": {}
	}
	
	# Include theme if requested
	if include_theme:
		preset_data["theme"] = ThemeManager.get_current_theme_id()
	
	# Collect all customizable properties
	for property_path in _property_constraints.keys():
		var parts: Array[String] = Array(property_path.split(".", false, 1))
		if parts.size() == 2:
			var value = _get_current_property_value(parts[0], parts[1])
			if value != null:
				preset_data.properties[property_path] = value
	
	# Save to file
	var filepath := PRESETS_DIR + preset_name + PRESET_EXTENSION
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("[CustomizationManager] Failed to create preset file: %s" % filepath)
		return false
	
	file.store_string(JSON.stringify(preset_data, "\t"))
	file.close()
	
	# Update available presets list
	if not _available_presets.has(preset_name):
		_available_presets.append(preset_name)
	
	preset_saved.emit(preset_name)
	print("[CustomizationManager] Saved preset: %s" % preset_name)
	return true

func load_preset(preset_name: String, apply_theme: bool = true) -> bool:
	"""
	Load a saved preset
	
	Args:
		preset_name: Name of preset to load
		apply_theme: Whether to apply theme from preset (if included)
	
	Returns:
		true on success, false on error
	"""
	var filepath := PRESETS_DIR + preset_name + PRESET_EXTENSION
	
	if not FileAccess.file_exists(filepath):
		push_error("[CustomizationManager] Preset not found: %s" % preset_name)
		return false
	
	# Load preset file
	var file := FileAccess.open(filepath, FileAccess.READ)
	if not file:
		push_error("[CustomizationManager] Failed to open preset file: %s" % filepath)
		return false
	
	var json_text := file.get_as_text()
	file.close()
	
	var preset_data = JSON.parse_string(json_text)
	if preset_data == null:
		push_error("[CustomizationManager] Failed to parse preset JSON: %s" % preset_name)
		return false
	
	# Apply theme if present and requested
	if apply_theme and preset_data.has("theme"):
		ThemeManager.switch_theme(preset_data.theme, false)
	
	# Apply all properties
	if preset_data.has("properties"):
		for property_path in preset_data.properties:
			var parts: Array[String] = Array(property_path.split(".", false, 1))
			if parts.size() == 2:
				var value = preset_data.properties[property_path]
				if validate_property(property_path, value):
					_apply_property_value(parts[0], parts[1], value)
	
	preset_loaded.emit(preset_name)
	print("[CustomizationManager] Loaded preset: %s" % preset_name)
	return true

func delete_preset(preset_name: String) -> bool:
	"""Delete a saved preset"""
	var filepath := PRESETS_DIR + preset_name + PRESET_EXTENSION
	
	if not FileAccess.file_exists(filepath):
		push_warning("[CustomizationManager] Preset not found: %s" % preset_name)
		return false
	
	var dir := DirAccess.open(PRESETS_DIR)
	var err := dir.remove(filepath)
	
	if err != OK:
		push_error("[CustomizationManager] Failed to delete preset: %s" % preset_name)
		return false
	
	_available_presets.erase(preset_name)
	print("[CustomizationManager] Deleted preset: %s" % preset_name)
	return true

func get_available_presets() -> Array:
	"""Get list of all available preset names"""
	return _available_presets.duplicate()

func preset_exists(preset_name: String) -> bool:
	"""Check if a preset exists"""
	return _available_presets.has(preset_name)

# ================================================================================================
# DEBUG
# ================================================================================================

func print_property_constraints() -> void:
	"""Debug: Print all property constraints"""
	print("\n=== Property Constraints ===")
	for property_path in _property_constraints.keys():
		var constraints: Dictionary = _property_constraints[property_path]
		print("\n%s:" % property_path)
		for key in constraints:
			print("  %s: %s" % [key, str(constraints[key])])
	print("\n")
