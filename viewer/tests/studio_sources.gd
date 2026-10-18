extends SceneTree
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Build controls without _ready(), timers, readers, or live HTTP requests.
	var studio = load("res://studio.tscn").instantiate()
	studio._build_ui()
	check(studio.connect_button.disabled, "Capture must wait for a real source selection")
	var cameras := [
		{"index": 0, "name": "Virtual camera", "device_id": "virtual"},
		{"index": 1, "name": "USB webcam", "device_id": "usb"},
		{"index": -1, "name": "Demo pattern (no camera)"},
	]
	studio._set_camera_choices(cameras)
	check(studio.source_picker.item_count == 4, "Only the prompt and discovered sources should appear")
	check(studio.connect_button.disabled, "Discovery must not silently select a virtual camera or demo")
	studio.source_picker.select(2)
	studio._source_selected(2)
	check(not studio.connect_button.disabled, "Selecting a webcam must enable capture")
	# A device moving to another Windows index must retain its identity.
	cameras[0].index = 1
	cameras[1].index = 0
	cameras.reverse()
	studio._set_camera_choices(cameras)
	var selected = studio.source_picker.get_item_metadata(studio.source_picker.selected)
	check(selected.get("device_id") == "usb" and selected.index == 0, "Refresh must preserve the selected device")
	studio._set_camera_choices([{"index": -1, "name": "Demo pattern (no camera)"}])
	check(studio.connect_button.disabled, "Unplugging a selected camera must not switch to demo")
	check("No cameras found" in studio.message.text, "Empty discovery should explain what to do")
	studio.source_picker.select(1)
	studio._source_selected(1)
	check(not studio.connect_button.disabled, "Demo must still be selectable explicitly")
	studio.free()
	print("STUDIO_SOURCES failures=", failures)
	quit(0 if failures.is_empty() else 1)
