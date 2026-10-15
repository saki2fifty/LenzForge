extends Control
## Landmark Canvas - Renders face landmarks on screen
## Draws 478 face mesh points as small circles

# Landmark data
var current_landmarks: PackedVector2Array = PackedVector2Array()
var is_tracking: bool = false

# Rendering settings
var point_color: Color = Color(0, 1, 0, 0.8)  # Green with transparency
var point_size: float = 2.0
var show_connections: bool = false
var connection_color: Color = Color(0, 1, 0, 0.3)

func _ready() -> void:
	# Make sure we redraw when landmarks update
	set_process(false)  # We'll draw on demand

func update_landmarks(landmarks: Dictionary) -> void:
	"""Update landmark positions and trigger redraw"""
	is_tracking = landmarks.get("is_tracking", false)
	
	if is_tracking:
		var face: PackedVector2Array = landmarks.get("face", PackedVector2Array())
		if face.size() > 0:
			current_landmarks = face
			print("[LandmarkCanvas] Received %d landmarks, first point: %v" % [face.size(), face[0] if face.size() > 0 else Vector2.ZERO])
			queue_redraw()  # Request redraw
		else:
			print("[LandmarkCanvas] No face landmarks in dict")
	else:
		current_landmarks.clear()
		queue_redraw()

func _draw() -> void:
	"""Draw landmarks as circles"""
	print("[LandmarkCanvas] _draw() called, tracking: %s, landmarks: %d" % [is_tracking, current_landmarks.size()])
	
	if not is_tracking or current_landmarks.is_empty():
		return
	
	# Draw each landmark point
	for point in current_landmarks:
		draw_circle(point, point_size, point_color)
	
	print("[LandmarkCanvas] Drew %d landmarks" % current_landmarks.size())
	
	# Optionally draw connections (face mesh edges)
	if show_connections:
		_draw_face_connections()


func _draw_face_connections() -> void:
	"""Draw lines connecting landmark points (creates face mesh wireframe)"""
	# MediaPipe face mesh has specific connection indices
	# For simplicity, we'll draw connections between nearby points
	var step: int = 5  # Draw every 5th connection to avoid cluttering
	
	for i in range(0, current_landmarks.size() - step, step):
		if i + step < current_landmarks.size():
			draw_line(current_landmarks[i], current_landmarks[i + step], connection_color, 1.0)

func set_point_color(color: Color) -> void:
	"""Change landmark point color"""
	point_color = color
	queue_redraw()

func set_point_size(size: float) -> void:
	"""Change landmark point size"""
	point_size = size
	queue_redraw()

func toggle_connections(enabled: bool) -> void:
	"""Toggle face mesh connection lines"""
	show_connections = enabled
	queue_redraw()
