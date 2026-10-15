extends RefCounted
## Application Configuration Manager
## Centralized configuration for the AR system
## Small, focused, reusable

class_name AppConfig

# Ring buffer names
const VID1_BUFFER_NAME: String = "LenzForge_Video"
const LMK1_BUFFER_NAME: String = "LenzForge_Landmarks"
const GOD1_BUFFER_NAME: String = "LenzForge_VirtualCamera"

# GDExtension paths
const VID1_READER_PATH: String = "res://addons/lenzforge/video/vid1_reader.gd"
const LMK1_READER_PATH: String = "res://addons/lenzforge/landmarks/lmk1_reader.gd"
const GOD1_WRITER_PATH: String = "res://addons/lenzforge/vcam/god1_writer.gd"

# Performance targets (milliseconds)
const TARGET_FPS: float = 60.0
const TARGET_FRAME_TIME_MS: float = 16.67  # 1000ms / 60fps
const VIDEO_PROCESS_TARGET_MS: float = 5.0
const LANDMARK_PROCESS_TARGET_MS: float = 3.0
const EFFECTS_APPLY_TARGET_MS: float = 3.0

# Landmark configuration
const FACE_LANDMARK_COUNT: int = 478
const IRIS_LANDMARK_COUNT: int = 5  # Per eye
const DEFAULT_SMOOTHING_FACTOR: float = 0.7

# Video configuration
const DEFAULT_VIDEO_WIDTH: int = 1920
const DEFAULT_VIDEO_HEIGHT: int = 1080
const MAX_FRAME_AGE_MS: float = 100.0  # Drop frames older than this

# Performance tracking
const PERF_HISTORY_SIZE: int = 60

# Keyboard shortcuts
const KEY_TOGGLE_FPS: Key = KEY_F
const KEY_TOGGLE_EFFECTS: Key = KEY_E
const KEY_TOGGLE_SETTINGS: Key = KEY_S
const KEY_TOGGLE_PAUSE: Key = KEY_SPACE
const KEY_TOGGLE_LANDMARKS: Key = KEY_L
const KEY_QUIT: Key = KEY_ESCAPE

static func create_default_settings() -> Dictionary:
	"""Create default application settings"""
	return {
		"video": {
			"width": DEFAULT_VIDEO_WIDTH,
			"height": DEFAULT_VIDEO_HEIGHT,
			"max_frame_age_ms": MAX_FRAME_AGE_MS
		},
		"landmarks": {
			"smoothing_enabled": true,
			"smoothing_factor": DEFAULT_SMOOTHING_FACTOR
		},
		"effects": {
			"current_effect": "none"
		},
		"ui": {
			"show_fps_overlay": true,
			"show_effects_panel": false,
			"show_settings": false
		},
		"performance": {
			"target_fps": TARGET_FPS,
			"history_size": PERF_HISTORY_SIZE
		}
	}

static func get_ring_buffer_name(buffer_type: String) -> String:
	"""Get ring buffer name by type"""
	match buffer_type:
		"video", "VID1":
			return VID1_BUFFER_NAME
		"landmarks", "LMK1":
			return LMK1_BUFFER_NAME
		"vcam", "GOD1":
			return GOD1_BUFFER_NAME
		_:
			push_error("[AppConfig] Unknown buffer type: %s" % buffer_type)
			return ""

static func get_reader_path(buffer_type: String) -> String:
	"""Get GDExtension reader path by type"""
	match buffer_type:
		"video", "VID1":
			return VID1_READER_PATH
		"landmarks", "LMK1":
			return LMK1_READER_PATH
		"vcam", "GOD1":
			return GOD1_WRITER_PATH
		_:
			push_error("[AppConfig] Unknown buffer type: %s" % buffer_type)
			return ""
