extends SceneTree
const Layer = preload("res://beard/beard_layer.gd")
const Surface = preload("res://tracking/head_surface.gd")
const Mannequin = preload("res://mannequin/mannequin_view.gd")
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)

func _initialize() -> void: _run.call_deferred()

func check_order(layer: Control) -> void:
	var positions: PackedVector3Array = layer.surface.math.sample(layer.surface.neutral_vertices(),layer.root_bindings.indices,layer.root_bindings.weights)
	var last_y := INF
	var seen := {}
	for slot in layer.render_order.size():
		var id: int = layer.render_order[slot]
		check(not seen.has(id),"Every strand appears exactly once")
		seen[id] = true
		if layer.attachment[slot].region in ["beard","mustache"]:
			check(layer.attachment[id].region in ["beard","mustache"],"Only facial slots participate in facial layering")
			check(positions[id].y <= last_y,"Higher fitted facial roots draw after lower measured/virtual roots")
			last_y = positions[id].y
		else: check(id == slot,"Scalp and brow ordering is retained")

func _run() -> void:
	var layer := Layer.new()
	root.add_child(layer)
	layer.set_settings({"strands":64,"brow_enabled":true,"brow_count":16,"hair_style":"Regular","hair_count":32})
	layer.set_enabled(true)
	check_order(layer)
	var original_order: PackedInt32Array = layer.render_order.duplicate()
	for yaw in [-80,0,80]:
		var rotation := Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.BACK,.4)
		var face := PackedVector2Array()
		var depth := PackedFloat32Array()
		for p in Surface.canonical_points():
			var q: Vector3 = rotation*p*20+Vector3(640,360,0)
			face.append(Vector2(q.x/1280,q.y/720)); depth.append(q.z/1280)
		layer.set_face(face,Vector2(1280,720),depth)
		layer.set_process(false)
		layer.set_mirror(yaw < 0)
		check(layer.render_order == original_order,"Turning, tilting and mirroring cannot shuffle layers")
	layer.set_setting("root_color","cc8844ff")
	layer.set_setting("mustache_wind",2.0)
	check(layer.render_order == original_order,"Color and force edits retain the cached order")
	layer.selected_strand = 0
	layer.set_strand_setting("anchor","face:10")
	check_order(layer)
	check(layer.render_order[63] == 0 and layer.selected_key() == "0","Moving a root updates its layer while selection retains the stable ID")
	layer.set_strand_setting("anchor",Surface.id_for(layer.root_bindings,1))
	check_order(layer)
	check(layer.get_document().strands["0"].anchor.begins_with("virtual:"),"Virtual landmark overrides remain attached to the original strand ID")
	layer.free()

	var physics: RefCounted = ClassDB.instantiate("BeardSimulator")
	var attributes := PackedFloat32Array([.4,12,12,0,1,0,0,1,1,0,0,1, .4,12,12,0,0,0,1,1,0,0,1,1])
	check(physics.configure(2,2,{"length":1.0,"collisions":false,"gravity":0.0},attributes),"Configure colored overlap fixture")
	physics.set_anchors_3d(PackedVector3Array([Vector3(70,60,10),Vector3(70,80,-10)]),300,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	var upper: PackedVector3Array = physics.get_strand_points_3d(0)
	var lower: PackedVector3Array = physics.get_strand_points_3d(1)
	check(physics.set_render_order(PackedInt32Array([1,0])),"Accept a complete layer permutation")
	var buffer: PackedFloat32Array = physics.get_render_buffer()
	check(buffer[10] == 1 and buffer[40] == 1,"Output places blue lower strand first, red upper strand last")
	check(upper == physics.get_strand_points_3d(0) and lower == physics.get_strand_points_3d(1),"Layering preserves physical positions and indexed editing")
	for invalid in [PackedInt32Array([0]),PackedInt32Array([0,0]),PackedInt32Array([-1,0]),PackedInt32Array([0,2])]:
		check(not physics.set_render_order(invalid),"Reject malformed layer permutations")
		check(physics.get_render_buffer() == buffer,"Rejected layer changes are atomic")
	if "--render" in OS.get_cmdline_user_args(): await render_layers(physics)
	check(physics.configure(1,2,{"collisions":false},attributes.slice(0,12)),"Resize layered solver")
	physics.set_anchors(PackedVector2Array([Vector2(70,60)]),300,Vector2.DOWN,Vector2.ZERO,Vector2.ONE)
	check(physics.get_render_buffer().size() == 32,"Resizing resets the render permutation safely")
	print("STRAND_LAYERING failures=",failures)
	quit(0 if failures.is_empty() else 1)

func render_layers(physics: RefCounted) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(200,220)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var drawing := MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true; mesh.use_custom_data = true
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	mesh.mesh = quad; mesh.instance_count = 4
	mesh.buffer = physics.get_render_buffer()
	drawing.multimesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://beard/strands.gdshader")
	material.set_shader_parameter("frame_width",200.0)
	material.set_shader_parameter("video_extent",Vector2(200,220))
	var plane := Image.create(200,220,false,Image.FORMAT_RF); plane.fill(Color(0,0,0,1))
	material.set_shader_parameter("head_depth",ImageTexture.create_from_image(plane))
	drawing.material = material
	viewport.add_child(drawing)
	for mirrored in [false,true]:
		drawing.transform = Transform2D(Vector2(-1 if mirrored else 1,0),Vector2(0,1),Vector2(200 if mirrored else 0,0))
		material.set_shader_parameter("occlusion_mirror",mirrored)
		for occluded in [false,true]:
			material.set_shader_parameter("occlusion_enabled",occluded)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var color := image.get_pixel(130 if mirrored else 70,120)
			check(color.b > .9 and color.r < .1 if occluded else color.r > .9 and color.b < .1,
				"2D upper root overlaps lower; true head depth still wins (mirror %s, occlusion %s)"%[mirrored,occluded])
			image.save_png(ProjectSettings.globalize_path("res://../artifacts/strand-layers-%s-%s.png"%[mirrored,occluded]))
	viewport.free()
	# The mannequin consumes the same ordered buffer. Keep its true depth test.
	var mannequin := Mannequin.new()
	mannequin.size = Vector2(640,360)
	root.add_child(mannequin)
	mannequin.set_active(true)
	mannequin.pivot.hide()
	physics.set_anchors_3d(PackedVector3Array([Vector3(640,200,0),Vector3(640,230,0)]),300,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	physics.reset()
	mannequin.update_hair(physics.get_render_buffer(),2,true)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := mannequin.viewport.get_texture().get_image()
	var pixel := Vector2i(Vector2(image.get_size())*Vector2(.5,270.0/720))
	var color := image.get_pixelv(pixel)
	check(color.r > .9 and color.b < .1,"3D mannequin uses the same upper-over-lower layering")
	mannequin.pivot.show()
	mannequin.request_frame()
	await process_frame
	await RenderingServer.frame_post_draw
	image = mannequin.viewport.get_texture().get_image()
	color = image.get_pixelv(pixel)
	check(not (color.r > .9 and color.b < .1),"Mannequin head still occludes hair behind it")
	mannequin.free()
