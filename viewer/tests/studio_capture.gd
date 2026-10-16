extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = arguments[0]
	var source_id := int(arguments[1]) if arguments.size() > 1 else -1
	root.add_child(studio)
	var deadline := Time.get_ticks_msec() + 8000
	while studio.source_picker.item_count < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	var selected := -1
	for index in studio.source_picker.item_count:
		var camera = studio.source_picker.get_item_metadata(index)
		if camera is Dictionary and camera.get("index") == source_id:
			selected = index
	if selected < 0:
		print("STUDIO_CAPTURE_FAILED source not discovered: ", studio.message.text)
		quit(1)
		return
	studio.source_picker.select(selected)
	studio.source_picker.item_selected.emit(selected)
	# Exercise the actual button, JSON serialization, HTTP route, capture, and
	# native reader. Starting capture separately through Python misses this path.
	studio.connect_button.pressed.emit()
	deadline = Time.get_ticks_msec() + 20000
	while studio.received_frames < 30 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	var valid = studio.received_frames >= 30 and studio.video.texture != null and studio.video.visible and not studio.empty_state.visible
	var before_buffers: Dictionary = studio.current_buffers.duplicate()
	var before_frames: int = studio.received_frames
	var before_revision: int = studio.tracking_panel.synced_revision
	studio.tracking_panel.controls.backend.select(2)
	studio.tracking_panel.controls.max_width.select(0)
	studio.tracking_panel.controls.detection_confidence.value = 0
	studio.tracking_panel._apply()
	deadline = Time.get_ticks_msec() + 5000
	while (studio.tracking_panel.synced_revision <= before_revision or studio.received_frames < before_frames + 15) and Time.get_ticks_msec() < deadline:
		await create_timer(.05).timeout
	valid = valid and studio.tracking_panel.synced_revision > before_revision and studio.current_buffers == before_buffers
	valid = valid and studio.tracking_panel.values().detection_confidence == 0 and studio.received_frames > before_frames
	print("STUDIO_CAPTURE_BUTTON frames=", studio.received_frames, " landmarks=", studio.overlay.points.size(), " source=", studio.source_picker.get_item_text(selected), " message=", studio.message.text)
	studio.video_reader.stop_reading()
	studio.landmark_reader.stop_reading()
	quit(0 if valid else 1)
