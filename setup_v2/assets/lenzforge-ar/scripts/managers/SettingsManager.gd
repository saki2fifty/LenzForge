# ================================================================================================
# SettingsManager.gd
# ================================================================================================
# Singleton manager for LenzForge AR settings persistence
# Handles loading, saving, validation, migration, and auto-save of all application settings
# 
# Part of: Modernization Phase 1 - Foundation + Theme System
# ================================================================================================

extends Node

# ================================================================================================
# SIGNALS
# ================================================================================================

## Emitted when any setting value changes
signal setting_changed(section: String, key: String, value: Variant)

## Emitted when settings are saved to disk
signal settings_saved()

## Emitted when settings are loaded from disk
signal settings_loaded()

## Emitted when settings are reset to defaults
signal settings_reset()

# ================================================================================================
# CONSTANTS
# ================================================================================================

const SETTINGS_FILE: String = "user://settings.cfg"
const AUTO_SAVE_DELAY: float = 2.0  # Seconds to wait before auto-saving after changes
const CURRENT_VERSION: int = 1  # Settings file format version for migrations

# ================================================================================================
# SETTINGS DATA
# ================================================================================================

var _config: ConfigFile = ConfigFile.new()
var _auto_save_timer: Timer = null
var _settings_dirty: bool = false
var _initialized: bool = false

# ================================================================================================
# LIFECYCLE
# ================================================================================================

func _ready() -> void:
	_setup_auto_save_timer()
	_load_settings()
	_initialized = true
	print("[SettingsManager] Initialized with auto-save enabled")

# ================================================================================================
# INITIALIZATION
# ================================================================================================

func _setup_auto_save_timer() -> void:
	"""Create timer for auto-save functionality"""
	_auto_save_timer = Timer.new()
	_auto_save_timer.one_shot = true
	_auto_save_timer.wait_time = AUTO_SAVE_DELAY
	_auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(_auto_save_timer)

# ================================================================================================
# SETTINGS LOADING
# ================================================================================================

func _load_settings() -> void:
	"""Load settings from disk or create with defaults"""
	var err := _config.load(SETTINGS_FILE)
	
	if err == ERR_FILE_NOT_FOUND:
		print("[SettingsManager] No settings file found, creating with defaults")
		_create_default_settings()
		_save_settings_immediate()
		settings_loaded.emit()
		return
	
	if err != OK:
		push_error("[SettingsManager] Failed to load settings: %d, using defaults" % err)
		_create_default_settings()
		settings_loaded.emit()
		return
	
	# Check version and migrate if needed
	var file_version: int = _config.get_value("meta", "version", 0)
	if file_version < CURRENT_VERSION:
		print("[SettingsManager] Migrating settings from v%d to v%d" % [file_version, CURRENT_VERSION])
		_migrate_settings(file_version)
		_save_settings_immediate()
	
	print("[SettingsManager] Loaded settings from: %s" % SETTINGS_FILE)
	settings_loaded.emit()

func _create_default_settings() -> void:
	"""Initialize all settings with default values"""
	
	# Meta section
	_config.set_value("meta", "version", CURRENT_VERSION)
	_config.set_value("meta", "created_at", Time.get_datetime_string_from_system())
	_config.set_value("meta", "last_modified", Time.get_datetime_string_from_system())
	
	# UI settings
	_config.set_value("ui", "theme", "dark")
	_config.set_value("ui", "show_fps", true)
	_config.set_value("ui", "show_metrics", true)
	_config.set_value("ui", "ui_scale", 1.0)
	_config.set_value("ui", "panel_opacity", 0.85)
	_config.set_value("ui", "enable_animations", true)
	_config.set_value("ui", "animation_speed", 1.0)
	
	# Video settings
	_config.set_value("video", "camera_index", 0)
	_config.set_value("video", "resolution_width", 640)
	_config.set_value("video", "resolution_height", 480)
	_config.set_value("video", "fps_target", 30)
	_config.set_value("video", "mirror_video", false)
	
	# Tracking settings
	_config.set_value("tracking", "render_mode", "gpu")  # "gpu" or "cpu"
	_config.set_value("tracking", "show_landmarks", true)
	_config.set_value("tracking", "show_mesh", true)
	_config.set_value("tracking", "show_iris", true)
	_config.set_value("tracking", "landmark_size", 3)
	_config.set_value("tracking", "mesh_opacity", 0.3)
	_config.set_value("tracking", "enable_smoothing", true)
	_config.set_value("tracking", "smoothing_factor", 0.7)
	
	# Performance settings
	_config.set_value("performance", "max_fps", 0)  # 0 = unlimited
	_config.set_value("performance", "vsync_enabled", true)
	_config.set_value("performance", "low_latency_mode", false)
	_config.set_value("performance", "buffer_size", 128)
	
	# Keyboard shortcuts
	_config.set_value("keyboard", "toggle_theme", "T")
	_config.set_value("keyboard", "toggle_fps", "F")
	_config.set_value("keyboard", "toggle_metrics", "M")
	_config.set_value("keyboard", "toggle_fullscreen", "F11")
	_config.set_value("keyboard", "screenshot", "F12")
	_config.set_value("keyboard", "quit", "Escape")
	
	# Window settings
	_config.set_value("window", "fullscreen", false)
	_config.set_value("window", "borderless", false)
	_config.set_value("window", "always_on_top", false)
	_config.set_value("window", "width", 1920)
	_config.set_value("window", "height", 1080)
	
	# Advanced settings
	_config.set_value("advanced", "debug_mode", false)
	_config.set_value("advanced", "log_level", "info")  # "debug", "info", "warning", "error"
	_config.set_value("advanced", "enable_profiling", false)
	_config.set_value("advanced", "backend_host", "localhost")
	_config.set_value("advanced", "backend_port", 5000)
	
	print("[SettingsManager] Created default settings")

# ================================================================================================
# SETTINGS MIGRATION
# ================================================================================================

func _migrate_settings(from_version: int) -> void:
	"""Migrate settings from older version to current version"""
	
	# Example migration logic (add as needed when format changes)
	match from_version:
		0:
			# Migrate from v0 to v1: Add new settings with defaults
			if not _config.has_section_key("ui", "animation_speed"):
				_config.set_value("ui", "animation_speed", 1.0)
			if not _config.has_section_key("tracking", "smoothing_factor"):
				_config.set_value("tracking", "smoothing_factor", 0.7)
	
	# Update version
	_config.set_value("meta", "version", CURRENT_VERSION)
	_config.set_value("meta", "last_modified", Time.get_datetime_string_from_system())
	
	print("[SettingsManager] Migration completed")

# ================================================================================================
# GET SETTINGS
# ================================================================================================

func get_setting(section: String, key: String, default: Variant = null) -> Variant:
	"""
	Get a setting value
	
	Args:
		section: Settings section (e.g., "ui", "video", "tracking")
		key: Setting key within section
		default: Default value if setting doesn't exist
	
	Returns:
		Setting value or default
	"""
	return _config.get_value(section, key, default)

func has_setting(section: String, key: String) -> bool:
	"""Check if a setting exists"""
	return _config.has_section_key(section, key)

func get_section(section: String) -> Dictionary:
	"""Get all settings in a section as Dictionary"""
	var result := {}
	if not _config.has_section(section):
		return result
	
	for key in _config.get_section_keys(section):
		result[key] = _config.get_value(section, key)
	
	return result

func get_all_sections() -> Array:
	"""Get list of all section names"""
	return _config.get_sections()

# ================================================================================================
# SET SETTINGS
# ================================================================================================

func set_setting(section: String, key: String, value: Variant, auto_save: bool = true) -> void:
	"""
	Set a setting value
	
	Args:
		section: Settings section
		key: Setting key within section
		value: New value
		auto_save: Whether to trigger auto-save (default: true)
	"""
	var old_value = _config.get_value(section, key, null)
	
	# Only update if value changed
	if old_value == value:
		return
	
	_config.set_value(section, key, value)
	_config.set_value("meta", "last_modified", Time.get_datetime_string_from_system())
	
	_settings_dirty = true
	setting_changed.emit(section, key, value)
	
	if auto_save:
		_trigger_auto_save()
	
	print("[SettingsManager] Updated %s.%s = %s" % [section, key, str(value)])

func set_multiple_settings(settings: Dictionary, auto_save: bool = true) -> void:
	"""
	Set multiple settings at once
	
	Args:
		settings: Dictionary with structure { "section.key": value }
		auto_save: Whether to trigger auto-save (default: true)
	"""
	for setting_path in settings:
		var parts: Array[String] = Array(setting_path.split(".", false, 1))
		if parts.size() != 2:
			push_warning("[SettingsManager] Invalid setting path: %s" % setting_path)
			continue
		
		set_setting(parts[0], parts[1], settings[setting_path], false)
	
	if auto_save:
		_trigger_auto_save()

# ================================================================================================
# SAVE SETTINGS
# ================================================================================================

func _trigger_auto_save() -> void:
	"""Trigger auto-save after delay"""
	if not _initialized:
		return
	
	if _auto_save_timer.is_stopped():
		_auto_save_timer.start()
	else:
		_auto_save_timer.start()  # Restart timer to delay save

func _on_auto_save_timeout() -> void:
	"""Called when auto-save timer expires"""
	if _settings_dirty:
		_save_settings_immediate()

func _save_settings_immediate() -> void:
	"""Save settings to disk immediately"""
	_config.set_value("meta", "last_modified", Time.get_datetime_string_from_system())
	
	var err := _config.save(SETTINGS_FILE)
	if err != OK:
		push_error("[SettingsManager] Failed to save settings: %d" % err)
		return
	
	_settings_dirty = false
	settings_saved.emit()
	print("[SettingsManager] Settings saved to: %s" % SETTINGS_FILE)

func save_now() -> void:
	"""Force immediate save of settings (public API)"""
	_save_settings_immediate()

# ================================================================================================
# RESET SETTINGS
# ================================================================================================

func reset_to_defaults() -> void:
	"""Reset all settings to default values"""
	_config.clear()
	_create_default_settings()
	_save_settings_immediate()
	settings_reset.emit()
	print("[SettingsManager] Reset all settings to defaults")

func reset_section(section: String) -> void:
	"""Reset a specific section to default values"""
	if not _config.has_section(section):
		return
	
	# Clear section
	_config.erase_section(section)
	
	# Re-create defaults for this section only
	# (This is a simplified version - in practice you'd want to be more selective)
	var temp_config := ConfigFile.new()
	var temp_manager: SettingsManager = SettingsManager.new()
	temp_manager._create_default_settings()
	
	if temp_manager._config.has_section(section):
		for key in temp_manager._config.get_section_keys(section):
			var default_value: Variant = temp_manager._config.get_value(section, key)
			_config.set_value(section, key, default_value)
	
	_trigger_auto_save()
	print("[SettingsManager] Reset section '%s' to defaults" % section)

# ================================================================================================
# VALIDATION
# ================================================================================================

func validate_setting(section: String, key: String, value: Variant) -> bool:
	"""
	Validate a setting value before applying
	
	Args:
		section: Settings section
		key: Setting key
		value: Proposed value
	
	Returns:
		true if valid, false otherwise
	"""
	
	# UI validation
	if section == "ui":
		match key:
			"ui_scale":
				return value is float and value >= 0.5 and value <= 2.0
			"panel_opacity":
				return value is float and value >= 0.0 and value <= 1.0
			"animation_speed":
				return value is float and value >= 0.1 and value <= 3.0
	
	# Video validation
	elif section == "video":
		match key:
			"camera_index":
				return value is int and value >= 0
			"resolution_width":
				return value is int and value >= 320 and value <= 3840
			"resolution_height":
				return value is int and value >= 240 and value <= 2160
			"fps_target":
				return value is int and value >= 15 and value <= 120
	
	# Tracking validation
	elif section == "tracking":
		match key:
			"render_mode":
				return value in ["gpu", "cpu"]
			"landmark_size":
				return value is int and value >= 1 and value <= 10
			"mesh_opacity":
				return value is float and value >= 0.0 and value <= 1.0
			"smoothing_factor":
				return value is float and value >= 0.0 and value <= 1.0
	
	# Performance validation
	elif section == "performance":
		match key:
			"max_fps":
				return value is int and value >= 0  # 0 = unlimited
			"buffer_size":
				return value is int and value >= 16 and value <= 1024
	
	# Default: allow all other settings
	return true

func set_setting_validated(section: String, key: String, value: Variant, auto_save: bool = true) -> bool:
	"""
	Set a setting value with validation
	
	Returns:
		true if value was valid and set, false otherwise
	"""
	if not validate_setting(section, key, value):
		push_warning("[SettingsManager] Invalid value for %s.%s: %s" % [section, key, str(value)])
		return false
	
	set_setting(section, key, value, auto_save)
	return true

# ================================================================================================
# EXPORT/IMPORT
# ================================================================================================

func export_settings(filepath: String) -> bool:
	"""
	Export settings to external file
	
	Args:
		filepath: Path to save settings file
	
	Returns:
		true on success, false on error
	"""
	var err := _config.save(filepath)
	if err != OK:
		push_error("[SettingsManager] Failed to export settings to %s: %d" % [filepath, err])
		return false
	
	print("[SettingsManager] Exported settings to: %s" % filepath)
	return true

func import_settings(filepath: String, merge: bool = false) -> bool:
	"""
	Import settings from external file
	
	Args:
		filepath: Path to load settings from
		merge: If true, merge with existing settings; if false, replace all
	
	Returns:
		true on success, false on error
	"""
	var temp_config := ConfigFile.new()
	var err := temp_config.load(filepath)
	
	if err != OK:
		push_error("[SettingsManager] Failed to import settings from %s: %d" % [filepath, err])
		return false
	
	if not merge:
		_config = temp_config
	else:
		# Merge: copy all sections/keys from imported config
		for section in temp_config.get_sections():
			for key in temp_config.get_section_keys(section):
				var value = temp_config.get_value(section, key)
				_config.set_value(section, key, value)
	
	_save_settings_immediate()
	settings_loaded.emit()
	print("[SettingsManager] Imported settings from: %s (merge=%s)" % [filepath, merge])
	return true

# ================================================================================================
# DEBUG
# ================================================================================================

func print_all_settings() -> void:
	"""Debug: Print all current settings"""
	print("\n=== Current Settings ===")
	for section in _config.get_sections():
		print("\n[%s]" % section)
		for key in _config.get_section_keys(section):
			var value = _config.get_value(section, key)
			print("  %s = %s" % [key, str(value)])
	print("\n")

func get_settings_file_path() -> String:
	"""Get the absolute path to settings file"""
	return ProjectSettings.globalize_path(SETTINGS_FILE)
