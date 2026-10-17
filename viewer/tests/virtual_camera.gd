extends SceneTree
var failures: Array[String] = []
func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	var output = studio.virtual_camera
	check(not output.active and output.viewport == null,"Output starts off without a render target")
	studio.quick_toolbar.buttons.camera.button_pressed = true
	check(not output.active and not studio.quick_toolbar.buttons.camera.button_pressed,"Starting without a source fails and resets the toolbar")
	studio.beard.set_mannequin(true)
	if "--device" in OS.get_cmdline_user_args():
		await _device(studio)
		return
	if "--render" in OS.get_cmdline_user_args():
		for i in 5: await process_frame
		output._make_viewport()
		# Exercise composition without installing or publishing a camera device.
		output.writer = FakeWriter.new()
		output.active = true
		output.set_process(true)
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image = output.viewport.get_texture().get_image()
		rendered.save_png(ProjectSettings.globalize_path("res://../artifacts/virtual-camera-composition.png"))
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/virtual-camera-toolbar.png"))
		check(rendered.get_size() == Vector2i(1280,720),"Output has a fixed camera resolution")
		check(output.writer.sent > 0,"Composed frames reach the native boundary")
		output.stop()
		check(output.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"Stop disables output rendering")
		check(not studio.quick_toolbar.buttons.camera.button_pressed,"Stop resets the toolbar")
	print("VIRTUAL_CAMERA failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _device(studio: Control) -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[args.find("--device")+1]
	for i in 5: await process_frame
	studio.quick_toolbar.buttons.camera.button_pressed = true
	var deadline := Time.get_ticks_msec()+25000
	while studio.virtual_camera.active and studio.virtual_camera.state == "Starting" and Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
	if studio.virtual_camera.state != "Ready":
		print("VIRTUAL_CAMERA_DEVICE_FAILED ",studio.virtual_camera.detail)
		quit(1)
		return
	var marker := FileAccess.open(path+".ready",FileAccess.WRITE)
	marker.store_string("ready")
	marker.close()
	var timings: Array[float] = []
	var last_sent := 0
	deadline = Time.get_ticks_msec()+60000
	while not FileAccess.file_exists(path+".stop") and Time.get_ticks_msec()<deadline:
		await process_frame
		var output: Node = studio.virtual_camera
		if output.stats.get("sent",0) != last_sent:
			last_sent = output.stats.get("sent",0)
			timings.append(output.readback_ms)
		if not output.active:
			print("VIRTUAL_CAMERA_DEVICE_FAILED ",output.detail)
			quit(1)
			return
	var report: Dictionary = studio.virtual_camera.writer.get_status()
	timings.sort()
	report["readback_ms_p50"] = timings[timings.size()/2] if not timings.is_empty() else 0
	report["readback_ms_p95"] = timings[int(timings.size()*.95)] if not timings.is_empty() else 0
	studio.quick_toolbar.buttons.camera.button_pressed = false
	check(not studio.virtual_camera.active,"Toolbar stops the installed camera")
	report["failures"] = failures
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("VIRTUAL_CAMERA_DEVICE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
class FakeWriter extends RefCounted:
	var sent := 0
	func get_status() -> Dictionary: return {"state":2,"consumer":true}
	func submit(_image: Image) -> void: sent += 1
	func stop() -> void: pass
