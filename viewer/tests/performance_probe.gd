extends SceneTree
var intervals: Array[float] = []
var ages: Array[float] = []
var uploads: Array[float] = []
var beard_updates: Array[float] = []
var landmark_ages: Array[float] = []
var pair_skews: Array[float] = []
var pair_mismatches := 0
var last_frame_at := 0
var measuring := false
var camera_consumer := -1
var output_readbacks: Array[float] = []
var output_conversions: Array[float] = []

func distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / values.size(), "p50": values[int((values.size()-1)*.50)], "p95": values[int((values.size()-1)*.95)], "p99": values[int((values.size()-1)*.99)], "max": values[-1]}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.gui_disable_input = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var args := OS.get_cmdline_user_args()
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = args[0]
	var source_id := int(args[1])
	var duration := float(args[2])
	root.add_child(studio)
	if args.size() > 3 and int(args[3]) >= 0: Engine.max_fps = int(args[3])
	if args.size() > 10 and args[10] != "project":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if args[10] == "on" else DisplayServer.VSYNC_DISABLED)
	studio.set_process_unhandled_key_input(false)
	var facial := args.size()>6 and args[6]=="1"
	var scalp_style := args[12] if args.size()>12 else "None"
	studio.beard.set_enabled(facial or scalp_style!="None")
	if studio.beard.enabled:
		var profile = load("res://beard/beard_profile.gd")
		studio.beard.apply_document(profile.document("Benchmark",profile.defaults(),{}))
		studio.beard.set_setting("strands",int(args[7]))
		studio.beard.set_setting("segments",int(args[8]))
		if not facial: studio.beard.set_settings({"beard_visible":false,"mustache_enabled":false,"brow_enabled":false})
	if scalp_style!="None": studio.beard.set_settings(preload("res://beard/groom_regions.gd").hair_preset(scalp_style))
	if args.size() > 4:
		studio.fps_picker.select({30: 0, 60: 1, 24: 2}[int(args[4])])
	if args.size() > 5:
		studio.overlay.show_points = args[5] == "1"
	var deadline := Time.get_ticks_msec() + 8000
	while studio.source_picker.item_count < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(.05).timeout
	var selected := -1
	for index in studio.source_picker.item_count:
		var camera = studio.source_picker.get_item_metadata(index)
		if camera is Dictionary and camera.get("index") == source_id:
			selected = index
	if selected < 0:
		quit(1)
		return
	studio.source_picker.select(selected)
	studio.source_picker.item_selected.emit(selected)
	studio.connect_button.pressed.emit()
	deadline = Time.get_ticks_msec() + 20000
	while studio.received_frames < 30 and Time.get_ticks_msec() < deadline:
		await create_timer(.05).timeout
	if studio.received_frames < 30:
		print("PERFORMANCE_FAILED ", studio.message.text)
		quit(1)
		return
	if args.size() > 11 and args[11] == "1":
		studio.virtual_camera.start()
		deadline = Time.get_ticks_msec()+25000
		while studio.virtual_camera.state == "Starting" and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
		if studio.virtual_camera.state != "Ready":
			print("PERFORMANCE_FAILED ",studio.virtual_camera.detail)
			quit(1)
			return
		camera_consumer = OS.create_process(ProjectSettings.globalize_path("res://../artifacts/virtual-camera-build/LenzForgeCameraProbe.exe"),["--discard",str(int((duration+float(args[9])+20)*60))],false)
		deadline = Time.get_ticks_msec()+10000
		while studio.virtual_camera.state != "Live" and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
		if studio.virtual_camera.state != "Live":
			print("PERFORMANCE_FAILED Virtual camera consumer did not connect")
			if camera_consumer > 0: OS.kill(camera_consumer)
			quit(1)
			return
	studio.video_reader.frame_ready.connect(func(_y, _uv, _frame, _timestamp):
		if not measuring:
			return
		var now := Time.get_ticks_usec()
		if last_frame_at:
			intervals.append((now - last_frame_at) / 1000.0)
		last_frame_at = now
		if studio.video_reader.has_method("get_frame_age_ms"):
			ages.append(studio.video_reader.get_frame_age_ms())
			uploads.append(studio.video_reader.get_upload_ms())
		if studio.beard.enabled and studio.beard._face_live:
			beard_updates.append(studio.beard.update_ms)
		if studio.virtual_camera.active:
			output_readbacks.append(studio.virtual_camera.readback_ms)
			output_conversions.append(studio.virtual_camera.stats.get("conversion_ms",0))
	)
	studio.landmark_reader.landmarks_ready.connect(func(_points, _frame, timestamp):
		if measuring:
			# Both readers use QPC microseconds. Cancel the video timestamp to
			# measure age at the landmark callback without another native API.
			landmark_ages.append(studio.video_reader.get_frame_age_ms() + (studio.video_reader.get_timestamp() - timestamp) / 1000.0)
	)
	RenderingServer.frame_pre_draw.connect(func():
		if measuring and not studio.overlay.points.is_empty():
			var skew := absf(studio.frame_timestamp-studio.landmark_timestamp)/1000.0
			pair_skews.append(skew)
			if skew != 0: pair_mismatches += 1)
	await create_timer(float(args[9]) if args.size() > 9 else 2.0).timeout
	var started := Time.get_ticks_usec()
	measuring = true
	await create_timer(duration).timeout
	measuring = false
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	var gaps := 0
	for interval in intervals:
		if interval > 50:
			gaps += 1
	var result := {"frames": intervals.size()+1, "elapsed_s":elapsed, "displayed_fps": (intervals.size()+1)/elapsed,
		"vsync":DisplayServer.window_get_vsync_mode(),"screen_refresh_hz":DisplayServer.screen_get_refresh_rate(),
		"render_fps": Engine.get_frames_per_second(), "frame_cap": Engine.max_fps,
		"interval_ms": distribution(intervals), "gaps_over_50_ms": gaps,
		"frame_age_ms": distribution(ages), "upload_ms": distribution(uploads),
		"landmark_age_ms": distribution(landmark_ages), "landmark_frames": landmark_ages.size(),
		"presented_pair_skew_ms":distribution(pair_skews),"mismatched_presentations":pair_mismatches,
		"beard_update_ms":distribution(beard_updates), "beard_frames":beard_updates.size(),
		"scalp_mesh_triangles":studio.beard.live_view.scalp.triangle_count,"scalp_mesh_revisions":studio.beard.live_view.scalp.revision,
		"output_handoff_ms":distribution(output_readbacks),"output_cpu_conversion_ms":distribution(output_conversions)}
	if studio.virtual_camera.active: result["virtual_camera"] = studio.virtual_camera.writer.get_status()
	print("LENZFORGE_PERFORMANCE ", JSON.stringify(result))
	if camera_consumer > 0 and OS.is_process_running(camera_consumer): OS.kill(camera_consumer)
	studio.virtual_camera.stop()
	studio.video_reader.stop_reading()
	studio.landmark_reader.stop_reading()
	quit()
