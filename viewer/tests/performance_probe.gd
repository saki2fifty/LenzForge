extends SceneTree
var intervals: Array[float] = []
var ages: Array[float] = []
var uploads: Array[float] = []
var beard_updates: Array[float] = []
var last_frame_at := 0
var measuring := false

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
	var args := OS.get_cmdline_user_args()
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = args[0]
	var source_id := int(args[1])
	var duration := float(args[2])
	if args.size() > 3:
		Engine.max_fps = int(args[3])
	root.add_child(studio)
	studio.beard.set_enabled(args.size() > 6 and args[6] == "1")
	if studio.beard.enabled:
		var profile = load("res://beard/beard_profile.gd")
		studio.beard.apply_document(profile.document("Benchmark",profile.defaults(),{}))
		studio.beard.set_setting("strands",int(args[7]))
		studio.beard.set_setting("segments",int(args[8]))
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
	)
	await create_timer(2).timeout
	measuring = true
	await create_timer(duration).timeout
	measuring = false
	var gaps := 0
	for interval in intervals:
		if interval > 50:
			gaps += 1
	var result := {"frames": intervals.size(), "displayed_fps": intervals.size()/duration,
		"render_fps": Engine.get_frames_per_second(), "frame_cap": Engine.max_fps,
		"interval_ms": distribution(intervals), "gaps_over_50_ms": gaps,
		"frame_age_ms": distribution(ages), "upload_ms": distribution(uploads),
		"beard_update_ms":distribution(beard_updates), "beard_frames":beard_updates.size()}
	print("LENZFORGE_PERFORMANCE ", JSON.stringify(result))
	studio.video_reader.stop_reading()
	studio.landmark_reader.stop_reading()
	quit()
