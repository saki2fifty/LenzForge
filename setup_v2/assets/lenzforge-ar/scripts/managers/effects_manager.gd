extends Node
## Effects System Manager (Phase 1 - Stub)
## Manages visual effects applied to video stream
## Full implementation in Phase 3

signal effect_changed(effect_name: String)
signal effect_applied()

# Current effect
var current_effect: String = "none"
var available_effects: Array[String] = []

# State
var is_running: bool = false

# Performance
var apply_times: Array[float] = []
const PERF_HISTORY_SIZE: int = 60

func _ready() -> void:
	print("[EffectsManager] Initializing (stub version)...")
	
	# Populate with placeholder effects
	available_effects = [
		"none",
		"grayscale",
		"blur",
		"edge_detect",
		"sepia"
	]
	
	is_running = true
	print("[EffectsManager] Ready - %d effects available" % available_effects.size())

func set_active_effect(effect_name: String) -> void:
	"""Set the currently active effect"""
	if effect_name not in available_effects:
		push_warning("[EffectsManager] Unknown effect: %s" % effect_name)
		return
	
	current_effect = effect_name
	effect_changed.emit(effect_name)
	print("[EffectsManager] Effect set: %s" % effect_name)

func apply_current_effect(video_texture: ImageTexture, landmarks: Dictionary) -> void:
	"""Apply current effect to video (stub - does nothing for now)"""
	var start_time: float = Time.get_ticks_usec()
	
	# TODO Phase 3: Actual effect application
	# For now, just track that we were called
	
	var apply_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	_track_performance(apply_time)
	
	effect_applied.emit()

func get_available_effects() -> Array[String]:
	"""Get list of available effects"""
	return available_effects.duplicate()

func get_current_effect() -> String:
	"""Get currently active effect"""
	return current_effect

func _track_performance(apply_time_ms: float) -> void:
	"""Track effect application performance"""
	apply_times.append(apply_time_ms)
	if apply_times.size() > PERF_HISTORY_SIZE:
		apply_times.pop_front()

func get_average_apply_time() -> float:
	"""Get average effect apply time in milliseconds"""
	if apply_times.is_empty():
		return 0.0
	
	var total: float = 0.0
	for at in apply_times:
		total += at
	return total / apply_times.size()

func cleanup() -> void:
	"""Clean shutdown"""
	is_running = false
	print("[EffectsManager] Cleaned up")

func get_stats() -> Dictionary:
	"""Get effects system statistics"""
	return {
		"is_running": is_running,
		"current_effect": current_effect,
		"available_effects": available_effects.size(),
		"avg_apply_time_ms": get_average_apply_time()
	}
