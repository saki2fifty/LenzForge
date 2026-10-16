extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	root.add_child(studio)
	studio.sidebar_tabs.current_tab = 1
	studio.beard_panel._create()
	studio.beard.set_mannequin(true)
	studio.beard.set_setting("wind", 1.5)
	if studio.beard_panel.controls.stiffness.editable: failures.append("Free-hanging mode must not offer an active shape spring")
	studio.beard_panel.controls.preserve_shape.button_pressed = true
	if not studio.beard.config.preserve_shape or not studio.beard_panel.controls.stiffness.editable:
		failures.append("Preserve styled shape switch did not enable the shape spring")
	studio.beard_panel.controls.preserve_shape.button_pressed = false
	studio.beard_panel.library.directory = ProjectSettings.globalize_path("res://../artifacts/beard-render-library-%d" % Time.get_ticks_usec())
	studio.beard_panel._save()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	if not FileAccess.file_exists(studio.beard_panel.library.thumbnail_path(studio.beard_panel.current_id)):
		failures.append("Saved beard thumbnail missing")
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../artifacts/beard-studio.png")
	root.get_texture().get_image().save_png(output)
	# Exercise actual strand selection and controls, including the topmost highlight.
	studio.beard.set_edit_strands(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = studio.beard._screen(studio.beard.roots[0])
	studio.beard._gui_input(click)
	if studio.beard.selected_strand != 0: failures.append("Click did not select the strand root")
	studio.beard_panel.strand_controls.length.value = 1.7
	if not is_equal_approx(float(studio.beard.overrides["0"].length),1.7): failures.append("Individual strand control did not apply")
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer = load("res://beard/beard_layer.gd").new()
	layer.size = Vector2(512,512)
	viewport.add_child(layer)
	layer.set_setting("root_color", "00ff00ff")
	layer.set_setting("tip_color", "00ff00ff")
	layer.set_enabled(true)
	layer.set_face(Profile.mannequin(), Vector2(1280,720))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var green := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.g > .6 and color.r < .1 and color.a > .15: green += 1
	if green < 500: failures.append("Instanced hair was not rendered: %d green pixels" % green)
	layer.set_enabled(false)
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	if not image.is_invisible(): failures.append("Hidden beard still renders")
	print("BEARD_RENDER green_pixels=", green, " failures=", failures, " screenshot=", output)
	quit(0 if failures.is_empty() else 1)
