extends SceneTree
func _initialize() -> void: _run.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func _run() -> void:
	var layer = load("res://beard/beard_layer.gd").new()
	layer.size = Vector2(900,600)
	root.add_child(layer)
	layer.set_enabled(true)
	layer.set_mannequin(true)
	layer.set_process(false)
	var result := []
	for maximum in [false,true]:
		layer.set_settings({"strands":1024,"segments":16 if maximum else 8,"brow_enabled":maximum,
			"brow_count":256,"hair_style":"Afro" if maximum else "None","hair_count":768})
		layer.set_process(false)
		layer.simulator.reset()
		var idle: Array[float] = []
		for i in 90:
			var begin := Time.get_ticks_usec()
			layer._process(1.0/120)
			if i>=30: idle.append((Time.get_ticks_usec()-begin)/1000.0)
		var bottom := -INF
		# Trim the facial hair after settling, even when longer scalp hair exists.
		for i in 1024: bottom = maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
		var count: int = layer.clippers.cut(layer._screen(Vector2(100,bottom-50)),layer._screen(Vector2(1180,bottom-70)))
		var active: Array[float] = []
		for i in 90:
			var begin := Time.get_ticks_usec()
			layer._process(1.0/120)
			active.append((Time.get_ticks_usec()-begin)/1000.0)
		result.append({"strands":layer.attachment.size(),"segments":layer.config.segments,"cut_count":count,
			"commit_ms":layer.clippers.last_cut_ms,"idle_physics_upload_ms":stats(idle),"with_clippings_physics_upload_ms":stats(active)})
		layer.clippers.clear_clippings()
	var solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config: Dictionary = preload("res://beard/beard_profile.gd").defaults()
	config.merge({"length":1.0,"collisions":false},true)
	var attributes := PackedFloat32Array()
	var anchors := PackedVector3Array()
	for i in 2048:
		attributes.append_array(PackedFloat32Array([.8,.1,.1,0,1,1,1,1,1,1,1,1]))
		anchors.append(Vector3(i+1,10,0))
	solver.configure(2048,16,config,attributes)
	solver.set_anchors_3d(anchors,100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	var projection := Transform3D(Basis(Vector3.RIGHT,Vector3.DOWN,Vector3.FORWARD),Vector3.ZERO)
	var begin := Time.get_ticks_usec()
	var cuts: Dictionary = solver.clip_line(Vector2(0,50),Vector2(2049,50),PackedVector3Array(),PackedInt32Array(),Transform3D.IDENTITY,projection,1.0)
	var stress := {"strands":2048,"segments":16,"cut_count":cuts.cuts.size(),"commit_ms":(Time.get_ticks_usec()-begin)/1000.0}
	var samples: Array[float] = []
	for i in 90:
		begin = Time.get_ticks_usec()
		solver.advance(1.0/120)
		solver.get_render_buffer()
		solver.get_clippings_buffer(projection)
		samples.append((Time.get_ticks_usec()-begin)/1000.0)
	stress["native_physics_packing_ms"] = stats(samples)
	stress["fixture"] = "2,048 detached pieces; straight separated strands, head collisions off; no Godot texture upload or GPU completion."
	var file := FileAccess.open("res://../artifacts/clippers-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"Synthetic mannequin; 60 idle samples, 90 with clippings. CPU only; no camera or GPU completion.","cases":result,"full_pool":stress},"\t"))
	print("CLIPPERS_PERFORMANCE ",JSON.stringify(result))
	print("CLIPPERS_FULL_POOL ",JSON.stringify(stress))
	layer.free()
	quit()
