extends SceneTree
## Inspect the actual default groom and GPU head occlusion in both turning directions.
const Layer = preload("res://beard/beard_layer.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var layer := Layer.new()
	layer.size = Vector2(960,540)
	root.add_child(layer)
	layer.set_enabled(true)
	layer.set_mannequin(true)
	layer.set_process(false)
	var view := layer.mannequin_view
	for yaw in [0,-60,60,-90,90]:
		view.set_pose(yaw,0)
		layer.simulator.reset()
		for i in 90: layer.simulator.advance(1.0/120)
		layer._process(1.0/120)
		await process_frame
		await RenderingServer.frame_post_draw
		view.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/sideburn-%s.png"%yaw))
		# Paint only the hidden ear-front strip. No far-side strand should leak through the head.
		if absi(yaw) != 90: continue
		var packed: PackedFloat32Array = layer.simulator.get_render_buffer()
		var far_count := 0
		for slot in layer.render_order.size():
			var id: int = layer.render_order[slot]
			var a: Dictionary = layer.attachment[id]
			var hidden: bool = a.has("sideburn_target") and view.root_camera_positions[id].z > 0
			if hidden: far_count += 1
			for j in int(layer.config.segments):
				var at := (slot*int(layer.config.segments)+j)*16
				packed[at+8] = 1; packed[at+9] = 0; packed[at+10] = 1
				packed[at+11] = 1 if hidden else 0
		view.update_hair(packed,int(layer.config.segments),true)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := view.viewport.get_texture().get_image()
		var visible := 0
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x,y)
				if color.r > .8 and color.g < .2 and color.b > .8: visible += 1
		if far_count < 12 or visible != 0: failures.append("Far sideburn at yaw %s: %s strands, %s visible pixels"%[yaw,far_count,visible])
	layer.free()
	print("SIDEBURN_RENDER failures=",failures)
	quit(0 if failures.is_empty() else 1)
