extends SceneTree
## Render synthetic points to verify instancing, circles, mirror and letterboxing.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var overlay = load("res://landmarks.gd").new()
	overlay.size = Vector2(400, 300)
	overlay.video_size = Vector2(800, 400)
	overlay.points = PackedVector2Array([Vector2(.25, .25), Vector2(.75, .75)])
	overlay.mirror = false
	overlay.point_size = 6.0
	viewport.add_child(overlay)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_pixel(100, 100).a > .9, "First point missing")
	assert(image.get_pixel(300, 200).a > .9, "Second point missing")
	assert(image.get_pixel(105, 105).a < .1, "Point should be circular")
	overlay.mirror = true
	overlay.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(300, 100).a > .9, "Mirrored point missing")
	assert(image.get_pixel(100, 100).a < .1, "Previous point not cleared")
	overlay.size = Vector2(400, 400)
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(300, 150).a > .9, "Resize/letterboxing incorrect")
	overlay.show_points = false
	overlay.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	assert(image.get_pixel(300, 150).a < .1, "Hidden overlay still drawn")
	print("LANDMARKS_RENDER_PASS")
	quit()
