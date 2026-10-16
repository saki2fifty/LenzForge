extends SceneTree
const Surface = preload("res://tracking/head_surface.gd")
const Extensions = preload("res://tracking/face_extensions.gd")
const Attachment = preload("res://tracking/landmark_attachment.gd")
const Profile = preload("res://beard/beard_profile.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := Extensions.new()
	var surface := Surface.new()
	surface.set_reference()
	var neutral := surface.vertices.duplicate()
	var samples := surface.sample(model.bindings)
	var canonical := Surface.canonical_points()
	# Compare the accelerated nearest search with an exhaustive per-triangle
	# oracle, including distant targets and points on triangle boundaries.
	var targets := PackedVector3Array([Vector3(0,-20,0),Vector3(15,0,0),Vector3(-15,0,0),
		Vector3(0,15,0),Vector3(0,0,30),Vector3(0,0,-30),canonical[10],canonical[152]])
	var fitted := surface.bind_nearest(targets)
	var nearest := surface.sample(fitted)
	var distances := PackedFloat32Array()
	distances.resize(targets.size())
	distances.fill(INF)
	var topology := Surface.topology()
	for i in range(0,topology.size(),3):
		var single: Dictionary = surface.math.bind_nearest(neutral,topology.slice(i,i+3),targets)
		if single.is_empty(): continue
		var points := surface.sample(single)
		for j in points.size(): distances[j] = minf(distances[j],targets[j].distance_to(points[j]))
	for i in targets.size(): check(absf(targets[i].distance_to(nearest[i])-distances[i]) < .0001,"Accelerated fitting agrees with exhaustive nearest-triangle search")
	var object := Attachment.new()
	root.add_child(object)
	object.surface = surface
	var virtual_id: String = model.ids[180]
	var measured_id := "face:152"
	check(not Surface.binding(virtual_id).is_empty(),"Virtual references resolve through the common API")
	for id in [measured_id,virtual_id]:
		object.landmark_id = id
		check(object.position.distance_to(surface.resolve(id).position) < .00001,"3D objects attach to either landmark kind")
	var dims := Vector2(1280,720)
	for yaw in [-135,-90,-60,0,60,90,135,180]:
		var rotation := Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.RIGHT,.2)*Basis(Vector3.BACK,.15)
		var offset := Vector3(640,360,40)
		var face := PackedVector2Array()
		var depth := PackedFloat32Array()
		for p in canonical:
			var q: Vector3 = rotation*p*20+offset
			face.append(Vector2(q.x,q.y)/dims)
			depth.append(q.z/dims.x)
		surface.update(face,depth,dims)
		check(surface.vertices.size() == 1198,"Fixed bounded mesh size independent of guide density")
		for i in 478:
			check(surface.resolve("face:%d"%i).position.distance_to(rotation*canonical[i]*20+offset) < .002,"Measured positions retain their original IDs and coordinates")
		var points := surface.sample(model.bindings)
		for i in points.size():
			check(points[i].distance_to(rotation*samples[i]*20+offset) < .003,"Virtual points follow yaw/pitch/roll, scale and translation")
		check(object.position.distance_to(surface.resolve(virtual_id).position) < .0001,"Objects follow tracking updates without render-frame polling")
		check(absf(object.basis.determinant()-1) < .001,"Attachment orientation remains orthonormal")
	var anchor: Vector3 = surface.resolve(virtual_id).position
	model.configure({"columns":144,"rings":12,"show_points":false,"enabled":false})
	check(surface.resolve(virtual_id).position == anchor,"Density and guide visibility cannot change or orphan an attachment")
	surface.clear()
	check(not object.visible and surface.resolve(virtual_id).is_empty(),"Tracking loss hides attached objects and clears stale data")
	surface.set_reference()
	check(object.visible,"Attached objects recover when tracking resumes")
	var before := surface.resolve(virtual_id)
	surface.head_depth = .9
	surface.crown = .35
	surface.set_reference()
	check(surface.resolve(virtual_id).position.distance_to(before.position) > .1,"Head shape changes deform the same attached surface")
	for id in ["face:-1","face:478","virtual:99999:0:0","virtual:1:-1:0","virtual:1:900000:900000","virtual:1:9223372036854775807:1","nonsense"]:
		check(Surface.binding(id).is_empty(),"Reject malformed or out-of-bounds landmark IDs")
	var broken := PackedVector3Array([Vector3(INF,0,0)])
	check(surface.bind_nearest(broken).is_empty(),"Native fitter rejects nonfinite targets")
	check(surface.math.sample(neutral,PackedInt32Array([-1,0,0]),PackedVector3Array([Vector3.ONE])).is_empty(),"Native sampler rejects invalid indices")
	var layer = load("res://beard/beard_layer.gd").new()
	layer.size = Vector2(800,600)
	root.add_child(layer)
	layer.set_mannequin(true)
	layer.set_enabled(true)
	layer.selected_strand = 0
	for id in [measured_id,virtual_id]:
		layer.set_strand_setting("anchor",id)
		var expected: Vector3 = layer.mannequin_view.surface.resolve(id).position*Vector3(1,-1,-1)
		check(layer.mannequin_view.root_positions[0].distance_to(expected) < .0001,"Hair and objects use exactly the same measured/virtual root position")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(layer.get_document()))
	check(Profile.validate(saved).is_empty() and saved.strands["0"].anchor == virtual_id,"Attachment IDs survive look serialization")
	layer.set_settings({"virtual_columns":48,"virtual_rows":10})
	check(layer.overrides["0"].anchor == virtual_id,"Changing legacy grooming density retains explicit anchors")
	var exported := Profile.with_geometry(saved)
	var root3: Vector3 = layer.mannequin_view.surface.resolve(virtual_id).position/layer.mannequin_view.surface.width
	var exported_root: Array = exported.geometry.guides[0].points[0]
	check(Vector3(exported_root[0],exported_root[1],exported_root[2]).distance_to(root3*Vector3(1,-1,-1)) < .0001,"Exported guides honor the same virtual surface attachment")
	var cached: Dictionary = layer.root_bindings.duplicate(true)
	var strand_before: PackedVector2Array = layer.simulator.get_strand_points(0)
	layer.set_setting("gravity",8.0)
	check(layer.root_bindings == cached,"Force changes reuse existing surface bindings")
	check(layer.simulator.get_strand_points(0) == strand_before,"Force updates preserve current strand positions")
	check(not layer.simulator.set_forces(INF,0,0,.025) and not layer.simulator.set_forces(3,11,0,.025),"Native force update validates bounds")
	layer.apply_document(saved)
	check(layer.mannequin_view.root_positions[0].distance_to(layer.mannequin_view.surface.resolve(virtual_id).position*Vector3(1,-1,-1)) < .0001,"Restored virtual root uses saved surface location")
	layer.set_mannequin(false)
	for yaw in [-90,90]:
		var face := PackedVector2Array()
		var depth := PackedFloat32Array()
		for p in canonical:
			var rotated: Vector3 = Basis(Vector3.UP,deg_to_rad(yaw))*p*20+Vector3(640,360,0)
			face.append(Vector2(rotated.x,rotated.y)/dims)
			depth.append(rotated.z/dims.x)
		layer.set_face(face,dims,depth)
		check(layer._face_live and layer.roots.size() == 512,"Live hair survives exact profile when projected cheek width collapses")
	layer.free()
	object.free()
	print("HEAD_SURFACE_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
