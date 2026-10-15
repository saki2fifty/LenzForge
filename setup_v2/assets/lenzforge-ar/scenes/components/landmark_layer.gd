extends Control
## Landmark Visualization Layer
## Renders 478 face landmarks in real-time
## Note: Control provides draw functions (queue_redraw, draw_circle, etc.)

var current_landmarks: Dictionary = {}
var landmark_color: Color = Color(0, 1, 0, 0.8)  # Green
var landmark_size: float = 2.0

func _ready() -> void:
	# Fill the viewport for drawing
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	print("[LandmarkLayer] Ready")

func update_landmarks(landmarks: Dictionary) -> void:
	"""Update and trigger redraw"""
	current_landmarks = landmarks
	queue_redraw()

func _draw() -> void:
	"""Draw all face landmarks"""
	if not current_landmarks.has("face"):
		return
	
	var face_landmarks: PackedVector2Array = current_landmarks.get("face", PackedVector2Array())
	
	# Draw each landmark as a small circle
	for point in face_landmarks:
		draw_circle(point, landmark_size, landmark_color)
	
	# Optionally draw iris landmarks
	if current_landmarks.has("iris_left"):
		var iris_left: PackedVector2Array = current_landmarks.get("iris_left", PackedVector2Array())
		for point in iris_left:
			draw_circle(point, landmark_size * 1.5, Color(1, 0, 1, 0.8))  # Magenta
	
	if current_landmarks.has("iris_right"):
		var iris_right: PackedVector2Array = current_landmarks.get("iris_right", PackedVector2Array())
		for point in iris_right:
			draw_circle(point, landmark_size * 1.5, Color(1, 0, 1, 0.8))  # Magenta

func set_landmark_color(color: Color) -> void:
	"""Change landmark color"""
	landmark_color = color
	queue_redraw()

func set_landmark_size(size: float) -> void:
	"""Change landmark size"""
	landmark_size = size
	queue_redraw()
