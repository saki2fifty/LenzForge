extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Sculpted = preload("res://beard/sculpted_hair.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	root.gui_disable_input = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio._set_guides(false)
	studio.sidebar_tabs.current_tab = 2
	studio.beard.apply_document(Profile.document("Sculpted hair test",Profile.defaults(),{}))
	studio.beard.set_enabled(true)
	studio.beard.set_mannequin(true)
	studio.beard.set_settings({"beard_visible":false,"mustache_enabled":false,"brow_enabled":false,
		"show_generated_roots":false,"show_virtual_landmarks":false})
	studio.beard_panel.show_page("Scalp hair")
	for style in Sculpted.MODELS:
		var picker: OptionButton = studio.beard_panel.controls.hair_style
		var index := Groom.HAIR_STYLES.find(style)
		picker.select(index); picker.item_selected.emit(index)
		if studio.beard.config.hair_style!=style: failures.append("Selector failed for "+style)
		for view in [Vector3(-25,-8,1),Vector3(-85,0,1),Vector3(155,0,1)]:
			studio.beard.mannequin_view.set_pose(view.x,view.y,view.z)
			await frame()
			var path := "res://../artifacts/hair-%s-%d.png"%[style.to_lower().replace(" ","-"),int(view.x)]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SCULPTED_HAIR_RENDER failures=",failures)
	quit(0 if failures.is_empty() else 1)
