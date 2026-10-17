extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Extensions = preload("res://tracking/face_extensions.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layer = load("res://beard/beard_layer.gd").new()
	layer.size = Vector2(800,600)
	root.add_child(layer)
	var view = layer.mannequin_view
	check(not view._built and view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"Live mode does not construct or render the 3D head")
	layer.set_mannequin(true)
	check(view.reference.size() == 478 and layer.face_depth.size() == 478,"Actual 3D reference points retain all tracking IDs")
	check(absf(layer.face_depth[1]-layer.face_depth[234]) > .05,"Nose and side landmarks have distinct depth")
	var extensions := Extensions.new()
	var extended: PackedVector3Array = view.extension_points(extensions)
	check(extended.size() == 288 and extended[0].z < view.reference[10].z,"Virtual forehead contours extend back in 3D")
	var stable := extended.duplicate()
	layer.set_enabled(true)
	for angle in [0,45,90,135,180,-90]:
		view.set_pose(angle,20)
		layer._process(1.0/60)
		check(layer._face_live and layer.roots.size() == int(layer.config.strands),"Hair remains attached at yaw %s"%angle)
		for point in layer.face: check(point.is_finite(),"Finite projected reference")
		for point in layer.roots: check(point.is_finite(),"Finite projected hair root")
		check(view.extension_points(extensions) == stable,"Orbit leaves local virtual fitting unchanged")
		var projected: Vector2 = view.project_points(view.reference)[1]
		var actual: Vector2 = view.camera.unproject_position(view.world_point(view.reference[1]))/Vector2(view.viewport.size)*view.FRAME
		check(projected.distance_to(actual) < .001,"Landmark projection matches the real 3D camera")
	view.reset_view()
	layer.mannequin_toolbar.get_child(1).pressed.emit()
	check(view.yaw == 90,"Side button rotates the actual head")
	layer.mannequin_toolbar.get_child(3).pressed.emit()
	check(view.yaw == 0 and view.pitch == 0 and view.zoom == 1,"Reset button restores the camera")
	var original: Vector2 = layer.face[1]
	var input := InputEventMouseMotion.new()
	input.relative = Vector2(100,30); input.button_mask = MOUSE_BUTTON_MASK_LEFT
	layer._gui_input(input)
	check(absf(view.yaw) > 30 and view.pitch > 10 and layer.face[1] != original,"Dragging rotates geometry and reference points")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true
	layer._gui_input(wheel)
	check(view.zoom > 1,"Wheel zoom changes the orthographic camera")
	view.set_pose(90,90,9)
	check(view.pitch == 70 and view.zoom == 2,"Orbit and zoom remain bounded")
	view.reset_view()
	layer.set_mirror(false)
	check(not view.picture.flip_h,"3D texture honors mirror off")
	layer.set_mirror(true)
	check(view.picture.flip_h,"3D texture honors mirror on")
	layer.set_enabled(false)
	check(not view.hair.visible and not layer.is_processing(),"Hair-off mode has no strand updates")
	layer.set_mannequin(false)
	check(not view.visible and view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"Leaving mannequin stops its viewport immediately")
	layer.set_enabled(true)
	layer.set_face(Profile.mannequin(),Vector2(640,360))
	layer._process(1.0/60)
	check(layer.live_view.visible and layer.live_view.hair.multimesh.instance_count == int(layer.config.strands)*int(layer.config.segments),"Live video restores the depth-tested hair batch")
	layer.set_enabled(false)
	layer.set_mannequin(true)
	check(not view.hair.visible,"Reopening a hairless preview cannot show stale strands")
	layer.free()
	print("MANNEQUIN_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
