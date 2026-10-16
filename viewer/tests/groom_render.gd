extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var suffix := args[0] if not args.is_empty() else ""
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio.sidebar_tabs.current_tab = 1
	studio.beard.apply_document(Profile.document("Complete look",Profile.defaults(),{}))
	studio.beard.set_enabled(true)
	studio.beard.set_mannequin(true)
	studio.beard.set_settings(Groom.virtual_preset())
	studio.beard.set_setting("show_virtual_landmarks",false)
	studio.beard.set_settings({"chin_extension":.08,"jaw_expansion":.06,"ear_reach":.06,"sideburn_height":.8,
		"coverage_fill":.55,"brow_enabled":true,"brow_style":"Arched","mustache_style":"Handlebar",
		"mustache_motion":"Static","mustache_curl":.8,"show_generated_roots":false})
	for child in studio.beard_panel.pages["Roots"].get_children():
		if child is Button and child.text == "Fuller coverage": child.pressed.emit()
	if int(studio.beard.config.strands) < 512: failures.append("Fuller coverage did not increase facial density")
	studio.beard_panel.show_page("Scalp hair")
	for style in ["Regular","Mohawk","Afro"]:
		var picker: OptionButton = studio.beard_panel.controls.hair_style
		var index := Groom.HAIR_STYLES.find(style)
		picker.select(index)
		picker.item_selected.emit(index)
		if studio.beard.config.hair_style != style: failures.append("Hair preset control did not apply " + style)
		studio.beard.simulator.reset()
		for i in 120: studio.beard.simulator.advance(1.0/120)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/groom-%s%s.png"%[style.to_lower(),suffix]))
	studio.beard_panel.show_page("Roots")
	studio.beard.set_setting("show_generated_roots",true)
	await process_frame
	await RenderingServer.frame_post_draw
	var markers := root.get_texture().get_image()
	markers.save_png(ProjectSettings.globalize_path("res://../artifacts/groom-roots%s.png"%suffix))
	var magenta := 0
	for y in markers.get_height():
		for x in markers.get_width():
			var color := markers.get_pixel(x,y)
			if color.r > .7 and color.b > .7 and color.g > .2 and color.g < .65: magenta += 1
	if magenta < 200: failures.append("Generated root markers did not render in their distinct color")
	studio.beard_panel.show_page("Eyebrows")
	studio.beard_panel.controls.brow_width.value = 1.3
	if not is_equal_approx(float(studio.beard.config.brow_width),1.3): failures.append("Eyebrow width control failed")
	studio.beard_panel.show_page("Strands")
	studio.beard.set_edit_strands(true)
	var hair_index := int(studio.beard.config.strands)+int(studio.beard.config.brow_count)
	studio.beard.selected_strand = hair_index
	studio.beard.strand_selected.emit(hair_index)
	studio.beard_panel.strand_controls.length.value = 1.2
	if not studio.beard.overrides.has("hair:0"): failures.append("Scalp strand editor did not use stable region IDs")
	print("GROOM_RENDER magenta_pixels=",magenta," failures=",failures)
	quit(0 if failures.is_empty() else 1)
