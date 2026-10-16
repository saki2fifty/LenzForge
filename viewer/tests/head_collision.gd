extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Surface = preload("res://tracking/head_surface.gd")
var failures: Array[String] = []
var test_mode := 0
var worst_box := [0.0,0.0,0.0]
var box_rotation := Basis.IDENTITY
var BOX := PackedVector3Array([Vector3(-50,-50,-50),Vector3(50,-50,-50),Vector3(50,50,-50),Vector3(-50,50,-50),
	Vector3(-50,-50,50),Vector3(50,-50,50),Vector3(50,50,50),Vector3(-50,50,50)])
var TRIANGLES := PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5])

func check(condition: bool, message: String) -> void:
	if not condition and not message in failures: failures.append(message)

func solver(enabled := true, mode := 0) -> RefCounted:
	var result: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config := Profile.defaults()
	config.merge({"length":1.2,"gravity":12.0,"wind":6.0,"damping":.045,"collisions":enabled},true)
	check(result.configure(1,8,config,PackedFloat32Array([1,2,1,0,1,0,0,1,0,0,1,1]),
		PackedVector2Array(),PackedFloat32Array([mode,.7,1])),"Configure spatial strand")
	return result

func outside_box(points: PackedVector3Array, shift: Vector3) -> void:
	for j in range(1,points.size()):
		for sample in range(1,9):
			var p := box_rotation.transposed()*(points[j-1].lerp(points[j],sample/8.0)-shift)
			check(p.is_finite(),"Finite collision output")
			worst_box[test_mode] = maxf(worst_box[test_mode],50-maxf(absf(p.x),maxf(absf(p.y),absf(p.z))))
			check(maxf(absf(p.x),maxf(absf(p.y),absf(p.z))) >= 49.99,"Entire links stay outside the solid box mode %d"%test_mode)

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for mode in [0,1,2]:
		test_mode = mode
		var physics := solver(true,mode)
		check(physics.set_head_surface(BOX,TRIANGLES),"Accept collider")
		check(not physics.set_head_surface(BOX,PackedInt32Array([0,1,900])),"Reject malformed collider")
		# Root above the solid volume; gravity pulls down through it and wind
		# pushes sideways. A physical barrier must deflect the strand around it.
		physics.set_anchors_3d(PackedVector3Array([Vector3(0,-65,-25)]),100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
		for tick in 180:
			var shift := Vector3(sin(tick*.07)*20,0,cos(tick*.09)*12)
			box_rotation = Basis(Vector3.UP,sin(tick*.06)*1.2)*Basis(Vector3.RIGHT,sin(tick*.05)*.2)
			var vertices := BOX.duplicate()
			for i in vertices.size(): vertices[i] = box_rotation*vertices[i]+shift
			physics.set_head_surface(vertices,TRIANGLES)
			var anchor := box_rotation*Vector3(0,-65,-25)+shift
			physics.set_anchors_3d(PackedVector3Array([anchor]),100,box_rotation*Vector3.DOWN,box_rotation*Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
			physics.advance(1.0/60)
			var points: PackedVector3Array = physics.get_strand_points_3d(0)
			outside_box(points,shift)
			check(points[0].distance_to(anchor)<.001,"Root stays pinned in three dimensions")
		var points: PackedVector3Array = physics.get_strand_points_3d(0)
		var buffer: PackedFloat32Array = physics.get_render_buffer()
		for j in 8:
			check(is_equal_approx(buffer[j*16+14],points[j].z) and is_equal_approx(buffer[j*16+15],points[j+1].z),
				"Render buffer carries each segment's actual endpoint depths")
	var disabled := solver(false)
	disabled.set_head_surface(BOX,TRIANGLES)
	disabled.set_anchors_3d(PackedVector3Array([Vector3(0,-65,0)]),100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	disabled.advance(1.0/60)
	check(absf(disabled.get_strand_points_3d(0)[2].y)<50,"Collision toggle permits penetration when disabled")
	# Actual shared mannequin mesh, including front/profile/back and every region.
	var layer = load("res://beard/beard_layer.gd").new()
	root.add_child(layer)
	layer.set_settings({"strands":32,"segments":8,"hair_style":"Regular","hair_count":32,"brow_enabled":true,"brow_count":16})
	layer.set_enabled(true)
	layer.set_mannequin(true)
	var worst := 0.0
	for angle in [0,30,60,90,120,150,180,-90,0]:
		layer.mannequin_view.set_pose(angle,15)
		for i in 12: layer.simulator.advance(1.0/60)
		var view = layer.mannequin_view
		var samples := PackedVector3Array()
		for s in layer.roots.size():
			var points: PackedVector3Array = layer.simulator.get_strand_points_3d(s)
			for j in range(1,points.size()):
				for t in [.25,.5,.75,1.0]:
					var p := points[j-1].lerp(points[j],t)
					var world := Vector3((p.x-640)/view.pixels_per_unit(),-(p.y-360)/view.pixels_per_unit()+view.camera.position.y,-p.z/view.pixels_per_unit())
					samples.append((view.pivot.transform.affine_inverse()*world)*Vector3(1,-1,-1))
		var bindings: Dictionary = view.surface.math.bind_nearest(view.surface.vertices,Surface.topology(),samples)
		var nearest: PackedVector3Array = view.surface.math.sample(view.surface.vertices,bindings.indices,bindings.weights)
		for i in samples.size():
			var a: Vector3 = view.surface.vertices[bindings.indices[i*3]]
			var b: Vector3 = view.surface.vertices[bindings.indices[i*3+1]]
			var c: Vector3 = view.surface.vertices[bindings.indices[i*3+2]]
			var normal := (b-a).cross(c-a).normalized()
			worst = maxf(worst,-(samples[i]-nearest[i]).dot(normal))
	check(worst < .03,"Shared head segment penetration stays below 0.03 model units: %f"%worst)
	if "--render" in OS.get_cmdline_user_args():
		root.size = Vector2i(1000,720)
		layer.size = Vector2(1000,720)
		layer.set_settings({"strands":512,"hair_style":"Regular","hair_count":128,"brow_enabled":false})
		for yaw in [0,65,95]:
			layer.mannequin_view.set_pose(yaw,0)
			for i in 180: layer.simulator.advance(1.0/120)
			layer._process(1.0/60)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/head-collision-%d.png"%yaw))
	layer.free()
	print("HEAD_COLLISION worst_box=",worst_box," worst_head_penetration=",worst," failures=",failures)
	quit(0 if failures.is_empty() else 1)
