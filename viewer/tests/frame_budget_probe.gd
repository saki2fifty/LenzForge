extends SceneTree
## Deterministic head motion, explicit simulation stepping, and isolated settings.
const Surface = preload("res://tracking/head_surface.gd")
const Profile = preload("res://beard/beard_profile.gd")
func _initialize() -> void: _run.call_deferred()
func stats(samples: Array) -> Dictionary:
	samples.sort()
	return {"median":samples[samples.size()/2],"p95":samples[int(samples.size()*.95)],"max":samples[-1]}
func _run() -> void:
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:1"
	root.add_child(studio)
	var output := []
	var source := Surface.canonical_points()
	for name in ["default_no_collision","default","maximum"]:
		var config := Profile.defaults()
		if name == "default_no_collision": config.collisions = false; config.mustache_collisions = false
		if name == "maximum": config.merge({"segments":16,"brow_enabled":true,"brow_count":256,"hair_style":"Afro","hair_count":768},true)
		studio.beard.apply_document(Profile.document(name,config,{}))
		var timings := {"tracking":[],"simulation":[],"packing":[],"upload":[],"total":[]}
		for frame in 220:
			var rotation := Basis(Vector3.UP,sin(frame*.03)*1.1)*Basis(Vector3.RIGHT,cos(frame*.02)*.25)
			var points := []
			for p in source:
				var q: Vector3 = rotation*p*22+Vector3(640,360,0)
				points.append(Vector3(q.x/1280,q.y/720,q.z/1280))
			studio.frame_timestamp = frame*16667
			var start := Time.get_ticks_usec()
			studio._on_landmarks(points,frame,studio.frame_timestamp)
			studio.beard.set_process(false)
			var attached := Time.get_ticks_usec()
			studio.beard.simulator.advance(1.0/60)
			var simulated := Time.get_ticks_usec()
			var buffer: PackedFloat32Array = studio.beard.simulator.get_render_buffer()
			var packed := Time.get_ticks_usec()
			studio.beard.live_view.update_hair(buffer,int(config.segments),studio.beard.surface.width)
			var finished := Time.get_ticks_usec()
			if frame >= 40:
				for pair in [["tracking",attached-start],["simulation",simulated-attached],["packing",packed-simulated],["upload",finished-packed],["total",finished-start]]:
					timings[pair[0]].append(pair[1]/1000.0)
			if frame%30 == 0: await process_frame
		var row := {"case":name,"strands":studio.beard.attachment.size(),"segments":config.segments}
		for key in timings: row[key] = stats(timings[key])
		output.append(row)
		print("FRAME_BUDGET ",JSON.stringify(row))
	var args := OS.get_cmdline_user_args()
	var label := args[0] if not args.is_empty() else "current"
	var file := FileAccess.open("res://../artifacts/frame-budget-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"Canonical head, 180 measured samples, 120 Hz physics stepped at 60 Hz. CPU stages only; no camera/inference/presentation.","cases":output},"\t"))
	quit()
