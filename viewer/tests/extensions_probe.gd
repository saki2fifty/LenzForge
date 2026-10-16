extends SceneTree
const Extensions = preload("res://tracking/face_extensions.gd")
const FaceFrame = preload("res://tracking/face_frame.gd")
const Layer = preload("res://tracking/extension_layer.gd")
const Profile = preload("res://beard/beard_profile.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := Extensions.new()
	var face := Profile.mannequin()
	var original := face.duplicate()
	var dims := Vector2(1280,720)
	model.update(face,dims)
	check(model.points.size() == 288,"Default full-outline extension is enabled")
	check(face == original and face.size() == 478,"Measured landmark IDs and positions remain untouched")
	var points := model.points.duplicate()
	var width: float = FaceFrame.frame(face,dims).width
	check(points[216].distance_to(face[10]*dims+Vector2(0,-.42*width)) < .001,"Top reaches above the tracked forehead")
	check(points[252].distance_to(face[152]*dims+Vector2(0,.2*width)) < .001,"Bottom reaches below the chin")
	check(points[232].distance_to(face[454]*dims+Vector2(.18*width,0)) < .001,"Right cheek extends sideways")
	check(points[272].distance_to(face[234]*dims-Vector2(.18*width,0)) < .001,"Left cheek extends sideways")
	var unique := {}
	for id in model.ids: unique[id] = true
	check(unique.size() == 288,"Virtual identifiers are unique and separate from measured indices")
	var original_ids := model.ids.duplicate()
	for shift in [-.25,.25]:
		model.configure({"vertical_offset":shift})
		model.update(face,dims)
		check(model.ids == original_ids,"Moving the virtual set preserves its identities and density")
		for i in points.size():
			check(model.points[i].distance_to(points[i]+Vector2(0,shift*width)) < .001,"Every ring moves equally up or down without changing shape")
	# Every virtual point must transform with the measured face in 3D.
	var rotation := Basis(Vector3.BACK,.3)*Basis(Vector3.UP,.6)*Basis(Vector3.RIGHT,-.25)
	var moved := PackedVector2Array()
	var depths := PackedFloat32Array()
	var pivot := dims*.5
	for p in face:
		var local := p*dims-pivot
		var q := rotation*Vector3(local.x,local.y,0)*1.15
		moved.append((Vector2(q.x,q.y)+pivot+Vector2(20,-15))/dims)
		depths.append(q.z/dims.x)
	model.update(moved,dims,depths)
	for i in model.points.size():
		var base := face[model.source_a[i]].lerp(face[model.source_b[i]],model.weights[i])*dims-pivot
		var expected: Vector3 = rotation*(Vector3(base.x,base.y,0)+model.offsets[i]*width)*1.15
		check(model.points[i].distance_to(Vector2(expected.x,expected.y)+pivot+Vector2(20,-15)) < .003,"Virtual point follows yaw/pitch/roll and scale")
	var behind := model.points[216]
	model.configure({"depth":-.3})
	model.update(moved,dims,depths)
	check(model.points[216].distance_to(behind) > 30,"Forward/backward offsets are visible during head turns")
	model.configure({"left":.6,"right":.1})
	model.update(face,dims)
	check(is_equal_approx(model.points[272].x,face[234].x*dims.x-.6*width),"Asymmetric side extension")
	var before := model.config.duplicate()
	for invalid in [{"rings":13},{"columns":36.5},{"left":INF},{"vertical_offset":-1.6},{"vertical_offset":INF},{"color":"oops"},{"enabled":1},{"unknown":true}]:
		check(not model.configure(invalid) and model.config == before,"Invalid configuration is rejected atomically")
	model.configure({"columns":144,"rings":12})
	model.update(face,dims)
	check(model.points.size() == 1728,"Maximum density remains bounded")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.config))
	var restored := Extensions.new()
	check(restored.configure(saved),"JSON settings reload")
	restored.update(face,dims)
	check(restored.points == model.points,"Saved fitting reproduces virtual references")
	var older_settings := Extensions.defaults()
	older_settings.erase("vertical_offset")
	var older := Extensions.new()
	check(older.configure(older_settings) and older.config.vertical_offset == 0,"Older settings keep the original vertical placement")
	face[338] = Vector2(INF,0)
	model.update(face,dims)
	check(model.points.is_empty(),"A malformed outline cannot produce invalid render transforms")
	var layer := Layer.new()
	layer.size = Vector2(640,480)
	root.add_child(layer)
	layer.set_face(original,dims)
	check(layer.drawing.visible and layer.model.points.size() == 288,"Independent layer works without any hair renderer")
	layer.set_settings({"show_points":false})
	check(not layer.drawing.visible and layer.model.points.size() == 288,"Hiding dots keeps virtual reference data")
	layer.set_settings({"enabled":false})
	check(layer.model.points.is_empty(),"Disabling extensions removes virtual references")
	layer.set_settings({"enabled":true,"show_points":true})
	layer.face_seen_at = Time.get_ticks_msec()-300
	layer._process(0)
	check(layer.model.points.is_empty() and not layer.drawing.visible and not layer.is_processing(),"Stale tracking clears even if video stops")
	layer.free()
	print("EXTENSIONS_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
