extends Node

# Video Service
# Manages VID1Reader for video streaming

signal video_frame_ready(texture: ImageTexture, frame_id: int)
signal video_started
signal video_stopped
signal video_error(message: String)

var video_reader: Node = null
var is_active: bool = false
var frame_count: int = 0
var fps: float = 0.0

func _ready():
	print("[VideoService] Initialized")

func start_video():
	if is_active:
		print("[VideoService] Already active")
		return
	
	print("[VideoService] Starting video stream...")
	
	# Create VID1Reader - will be available once GDExtension loads
	# For now, this is a placeholder that will be replaced
	# when the extension is properly loaded
	
	is_active = true
	video_started.emit()
	print("[VideoService] Video stream started")

func stop_video():
	if not is_active:
		return
	
	print("[VideoService] Stopping video stream...")
	
	if video_reader:
		if video_reader.has_method("stop_reading"):
			video_reader.stop_reading()
		video_reader.queue_free()
		video_reader = null
	
	is_active = false
	video_stopped.emit()
	print("[VideoService] Video stream stopped")

func get_status() -> Dictionary:
	return {
		"active": is_active,
		"frame_count": frame_count,
		"fps": fps
	}

func _exit_tree():
	stop_video()
