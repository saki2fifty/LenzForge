extends Node
## Global Signal Bus (Autoload Singleton)
## Provides centralized signal communication between managers
## Reduces coupling and makes signal flow transparent

# Performance signals
signal fps_updated(fps: float, frame_time_ms: float)
signal performance_warning(manager: String, operation: String, time_ms: float)

# Video signals
signal video_started()
signal video_stopped()
signal video_paused()
signal video_resumed()
signal new_video_frame(frame_id: int, texture: ImageTexture)

# Landmark signals
signal landmarks_updated(data: Dictionary)
signal face_tracking_started()
signal face_tracking_lost()

# Effect signals
signal effect_changed(effect_name: String)
signal effect_applied()

# UI signals
signal ui_toggle_requested(panel_name: String)
signal overlay_visibility_changed(visible: bool)

# System signals
signal shutdown_requested()
signal settings_changed(settings: Dictionary)

func _ready() -> void:
	print("[SignalBus] Global signal bus ready")
