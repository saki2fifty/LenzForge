extends Node

# Landmark Service
# Manages LMK1Reader for facial landmark tracking

signal landmarks_ready(points: Array, frame_id: int)
signal face_detected
signal face_lost
signal landmark_error(message: String)

var landmark_reader: Node = null
var is_active: bool = false
var last_landmark_count: int = 0

func _ready():
	print("[LandmarkService] Initialized")

func start_tracking():
	if is_active:
		print("[LandmarkService] Already active")
		return
	
	print("[LandmarkService] Starting landmark tracking...")
	
	# Create LMK1Reader - will be available once GDExtension loads
	# For now, this is a placeholder
	
	is_active = true
	print("[LandmarkService] Landmark tracking started")

func stop_tracking():
	if not is_active:
		return
	
	print("[LandmarkService] Stopping landmark tracking...")
	
	if landmark_reader:
		if landmark_reader.has_method("stop_reading"):
			landmark_reader.stop_reading()
		landmark_reader.queue_free()
		landmark_reader = null
	
	is_active = false
	print("[LandmarkService] Landmark tracking stopped")

func get_status() -> Dictionary:
	return {
		"active": is_active,
		"landmark_count": last_landmark_count
	}

func _exit_tree():
	stop_tracking()
