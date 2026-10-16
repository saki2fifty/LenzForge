extends VBoxContainer
## Live model configuration; edits stay local until Apply succeeds.
var host: Control
var controls: Dictionary = {}
var runtime: Label
var timings: Label
var explanation: Label
var dirty := false
var synced_revision := -1
var _syncing := false

func setup(studio: Control) -> void:
	host = studio
	add_theme_constant_override("separation", 8)
	host._section(self, "MediaPipe", "Apply settings while capture is running. Video keeps playing during model changes.")
	runtime = host._label("Waiting for backend…", 12, host.ACCENT)
	runtime.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(runtime)
	timings = host._label("", 11, host.MUTED)
	timings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(timings)
	_picker("backend", "Processing", ["Auto · fastest measured", "GPU · browser worker", "CPU · native"], ["auto", "gpu", "cpu"])
	_picker("max_width", "Tracking image width", ["320 px", "480 px", "640 px", "960 px", "Native resolution"], [320,480,640,960,0])
	_spin("num_faces", "Maximum faces", 1, 4, 1)
	_spin("detection_confidence", "Detection confidence", 0, 1, .05)
	_spin("presence_confidence", "Presence confidence", 0, 1, .05)
	_spin("tracking_confidence", "Tracking confidence", 0, 1, .05)
	for entry in [["blendshapes", "Expression coefficients"], ["face_transform", "3D face transform"]]:
		var check := CheckBox.new()
		check.text = entry[1]
		check.toggled.connect(func(_v): _edited())
		controls[entry[0]] = check
		add_child(check)
	add_child(host._button("Apply tracking settings", _apply, true))
	add_child(host._button("Restore tracking defaults", func(): host._action("/api/tracking/reset", {})))
	explanation = host._label("Auto keeps CPU tracking live while GPU warms up, then compares latency. GPU errors fall back to CPU. Apply again to retry.\n\nOne face enables smoothing. With multiple faces, the desktop follows the first face; JSON includes the others.", 11, host.MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	accept_config({"backend":"auto","max_width":640,"num_faces":1,
		"detection_confidence":.5,"presence_confidence":.5,"tracking_confidence":.5,
		"blendshapes":true,"face_transform":true}, -1)

func _picker(key: String, title: String, labels: Array, values: Array) -> void:
	add_child(host._label(title, 11, host.MUTED))
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	for i in labels.size():
		picker.add_item(labels[i])
		picker.set_item_metadata(i, values[i])
	picker.item_selected.connect(func(_v): _edited())
	controls[key] = picker
	add_child(picker)

func _spin(key: String, title: String, low: float, high: float, increment: float) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var label: Label = host._label(title, 11, host.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low; spin.max_value = high; spin.step = increment
	spin.custom_minimum_size.x = 80
	spin.value_changed.connect(func(_v): _edited())
	controls[key] = spin
	row.add_child(spin)

func _edited() -> void:
	if not _syncing: dirty = true

func values() -> Dictionary:
	var result := {}
	for key in controls:
		var control = controls[key]
		if control is OptionButton: result[key] = control.get_item_metadata(control.selected)
		elif control is CheckBox: result[key] = control.button_pressed
		else: result[key] = int(control.value) if key == "num_faces" else control.value
	return result

func _apply() -> void:
	host._action("/api/tracking/configure", values())

func accept_config(config: Dictionary, revision: int) -> void:
	_syncing = true
	for key in controls:
		if not config.has(key): continue
		var control = controls[key]
		if control is OptionButton:
			for i in control.item_count:
				if control.get_item_metadata(i) == config[key]: control.select(i)
		elif control is CheckBox: control.set_pressed_no_signal(config[key])
		else: control.set_value_no_signal(config[key])
	dirty = false
	synced_revision = revision
	_syncing = false

func update_status(data: Dictionary) -> void:
	var revision := int(data.get("settings_revision", 0))
	if not dirty and (synced_revision != revision or synced_revision < 0):
		accept_config(data.get("settings", {}), revision)
	var active: String = str(data.get("active_backend", "")).to_upper()
	if active.is_empty() or active == "<NULL>": active = "Waiting for capture"
	var phase: String = data.get("phase", "ready")
	runtime.text = active
	if phase == "starting_gpu": runtime.text += " · starting GPU"
	elif phase == "calibrating_cpu": runtime.text += " · measuring CPU baseline"
	elif phase == "waiting_for_face": runtime.text += " · face needed for comparison"
	elif phase in ["warming_gpu", "gpu_ready"]: runtime.text += " · calibrating GPU"
	if data.get("fallback_reason"):
		runtime.text += " · fallback\n" + str(data.fallback_reason)
	runtime.tooltip_text = str(data.get("renderer", ""))
	timings.text = "%.1f tracking fps\n%.1f ms median · %.1f ms p95\n%.1f ms capture → landmarks p95" % [data.get("fps",0.0),data.get("round_trip_p50_ms",0.0),data.get("round_trip_p95_ms",0.0),data.get("capture_to_landmarks_p95_ms",0.0)]
	var comparison = data.get("comparison")
	if comparison is Dictionary:
		timings.text += "\nAuto: CPU %.1f / GPU %.1f ms" % [comparison.cpu_p50_ms,comparison.gpu_p50_ms]
