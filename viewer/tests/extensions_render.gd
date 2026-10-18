extends SceneTree
const Extensions = preload("res://tracking/face_extensions.gd")
const Profile = preload("res://beard/beard_profile.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio.extensions.set_settings(Extensions.defaults())
	studio.beard.apply_document(Profile.document("No hair needed",Profile.defaults(),{}))
	studio.beard.set_enabled(false)
	studio.sidebar_tabs.current_tab = 1
	check(studio.sidebar_tabs.get_tab_title(1) == "Landmarks","Landmarks has its own visible tab")
	studio.landmarks_panel.preview_check.button_pressed = true
	studio.points_check.button_pressed = true
	check(studio.extensions.model.points.size() == 288 and not studio.beard.enabled,"Preview creates virtual landmarks with hair disabled")
	check("288 virtual" in studio.landmarks_panel.stats.text,"Visible count immediately reflects the active virtual references")
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var orange := 0
	var box: Rect2 = studio.extensions.get_global_rect()
	for y in range(int(box.position.y),int(box.end.y)):
		for x in range(int(box.position.x),int(box.end.x)):
			var c := screenshot.get_pixel(x,y)
			if c.r > .85 and c.g > .6 and c.g < .83 and c.b > .25 and c.b < .5: orange += 1
	check(orange > 1000,"Orange markers are visible in the preview without hair")
	var args := OS.get_cmdline_user_args()
	var suffix := args[0] if not args.is_empty() else ""
	screenshot.save_png(ProjectSettings.globalize_path("res://../artifacts/landmark-extensions%s.png"%suffix))
	var first_point: Vector2 = studio.extensions.model.points[0]
	studio.landmarks_panel.controls.vertical_offset.value = -.25
	check(studio.extensions.model.points[0].y < first_point.y and studio.extensions.model.points[0].x == first_point.x,"Move up / down control shifts the virtual set immediately")
	for region in Extensions.REGIONS:
		var picker = studio.landmarks_panel.region_picker
		picker.select(Extensions.REGIONS.find(region))
		picker.item_selected.emit(picker.selected)
		check(studio.landmarks_panel.region_pages[region].visible,"Region picker exposes that region's contour controls")
		for child in studio.landmarks_panel.region_pages[region].get_children():
			if child is Button and child.text == "Round this region": child.pressed.emit()
		studio.landmarks_panel.controls[region+"_vertical"].value = .1
		if region.ends_with("side"):
			studio.landmarks_panel.controls[region+"_inset"].value = -.08
			check(is_equal_approx(studio.extensions.model.config[region+"_inset"],-.08),"Side region exposes an independent inward/outward starting position")
		check(studio.extensions.model.config[region+"_wrap"] == 110 and studio.extensions.model.config[region+"_back"] > 0,"Rounded region button updates its own contour")
	check(is_equal_approx(studio.extensions.model.config.vertical_offset,-.25),"Regional fitting keeps the existing whole-set up/down offset")
	studio.landmarks_panel.show_region("forehead")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/landmark-contours%s.png"%suffix))
	studio.landmarks_panel.controls.left.value = .4
	studio.landmarks_panel.controls.columns.value = 96
	studio.landmarks_panel.controls.rings.value = 6
	check(studio.extensions.model.points.size() == 576 and studio.extensions.model.config.left == .4,"Actual controls change extents and density")
	var cached: PackedVector2Array = studio.extensions.model.points.duplicate()
	studio.points_check.button_pressed = false
	studio.beard.set_enabled(true)
	studio.beard.set_enabled(false)
	check(studio.beard.mannequin_view.dots.extensions.visible and studio.extensions.model.points == cached,"Virtual markers survive measured-dot and hair visibility changes")
	studio.landmarks_panel.controls.show_points.button_pressed = false
	check(not studio.beard.mannequin_view.dots.extensions.visible and studio.extensions.model.points.size() == 576,"Hide dots retains usable references")
	studio.landmarks_panel.controls.show_points.button_pressed = true
	studio._set_mirror(false)
	var local: Vector2 = studio.extensions.model.points[0]
	var unmirrored: Vector2 = studio.beard._screen(local)
	studio._set_mirror(true)
	var mirrored: Vector2 = studio.beard._screen(local)
	check(studio.beard.mannequin_view.picture.flip_h and absf(unmirrored.x+mirrored.x-studio.extensions.size.x) < .01 and is_equal_approx(unmirrored.y,mirrored.y),"Mirror and letterboxing align")
	studio.landmarks_panel.preview_check.button_pressed = false
	check(studio.extensions.model.points.is_empty(),"Leaving mannequin clears synthetic landmarks")
	var raw: Array = []
	for p in Profile.mannequin(): raw.append(Vector3(p.x,p.y,(p.x-.5)*.4))
	studio.frame_timestamp = Time.get_ticks_usec()
	studio._on_landmarks(raw,1,studio.frame_timestamp)
	check(studio.extensions.model.points.size() == 576 and studio.extensions.face_depth.size() == 478,"Live callback drives virtual landmarks with hair off")
	studio._clear_tracking()
	check(not studio.extensions.drawing.visible and studio.overlay.points.is_empty(),"Face loss clears both landmark layers")
	# Exercise the real settings save/load path in memory, without touching studio.cfg.
	studio._store_settings()
	var restored = load("res://studio.tscn").instantiate()
	restored.persist_settings = false
	check(restored.settings.parse(studio.settings.encode_to_text()) == OK,"Studio configuration round trip")
	restored._build_ui()
	for key in studio.extensions.model.config:
		var value = studio.extensions.model.config[key]
		var saved_value = restored.extensions.model.config[key]
		check(is_equal_approx(float(saved_value),float(value)) if value is float or value is int else saved_value == value,
			"Independent extension setting restores without a hairstyle dependency: "+key)
	restored.free()
	print("EXTENSIONS_RENDER orange_pixels=",orange," failures=",failures)
	quit(0 if failures.is_empty() else 1)
