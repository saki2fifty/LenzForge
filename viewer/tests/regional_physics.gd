extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Surface = preload("res://tracking/head_surface.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)

func solver(config: Dictionary) -> RefCounted:
	var physics: RefCounted = ClassDB.instantiate("BeardSimulator")
	var attributes := PackedFloat32Array()
	for i in 2: attributes.append_array(PackedFloat32Array([1,2,.2,0,1,1,1,1,1,1,1,1]))
	check(physics.configure(2,8,config,attributes,PackedVector2Array(),PackedFloat32Array([0,0,0,0,0,0,0,1])),"Configure two force groups")
	physics.set_anchors(PackedVector2Array([Vector2(300,200),Vector2(300,200)]),200,Vector2.DOWN,Vector2.ZERO,Vector2.ONE)
	return physics

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var config := Profile.defaults()
	config.merge({"gravity":3.0,"wind":3.0,"turbulence":0.0,"damping":.025,"collisions":false,
		"mustache_gravity":3.0,"mustache_wind":3.0,"mustache_turbulence":0.0,"mustache_damping":.025,"mustache_collisions":false},true)
	for key in {"gravity":10.0,"wind":-4.0,"turbulence":4.0,"damping":.5}:
		for prefix in ["","mustache_"]:
			var baseline := solver(config)
			var changed := solver(config)
			var edited := config.duplicate()
			edited[prefix+key] = {"gravity":10.0,"wind":-4.0,"turbulence":4.0,"damping":.5}[key]
			for i in 20: baseline.advance(1.0/120); changed.advance(1.0/120)
			var before: PackedVector3Array = changed.get_strand_points_3d(1)
			if prefix.is_empty(): changed.set_forces(edited.gravity,edited.wind,edited.turbulence,edited.damping)
			else: changed.set_mustache_forces(edited.mustache_gravity,edited.mustache_wind,edited.mustache_turbulence,edited.mustache_damping,false)
			check(changed.get_strand_points_3d(1) == before,"Force editing preserves motion")
			for i in 60: baseline.advance(1.0/120); changed.advance(1.0/120)
			var affected := 0 if prefix.is_empty() else 1
			check(changed.get_strand_points_3d(1-affected) == baseline.get_strand_points_3d(1-affected),"Independent "+prefix+key+" leaves other region unchanged")
			check(changed.get_strand_points_3d(affected)[-1].distance_to(baseline.get_strand_points_3d(affected)[-1]) > .01,"Selected force affects "+prefix+key)
	var native := solver(config)
	check(not native.set_mustache_forces(INF,0,0,.025,true),"Reject nonfinite regional forces")
	check(not native.set_mustache_forces(3,11,0,.025,true),"Reject out-of-range regional forces")
	var box := PackedVector3Array([Vector3(-50,-50,-50),Vector3(50,-50,-50),Vector3(50,50,-50),Vector3(-50,50,-50),
		Vector3(-50,-50,50),Vector3(50,-50,50),Vector3(50,50,50),Vector3(-50,50,50)])
	var triangles := PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5])
	for mustache_only in [false,true]:
		var collision_config := config.duplicate()
		collision_config.collisions = not mustache_only
		collision_config.mustache_collisions = mustache_only
		var physics := solver(collision_config)
		physics.set_head_surface(box,triangles)
		physics.set_anchors_3d(PackedVector3Array([Vector3(0,-65,0),Vector3(0,-65,0)]),200,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
		physics.reset()
		var protected := 1 if mustache_only else 0
		var point: Vector3 = physics.get_strand_points_3d(protected)[2]
		check(maxf(absf(point.x),maxf(absf(point.y),absf(point.z))) >= 50,"Selected region collides with head")
		point = physics.get_strand_points_3d(1-protected)[2]
		check(maxf(absf(point.x),maxf(absf(point.y),absf(point.z))) < 50,"Other region collision can remain disabled")
	var legacy := config.duplicate()
	for key in ["gravity","wind","turbulence","damping","collisions","variation"]: legacy.erase("mustache_"+key)
	var migrated := Groom.normalized(legacy)
	for key in ["gravity","wind","turbulence","damping","collisions","variation"]:
		check(migrated["mustache_"+key] == legacy[key],"Old look retains former shared "+key)
	var anchors := Profile.all_anchors(config)
	var varied := config.duplicate()
	varied.variation = .8
	var other := Profile.all_anchors(varied)
	for i in anchors.size():
		if anchors[i].region == "mustache": check(anchors[i] == other[i],"Beard variation cannot change the mustache")
	# Default automatic lower coverage uses the same resolvable virtual IDs as objects.
	var layer = load("res://beard/beard_layer.gd").new()
	root.add_child(layer)
	layer.set_settings({"hair_style":"Regular","hair_count":32,"brow_enabled":true,"brow_count":16})
	layer.set_enabled(true); layer.set_mannequin(true)
	var lower := 0
	var sideburns := Vector2i.ZERO
	var beard_count := 0
	var low_x := INF
	var high_x := -INF
	var depth_range := Vector2(INF,-INF)
	var representatives := {}
	for i in layer.attachment.size():
		var a: Dictionary = layer.attachment[i]
		representatives[a.region] = i
		if a.region != "beard": continue
		beard_count += 1
		if a.has("sideburn_target"):
			var side_id := Surface.id_for(layer.root_bindings,i)
			var side_point: Vector3 = layer.mannequin_view.surface.resolve(side_id).position
			check(side_point.distance_to(layer.mannequin_view.root_positions[i]*Vector3(1,-1,-1)) < .0001,"Sideburns bind to the shared head")
			check(absf(side_point.x) > 5 and side_point.z < 2,"Sideburns sit along the ear-front sides: %s"%side_point)
			check(a.sideburn_target.z <= .005+layer.config.sideburn_width,"Sideburn width limits backward wrap")
			if side_point.x < 0: sideburns.x += 1
			else: sideburns.y += 1
		if not a.has("lower_surface"): continue
		lower += 1
		var id := Surface.id_for(layer.root_bindings,i)
		var point: Vector3 = layer.mannequin_view.surface.resolve(id).position
		check(point.distance_to(layer.mannequin_view.root_positions[i]*Vector3(1,-1,-1)) < .0001,"Automatic lower roots resolve on the shared head")
		check(point.y > 0,"Lower roots stay below the cheek center")
		low_x = minf(low_x,point.x); high_x = maxf(high_x,point.x)
		depth_range.x = minf(depth_range.x,point.z); depth_range.y = maxf(depth_range.y,point.z)
	check(lower+sideburns.x+sideburns.y > beard_count*.35 and lower+sideburns.x+sideburns.y < beard_count*.55,"Default coverage shares roots between measured face and virtual surface")
	check(sideburns.x > 12 and sideburns.y > 12,"Default sideburn coverage reaches both ears within the strand budget")
	check(low_x < -3 and high_x > 3 and depth_range.y-depth_range.x > 2,"Virtual beard roots cover both sides and real depth")
	var neutral_roots: PackedVector3Array = layer.mannequin_view.root_positions.duplicate()
	layer.set_mannequin(false)
	for yaw in [-90,-45,0,45,90]:
		var rotation := Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.RIGHT,.15)
		var face := PackedVector2Array()
		var depth := PackedFloat32Array()
		for p in Surface.canonical_points():
			var point := rotation*p*20+Vector3(640,360,0)
			face.append(Vector2(point.x/1280,point.y/720)); depth.append(point.z/1280)
		layer.set_face(face,Vector2(1280,720),depth)
		for i in layer.attachment.size():
			if not layer.attachment[i].has("lower_surface") and not layer.attachment[i].has("sideburn_target"): continue
			var expected := rotation*(neutral_roots[i]*Vector3(1,-1,-1))*20+Vector3(640,360,0)
			check(Vector3(layer.roots[i].x,layer.roots[i].y,layer.root_depth[i]*1280).distance_to(expected) < .003,"Automatic lower roots follow live head rotation")
	layer.set_mannequin(true)
	var bindings: Dictionary = layer.root_bindings.duplicate(true)
	layer.set_setting("mustache_wind",-4.0)
	check(layer.root_bindings == bindings,"Regional force changes reuse cached root bindings")
	for region in representatives:
		layer.selected_strand = representatives[region]
		for id in ["face:152","virtual:1000:250000:250000"]:
			layer.set_strand_setting("anchor",id)
			for yaw in [-90,0,90]:
				layer.mannequin_view.set_pose(yaw,10)
				check(layer.mannequin_view.root_positions[layer.selected_strand].distance_to(layer.mannequin_view.surface.resolve(id).position*Vector3(1,-1,-1)) < .0001,"Any region attaches to measured/virtual landmarks through head turns")
	layer.free()
	print("REGIONAL_PHYSICS failures=",failures)
	quit(0 if failures.is_empty() else 1)
