extends SceneTree
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	var toolbar = studio.quick_toolbar
	toolbar.buttons.occlusion.button_pressed = false
	check(not studio.occlusion.enabled and not studio.occlusion_check.button_pressed,"Occlusion shortcut updates the panel and renderer")
	studio.occlusion_check.button_pressed = true
	check(toolbar.buttons.occlusion.button_pressed,"Panel occlusion updates the shortcut")
	toolbar.buttons.mirror.button_pressed = false
	check(not studio.overlay.mirror and not studio.beard.mirror and not studio.mirror_check.button_pressed,"Mirror shortcut shares the existing control")
	studio.mirror_check.button_pressed = true
	check(toolbar.buttons.mirror.button_pressed,"Panel mirror updates the shortcut")
	toolbar.buttons.hair.button_pressed = true
	check(studio.beard.enabled and studio.beard_panel.enabled_check.button_pressed,"Hair shortcut updates the working look")
	toolbar.buttons.mannequin.button_pressed = true
	check(studio.beard.mannequin and studio.landmarks_panel.preview_check.button_pressed,"Mannequin shortcut updates both panels")
	studio.beard.set_settings({"show_generated_roots":true,"virtual_enabled":true,"show_virtual_landmarks":true})
	studio.extensions.set_settings({"enabled":true,"show_points":true})
	studio.points_check.button_pressed = true
	var face_count: int = studio.beard.face.size()
	toolbar.buttons.landmarks.button_pressed = false
	await process_frame
	await process_frame
	check(not studio.guides_check.button_pressed and not studio.overlay.guides_visible and not studio.extensions.guides_visible and not studio.beard.guides_visible,"Master guides shortcut reaches every layer")
	check(studio.overlay.show_points and studio.extensions.model.config.show_points and studio.beard.config.show_generated_roots,"Master hide preserves individual visibility preferences")
	check(studio.beard.face.size() == face_count and studio.beard.enabled,"Hiding guides keeps tracking references and hair")
	for kind in ["reference","extensions","generated","surface"]:
		check(not studio.beard.mannequin_view.dots[kind].visible,"Mannequin %s dots hidden" % kind)
	studio.guides_check.button_pressed = true
	await process_frame
	await process_frame
	check(toolbar.buttons.landmarks.button_pressed and studio.beard.mannequin_view.dots.reference.visible,"Showing guides restores previous visibility")
	toolbar.processing.get_popup().id_pressed.emit(1)
	check(studio.tracking_panel.values().backend == "gpu" and studio.pending_settings["/api/tracking/configure"].backend == "gpu","GPU shortcut uses the durable automatic-apply queue")
	studio.tracking_panel.choose("backend","cpu")
	check(toolbar.processing.text.begins_with("CPU") and toolbar.processing.get_popup().is_item_checked(2),"Panel processor choice updates the shortcut")
	studio.tracking_panel._update_models({"models":[
		{"kind":"face","id":"face_landmarker","label":"Face","bytes":100,"installed":true},
		{"kind":"hand","id":"hand_landmarker","label":"Hands","bytes":100,"installed":true},
		{"kind":"pose","id":"pose_landmarker_lite","label":"Pose Lite","bytes":100,"installed":true},
		{"kind":"pose","id":"custom_pose","label":"Custom pose","bytes":100,"installed":true}]})
	toolbar._populate_models()
	toolbar.model_popups.pose.id_pressed.emit(1)
	check(studio.tracking_panel.values().pose_model == "custom_pose" and studio.pending_settings["/api/tracking/configure"].pose_model == "custom_pose","Model shortcut applies the model ID through the shared settings path")
	toolbar._populate_models()
	check(toolbar.model_popups.pose.is_item_checked(1),"Model menu checks the current selection")
	toolbar.update_status({"active_backend":"cpu","fallback_reason":"GPU unavailable"})
	check("Running on CPU" in toolbar.processing.tooltip_text and "GPU unavailable" in toolbar.processing.tooltip_text,"Processor tooltip reports actual fallback status")
	toolbar.open_models()
	check(studio.sidebar_tabs.current_tab == 3 and studio.tracking_panel.model_group.visible,"Model manager opens from the shortcut")
	if OS.get_cmdline_user_args().has("--render"):
		studio.tracking_panel.choose("backend","auto")
		studio.sidebar_tabs.current_tab = 0
		for dimensions in [Vector2i(1440,900),Vector2i(1200,800),Vector2i(960,640)]:
			root.size = dimensions
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/quick-toolbar-%d.png" % dimensions.x))
	print("QUICK_TOOLBAR failures=",failures)
	quit(0 if failures.is_empty() else 1)
