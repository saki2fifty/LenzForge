extends Control
## Desktop studio: direct video display, bounded-age tracking, and real backend controls.
const Overlay = preload("res://landmarks.gd")
const INK := Color("e4ebf3")
const MUTED := Color("8d9bb0")
const ACCENT := Color("68dfc3")
const BG := Color("0c111a")
const PANEL := Color("131c28")
const EDGE := Color("273448")
const BACKEND := "http://127.0.0.1:5000"

var video_reader: Node
var landmark_reader: Node
var video: TextureRect
var overlay: Control
var material_video: ShaderMaterial
var empty_state: VBoxContainer
var status: Label
var metrics: Label
var message: Label
var source_picker: OptionButton
var resolution_picker: OptionButton
var fps_picker: OptionButton
var record_button: Button
var connect_button: Button
var right_panel: PanelContainer
var mirror_check: CheckBox
var points_check: CheckBox
var preset_picker: OptionButton
var api_poll: HTTPRequest
var action_request: HTTPRequest
var online := false
var recording := false
var frame_timestamp: int = 0
var landmark_timestamp: int = 0
var last_video_at: int = 0
var last_record_poll := 0
var received_frames := 0
var pending_action := ""
var settings := ConfigFile.new()
var capture_path := ""
var current_buffers: Dictionary = {}
var last_source_id := -999
var shortcut_hint: Label
var tracking_checks: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 640))
	settings.load("user://studio.cfg")
	_build_ui()
	_setup_requests()
	_setup_readers()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_poll()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	if not capture_path.is_empty():
		get_tree().create_timer(3.0).timeout.connect(_capture_and_quit)

func _style(color: Color, radius := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func _label(text: String, font_size := 14, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var fill := Color("24483f") if primary else Color("1a2738")
		if state == "hover":
			fill = Color("2a594c") if primary else Color("26394e")
		var button_style := _style(fill, 8)
		button_style.content_margin_top = 8
		button_style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, button_style)
	button.pressed.connect(callback)
	return button

func _section(parent: VBoxContainer, title: String, description := "") -> void:
	parent.add_child(_label(title.to_upper(), 11, ACCENT))
	if not description.is_empty():
		var label := _label(description, 12, MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(label)

func _card(parent: Node, width := 0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", _style(PANEL))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	header.add_child(_label("LF", 30, ACCENT))
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header.add_child(brand)
	brand.add_child(_label("LenzForge", 24))
	brand.add_child(_label("REAL-TIME AR STUDIO", 10, MUTED))
	_spacer(header)
	status = _label("CONNECTING", 12, MUTED)
	header.add_child(status)
	header.add_child(_button("Browser controls  ↗", func(): OS.shell_open(BACKEND)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	var left := _card(body, 226)
	_section(left, "01 / Capture", "Choose a camera or explore the demo source.")
	source_picker = OptionButton.new()
	source_picker.add_item("Camera 0", 0)
	source_picker.add_item("Camera 1", 1)
	source_picker.add_item("Camera 2", 2)
	source_picker.add_item("Demo pattern", 99)
	source_picker.custom_minimum_size.y = 38
	left.add_child(source_picker)
	left.add_child(_button("Find cameras", _find_cameras))
	left.add_child(_label("RESOLUTION", 10, MUTED))
	resolution_picker = OptionButton.new()
	for item in ["1280 × 720", "1920 × 1080", "640 × 360"]:
		resolution_picker.add_item(item)
	left.add_child(resolution_picker)
	left.add_child(_label("FRAME RATE", 10, MUTED))
	fps_picker = OptionButton.new()
	for item in ["30 fps", "60 fps", "24 fps"]:
		fps_picker.add_item(item)
	left.add_child(fps_picker)
	connect_button = _button("Start capture", _start, true)
	left.add_child(connect_button)
	left.add_child(_button("Stop capture", func(): _action("/api/camera/stop", {})))
	left.add_child(HSeparator.new())
	_section(left, "02 / Tracking", "One tracking worker serves both previews.")
	for feature in ["face_mesh", "hands", "pose"]:
		var check := CheckBox.new()
		check.text = {"face_mesh": "Face + iris", "hands": "Hands", "pose": "Body pose"}[feature]
		check.button_pressed = feature == "face_mesh"
		tracking_checks["face" if feature == "face_mesh" else feature] = check
		check.toggled.connect(func(value): _action("/api/tracking/enable", {"face_mesh": value, "iris": value} if feature == "face_mesh" else {feature: value}))
		left.add_child(check)
	_spacer(left)
	left.add_child(_label("LOCAL PROCESSING", 10, ACCENT))
	var privacy := _label("Camera frames stay on this computer.", 12, MUTED)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(privacy)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	body.add_child(center)
	var preview_header := HBoxContainer.new()
	center.add_child(preview_header)
	preview_header.add_child(_label("Preview", 18))
	_spacer(preview_header)
	preview_header.add_child(_label("LIVE WORKSPACE", 10, MUTED))
	var preview := PanelContainer.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_theme_stylebox_override("panel", _style(Color("080d15"), 14))
	center.add_child(preview)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(240, 240)
	preview.add_child(canvas)
	video = TextureRect.new()
	video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	video.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(video)
	material_video = ShaderMaterial.new()
	material_video.shader = preload("res://video.gdshader")
	video.material = material_video
	overlay = Overlay.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	var empty_center := CenterContainer.new()
	empty_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(empty_center)
	empty_state = VBoxContainer.new()
	empty_state.add_theme_constant_override("separation", 14)
	empty_center.add_child(empty_state)
	for item in [["◎", 72, ACCENT], ["Make something expressive.", 23, INK], ["Start a camera to bring your workspace to life.", 13, MUTED], ["No camera? Choose Demo pattern.", 12, MUTED]]:
		var label := _label(item[0], item[1], item[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_state.add_child(label)
	metrics = _label("— fps    ·    — landmarks    ·    Waiting for a source", 12, MUTED)
	metrics.clip_text = true
	center.add_child(metrics)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	center.add_child(actions)
	actions.add_child(_button("Save snapshot", _snapshot))
	record_button = _button("●  Record source", _toggle_recording)
	actions.add_child(record_button)
	_spacer(actions)
	shortcut_hint = _label("L  landmarks    M  mirror    F11  fullscreen", 10, MUTED)
	actions.add_child(shortcut_hint)
	var right := _card(body, 228)
	right_panel = right.get_parent().get_parent()
	_section(right, "03 / Appearance", "Adjust the desktop preview. Recordings keep the original source.")
	right.add_child(_label("LOOK", 10, MUTED))
	preset_picker = OptionButton.new()
	for item in ["Natural", "Monochrome", "Warm film", "Crisp"]:
		preset_picker.add_item(item)
	preset_picker.item_selected.connect(_set_look)
	right.add_child(preset_picker)
	preset_picker.select(int(settings.get_value("view", "look", 0)))
	_set_look(preset_picker.selected)
	_slider(right, "Exposure", -0.3, 0.3, 0.01, 0.0, func(value): material_video.set_shader_parameter("exposure", value))
	mirror_check = CheckBox.new()
	mirror_check.text = "Mirror preview"
	mirror_check.button_pressed = bool(settings.get_value("view", "mirror", true))
	mirror_check.toggled.connect(_set_mirror)
	right.add_child(mirror_check)
	_set_mirror(mirror_check.button_pressed)
	right.add_child(HSeparator.new())
	_section(right, "Landmark overlay")
	points_check = CheckBox.new()
	points_check.text = "Show landmarks"
	points_check.button_pressed = bool(settings.get_value("view", "points", true))
	points_check.toggled.connect(_set_points)
	right.add_child(points_check)
	_set_points(points_check.button_pressed)
	_slider(right, "Point size", 1.0, 5.0, 0.25, 2.0, func(value): overlay.point_size = value; overlay.queue_redraw())
	var color := ColorPickerButton.new()
	color.color = ACCENT
	color.custom_minimum_size.y = 32
	color.color_changed.connect(func(value): overlay.tint = value; overlay.queue_redraw())
	right.add_child(color)
	_spacer(right)
	right.add_child(_label("DESIGNED FOR LOW LATENCY", 10, ACCENT))
	var note := _label("Video keeps moving when tracking pauses. Stale overlays clear automatically.", 12, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	message = _label("Ready. Start the backend, then select a capture source.", 12, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message)
	resized.connect(_adapt_layout)
	call_deferred("_adapt_layout")

func _adapt_layout() -> void:
	right_panel.visible = true
	shortcut_hint.visible = size.x >= 1280

func _slider(parent: Node, title: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> void:
	parent.add_child(_label(title, 12, MUTED))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(callback)
	parent.add_child(slider)

func _setup_requests() -> void:
	api_poll = HTTPRequest.new()
	api_poll.timeout = 2.0
	add_child(api_poll)
	api_poll.request_completed.connect(_on_poll)
	action_request = HTTPRequest.new()
	action_request.timeout = 20.0
	add_child(action_request)
	action_request.request_completed.connect(_on_action)

func _setup_readers() -> void:
	if not ClassDB.class_exists("VID1Reader") or not ClassDB.class_exists("LMK1Reader"):
		message.text = "Native video extension is missing. Run Setup.ps1 to build it."
		return
	video_reader = ClassDB.instantiate("VID1Reader")
	landmark_reader = ClassDB.instantiate("LMK1Reader")
	add_child(video_reader)
	add_child(landmark_reader)
	video_reader.frame_ready.connect(_on_video)
	landmark_reader.landmarks_ready.connect(_on_landmarks)
	landmark_reader.face_lost.connect(func(): overlay.points.clear(); overlay.queue_redraw())

func _poll() -> void:
	if api_poll.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		api_poll.request(BACKEND + "/api/status")
	if last_video_at and Time.get_ticks_msec() - last_video_at > 1500:
		empty_state.show()
		video.hide()
		overlay.points.clear()
		overlay.queue_redraw()
		if video_reader:
			video_reader.stop_reading()
			landmark_reader.stop_reading()

func _on_poll(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	online = code == 200
	status.text = "BACKEND CONNECTED" if online else "BACKEND OFFLINE"
	status.add_theme_color_override("font_color", ACCENT if online else Color("e9b665"))
	if not online:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var active: bool = data.get("camera_active", false)
	if active and video_reader:
		var buffers: Dictionary = data.get("buffers", {})
		if buffers != current_buffers:
			video_reader.stop_reading()
			landmark_reader.stop_reading()
			current_buffers = buffers
		if not video_reader.is_reading():
			video_reader.start_reading(current_buffers.get("video", "LenzForge_Video_NV12"))
		if not landmark_reader.is_reading():
			landmark_reader.start_reading(current_buffers.get("landmarks", "LenzForge_Landmarks"))
	if active:
		var source_id: int = int(data.get("camera_index", 0))
		if source_id != last_source_id:
			last_source_id = source_id
			for index in source_picker.item_count:
				if source_picker.get_item_id(index) == (99 if source_id == -1 else source_id):
					source_picker.select(index)
		status.text = "SOURCE LIVE"
	var tracking: Dictionary = data.get("tracking", {})
	var features: Dictionary = tracking.get("features", {})
	for feature in tracking_checks:
		if features.has(feature):
			tracking_checks[feature].set_pressed_no_signal(features[feature])
	metrics.text = "%.1f fps    ·    %d landmarks    ·    %.1f ms inference    ·    %s" % [data.get("fps", 0.0), tracking.get("landmark_count", 0), tracking.get("last_inference_ms", 0.0), data.get("source", "No source")]
	if tracking.get("error"):
		message.text = "Tracking: " + str(tracking.error)
	if data.has("recording"):
		recording = data.recording
		record_button.text = "■  Stop recording" if recording else "●  Record source"

func _action(path: String, data: Dictionary, method := HTTPClient.METHOD_POST) -> void:
	if action_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		message.text = "Waiting for the previous request…"
		return
	pending_action = path
	message.text = "Working…"
	var error := action_request.request(BACKEND + path, ["Content-Type: application/json"], method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(data))
	if error != OK:
		message.text = "Could not contact the backend."

func _on_action(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if code < 200 or code >= 300 or not data is Dictionary:
		var detail = data.get("error", "Request failed. Check the backend.") if data is Dictionary else "Backend unavailable. Run Start-Backend.ps1."
		message.text = str(detail.get("message", "Request failed.")) if detail is Dictionary else str(detail)
		return
	message.text = "Updated."
	if pending_action == "/api/camera/list":
		source_picker.clear()
		for camera in data.get("cameras", []):
			source_picker.add_item(camera.name, 99 if camera.index == -1 else camera.index)
	if data.has("files"):
		message.text = "Recording: " + ", ".join(PackedStringArray(data.files))
	_poll()

func _find_cameras() -> void:
	_action("/api/camera/list", {}, HTTPClient.METHOD_GET)

func _start() -> void:
	if video_reader:
		video_reader.stop_reading()
		landmark_reader.stop_reading()
	var index := source_picker.get_selected_id()
	_action("/api/camera/select", {"camera_index": -1 if index == 99 else index, "resolution": [[1280, 720], [1920, 1080], [640, 360]][resolution_picker.selected], "fps": [30, 60, 24][fps_picker.selected]})

func _on_video(y: ImageTexture, uv: ImageTexture, _frame_id: int, timestamp: int) -> void:
	video.texture = y
	video.show()
	empty_state.hide()
	material_video.set_shader_parameter("y_texture", y)
	material_video.set_shader_parameter("uv_texture", uv)
	overlay.video_size = Vector2(y.get_width(), y.get_height())
	frame_timestamp = timestamp
	last_video_at = Time.get_ticks_msec()
	received_frames += 1
	if received_frames == 1:
		message.text = "Source connected. Adjust your look or start a recording."
	if frame_timestamp - landmark_timestamp > 150000:
		overlay.points.clear()
	overlay.queue_redraw()

func _on_landmarks(points: Array, _frame_id: int, timestamp: int) -> void:
	landmark_timestamp = timestamp
	if absi(frame_timestamp - timestamp) > 150000:
		return
	var normalized := PackedVector2Array()
	for point in points:
		normalized.append(Vector2(point.x, point.y))
	overlay.points = normalized
	overlay.queue_redraw()

func _set_look(index: int) -> void:
	var looks := [[1.0, 1.0, 0.0], [0.0, 1.15, 0.0], [0.8, 1.05, 0.045], [1.15, 1.18, 0.0]]
	index = clampi(index, 0, looks.size() - 1)
	material_video.set_shader_parameter("saturation", looks[index][0])
	material_video.set_shader_parameter("contrast", looks[index][1])
	material_video.set_shader_parameter("warmth", looks[index][2])
	settings.set_value("view", "look", index)

func _set_mirror(value: bool) -> void:
	material_video.set_shader_parameter("mirror", value)
	overlay.mirror = value
	overlay.queue_redraw()
	settings.set_value("view", "mirror", value)

func _set_points(value: bool) -> void:
	overlay.show_points = value
	overlay.queue_redraw()
	settings.set_value("view", "points", value)

func _snapshot() -> void:
	if video.texture == null:
		message.text = "Start a source before taking a snapshot."
		return
	var path := "user://captures"
	DirAccess.make_dir_recursive_absolute(path)
	var destination := path + "/studio-%d.png" % Time.get_unix_time_from_system()
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(destination)
	message.text = "Saved " + ProjectSettings.globalize_path(destination) if error == OK else "Snapshot could not be saved."

func _toggle_recording() -> void:
	_action("/api/export/recording/stop" if recording else "/api/export/recording/start", {})

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L: points_check.button_pressed = not points_check.button_pressed
			KEY_M: mirror_check.button_pressed = not mirror_check.button_pressed
			KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _exit_tree() -> void:
	settings.save("user://studio.cfg")

func _capture_and_quit() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("STUDIO_CAPTURE frames=", received_frames, " landmarks=", overlay.points.size())
	get_tree().quit()
