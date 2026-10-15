extends Node2D

# Simple test scene for VID1Reader
# Tests real-time video streaming from LenzForge backend

var video_reader: Node
var frame_count: int = 0
var start_time: float = 0.0

func _ready():
	print("[TestVideo] Initializing...")
	
	# Create video reader (using Node since we don't have type hints for custom classes yet)
	video_reader = Node.new()
	video_reader.set_script(load("res://addons/lenzforge/video/vid1_reader.gd"))
	add_child(video_reader)
	
	# Alternative: Create directly if GDExtension is working
	# video_reader = VID1Reader.new()
	# add_child(video_reader)
	
	# Connect signals
	if video_reader.has_signal("frame_ready"):
		video_reader.frame_ready.connect(_on_frame_ready)
		print("[TestVideo] Connected to frame_ready signal")
	else:
		print("[TestVideo] ERROR: frame_ready signal not found!")
		print("[TestVideo] Available signals: ", video_reader.get_signal_list())
	
	# Start reading
	if video_reader.has_method("start_reading"):
		var success = video_reader.start_reading()
		if success:
			print("[TestVideo] Started reading video stream")
			start_time = Time.get_ticks_msec() / 1000.0
		else:
			print("[TestVideo] ERROR: Failed to start reading!")
	else:
		print("[TestVideo] ERROR: start_reading method not found!")
		print("[TestVideo] Available methods: ", video_reader.get_method_list())

func _on_frame_ready(texture: ImageTexture, frame_id: int):
	# Update display
	$VideoDisplay.texture = texture
	
	# Count frames
	frame_count += 1
	
	# Calculate FPS every second
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	if elapsed >= 1.0:
		var fps = frame_count / elapsed
		print("[TestVideo] FPS: %.1f | Frame ID: %d" % [fps, frame_id])
		
		# Reset counters
		frame_count = 0
		start_time = Time.get_ticks_msec() / 1000.0

func _exit_tree():
	# Clean up
	if video_reader and video_reader.has_method("stop_reading"):
		video_reader.stop_reading()
		print("[TestVideo] Stopped video reader")
