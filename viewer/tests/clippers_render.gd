extends SceneTree
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/clippers-"+name+".png"))
func blue_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x,y)
			if c.b>.5 and c.r<.25: count += 1
	return count
func _run() -> void:
	root.size = Vector2i(1440,900)
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	studio._set_guides(false)
	studio.sidebar_tabs.current_tab = 2
	studio.beard_panel.show_page("Strands")
	await frame()
	save("disabled")
	var layer: Control = studio.beard
	layer.set_mannequin(true)
	layer.set_enabled(true)
	studio.quick_toolbar.buttons.clippers.button_pressed = true
	layer.set_process(false)
	for i in 240: layer.simulator.advance(1.0/120)
	layer._process(1.0/120)
	var bottom := -INF
	for i in layer.attachment.size(): bottom = maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
	var tool: Control = layer.clippers
	tool.start = layer._screen(Vector2(320,bottom-55))
	tool.finish = layer._screen(Vector2(960,bottom-90))
	tool.dragging = true
	tool.queue_redraw()
	await frame()
	save("line")
	tool.dragging = false
	var count: int = tool.cut(tool.start,tool.finish)
	check(count>0,"Rendered haircut crosses actual visible hair")
	tool.queue_redraw()
	var view: Control = layer.mannequin_view
	check(view.clippings.multimesh.instance_count>0,"Detached pieces upload as one batch")
	for i in 24: layer._process(1.0/120)
	await frame()
	save("falling")
	view.hair.hide(); view.request_frame()
	await frame()
	var pixels := blue_pixels(view.viewport.get_texture().get_image())
	check(pixels>8,"Detached hair renders visible pixels after falling")
	view.hair.show()
	for i in 320: layer._process(1.0/120)
	await frame()
	save("trimmed")
	check(not view.clippings.visible and view.clippings.multimesh.instance_count==0,"Expired fragments disappear from rendering")
	check(view.clippings.data_texture==null and view.clippings.data_image==null,"Expired fragments release their upload storage")
	for yaw in [-90,90]:
		view.set_pose(yaw,0)
		layer.simulator.reset()
		layer.set_process(false)
		bottom = -INF
		for i in layer.attachment.size(): bottom = maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
		check(tool.cut(layer._screen(Vector2(200,bottom-30)),layer._screen(Vector2(1080,bottom-60)))>0,"Cut from side view %d" % yaw)
		layer._process(1.0/60)
		await frame()
		save("side-%d" % yaw)
	layer.set_mannequin(false)
	await frame()
	check(studio.quick_toolbar.buttons.clippers.disabled,"Camera disables clippers after editing")
	print("CLIPPERS_RENDER cuts=",count," detached_pixels=",pixels," failures=",failures)
	quit(0 if failures.is_empty() else 1)
