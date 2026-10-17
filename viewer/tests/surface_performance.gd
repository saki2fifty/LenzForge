extends SceneTree
const Reference = preload("res://mannequin/head_model.gd")
func _initialize() -> void: _run.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:1"
	root.add_child(studio)
	# Keep the published before/after workload independent of personal defaults.
	studio.beard.set_settings({"strands":512,"segments":8,"length":.45,"root_width":2.4,"tip_width":.25,
		"gravity":3.0,"damping":.025,"curl":.12,"variation":.25,"root_color":"302019ff","tip_color":"77513aff",
		"mustache_style":"Natural","mustache_width":1.0,"mustache_thickness":1.0,"mustache_density":1.0,
		"mustache_motion":"Free","mustache_color":"302019ff","mustache_tip_color":"302019ff","brow_color":"302019ff"})
	studio.beard.set_settings({"mustache_gravity":3.0,"mustache_damping":.025,"mustache_variation":.25})
	studio.beard.set_enabled(true)
	var source := Reference.reference_points()
	var result := []
	var edit_costs := {}
	for maximum in [false,true]:
		if maximum:
			var edit_start := Time.get_ticks_usec()
			studio.beard.set_settings({"strands":1024,"segments":16,"brow_enabled":true,"brow_count":256,"hair_style":"Afro","hair_count":768,"virtual_enabled":true})
			studio.extensions.set_settings({"columns":144,"rings":12})
			edit_costs.maximum_placement_ms = (Time.get_ticks_usec()-edit_start)/1000.0
			edit_start = Time.get_ticks_usec()
			studio.beard.set_setting("gravity",3.1)
			edit_costs.maximum_force_ms = (Time.get_ticks_usec()-edit_start)/1000.0
			studio.beard.set_setting("gravity",3.0)
			edit_start = Time.get_ticks_usec()
			studio.beard.set_setting("mustache_wind",.1)
			edit_costs.mustache_force_ms = (Time.get_ticks_usec()-edit_start)/1000.0
			studio.beard.set_setting("mustache_wind",0.0)
		var pipeline: Array[float] = []
		var physics: Array[float] = []
		for frame in 270:
			var rotation := Basis(Vector3.UP,sin(frame*.03)*1.1)*Basis(Vector3.RIGHT,cos(frame*.02)*.25)
			var points := []
			for p in source:
				var q: Vector3 = rotation*p
				points.append(Vector3((640+q.x*22)/1280,(360-q.y*22)/720,-q.z*22/1280))
			studio.frame_timestamp = frame*16667
			var start := Time.get_ticks_usec()
			studio._on_landmarks(points,frame,studio.frame_timestamp)
			var attached := Time.get_ticks_usec()
			studio.beard._process(1.0/60)
			if frame >= 30:
				pipeline.append((attached-start)/1000.0)
				physics.append((Time.get_ticks_usec()-attached)/1000.0)
			if frame % 30 == 0: await process_frame
		result.append({"case":"maximum" if maximum else "default","tracking_result_cpu_ms":stats(pipeline),"physics_upload_cpu_ms":stats(physics),"strands":studio.beard.attachment.size(),"guides":studio.extensions.model.points.size()})
	var name := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "current"
	var file := FileAccess.open("res://../artifacts/surface-performance-"+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"Canonical face with synthetic yaw/pitch, 240 measured samples. CPU only; no camera, inference, GPU completion, or presentation.","cases":result,"edit_costs":edit_costs},"\t"))
	print("SURFACE_PERFORMANCE ",JSON.stringify(result)," edits=",edit_costs)
	quit()
