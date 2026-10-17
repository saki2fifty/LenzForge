extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	var surface = studio.occlusion.surface
	surface.set_reference()
	var original: PackedVector3Array = surface.vertices.duplicate()
	var attachment: Dictionary = surface.resolve("virtual:1000:250000:250000")
	var profile := {"version":1,"depth":.8,"crown":.3,"sides":1.15,"jaw":1.1,"views":5}
	studio.apply_calibration(profile)
	surface.set_reference()
	assert(surface.vertices.size()==original.size())
	assert(surface.vertices.slice(0,478)==original.slice(0,478),"Measured anchors must retain tracked coordinates")
	assert(surface.vertices.slice(478)!=original.slice(478),"Calibration changes virtual head geometry")
	assert(not surface.resolve("virtual:1000:250000:250000").is_empty(),"Attachment IDs survive calibration")
	assert(surface == studio.beard.surface and surface == studio.extensions.model.surface)
	assert(studio.beard.mannequin_view.surface.shape_signature()==Vector4(.8,.3,1.15,1.1))
	studio._store_settings()
	assert(studio.settings.get_value("calibration","profile").sides==1.15)
	assert(studio.quick_toolbar.buttons.has("calibrate"))
	studio.apply_calibration({})
	assert(surface.sides==1 and surface.jaw==1)
	assert(preload("res://tracking/head_profile.gd").validate({"version":1,"depth":NAN,"crown":.2,"sides":1,"jaw":1}).is_empty())
	if "--render" in OS.get_cmdline_user_args():
		studio.calibration.open()
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		studio.calibration.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/calibration-wizard.png"))
		var fixture_path := ProjectSettings.globalize_path("res://../artifacts/calibration-portrait.json")
		if FileAccess.file_exists(fixture_path):
			var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
			studio.calibration.preview.packet = packet
			studio.calibration.preview.load_frame()
			studio.calibration.captures.append(packet)
			studio.calibration.view_picker.add_item("Face forward")
			studio.calibration.observations.append({"face":packet.face,"contour":packet.contour})
			studio.calibration.operation = "fit"
			studio.calibration._completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"profile":profile}).to_utf8_buffer())
			for i in 10: await process_frame
			await RenderingServer.frame_post_draw
			studio.calibration.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/calibration-review.png"))
	print("CALIBRATION passed")
	quit()
