extends SceneTree
var video_count := 0
var landmark_count := 0
var lost_count := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("VID1Reader") or not ClassDB.class_exists("LMK1Reader"):
		push_error("IPC_PROBE missing native readers")
		quit(1)
		return
	var video: Node = ClassDB.instantiate("VID1Reader")
	var landmarks: Node = ClassDB.instantiate("LMK1Reader")
	root.add_child(video)
	root.add_child(landmarks)
	video.frame_ready.connect(func(y, uv, _id, timestamp):
		video_count += 1
		if y.get_width() != 64 or uv.get_width() != 32 or timestamp <= 0:
			failures.append("Invalid video dimensions or timestamp")
	)
	landmarks.landmarks_ready.connect(func(points, _id, timestamp):
		landmark_count += 1
		if points.size() != 478 or absf(points[0].x - 0.25) > 0.001 or absf(points[0].y - 0.75) > 0.001:
			failures.append("Invalid landmark payload")
		if timestamp <= 0 or absi(timestamp - video.get_timestamp()) > 1000000:
			failures.append("QPC timestamps must be converted to microseconds consistently")
	)
	landmarks.face_lost.connect(func(): lost_count += 1)
	var args := OS.get_cmdline_user_args()
	if not video.start_reading(args[0]) or not landmarks.start_reading(args[1]):
		failures.append("Could not open producer buffers")
	await create_timer(2.0).timeout
	video.stop_reading()
	landmarks.stop_reading()
	print("IPC_PROBE video=", video_count, " landmarks=", landmark_count, " lost=", lost_count, " failures=", failures)
	quit(0 if failures.is_empty() and video_count > 10 and landmark_count > 10 and lost_count > 0 else 1)
