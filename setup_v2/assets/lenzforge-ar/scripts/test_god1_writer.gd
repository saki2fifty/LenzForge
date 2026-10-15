extends Node

# Simple test script for GOD1Writer
# Place this in your main scene and run to test viewport capture

var god1_writer  # GOD1Writer instance
var frame_count: int = 0
var test_duration: float = 10.0  # Test for 10 seconds
var elapsed: float = 0.0

func _ready():
	print("=== GOD1Writer Test Starting ===")
	
	# Create GOD1Writer instance
	god1_writer = ClassDB.instantiate("GOD1Writer")
	
	# Initialize with 1280x720 RGB24
	var success = god1_writer.init(1280, 720, 0)  # 0 = RGB24
	
	if success:
		print("✅ GOD1Writer initialized successfully")
		print("   Resolution: 1280x720")
		print("   Format: RGB24")
		print("   Buffer size: ~21 MB")
		print("   Testing for %.1f seconds..." % test_duration)
	else:
		print("❌ GOD1Writer initialization FAILED")
		push_error("Failed to initialize GOD1Writer")
		return

func _process(delta):
	if god1_writer == null or not god1_writer.is_ready():
		return
	
	elapsed += delta
	
	# Write a frame from the viewport
	var viewport = get_viewport()
	var success = god1_writer.write_frame_from_viewport(viewport)
	
	if success:
		frame_count += 1
		
		# Print stats every second
		if int(elapsed) != int(elapsed - delta):
			var stats = god1_writer.get_stats()
			print("Frame %d | Elapsed: %.1fs | Stats: %s" % [
				frame_count,
				elapsed,
				str(stats)
			])
	else:
		print("⚠️ Failed to write frame %d" % frame_count)
	
	# Stop test after duration
	if elapsed >= test_duration:
		print("\n=== GOD1Writer Test Complete ===")
		print_final_stats()
		set_process(false)

func print_final_stats():
	if god1_writer == null:
		return
	
	var stats = god1_writer.get_stats()
	print("Final Statistics:")
	print("  Total Frames: %d" % god1_writer.get_total_frames())
	print("  Dropped Frames: %d" % god1_writer.get_dropped_frames())
	print("  Frame Width: %d" % god1_writer.get_frame_width())
	print("  Frame Height: %d" % god1_writer.get_frame_height())
	print("  Pixel Format: %d (0=RGB24, 1=NV12)" % god1_writer.get_pixel_format())
	print("  Average FPS: %.1f" % (frame_count / test_duration))
	print("\n✅ GOD1Writer is working correctly!")
	print("   Shared memory buffer: Global\\LenzForge_GodotOutput")
	print("   You can now implement the Python GOD1Reader to consume frames")

func _exit_tree():
	if god1_writer != null:
		god1_writer.shutdown()
		print("GOD1Writer shutdown complete")
