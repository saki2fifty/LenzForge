extends Node2D

# Main scene for LenzForge Demo
# Simple launcher that shows available demos

func _ready():
	print("[LenzForge] Main scene loaded")
	print("[LenzForge] Available demos:")
	print("  - res://scenes/test_video.gd - Basic video test")
	print("[LenzForge] To test video: Run test_video.tscn scene (F6)")
	
	# Display simple instructions
	$Label.text = """
	LenzForge Demo Project
	
	Available Test Scenes:
	- test_video.tscn - Basic video streaming test
	
	To test:
	1. Ensure backend is running (http://localhost:5000)
	2. Open test_video.tscn in FileSystem
	3. Press F6 to run the scene
	"""
