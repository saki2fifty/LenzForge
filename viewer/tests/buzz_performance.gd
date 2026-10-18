extends SceneTree
func _initialize() -> void: _run.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func _run() -> void:
	var layer = load("res://beard/beard_layer.gd").new()
	layer.size=Vector2(900,600)
	root.add_child(layer)
	layer.set_enabled(true); layer.set_mannequin(true)
	var cases := []
	for maximum in [false,true]:
		var began := Time.get_ticks_usec()
		layer.set_settings({"hair_style":"Regular","hair_count":768 if maximum else 512,"brow_enabled":maximum,"brow_count":256,"segments":16 if maximum else 8})
		var edit_ms := (Time.get_ticks_usec()-began)/1000.0
		layer.set_process(false); layer.simulator.reset()
		var idle: Array[float] = []
		for i in 90:
			began=Time.get_ticks_usec()
			layer._process(1.0/60)
			if i>=30: idle.append((Time.get_ticks_usec()-began)/1000.0)
		var bottom := -INF
		for i in int(layer.config.strands): bottom=maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
		var tool: Control = layer.clippers
		tool.set_mode("Buzz")
		var button := InputEventMouseButton.new()
		button.button_index=MOUSE_BUTTON_LEFT; button.pressed=true; button.position=layer._screen(Vector2(400,bottom-70))
		layer._gui_input(button)
		var active: Array[float] = []
		var cutting: Array[float] = []
		for i in 120:
			var motion := InputEventMouseMotion.new()
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			motion.position=layer._screen(Vector2(640+sin(i*.08)*260,bottom-70-i*.4))
			layer._gui_input(motion)
			began=Time.get_ticks_usec()
			tool._process(1.0/60)
			cutting.append(tool.last_cut_ms)
			layer._process(1.0/60)
			active.append((Time.get_ticks_usec()-began)/1000.0)
		tool.cancel_stroke()
		cases.append({"strands":layer.attachment.size(),"segments":layer.config.segments,"scalp_edit_ms":edit_ms,"cuts":tool.stroke_count,
			"idle_frame_cpu_ms":stats(idle),"buzz_query_ms":stats(cutting),"buzz_frame_cpu_ms":stats(active)})
		tool.clear_clippings()
	var report := {"fixture":"Headless native mannequin; Regular scalp, collisions on. 60 idle and 120 held-Buzz samples at 60 Hz. Includes physics and upload preparation, excludes GPU completion, camera and tracking.","cases":cases}
	var file := FileAccess.open("res://../artifacts/buzz-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BUZZ_PERFORMANCE ",JSON.stringify(report))
	layer.free()
	quit()
