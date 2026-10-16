extends SceneTree
## Offline animated face fixture: no backend, camera, or saved settings touched.
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Layer = preload("res://beard/beard_layer.gd")

func distribution(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p50":values[int(values.size()*.5)],"p95":values[int(values.size()*.95)],"max":values[-1]}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layer := Layer.new()
	layer.size = Vector2(1000,700)
	root.add_child(layer)
	var face := Profile.mannequin()
	var dims := Vector2(1280,720)
	var rows: Array = []
	var args := OS.get_cmdline_user_args()
	var virtual_test := not args.is_empty() and args[0] == "virtual"
	var cases := ["combined","virtual","virtual_markers","virtual_dense"] if virtual_test else ["beard","combined","combined_markers","maximum","maximum_markers"]
	for test in cases:
		var config := Profile.defaults()
		if test != "beard":
			config.merge(Groom.hair_preset("Afro"),true)
			config.brow_enabled = true
			config.chin_extension = .1; config.ear_reach = .08; config.sideburn_height = .8
		if test.begins_with("maximum"):
			config.strands = 1024; config.brow_count = 256; config.hair_count = 768; config.segments = 16
		config.show_generated_roots = test.ends_with("markers")
		if test.begins_with("virtual"):
			config.merge(Groom.virtual_preset(),true)
			config.show_virtual_landmarks = test != "virtual"
			if test == "virtual_dense": config.virtual_columns = 48; config.virtual_rows = 10
		var rebuild_start := Time.get_ticks_usec()
		layer.apply_document(Profile.document(test,config,{}))
		var rebuild_ms := (Time.get_ticks_usec()-rebuild_start)/1000.0
		layer.set_enabled(true)
		var attach: Array[float] = []
		var physics: Array[float] = []
		var total: Array[float] = []
		var intervals: Array[float] = []
		var last_frame := 0
		for frame in 270:
			await process_frame
			var now := Time.get_ticks_usec()
			var t := frame/60.0
			var moved := PackedVector2Array()
			var depths := PackedFloat32Array()
			var rotation := Basis(Vector3.BACK,sin(t*2)*.22)*Basis(Vector3.UP,sin(t*1.4)*.45)*Basis(Vector3.RIGHT,cos(t)*.15)
			for point in face:
				if virtual_test:
					var local := point*dims-dims*.5
					var turned := rotation*Vector3(local.x,local.y,0)
					moved.append((Vector2(turned.x,turned.y)+dims*.5+Vector2(sin(t*3)*24,cos(t*2)*12))/dims)
					depths.append(turned.z/dims.x)
				else:
					moved.append(((point*dims-dims*.5).rotated(sin(t*2)*.22)+dims*.5+Vector2(sin(t*3)*24,cos(t*2)*12))/dims)
			var started := Time.get_ticks_usec()
			layer.set_face(moved,dims,depths)
			layer.set_process(false)
			var attached := Time.get_ticks_usec()
			layer._process(1.0/60)
			var finished := Time.get_ticks_usec()
			if frame >= 30:
				attach.append((attached-started)/1000.0)
				physics.append(layer.update_ms)
				total.append((finished-started)/1000.0)
				intervals.append((now-last_frame)/1000.0)
			last_frame = now
		var row := {"case":test,"strands":layer.attachment.size(),"segments":config.segments,"samples":total.size(),
			"virtual_landmarks":layer.virtual_points.size(),
			"rebuild_ms":rebuild_ms,"attachment_and_markers_ms":distribution(attach),
			"physics_and_upload_ms":distribution(physics),"total_cpu_ms":distribution(total),"frame_interval_ms":distribution(intervals)}
		rows.append(row)
		print("GROOM_PERFORMANCE ",JSON.stringify(row))
	var file := FileAccess.open("res://../artifacts/virtual-head-performance.json" if virtual_test else "res://../artifacts/groom-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"Synthetic animated face; no camera or inference. 60 Hz display, 120 Hz physics. CPU times exclude GPU completion/presentation.","cases":rows},"\t"))
	layer.free()
	quit()
