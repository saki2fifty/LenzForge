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
var model_status: Label
var model_signature := ""
var import_kind := OptionButton.new()
var import_dialog := FileDialog.new()
var import_request := HTTPRequest.new()
var model_group := VBoxContainer.new()

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
	add_child(host._button("Models · select / download…", func(): model_group.visible = not model_group.visible))
	model_group.add_theme_constant_override("separation",8)
	model_group.hide()
	add_child(model_group)
	host._section(model_group, "Models", "Choose an installed model, then Apply. Downloads keep capture running.")
	for kind in ["face", "hand", "pose"]:
		var id: String = kind + "_landmarker" + ("_lite" if kind == "pose" else "")
		_picker(kind+"_model", kind.capitalize()+" model", [id], [id], model_group)
		model_group.add_child(host._button("Download selected " + kind + " model", func():
			host._action("/api/tracking/models/download", {"id": controls[kind+"_model"].get_item_metadata(controls[kind+"_model"].selected)})))
	for kind in ["face", "hand", "pose"]: import_kind.add_item(kind.capitalize())
	model_group.add_child(import_kind)
	model_group.add_child(host._button("Import compatible .task…", func(): import_dialog.popup_centered_ratio(.75)))
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.task ; MediaPipe Landmarker bundle"])
	import_dialog.file_selected.connect(_import_model)
	add_child(import_dialog)
	import_request.timeout = 30
	import_request.request_completed.connect(func(_result, code, _headers, body):
		var reply = JSON.parse_string(body.get_string_from_utf8())
		host.message.text = "Validating model…" if code == 202 else str(reply.get("error", {}).get("message", "Import failed")) if reply is Dictionary else "Import failed")
	add_child(import_request)
	model_status = host._label("Face: one official bundle. Pose: Lite, Full, Heavy. Custom bundles must match the task and landmark layout.", 11, host.MUTED)
	model_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	model_group.add_child(model_status)
	host._section(self, "Detection", "Thresholds and optional outputs apply to the selected models.")
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

func _picker(key: String, title: String, labels: Array, values: Array, parent: Node = null) -> void:
	if parent == null: parent = self
	parent.add_child(host._label(title, 11, host.MUTED))
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	for i in labels.size():
		picker.add_item(labels[i])
		picker.set_item_metadata(i, values[i])
	picker.item_selected.connect(func(_v): _edited())
	controls[key] = picker
	parent.add_child(picker)

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
	if data.has("library"): _update_models(data.library)
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

func _update_models(library: Dictionary) -> void:
	var entries: Array = library.get("models", [])
	var signature := JSON.stringify(entries)
	if signature != model_signature:
		model_signature = signature
		for kind in ["face", "hand", "pose"]:
			var picker: OptionButton = controls[kind+"_model"]
			var selected = picker.get_item_metadata(picker.selected) if picker.selected >= 0 else ""
			picker.clear()
			for item in entries:
				if item.kind != kind: continue
				picker.add_item(item.label + (" ✓" if item.installed else " ↓"))
				picker.set_item_metadata(picker.item_count-1, item.id)
				picker.set_item_tooltip(picker.item_count-1, "%s · %.1f MB · %s" % [item.label, item.bytes/1048576.0, "Installed" if item.installed else "Download first"])
			for i in picker.item_count:
				if picker.get_item_metadata(i) == selected: picker.select(i)
	var job: Dictionary = library.get("job", {})
	var state: String = job.get("state", "idle")
	if state == "idle": return
	model_status.text = str(job.get("label", "Model")) + " · " + state.capitalize()
	if state == "downloading": model_status.text += " %.1f / %.1f MB" % [job.get("received",0)/1048576.0,job.get("total",0)/1048576.0]
	elif state == "ready": model_status.text += ". Select it above, then Apply."
	elif state == "error": model_status.text += "\n" + str(job.get("error", "Import/download failed"))

func _import_model(path: String) -> void:
	if import_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 100*1024*1024:
		host.message.text = "Choose a readable .task bundle under 100 MB."
		return
	var kind: String = ["face", "hand", "pose"][import_kind.selected]
	var url: String = host.backend_url + "/api/tracking/models/import?kind=" + kind + "&name=" + path.get_file().uri_encode()
	host.message.text = "Uploading model…"
	var error := import_request.request_raw(url, ["Content-Type: application/octet-stream"], HTTPClient.METHOD_POST, file.get_buffer(file.get_length()))
	if error != OK: host.message.text = "Could not upload the model."
