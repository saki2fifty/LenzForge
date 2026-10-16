extends SceneTree
const Extensions = preload("res://tracking/face_extensions.gd")
const Surface = preload("res://tracking/head_surface.gd")
const Layer = preload("res://tracking/extension_layer.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := Extensions.new()
	var face := PackedVector2Array()
	var depth := PackedFloat32Array()
	var dims := Vector2(1280,720)
	for p in Surface.canonical_points():
		face.append((dims*.5+Vector2(p.x,p.y)*20)/dims)
		depth.append(p.z*20/dims.x)
	var original := face.duplicate()
	model.update(face,dims,depth)
	check(model.points.size() == 288,"Default full-outline extension is enabled")
	check(face == original and face.size() == 478,"Measured inputs remain untouched")
	for i in model.points.size():
		var resolved: Dictionary = model.surface.resolve(model.ids[i])
		check(model.points[i].distance_to(Vector2(resolved.position.x,resolved.position.y)) < .0001,"Guide positions equal attachment positions")
		check(absf(model.point_depth[i]-resolved.position.z/dims.x) < .000001,"Guides and attachments share depth")
	var before := model.config.duplicate()
	for invalid in [{"rings":13},{"columns":36.5},{"left":INF},{"vertical_offset":-1.6},{"vertical_offset":INF},{"color":"oops"},{"enabled":1},{"unknown":true}]:
		check(not model.configure(invalid) and model.config == before,"Invalid configuration is rejected atomically")
	var initial := model.points.duplicate()
	for shift in [-.4,.4]:
		model.configure({"vertical_offset":shift})
		model.update(face,dims,depth)
		check(model.points != initial,"Up/down moves coverage along the skin")
		var positions: PackedVector3Array = model.surface.sample(model.bindings)
		# Independent nearest-point fit against the rendered mesh must have zero gap.
		var fitted: Dictionary = model.surface.math.bind_nearest(model.surface.vertices,Surface.topology(),positions)
		var projected: PackedVector3Array = model.surface.sample(fitted)
		for i in positions.size(): check(positions[i].distance_to(projected[i]) < .001,"Every shifted guide stays on a real surface triangle")
	model.configure({"columns":144,"rings":12})
	model.update(face,dims,depth)
	check(model.points.size() == 1728,"Maximum density remains bounded")
	var restored := Extensions.new()
	check(restored.configure(JSON.parse_string(JSON.stringify(model.config))),"JSON settings reload")
	restored.update(face,dims,depth)
	check(restored.points == model.points,"Saved fitting reproduces virtual references")
	model.configure({"show_points":false})
	model.update(face,dims,depth)
	check(model.points.size() == 1728,"Hiding guides leaves reference data available")
	model.configure({"enabled":false})
	model.update(face,dims,depth)
	check(model.points.is_empty(),"Disabling the guide set clears display points")
	model.configure({"enabled":true})
	model.update(PackedVector2Array(),dims)
	check(model.points.is_empty() and model.point_depth.is_empty(),"Tracking loss clears all projected references")
	var layer := Layer.new()
	layer.size = Vector2(800,600)
	root.add_child(layer)
	layer.set_face(face,dims,depth)
	check(layer.drawing.visible and layer.model.points.size() == 288,"Virtual landmarks work independently of hair")
	layer.set_settings({"show_points":false})
	check(not layer.drawing.visible and layer.model.points.size() == 288,"Hidden guides remain usable")
	layer.clear_face()
	check(layer.model.points.is_empty() and not layer.is_processing(),"Stale tracking stops overlay processing")
	layer.free()
	print("EXTENSIONS_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
