extends Control
## Desktop studio: direct video display, bounded-age tracking, and real backend controls.
const Overlay = preload("res://landmarks.gd")
const ExtensionLayer = preload("res://tracking/extension_layer.gd")
const LandmarksPanel = preload("res://tracking/landmarks_panel.gd")
const TrackingPanel = preload("res://tracking/tracking_panel.gd")
const HeadOcclusion = preload("res://tracking/head_occlusion.gd")
const BeardLayer = preload("res://beard/beard_layer.gd")
const BeardPanel = preload("res://beard/beard_panel.gd")
const QuickToolbar = preload("res://ui/quick_toolbar.gd")
const INK := Color("e4ebf3")
const MUTED := Color("8d9bb0")
const ACCENT := Color("68dfc3")
const BG := Color("0c111a")
const PANEL := Color("131c28")
const EDGE := Color("273448")
const BACKEND := "http://127.0.0.1:5000"

var backend_url := BACKEND
var video_reader: Node
var landmark_reader: Node
var video: TextureRect
var overlay: Control
var extensions: Control
var landmarks_panel: VBoxContainer
var tracking_panel: VBoxContainer
var occlusion := HeadOcclusion.new()
var beard: Control
var beard_panel: VBoxContainer
var sidebar_tabs: TabContainer
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
var left_panel: PanelContainer
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
var discovery_attempted := false
var persist_settings := true
var settings_path := "user://studio.cfg"
var save_timer := Timer.new()
var backend_save_timer := Timer.new()
var settings_ready := false
var saved_text := ""
var pending_settings: Dictionary = {}
var blocked_settings: Dictionary = {}
var action_queue: Array[Dictionary] = []
var pending_payload: Dictionary = {}
var exposure_slider: HSlider
var point_slider: HSlider
var point_color: ColorPickerButton
var quick_toolbar: PanelContainer
var guides_check: CheckBox
var occlusion_check: CheckBox
var pacing_picker: OptionButton
const PACING_MODES := ["responsive","display_sync","low_power"]

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 640))
	if OS.has_environment("LENZFORGE_SETTINGS_DIR"):
		settings_path = OS.get_environment("LENZFORGE_SETTINGS_DIR").path_join("studio.cfg")
	if persist_settings:
		var error := settings.load(settings_path)
		if error != OK and error != ERR_FILE_NOT_FOUND:
			push_warning("Could not read settings; trying the previous save.")
			settings.load(settings_path + ".bak")
	pending_settings = settings.get_value("backend", "pending", {})
	_build_ui()
	_setup_requests()
	_setup_readers()
	_setup_autosave()
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
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var fill := Color("24483f") if primary else Color("1a2738")
		if state == "hover":
			fill = Color("2a594c") if primary else Color("26394e")
		var button_style := _style(fill, 8)
		button_style.content_margin_top = 8
		button_style.content_margin_bottom = 8
		button_style.content_margin_left = 10
		button_style.content_margin_right = 10
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
	header.add_child(_button("Browser controls  ↗", func(): OS.shell_open(backend_url)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	var left := _card(body, 206)
	left_panel = left.get_parent().get_parent()
	var compact_theme := Theme.new()
	compact_theme.default_font_size = 12
	left_panel.theme = compact_theme
	_section(left, "01 / Capture", "Choose your webcam by name, then start capture.")
	source_picker = OptionButton.new()
	source_picker.add_item("Waiting for cameras…")
	source_picker.set_item_disabled(0, true)
	source_picker.item_selected.connect(_source_selected)
	source_picker.custom_minimum_size.y = 38
	source_picker.fit_to_longest_item = false
	source_picker.clip_text = true
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
	resolution_picker.select(clampi(int(settings.get_value("capture", "resolution", 0)),0,2))
	fps_picker.select(clampi(int(settings.get_value("capture", "fps", 1)),0,2))
	left.add_child(fps_picker)
	connect_button = _button("Start capture", _start, true)
	connect_button.disabled = true
	left.add_child(connect_button)
	left.add_child(_button("Stop capture", func(): _action("/api/camera/stop", {})))
	left.add_child(HSeparator.new())
	_section(left, "02 / Tracking", "One tracking worker serves both previews.")
	for feature in ["face_mesh", "hands", "pose"]:
		var check := CheckBox.new()
		check.text = {"face_mesh": "Face + iris", "hands": "Hands", "pose": "Body pose"}[feature]
		check.button_pressed = feature == "face_mesh"
		tracking_checks["face" if feature == "face_mesh" else feature] = check
		check.toggled.connect(func(value): _queue_backend_setting("/api/tracking/enable", {"face_mesh": value, "iris": value} if feature == "face_mesh" else {feature: value}))
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
	quick_toolbar = QuickToolbar.new()
	center.add_child(quick_toolbar)
	var preview := PanelContainer.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_theme_stylebox_override("panel", _style(Color("080d15"), 14))
	center.add_child(preview)
	var canvas := Control.new()
	canvas.clip_contents = true
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
	beard = BeardLayer.new()
	beard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(beard)
	overlay = Overlay.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	extensions = ExtensionLayer.new()
	extensions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(extensions)
	var saved_extensions = settings.get_value("landmarks", "extensions", {})
	if saved_extensions is Dictionary and not saved_extensions.is_empty():
		extensions.set_settings(extensions.model.for_saved_settings(saved_extensions))
	beard.preview_face_changed.connect(_sync_preview_landmarks)
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
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	center.add_child(actions)
	actions.add_child(_button("Save snapshot", _snapshot))
	record_button = _button("●  Record source", _toggle_recording)
	actions.add_child(record_button)
	shortcut_hint = _label("L  landmarks    M  mirror    F11  fullscreen", 10, MUTED)
	actions.add_child(shortcut_hint)
	right_panel = PanelContainer.new()
	right_panel.custom_minimum_size.x = 320
	right_panel.theme = compact_theme
	var right_style := _style(PANEL)
	right_style.content_margin_left = 12
	right_style.content_margin_right = 12
	right_panel.add_theme_stylebox_override("panel", right_style)
	body.add_child(right_panel)
	sidebar_tabs = TabContainer.new()
	sidebar_tabs.clip_tabs = true
	sidebar_tabs.add_theme_font_size_override("font_size", 12)
	right_panel.add_child(sidebar_tabs)
	var right := _tab_column("Look")
	_section(right, "03 / Appearance", "Adjust the desktop preview. Recordings keep the original source.")
	right.add_child(_label("LOOK", 10, MUTED))
	preset_picker = OptionButton.new()
	for item in ["Natural", "Monochrome", "Warm film", "Crisp"]:
		preset_picker.add_item(item)
	preset_picker.item_selected.connect(_set_look)
	right.add_child(preset_picker)
	preset_picker.select(int(settings.get_value("view", "look", 0)))
	_set_look(preset_picker.selected)
	exposure_slider = _slider(right, "Exposure", -0.3, 0.3, 0.01, float(settings.get_value("view", "exposure", 0.0)), func(value): material_video.set_shader_parameter("exposure", value))
	material_video.set_shader_parameter("exposure", exposure_slider.value)
	mirror_check = CheckBox.new()
	mirror_check.text = "Mirror preview"
	mirror_check.button_pressed = bool(settings.get_value("view", "mirror", true))
	mirror_check.toggled.connect(_set_mirror)
	right.add_child(mirror_check)
	_set_mirror(mirror_check.button_pressed)
	right.add_child(_label("PREVIEW PACING",10,MUTED))
	pacing_picker = OptionButton.new()
	for title in ["Responsive (up to 120 fps)","Display synchronized","Low power (up to 60 fps)"]: pacing_picker.add_item(title)
	pacing_picker.fit_to_longest_item = false
	pacing_picker.tooltip_text = "Responsive avoids VSync stalls and polls new camera frames quickly. Display synchronized prevents tearing. Low power reduces rendering work."
	var saved_pacing := str(settings.get_value("view","pacing","responsive"))
	pacing_picker.select(maxi(0,PACING_MODES.find(saved_pacing)))
	pacing_picker.item_selected.connect(_set_pacing)
	right.add_child(pacing_picker)
	_set_pacing(pacing_picker.selected)
	right.add_child(HSeparator.new())
	var landmark_column := _tab_column("Landmarks")
	guides_check = CheckBox.new()
	guides_check.text = "Show landmark guides"
	guides_check.tooltip_text = "Show / hide all guide dots while keeping tracking and individual visibility choices."
	guides_check.button_pressed = bool(settings.get_value("view", "guides", false))
	guides_check.toggled.connect(_set_guides)
	landmark_column.add_child(guides_check)
	_set_guides(guides_check.button_pressed)
	landmarks_panel = LandmarksPanel.new()
	landmark_column.add_child(landmarks_panel)
	landmarks_panel.setup(self, extensions)
	_section(landmark_column, "Visibility", "Hide landmarks and strands behind the fitted head. Uncheck to inspect hidden guides. Head shape is estimated; hands and room objects are not occluders.")
	var hide_back := CheckBox.new()
	occlusion_check = hide_back
	hide_back.text = "Hide behind head"
	occlusion.enabled = bool(settings.get_value("view", "occlusion", true))
	hide_back.button_pressed = occlusion.enabled
	hide_back.toggled.connect(func(value): occlusion.enabled = value; _refresh_occlusion())
	landmark_column.add_child(hide_back)
	occlusion.head_depth = clampf(float(settings.get_value("view", "head_depth", .65)),.25,1.0)
	occlusion.crown = clampf(float(settings.get_value("view", "head_crown", .20)),0,.5)
	_slider(landmark_column, "Head depth", .25, 1.0, .01, occlusion.head_depth, func(value): occlusion.head_depth = value; _refresh_occlusion())
	_slider(landmark_column, "Crown height", 0.0, .5, .01, occlusion.crown, func(value): occlusion.crown = value; _refresh_occlusion())
	overlay.occlusion = occlusion
	extensions.occlusion = occlusion
	beard.occlusion = occlusion
	beard.surface = occlusion.surface
	beard.external_surface = true
	extensions.model.surface = occlusion.surface
	extensions.model.external_surface = true
	beard.extension_model = extensions.model
	beard.mannequin_view.set_surface_shape(occlusion.head_depth,occlusion.crown)
	landmark_column.add_child(HSeparator.new())
	_section(landmark_column, "Measured landmarks")
	points_check = CheckBox.new()
	points_check.text = "Show measured landmarks"
	points_check.button_pressed = bool(settings.get_value("view", "points", true))
	points_check.toggled.connect(_set_points)
	landmark_column.add_child(points_check)
	_set_points(points_check.button_pressed)
	point_slider = _slider(landmark_column, "Point size", 1.0, 5.0, 0.25, float(settings.get_value("view", "point_size", 2.0)), func(value): overlay.point_size = value; overlay.queue_redraw())
	overlay.point_size = point_slider.value
	var color := ColorPickerButton.new()
	point_color = color
	color.color = settings.get_value("view", "point_color", ACCENT)
	overlay.tint = color.color
	color.custom_minimum_size.y = 32
	color.color_changed.connect(func(value): overlay.tint = value; overlay.queue_redraw())
	landmark_column.add_child(color)
	_spacer(right)
	right.add_child(_label("DESIGNED FOR LOW LATENCY", 10, ACCENT))
	var note := _label("Video keeps moving when tracking pauses. Stale overlays clear automatically.", 12, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	var beard_column := _tab_column("Hair")
	beard_panel = BeardPanel.new()
	beard_column.add_child(beard_panel)
	beard_panel.setup(beard, self)
	beard_panel.message.connect(func(text): message.text = text)
	beard.changed.connect(func():
		if beard.mannequin: empty_state.hide()
		elif video.texture == null: empty_state.show()
		if not beard.mannequin and extensions.preview:
			extensions.preview = false
			_clear_tracking())
	var saved_beard = settings.get_value("beard", "document", {})
	if saved_beard is Dictionary and not saved_beard.is_empty():
		beard.apply_document(saved_beard)
	beard.set_enabled(bool(settings.get_value("beard", "enabled", true)))
	var tracking_column := _tab_column("Tracking")
	tracking_panel = TrackingPanel.new()
	tracking_column.add_child(tracking_panel)
	tracking_panel.setup(self)
	_compact_panel(right_panel)
	sidebar_tabs.current_tab = clampi(int(settings.get_value("view", "sidebar_tab", 1)),0,3)
	message = _label("Ready. Start the backend, then select a capture source.", 12, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message)
	quick_toolbar.setup(self)
	resized.connect(_adapt_layout)
	call_deferred("_adapt_layout")

func _tab_column(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar_tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _adapt_layout() -> void:
	right_panel.visible = true
	right_panel.custom_minimum_size.x = 320 if size.x >= 1100 else 296
	left_panel.custom_minimum_size.x = 206 if size.x >= 1100 else 188
	shortcut_hint.visible = size.x >= 1280

func _compact_panel(node: Node) -> void:
	# Wrap row labels instead of letting their minimum width push the sidebar
	# beyond the window. Menus use available width, not their longest option.
	if node is Label and node.get_parent() is HBoxContainer:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is OptionButton:
		node.fit_to_longest_item = false
		node.clip_text = true
	if node is Button:
		node.add_theme_font_size_override("font_size", 12)
	if node is SpinBox:
		node.custom_minimum_size.x = 80
	for child in node.get_children(): _compact_panel(child)

func _slider(parent: Node, title: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> HSlider:
	parent.add_child(_label(title, 12, MUTED))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider

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
	# Publish a matched pair before hair simulation and GPU uploads this frame.
	landmark_reader.process_priority = -20
	video_reader.process_priority = -10
	add_child(video_reader)
	add_child(landmark_reader)
	video_reader.frame_ready.connect(_on_video)
	landmark_reader.landmarks_ready.connect(_on_landmarks)
	landmark_reader.face_lost.connect(_clear_tracking)
	video_reader.synchronization_lost.connect(_clear_tracking)

func _sync_preview_landmarks() -> void:
	if video_reader: video_reader.set_frame_locked(false)
	overlay.preview_surface = beard.mannequin_view
	extensions.preview_surface = beard.mannequin_view
	overlay.points = beard.face
	overlay.video_size = beard.video_size
	overlay.queue_redraw()
	extensions.set_face(beard.face,beard.video_size,beard.face_depth,true)
	if empty_state: empty_state.hide()

func _clear_tracking() -> void:
	if video_reader: video_reader.set_frame_locked(false)
	occlusion.valid = false
	if beard.mannequin: return
	occlusion.surface.clear()
	overlay.preview_surface = null
	extensions.preview_surface = null
	extensions.clear_face()
	overlay.points.clear()
	overlay.queue_redraw()
	if not beard.mannequin: beard.clear_face()

func _poll() -> void:
	if api_poll.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		api_poll.request(backend_url + "/api/status")
	if last_video_at and Time.get_ticks_msec() - last_video_at > 1500:
		empty_state.visible = not beard.mannequin
		video.hide()
		_clear_tracking()
		if video_reader:
			video_reader.stop_reading()
			landmark_reader.stop_reading()

func _on_poll(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	online = code == 200
	status.text = "BACKEND CONNECTED" if online else "BACKEND OFFLINE"
	status.add_theme_color_override("font_color", ACCENT if online else Color("e9b665"))
	if not online:
		discovery_attempted = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	if not discovery_attempted and action_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		discovery_attempted = true
		_find_cameras()
	var active: bool = data.get("camera_active", false)
	if active and video_reader:
		var buffers: Dictionary = data.get("buffers", {})
		if buffers != current_buffers:
			_clear_tracking()
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
				var camera = source_picker.get_item_metadata(index)
				if camera is Dictionary and camera.get("index") == source_id:
					source_picker.select(index)
					connect_button.disabled = false
		status.text = "DEMO ACTIVE" if source_id == -1 else "CAMERA LIVE"
	var tracking: Dictionary = data.get("tracking", {})
	tracking_panel.update_status(tracking)
	quick_toolbar.update_status(tracking)
	if not backend_save_timer.time_left: _flush_backend_settings()
	var features: Dictionary = tracking.get("features", {})
	for feature in tracking_checks:
		if features.has(feature) and not pending_settings.has("/api/tracking/enable"):
			tracking_checks[feature].set_pressed_no_signal(features[feature])
	var capture_fps := float(data.get("capture_timing", {}).get("fps", data.get("fps", 0.0)))
	var preview_fps: int = video_reader.get_fps() if video_reader and video_reader.is_reading() else 0
	metrics.text = "%d preview / %.1f capture fps    ·    %d landmarks    ·    %.1f ms inference" % [preview_fps, capture_fps, tracking.get("landmark_count", 0), tracking.get("last_inference_ms", 0.0)]
	metrics.tooltip_text = "%s\nRender: %d fps · Hair CPU: %.2f ms\nPreview counts new video frames displayed; capture measures camera delivery.\nWith face tracking, video and attachments use the same captured frame.\nPreview rate follows completed tracking; Auto selects the faster backend.\nPreview pacing: Look → Preview pacing." % [data.get("source","No source"),Engine.get_frames_per_second(),beard.update_ms]
	if data.get("error"):
		status.text = "CAPTURE ERROR"
		message.text = str(data.error)
	elif tracking.get("error"):
		message.text = "Tracking: " + str(tracking.error)
	if data.has("recording"):
		recording = data.recording
		record_button.text = "■  Stop recording" if recording else "●  Record source"

func _action(path: String, data: Dictionary, method := HTTPClient.METHOD_POST) -> void:
	if action_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		for queued in action_queue:
			if queued.path == path:
				queued.data.merge(data, true)
				return
		action_queue.append({"path":path,"data":data.duplicate(true),"method":method})
		return
	pending_action = path
	pending_payload = data.duplicate(true)
	message.text = "Working…"
	var error := action_request.request(backend_url + path, ["Content-Type: application/json"], method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(data))
	if error != OK:
		message.text = "Could not contact the backend."

func _on_action(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_next_action.call_deferred()
	if code == 0: online = false
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result == HTTPRequest.RESULT_TIMEOUT:
		message.text = "Camera request timed out. Check the backend for a device error, then try again."
		return
	if code < 200 or code >= 300 or not data is Dictionary:
		if code >= 400 and pending_settings.get(pending_action) == pending_payload:
			blocked_settings[pending_action] = true
		var detail = data.get("error", "Request failed. Check the backend.") if data is Dictionary else "Backend unavailable. Run Start-Backend.ps1."
		message.text = str(detail.get("message", "Request failed.")) if detail is Dictionary else str(detail)
		return
	message.text = "Updated."
	if pending_settings.get(pending_action) == pending_payload:
		pending_settings.erase(pending_action)
		blocked_settings.erase(pending_action)
		queue_settings_save()
	if pending_action == "/api/camera/list":
		_set_camera_choices(data.get("cameras", []))
	elif pending_action == "/api/camera/select":
		message.text = "Capturing " + str(data.get("camera", {}).get("name", "camera")) + "."
	elif pending_action in ["/api/tracking/configure", "/api/tracking/reset"]:
		if not pending_settings.has("/api/tracking/configure"):
			tracking_panel.accept_config(data.get("config", {}), int(data.get("revision", 0)))
		message.text = "Tracking settings applied. " + {"cpu":"CPU tracking selected.", "gpu":"CPU stays live while GPU starts.", "auto":"Auto will compare CPU and GPU."}.get(data.get("config", {}).get("backend", "auto"), "")
	if data.has("files"):
		message.text = "Recording: " + ", ".join(PackedStringArray(data.files))
	_poll()

func _find_cameras() -> void:
	_action("/api/camera/list", {}, HTTPClient.METHOD_GET)

func _set_camera_choices(cameras: Array) -> void:
	var previous = source_picker.get_item_metadata(source_picker.selected) if source_picker.selected >= 0 else null
	if not previous is Dictionary and settings.has_section_key("capture", "camera"):
		previous = settings.get_value("capture", "camera")
	source_picker.clear()
	source_picker.add_item("Choose your camera…")
	source_picker.set_item_disabled(0, true)
	var selected := 0
	var device_count := 0
	for camera in cameras:
		source_picker.add_item(camera.name)
		var item := source_picker.item_count - 1
		source_picker.set_item_metadata(item, camera)
		if camera.index >= 0:
			device_count += 1
		if previous is Dictionary:
			if (previous.get("device_id", "") != "" and previous.get("device_id") == camera.get("device_id")) or (previous.get("index") == -1 and camera.index == -1) or (not previous.get("device_id") and previous.get("index") == camera.index):
				selected = item
		elif camera.index == last_source_id:
			selected = item
	source_picker.select(selected)
	connect_button.disabled = selected == 0
	message.text = "Select your webcam by name, then click Start capture." if device_count else "No cameras found. Connect a webcam and click Find cameras, or choose Demo pattern."

func _source_selected(index: int) -> void:
	connect_button.disabled = not source_picker.get_item_metadata(index) is Dictionary
	source_picker.tooltip_text = source_picker.get_item_text(index)
	message.text = "Click Start capture to use " + source_picker.get_item_text(index) + "."

func _start() -> void:
	var camera = source_picker.get_item_metadata(source_picker.selected)
	if not camera is Dictionary:
		return
	if video_reader:
		video_reader.stop_reading()
		landmark_reader.stop_reading()
	_clear_tracking()
	# JSON.parse_string turns the discovered index into a float. Camera IDs are
	# discrete identifiers, so send an integer back to the capture API.
	_action("/api/camera/select", {"camera_index": int(camera.index), "device_id": camera.get("device_id"), "resolution": [[1280, 720], [1920, 1080], [640, 360]][resolution_picker.selected], "fps": [30, 60, 24][fps_picker.selected]})

func _on_video(y: ImageTexture, uv: ImageTexture, _frame_id: int, timestamp: int) -> void:
	if video.texture != y:
		video.texture = y
		material_video.set_shader_parameter("y_texture", y)
		material_video.set_shader_parameter("uv_texture", uv)
	if not beard.mannequin: overlay.video_size = Vector2(y.get_width(), y.get_height())
	video.show()
	empty_state.hide()
	frame_timestamp = timestamp
	last_video_at = Time.get_ticks_msec()
	received_frames += 1
	if received_frames == 1:
		message.text = "Source connected. Adjust your look or start a recording."
	if frame_timestamp - landmark_timestamp > 150000 and not overlay.points.is_empty():
		_clear_tracking()

func _on_landmarks(points: Array, frame_id: int, timestamp: int) -> void:
	landmark_timestamp = timestamp
	if beard.mannequin: return
	if video_reader and video_reader.is_reading():
		if not video_reader.present_frame(frame_id,timestamp):
			_clear_tracking()
			return
	elif absi(frame_timestamp - timestamp) > 150000: return
	var normalized := PackedVector2Array()
	var depth := PackedFloat32Array()
	for point in points:
		normalized.append(Vector2(point.x, point.y))
		depth.append(point.z)
	overlay.points = normalized
	overlay.depth = depth
	occlusion.update(normalized,depth,overlay.video_size)
	overlay.queue_redraw()
	extensions.set_face(normalized, overlay.video_size, depth)
	beard.set_face(normalized, overlay.video_size, depth)

func _refresh_occlusion() -> void:
	beard.mannequin_view.set_surface_shape(occlusion.head_depth,occlusion.crown)
	if beard.mannequin: return
	occlusion.update(overlay.points,overlay.depth,overlay.video_size)
	overlay.queue_redraw()
	extensions._refresh()
	if beard.enabled and beard._face_live: beard._attach()
	beard._apply_occlusion()

func _set_look(index: int) -> void:
	var looks := [[1.0, 1.0, 0.0], [0.0, 1.15, 0.0], [0.8, 1.05, 0.045], [1.15, 1.18, 0.0]]
	index = clampi(index, 0, looks.size() - 1)
	material_video.set_shader_parameter("saturation", looks[index][0])
	material_video.set_shader_parameter("contrast", looks[index][1])
	material_video.set_shader_parameter("warmth", looks[index][2])
	settings.set_value("view", "look", index)
	queue_settings_save()

func _set_pacing(index: int) -> void:
	index = clampi(index,0,PACING_MODES.size()-1)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if index == 1 else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if index == 1 else 60 if index == 2 else 120
	settings.set_value("view","pacing",PACING_MODES[index])
	queue_settings_save()

func _set_mirror(value: bool) -> void:
	material_video.set_shader_parameter("mirror", value)
	overlay.mirror = value
	overlay.queue_redraw()
	beard.set_mirror(value)
	extensions.set_mirror(value)
	settings.set_value("view", "mirror", value)
	queue_settings_save()

func _set_points(value: bool) -> void:
	overlay.show_points = value
	overlay.queue_redraw()
	settings.set_value("view", "points", value)
	queue_settings_save()

func _set_guides(value: bool) -> void:
	overlay.guides_visible = value
	extensions.guides_visible = value
	beard.guides_visible = value
	overlay.queue_redraw()
	extensions._upload()
	beard._update_root_markers()
	beard._update_virtual_markers()
	settings.set_value("view", "guides", value)
	queue_settings_save()

func _snapshot() -> void:
	if video.texture == null and not beard.mannequin:
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
		queue_settings_save()

func _setup_autosave() -> void:
	# Restore view-only choices after constructing all controls, before observing edits.
	beard.set_mannequin(bool(settings.get_value("beard", "mannequin", false)))
	beard.set_edit_strands(bool(settings.get_value("beard", "edit_strands", false)))
	var pose: Vector3 = settings.get_value("beard", "pose", Vector3(0,0,1))
	beard.mannequin_view.set_pose(pose.x,pose.y,pose.z)
	beard_panel.select_check.set_pressed_no_signal(beard.edit_strands)
	beard_panel.page_picker.select(clampi(int(settings.get_value("view", "hair_page", 0)),0,beard_panel.page_picker.item_count-1))
	beard_panel.show_page(beard_panel.page_picker.get_item_text(beard_panel.page_picker.selected))
	beard_panel.style.select(clampi(int(settings.get_value("view", "beard_preset", 0)),0,beard_panel.style.item_count-1))
	beard_panel.current_id = str(settings.get_value("beard", "library_id", ""))
	var library_selection: String = settings.get_value("beard", "library_selection", beard_panel.current_id)
	for i in beard_panel.models.item_count:
		if beard_panel.models.get_item_metadata(i) == library_selection: beard_panel.models.select(i)
	landmarks_panel.region_picker.select(clampi(int(settings.get_value("view", "landmark_region", 0)),0,3))
	landmarks_panel.show_region(landmarks_panel.Extensions.REGIONS[landmarks_panel.region_picker.selected])
	tracking_panel.model_group.visible = bool(settings.get_value("view", "model_group", false))
	tracking_panel.import_kind.select(clampi(int(settings.get_value("view", "import_kind", 0)),0,2))
	var cached: Dictionary = settings.get_value("backend", "tracking", {})
	if not cached.is_empty(): tracking_panel.accept_config(cached,-1)
	if pending_settings.has("/api/tracking/configure"):
		tracking_panel.accept_config(pending_settings["/api/tracking/configure"],-1)
		tracking_panel.dirty = true
	var features: Dictionary = settings.get_value("backend", "features", {})
	for key in tracking_checks:
		if features.has(key): tracking_checks[key].set_pressed_no_signal(features[key])
	if persist_settings and DisplayServer.get_name() != "headless":
		var dimensions: Vector2i = settings.get_value("window", "size", Vector2i(1440,900))
		DisplayServer.window_set_size(dimensions.clamp(Vector2i(960,640), DisplayServer.screen_get_usable_rect().size.max(Vector2i(960,640))))
		var mode: int = int(settings.get_value("window", "mode", DisplayServer.WINDOW_MODE_WINDOWED))
		if mode in [DisplayServer.WINDOW_MODE_WINDOWED,DisplayServer.WINDOW_MODE_MAXIMIZED,DisplayServer.WINDOW_MODE_FULLSCREEN]: DisplayServer.window_set_mode(mode)
	for timer in [save_timer, backend_save_timer]:
		timer.one_shot = true
		timer.wait_time = .35
		add_child(timer)
	save_timer.timeout.connect(_save_settings)
	backend_save_timer.timeout.connect(_flush_backend_settings)
	beard.changed.connect(queue_settings_save)
	beard.mannequin_view.pose_changed.connect(queue_settings_save)
	extensions.settings_changed.connect(queue_settings_save)
	get_window().size_changed.connect(queue_settings_save)
	_watch_settings_controls(self)
	settings_ready = true
	quick_toolbar.sync()
	saved_text = settings.encode_to_text()

func _watch_settings_controls(node: Node) -> void:
	if node is Range: node.value_changed.connect(func(_v): queue_settings_save())
	elif node is OptionButton: node.item_selected.connect(func(_v): queue_settings_save())
	elif node is CheckBox: node.toggled.connect(func(_v): queue_settings_save())
	elif node is ColorPickerButton: node.color_changed.connect(func(_v): queue_settings_save())
	elif node is LineEdit: node.text_changed.connect(func(_v): queue_settings_save())
	if node == sidebar_tabs: sidebar_tabs.tab_changed.connect(func(_v): queue_settings_save())
	if node == tracking_panel.model_group: node.visibility_changed.connect(queue_settings_save)
	for child in node.get_children(): _watch_settings_controls(child)

func queue_settings_save() -> void:
	if settings_ready and persist_settings: save_timer.start()

func _queue_backend_setting(path: String, data: Dictionary) -> void:
	if path == "/api/tracking/enable":
		var merged: Dictionary = pending_settings.get(path, {}).duplicate()
		merged.merge(data, true)
		pending_settings[path] = merged
	else: pending_settings[path] = data.duplicate(true)
	blocked_settings.erase(path)
	queue_settings_save()
	backend_save_timer.start()

func _flush_backend_settings() -> void:
	if not online or backend_save_timer.time_left > 0 or action_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	for path in pending_settings:
		if blocked_settings.has(path): continue
		_action(path, pending_settings[path])
		return

func _next_action() -> void:
	if not action_queue.is_empty():
		var queued: Dictionary = action_queue.pop_front()
		_action(queued.path,queued.data,queued.method)
	else: _flush_backend_settings()

func _store_settings() -> void:
	if beard:
		settings.set_value("beard", "document", beard.get_document())
		settings.set_value("beard", "enabled", beard.enabled)
		settings.set_value("beard", "mannequin", beard.mannequin)
		settings.set_value("beard", "edit_strands", beard.edit_strands)
		settings.set_value("beard", "pose", Vector3(beard.mannequin_view.yaw,beard.mannequin_view.pitch,beard.mannequin_view.zoom))
		settings.set_value("beard", "library_id", beard_panel.current_id)
		if beard_panel.models.selected > 0: settings.set_value("beard", "library_selection", beard_panel.models.get_item_metadata(beard_panel.models.selected))
	if extensions: settings.set_value("landmarks", "extensions", extensions.model.config)
	settings.set_value("view", "occlusion", occlusion.enabled)
	settings.set_value("view", "head_depth", occlusion.head_depth)
	settings.set_value("view", "head_crown", occlusion.crown)
	if sidebar_tabs: settings.set_value("view", "sidebar_tab", sidebar_tabs.current_tab)
	settings.set_value("view", "exposure", exposure_slider.value)
	settings.set_value("view", "point_size", overlay.point_size)
	settings.set_value("view", "point_color", overlay.tint)
	settings.set_value("view", "hair_page", beard_panel.page_picker.selected)
	settings.set_value("view", "beard_preset", beard_panel.style.selected)
	settings.set_value("view", "landmark_region", landmarks_panel.region_picker.selected)
	settings.set_value("view", "model_group", tracking_panel.model_group.visible)
	settings.set_value("view", "import_kind", tracking_panel.import_kind.selected)
	settings.set_value("backend", "tracking", tracking_panel.values())
	settings.set_value("backend", "pending", pending_settings)
	var features := {}
	for key in tracking_checks: features[key] = tracking_checks[key].button_pressed
	settings.set_value("backend", "features", features)
	settings.set_value("capture", "resolution", resolution_picker.selected)
	settings.set_value("capture", "fps", fps_picker.selected)
	if source_picker.selected >= 0:
		var camera = source_picker.get_item_metadata(source_picker.selected)
		if camera is Dictionary: settings.set_value("capture", "camera", camera)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_WINDOWED: settings.set_value("window", "size", DisplayServer.window_get_size())
		if mode != DisplayServer.WINDOW_MODE_MINIMIZED: settings.set_value("window", "mode", mode)

func _save_settings() -> void:
	if not persist_settings or not settings_ready: return
	_store_settings()
	var encoded := settings.encode_to_text()
	if encoded == saved_text: return
	var path := ProjectSettings.globalize_path(settings_path)
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK: error = settings.save(path + ".tmp")
	if error == OK and FileAccess.file_exists(path): error = DirAccess.copy_absolute(path,path + ".bak")
	if error == OK: error = DirAccess.rename_absolute(path + ".tmp",path)
	if error == OK: saved_text = encoded
	else:
		message.text = "Settings could not be saved: " + error_string(error)
		push_warning(message.text)

func _exit_tree() -> void:
	_save_settings()

func _capture_and_quit() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("STUDIO_CAPTURE frames=", received_frames, " landmarks=", overlay.points.size())
	get_tree().quit()
