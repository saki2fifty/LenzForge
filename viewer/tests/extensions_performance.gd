extends SceneTree
## Isolated CPU projection + marker upload timing; no hair, camera, or inference.
const Layer = preload("res://tracking/extension_layer.gd")
const Profile = preload("res://beard/beard_profile.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layer := Layer.new()
	layer.size = Vector2(1000,700)
	root.add_child(layer)
	var source := Profile.mannequin()
	var dimensions := Vector2(1280,720)
	var cases: Array = []
	for test in ["disabled","default_hidden","default_visible","maximum_visible"]:
		layer.set_settings({"enabled":test != "disabled","show_points":test.ends_with("visible"),
			"columns":144 if test == "maximum_visible" else 72,"rings":12 if test == "maximum_visible" else 4})
		var times: Array[float] = []
		for frame in 270:
			await process_frame
			var t := frame/60.0
			var rotation := Basis(Vector3.BACK,sin(t*2)*.22)*Basis(Vector3.UP,sin(t*1.4)*.45)*Basis(Vector3.RIGHT,cos(t)*.15)
			var face := PackedVector2Array()
			var depth := PackedFloat32Array()
			for point in source:
				var local := point*dimensions-dimensions*.5
				var turned := rotation*Vector3(local.x,local.y,0)
				face.append((Vector2(turned.x,turned.y)+dimensions*.5+Vector2(sin(t*3)*24,cos(t*2)*12))/dimensions)
				depth.append(turned.z/dimensions.x)
			var started := Time.get_ticks_usec()
			layer.set_face(face,dimensions,depth)
			if frame >= 30: times.append((Time.get_ticks_usec()-started)/1000.0)
		times.sort()
		var total := 0.0
		for value in times: total += value
		var result := {"case":test,"points":layer.model.points.size(),"samples":times.size(),
			"mean_ms":total/times.size(),"p95_ms":times[int(times.size()*.95)],"max_ms":times[-1]}
		cases.append(result)
		print("EXTENSIONS_PERFORMANCE ",JSON.stringify(result))
	var file := FileAccess.open("res://../artifacts/landmark-extensions-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"Synthetic yaw, pitch, roll, translation and relative Z. One independent landmark layer. 30 warmup + 240 measured frames/case. CPU projection + upload preparation only; excludes fixture generation, camera, inference, GPU completion and presentation.","cases":cases},"\t"))
	layer.free()
	quit()
