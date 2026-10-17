extends SceneTree
var failures: Array[String] = []
var pairs := 0
var unlocked := 0
var timeouts := 0
var source_pixels := 0
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:1"
	root.add_child(studio)
	for child in studio.get_children():
		if child is Timer: child.stop()
	studio.beard.set_settings({"strands":64,"collisions":false,"mustache_collisions":false})
	studio.beard.set_enabled(true)
	var args := OS.get_cmdline_user_args()
	check(studio.video_reader.start_reading(args[0]),"Open video ring")
	check(studio.landmark_reader.start_reading(args[1]),"Open landmark ring")
	studio.video_reader.synchronization_lost.connect(func(): timeouts += 1)
	RenderingServer.frame_pre_draw.connect(func():
		if studio.video_reader.is_frame_locked() and studio.beard._face_live:
			pairs += 1
			check(studio.frame_timestamp == studio.landmark_timestamp,"Every rendered face/hair overlay matches its displayed camera timestamp")
			var target := Vector3(studio.beard.roots[0].x,studio.beard.roots[0].y,studio.beard.root_depth[0]*64)
			check(studio.beard.simulator.get_strand_points_3d(0)[0].distance_to(target) < .0001,"Pinned hair root uses this frame's attachment before drawing")
		else:
			unlocked += 1
			check(studio.overlay.points.is_empty(),"Stale/missing results show raw video without a detached face overlay"))
	studio.landmark_reader.landmarks_ready.connect(func(_points, id, timestamp):
		if not studio.video_reader.is_frame_locked(): return
		check(studio.video_reader.get_frame_id() == id and studio.frame_timestamp == timestamp,"Frame ID and timestamp match together")
		var before: int = studio.video_reader.get_frame_id()
		check(not studio.video_reader.present_frame(id,timestamp+1),"Reject a matching ID with the wrong timestamp")
		check(not studio.video_reader.present_frame(id+10000,timestamp),"Reject unavailable frame IDs")
		check(studio.video_reader.get_frame_id() == before,"Rejected matches cannot alter the displayed frame")
		source_pixels += 1
		var actual := roundi(studio.video.texture.get_image().get_pixel(0,0).r*255)
		check(actual == 40+id%160,"Uploaded video pixels belong to the tracking result, through ring wrap"))
	await create_timer(6.0).timeout
	check(pairs > 100 and source_pixels > 60,"Exercise fast and delayed tracking, rapid reversals, and many ring wraps")
	check(timeouts > 0 and unlocked > 20,"Stalled inference times out, clears overlays, and resumes raw video")
	check(studio.video_reader.is_frame_locked() and studio.beard._face_live,"Face tracking recovers without restarting capture")
	studio.video_reader.stop_reading(); studio.landmark_reader.stop_reading()
	print("ATTACHMENT_SYNC pairs=",pairs," source_frames=",source_pixels," unlocked=",unlocked," timeouts=",timeouts," failures=",failures)
	quit(0 if failures.is_empty() else 1)
