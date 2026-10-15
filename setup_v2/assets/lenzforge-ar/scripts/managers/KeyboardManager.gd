extends Node

## KeyboardManager.gd
## Manages global keyboard shortcuts and key bindings for LenzForge AR
## Handles hotkey registration, rebinding, conflict detection, and persistence

signal key_pressed(action: String, key: int)
signal binding_changed(action: String, old_key: int, new_key: int)
signal conflict_detected(action: String, conflicting_action: String)
signal shortcut_triggered(action: String)

## Default key bindings (action -> KEY_* constant)
const DEFAULT_BINDINGS := {
	"toggle_theme": KEY_T,
	"toggle_fps": KEY_F,
	"toggle_metrics": KEY_M,
	"toggle_fullscreen": KEY_F11,
	"screenshot": KEY_F12,
	"quit": KEY_ESCAPE,
	"cycle_render_mode": KEY_R,
	"reset_view": KEY_SPACE,
	"toggle_landmarks": KEY_L,
	"toggle_video": KEY_V,
	"save_preset": KEY_S,  # Ctrl+S
	"load_preset": KEY_O,  # Ctrl+O
	"undo": KEY_Z,         # Ctrl+Z
	"redo": KEY_Y          # Ctrl+Y
}

## Current active bindings (typed for Godot 4.5+ type inference)
var bindings: Dictionary[String, int] = {}

## Reverse lookup: key -> action (typed for Godot 4.5+ type inference)
var key_to_action: Dictionary[int, String] = {}

## Track which actions require modifiers (Ctrl, Shift, Alt)
var modifier_requirements: Dictionary = {
	"save_preset": {"ctrl": true},
	"load_preset": {"ctrl": true},
	"undo": {"ctrl": true},
	"redo": {"ctrl": true}
}

## Action descriptions for UI/tooltips
var action_descriptions: Dictionary = {
	"toggle_theme": "Cycle through Dark, Light, and Neon themes",
	"toggle_fps": "Show/hide FPS counter",
	"toggle_metrics": "Show/hide performance metrics",
	"toggle_fullscreen": "Toggle fullscreen mode",
	"screenshot": "Capture screenshot",
	"quit": "Exit application",
	"cycle_render_mode": "Switch between GPU and CPU rendering",
	"reset_view": "Reset camera and view settings",
	"toggle_landmarks": "Show/hide facial landmarks",
	"toggle_video": "Show/hide video feed",
	"save_preset": "Save current settings as preset (Ctrl+S)",
	"load_preset": "Load settings preset (Ctrl+O)",
	"undo": "Undo last change (Ctrl+Z)",
	"redo": "Redo last undone change (Ctrl+Y)"
}

## Track enabled/disabled state per action
var action_enabled: Dictionary = {}

## Cooldown tracking to prevent rapid-fire triggering (action -> timestamp)
var cooldowns: Dictionary = {}
const COOLDOWN_MS: int = 200  # 200ms between same key presses


func _ready() -> void:
	# Load bindings from settings or use defaults
	_load_bindings()
	
	# Enable all actions by default
	for action in bindings.keys():
		action_enabled[action] = true
	
	print("[KeyboardManager] Initialized with %d key bindings" % bindings.size())


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	var key_event := event as InputEventKey
	
	# Only handle key press (not release)
	if not key_event.pressed or key_event.echo:
		return
	
	# Get the action for this key
	var action := _get_action_for_key(key_event)
	if action.is_empty():
		return
	
	# Check if action is enabled
	if not action_enabled.get(action, true):
		return
	
	# Check cooldown
	if _is_on_cooldown(action):
		return
	
	# Verify modifier requirements
	if not _check_modifiers(action, key_event):
		return
	
	# Execute the action
	_execute_action(action, key_event.keycode)
	
	# Set cooldown
	cooldowns[action] = Time.get_ticks_msec()


## Load bindings from SettingsManager or use defaults
func _load_bindings() -> void:
	bindings.clear()
	key_to_action.clear()
	
	# Try to load from settings
	if SettingsManager:
		var saved_bindings: Dictionary = SettingsManager.get_setting("keyboard", "bindings", {})
		
		# If saved bindings exist, use them
		if not saved_bindings.is_empty():
			for action in saved_bindings.keys():
				var key: int = saved_bindings[action]
				_set_binding_internal(action, key, false)
			print("[KeyboardManager] Loaded %d saved bindings" % bindings.size())
			return
	
	# Use defaults
	for action in DEFAULT_BINDINGS.keys():
		_set_binding_internal(action, DEFAULT_BINDINGS[action], false)
	
	print("[KeyboardManager] Initialized with default bindings")


## Save current bindings to settings
func _save_bindings() -> void:
	if not SettingsManager:
		push_warning("[KeyboardManager] SettingsManager not available, cannot save bindings")
		return
	
	# Convert bindings to saveable format
	var save_dict := {}
	for action in bindings.keys():
		save_dict[action] = bindings[action]
	
	SettingsManager.set_setting("keyboard", "bindings", save_dict)
	print("[KeyboardManager] Saved %d key bindings" % bindings.size())


## Get action name for a key event
func _get_action_for_key(key_event: InputEventKey) -> String:
	var key := key_event.keycode
	
	# Check if this key is bound
	if not key_to_action.has(key):
		return ""
	
	# Use cast to avoid Variant type inference in Godot 4.5+
	var action := key_to_action[key] as String
	
	# For actions requiring modifiers, check them
	if modifier_requirements.has(action):
		var required: Dictionary = modifier_requirements[action]
		if required.get("ctrl", false) and not key_event.ctrl_pressed:
			return ""
		if required.get("shift", false) and not key_event.shift_pressed:
			return ""
		if required.get("alt", false) and not key_event.alt_pressed:
			return ""
	
	return action


## Check if modifiers match requirements
func _check_modifiers(action: String, key_event: InputEventKey) -> bool:
	if not modifier_requirements.has(action):
		return true  # No requirements
	
	var required: Dictionary = modifier_requirements[action]
	
	if required.get("ctrl", false) and not key_event.ctrl_pressed:
		return false
	if required.get("shift", false) and not key_event.shift_pressed:
		return false
	if required.get("alt", false) and not key_event.alt_pressed:
		return false
	
	return true


## Check if action is on cooldown
func _is_on_cooldown(action: String) -> bool:
	if not cooldowns.has(action):
		return false
	
	var last_press: int = cooldowns[action]
	var current_time := Time.get_ticks_msec()
	
	return (current_time - last_press) < COOLDOWN_MS


## Execute the action
func _execute_action(action: String, key: int) -> void:
	# Emit generic signal
	key_pressed.emit(action, key)
	shortcut_triggered.emit(action)
	
	# Execute specific action via managers
	match action:
		"toggle_theme":
			if ThemeManager:
				ThemeManager.cycle_theme()
		
		"toggle_fps":
			if SettingsManager:
				var current = SettingsManager.get_setting("ui", "show_fps", true)
				SettingsManager.set_setting("ui", "show_fps", not current)
		
		"toggle_metrics":
			if SettingsManager:
				var current = SettingsManager.get_setting("ui", "show_metrics", false)
				SettingsManager.set_setting("ui", "show_metrics", not current)
		
		"toggle_fullscreen":
			_toggle_fullscreen()
		
		"screenshot":
			_take_screenshot()
		
		"quit":
			_quit_application()
		
		"cycle_render_mode":
			if SettingsManager:
				var current = SettingsManager.get_setting("tracking", "render_mode", "gpu")
				var new_mode = "cpu" if current == "gpu" else "gpu"
				SettingsManager.set_setting("tracking", "render_mode", new_mode)
				print("[KeyboardManager] Render mode: %s" % new_mode)
		
		"reset_view":
			# Signal for other systems to handle
			pass
		
		"toggle_landmarks":
			if SettingsManager:
				var current = SettingsManager.get_setting("tracking", "show_landmarks", true)
				SettingsManager.set_setting("tracking", "show_landmarks", not current)
		
		"toggle_video":
			if SettingsManager:
				var current = SettingsManager.get_setting("ui", "show_video", true)
				SettingsManager.set_setting("ui", "show_video", not current)
		
		"save_preset":
			# Signal for preset system
			pass
		
		"load_preset":
			# Signal for preset system
			pass
		
		"undo":
			# Signal for undo system
			pass
		
		"redo":
			# Signal for redo system
			pass
	
	print("[KeyboardManager] Executed action: %s" % action)


## Toggle fullscreen mode
func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("[KeyboardManager] Windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[KeyboardManager] Fullscreen mode")


## Take screenshot
func _take_screenshot() -> void:
	# Create screenshots directory if needed
	var screenshots_dir := "user://screenshots"
	if not DirAccess.dir_exists_absolute(screenshots_dir):
		DirAccess.make_dir_recursive_absolute(screenshots_dir)
	
	# Generate filename with timestamp
	var datetime := Time.get_datetime_dict_from_system()
	var filename := "screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	var filepath := screenshots_dir.path_join(filename)
	
	# Capture viewport
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	
	# Save as PNG
	var error := img.save_png(filepath)
	if error == OK:
		print("[KeyboardManager] Screenshot saved: %s" % filepath)
	else:
		push_error("[KeyboardManager] Failed to save screenshot: %d" % error)


## Quit application with confirmation
func _quit_application() -> void:
	# TODO: Add confirmation dialog in production
	print("[KeyboardManager] Quitting application...")
	get_tree().quit()


## Set a key binding for an action
func set_binding(action: String, key: int) -> bool:
	if not DEFAULT_BINDINGS.has(action):
		push_warning("[KeyboardManager] Unknown action: %s" % action)
		return false
	
	# Check for conflicts
	var conflict := _check_conflict(action, key)
	if not conflict.is_empty():
		conflict_detected.emit(action, conflict)
		push_warning("[KeyboardManager] Key conflict: %s conflicts with %s" % [action, conflict])
		return false
	
	# Get old key (now safe with typed Dictionary)
	var old_key: int = bindings.get(action, -1)
	
	_set_binding_internal(action, key, true)
	
	binding_changed.emit(action, old_key, key)
	_save_bindings()
	
	return true


## Internal binding setter (no conflict check)
func _set_binding_internal(action: String, key: int, emit_signal: bool) -> void:
	# Remove old key from reverse lookup
	if bindings.has(action):
		var old_key := bindings[action]
		key_to_action.erase(old_key)
	
	# Set new binding
	bindings[action] = key
	key_to_action[key] = action


## Check if key is already bound to another action
func _check_conflict(action: String, key: int) -> String:
	if key_to_action.has(key):
		var existing_action := key_to_action[key] as String
		if existing_action != action:
			return existing_action
	return ""


## Get current key binding for action
func get_binding(action: String) -> int:
	return bindings.get(action, -1)


## Get action for a key
func get_action_for_key(key: int) -> String:
	return key_to_action.get(key, "")


## Get human-readable key name
func get_key_name(key: int) -> String:
	return OS.get_keycode_string(key)


## Get action description
func get_action_description(action: String) -> String:
	return action_descriptions.get(action, "")


## Enable/disable an action
func set_action_enabled(action: String, enabled: bool) -> void:
	if bindings.has(action):
		action_enabled[action] = enabled


## Check if action is enabled
func is_action_enabled(action: String) -> bool:
	return action_enabled.get(action, true)


## Reset bindings to defaults
func reset_to_defaults() -> void:
	bindings.clear()
	key_to_action.clear()
	
	for action in DEFAULT_BINDINGS.keys():
		_set_binding_internal(action, DEFAULT_BINDINGS[action], false)
	
	_save_bindings()
	print("[KeyboardManager] Reset to default bindings")


## Get all actions
func get_all_actions() -> Array:
	return bindings.keys()


## Get all bindings as dictionary
func get_all_bindings() -> Dictionary:
	return bindings.duplicate()


## Export bindings to JSON string
func export_bindings() -> String:
	var export_data := {
		"version": 1,
		"bindings": bindings.duplicate(),
		"modifiers": modifier_requirements.duplicate()
	}
	return JSON.stringify(export_data, "\t")


## Import bindings from JSON string
func import_bindings(json_string: String) -> bool:
	var json := JSON.new()
	var error := json.parse(json_string)
	
	if error != OK:
		push_error("[KeyboardManager] Failed to parse JSON: %s" % json.get_error_message())
		return false
	
	# Explicitly type as Variant to satisfy Godot 4.5+ type checker
	var data: Variant = json.data
	if not data is Dictionary:
		push_error("[KeyboardManager] Invalid import data format")
		return false
	
	if not data.has("bindings"):
		push_error("[KeyboardManager] Import data missing 'bindings' field")
		return false
	
	# Safely extract and validate bindings
	if not data["bindings"] is Dictionary:
		push_error("[KeyboardManager] Invalid bindings format")
		return false
	
	# Import bindings one by one
	var import_count: int = 0
	for action_name: String in data["bindings"].keys():
		if not DEFAULT_BINDINGS.has(action_name):
			push_warning("[KeyboardManager] Unknown action in import: %s" % action_name)
			continue
		
		var key_code: int = int(data["bindings"][action_name])
		_set_binding_internal(action_name, key_code, false)
		import_count += 1
	
	_save_bindings()
	print("[KeyboardManager] Imported %d bindings" % import_count)
	return true
