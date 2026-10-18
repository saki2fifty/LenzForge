extends SceneTree
const Groom = preload("res://beard/groom_regions.gd")
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/buzz-scalp-"+name+".png"))
func _run() -> void:
	root.size=Vector2i(1440,900)
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings=false; studio.backend_url="http://127.0.0.1:9"
	root.add_child(studio)
	studio._set_guides(false)
	studio.sidebar_tabs.current_tab=2
	studio.beard_panel.show_page("Scalp hair")
	var layer: Control = studio.beard
	layer.set_mannequin(true); layer.set_enabled(true)
	for style in ["Regular","Mohawk","Afro"]:
		layer.set_settings(Groom.hair_preset(style))
		layer.set_process(false)
		for pose in [Vector2(0,0),Vector2(90,0),Vector2(180,0),Vector2(0,35)]:
			layer.mannequin_view.set_pose(pose.x,pose.y,.9)
			layer.set_process(false)
			layer.simulator.reset()
			for i in 120: layer.simulator.advance(1.0/120)
			layer._process(1.0/120)
			await frame()
			save(style.to_lower()+"-%d-%d"%[pose.x,pose.y])
	layer.set_settings(Groom.hair_preset("Regular"))
	layer.mannequin_view.set_pose(0,0,1.2)
	layer.set_process(false)
	layer.simulator.reset()
	for i in 120: layer.simulator.advance(1.0/120)
	layer._process(1.0/120)
	studio.quick_toolbar.clipper_menu.get_popup().id_pressed.emit(1)
	var tool: Control = layer.clippers
	tool.cursor_visible=true
	var bottom := -INF
	for i in int(layer.config.strands): bottom=maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
	tool.cursor=layer._screen(Vector2(550,bottom-60))
	tool.queue_redraw()
	await frame()
	save("buzz-idle")
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=tool.cursor
	layer._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT; motion.position=layer._screen(Vector2(750,bottom-60))
	layer._gui_input(motion); tool._process(1.0/60)
	layer._process(1.0/120)
	await frame()
	save("buzz-running")
	press.pressed=false; press.position=motion.position
	layer._gui_input(press)
	studio.quick_toolbar.clipper_menu.show_popup()
	await frame()
	save("menu")
	print("BUZZ_SCALP_RENDER cuts=",tool.stroke_count)
	quit(0 if tool.stroke_count>0 else 1)
