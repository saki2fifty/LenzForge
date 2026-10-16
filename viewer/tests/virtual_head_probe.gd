extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Head = preload("res://beard/virtual_head.gd")
const Layer = preload("res://beard/beard_layer.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := Profile.defaults()
	config.merge(Groom.virtual_preset(),true)
	config.merge(Groom.hair_preset("Mohawk"),true)
	var anchors := Head.build(config)
	check(anchors.size() == 380 and anchors == Head.build(config),"Bounded deterministic virtual grid")
	var face := Profile.mannequin()
	var dims := Vector2(1280,720)
	var basis := Head.frame(face,dims)
	var points := Head.project(anchors,face,dims,basis)
	var top := INF
	var bottom := -INF
	var left := INF
	var right := -INF
	for i in points.size():
		check(points[i].is_finite(),"Finite virtual landmarks")
		if anchors[i].patch == "scalp": top = minf(top,points[i].y)
		if anchors[i].patch == "chin": bottom = maxf(bottom,points[i].y)
		if anchors[i].patch == "left_side": left = minf(left,points[i].x)
		if anchors[i].patch == "right_side": right = maxf(right,points[i].x)
	check(top < face[10].y*dims.y-basis.width*.4,"Crown points extend above tracked forehead")
	check(bottom > face[152].y*dims.y+basis.width*.17,"Chin points extend below tracked chin")
	check(left < face[234].x*dims.x and right > face[454].x*dims.x,"Side points extend beyond cheek contours")
	var bindings := Profile.all_anchors(config)
	var roots := Groom.root_positions(config,bindings,face,dims,points)
	var bound := 0
	var scalp_min := INF
	var scalp_max := -INF
	for i in bindings.size():
		var b: Dictionary = bindings[i]
		if not b.has("virtual_cell"): continue
		bound += 1
		check(roots[i].distance_to(Head.interpolate(b,points)) < .001,"Hair roots use the displayed virtual surface")
		if b.region == "hair":
			scalp_min = minf(scalp_min,roots[i].y); scalp_max = maxf(scalp_max,roots[i].y)
	check(bound > int(config.hair_count),"Scalp and extended facial roots attach to virtual landmarks")
	check(scalp_max-scalp_min > basis.width*.35,"Mohawk roots span forehead to crown, not a small forehead patch")
	# A known 3D rotation must produce the same projection, including back reach.
	var rotation := Basis(Vector3.BACK,.3)*Basis(Vector3.UP,.6)*Basis(Vector3.RIGHT,-.25)
	var pivot := dims*.5
	var moved := PackedVector2Array()
	var depths := PackedFloat32Array()
	for point in face:
		var local := point*dims-pivot
		var turned := rotation*Vector3(local.x,local.y,0)*1.15
		moved.append((Vector2(turned.x,turned.y)+pivot+Vector2(20,-15))/dims)
		depths.append(turned.z/dims.x)
	var projected := Head.project(anchors,moved,dims,Head.frame(moved,dims,depths))
	for i in anchors.size():
		var a: Dictionary = anchors[i]
		var ids: Vector3i = a.indices
		var w: Vector3 = a.weights
		var local := (face[ids.x]*w.x+face[ids.y]*w.y+face[ids.z]*w.z)*dims-pivot
		var original: Vector3 = Vector3(local.x,local.y,0)+a.offset*float(basis.width)
		var turned: Vector3 = rotation*original*1.15
		check(projected[i].distance_to(Vector2(turned.x,turned.y)+pivot+Vector2(20,-15)) < .003,"Depth-based points follow yaw, pitch, roll, scale, and translation")
	var no_back := config.duplicate(true)
	no_back.side_back = 0.0
	var flat := Head.project(Head.build(no_back),moved,dims,Head.frame(moved,dims,depths))
	check(flat[-1].distance_to(projected[-1]) > 20,"Back reach changes projection during a head turn")
	var malformed := depths.duplicate()
	malformed[152] = INF
	check(not Head.frame(moved,dims,malformed).is_empty(),"Invalid depth falls back to the 2D face")
	check(Head.frame(PackedVector2Array(),dims).is_empty(),"Missing face does not extrapolate stale points")
	var distorted := face.duplicate()
	distorted[152] = Vector2(.5,100)
	check(Head.frame(distorted,dims).is_empty(),"Malformed planar references stop instead of recursively retrying")
	var depth_only := Profile.defaults()
	depth_only.virtual_enabled = true
	var side_bound := false
	for b in Profile.all_anchors(depth_only):
		side_bound = side_bound or b.get("virtual_patch","") in ["left_side","right_side"]
	check(side_bound,"Side depth alone attaches roots to the virtual side regions")
	var layer := Layer.new()
	layer.size = Vector2(640,480)
	root.add_child(layer)
	layer.apply_document(Profile.document("Virtual head",config,{}))
	layer.set_enabled(true)
	layer.set_face(moved,dims,depths)
	check(layer.roots.size() == layer.attachment.size() and not layer.virtual_markers.visible,"Legacy coverage now fits the shared head without a duplicate grid")
	var count := layer.attachment.size()
	layer.set_settings({"virtual_columns":48,"virtual_rows":10})
	check(layer.roots.size() == count and layer.attachment.size() == count,"Increasing virtual density does not add simulated hairs")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(layer.get_document()))
	check(layer.apply_document(saved).is_empty() and layer.roots.size() == count,"Virtual fitting settings survive save/load")
	var export := Profile.with_geometry(saved)
	check(export.geometry.guides.size() == count,"Virtual roots support complete-look export")
	layer.clear_face()
	check(not layer.virtual_markers.visible and layer.virtual_points.is_empty(),"Face loss clears virtual geometry")
	layer.set_face(face,dims)
	layer.set_enabled(false)
	check(not layer.virtual_markers.visible and not layer.is_processing(),"Hiding the look stops its virtual overlay")
	var old := Profile.document("Older look",Profile.defaults(),{})
	for key in ["virtual_enabled","show_virtual_landmarks","virtual_color","virtual_columns","virtual_rows","crown_height","crown_width","crown_back","side_back","chin_back"]: old.settings.erase(key)
	layer.apply_document(old)
	check(not layer.config.virtual_enabled,"Existing looks retain original root placement until enabled")
	layer.free()
	print("VIRTUAL_HEAD_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
