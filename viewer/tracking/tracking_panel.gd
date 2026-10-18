extends VBoxContainer
const SceneRefs = preload("res://ui/scene_refs.gd")
var ui_actions: Dictionary = {}
## Live model configuration with debounced automatic application and saving.
signal settings_changed
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
var import_kind: OptionButton
var import_dialog := FileDialog.new()
var import_request := HTTPRequest.new()
var model_group: VBoxContainer

func setup(studio: Control) -> void:
	host = studio
	SceneRefs.bind(self)
	# OptionButton item metadata is runtime-only; labels and layout are authored.
	var option_values := {"backend":["auto","gpu","cpu"],"max_width":[320,480,640,960,0],
		"face_model":["face_landmarker"],"hand_model":["hand_landmarker"],"pose_model":["pose_landmarker_lite"]}
	for key in option_values:
		for i in option_values[key].size(): controls[key].set_item_metadata(i,option_values[key][i])
	for key in controls:
		var control = controls[key]
		if control is OptionButton: control.item_selected.connect(func(_v): _edited())
		elif control is CheckBox: control.toggled.connect(func(_v): _edited())
		else: control.value_changed.connect(func(_v): _edited())
	SceneRefs.action(self,"Models · select / download…",func(): model_group.visible = not model_group.visible)
	for kind in ["face", "hand", "pose"]:
		SceneRefs.action(self,"Download selected " + kind + " model",func():
			host._action("/api/tracking/models/download", {"id":controls[kind+"_model"].get_item_metadata(controls[kind+"_model"].selected)}))
	SceneRefs.action(self,"Import compatible .task…",func(): import_dialog.popup_centered_ratio(.75))
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
	SceneRefs.action(self,"Apply tracking settings",_apply)
	SceneRefs.action(self,"Restore tracking defaults",func():
		host.pending_settings.erase("/api/tracking/configure")
		dirty = true
		host._queue_backend_setting("/api/tracking/reset", {}))
	accept_config({"backend":"auto","max_width":640,"num_faces":1,
		"detection_confidence":.5,"presence_confidence":.5,"tracking_confidence":.5,
		"blendshapes":true,"face_transform":true}, -1)

func _edited() -> void:
	if not _syncing:
		dirty = true
		host._queue_backend_setting("/api/tracking/configure", values())
		settings_changed.emit()

func choose(key: String, value: Variant) -> void:
	var picker: OptionButton = controls[key]
	for i in picker.item_count:
		if picker.get_item_metadata(i) == value:
			picker.select(i)
			_edited()
			return

func values() -> Dictionary:
	var result := {}
	for key in controls:
		var control = controls[key]
		if control is OptionButton: result[key] = control.get_item_metadata(control.selected)
		elif control is CheckBox: result[key] = control.button_pressed
		else: result[key] = int(control.value) if key == "num_faces" else control.value
	return result

func _apply() -> void:
	dirty = true
	host._queue_backend_setting("/api/tracking/configure", values())
	host.backend_save_timer.stop()
	host._flush_backend_settings()

func accept_config(config: Dictionary, revision: int) -> void:
	_syncing = true
	for key in controls:
		if not config.has(key): continue
		var control = controls[key]
		if control is OptionButton:
			var found := false
			for i in control.item_count:
				if control.get_item_metadata(i) == config[key]: control.select(i); found = true
			if not found and key.ends_with("_model"):
				control.add_item(str(config[key]) + " · unavailable")
				control.set_item_metadata(control.item_count-1,config[key])
				control.select(control.item_count-1)
		elif control is CheckBox: control.set_pressed_no_signal(config[key])
		else: control.set_value_no_signal(config[key])
	dirty = false
	synced_revision = revision
	_syncing = false
	host.queue_settings_save()
	settings_changed.emit()

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
		host.blocked_settings.erase("/api/tracking/configure")
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
			if picker.selected < 0 or picker.get_item_metadata(picker.selected) != selected:
				picker.add_item(str(selected) + " · unavailable")
				picker.set_item_metadata(picker.item_count-1,selected)
				picker.select(picker.item_count-1)
	var job: Dictionary = library.get("job", {})
	var state: String = job.get("state", "idle")
	if state == "idle": return
	model_status.text = str(job.get("label", "Model")) + " · " + state.capitalize()
	if state == "downloading": model_status.text += " %.1f / %.1f MB" % [job.get("received",0)/1048576.0,job.get("total",0)/1048576.0]
	elif state == "ready": model_status.text += ". Selected models apply automatically."
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
