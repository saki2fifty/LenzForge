extends SceneTree
const Occlusion = preload("res://tracking/head_occlusion.gd")
const Head = preload("res://mannequin/head_model.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raster: RefCounted = ClassDB.instantiate("FaceOccluder")
	var vertices := PackedVector3Array([Vector3(0,0,.5),Vector3(100,0,.5),Vector3(0,100,.5),Vector3(0,0,-.2),Vector3(100,0,-.2),Vector3(0,100,-.2)])
	var image: Image = raster.rasterize(vertices,PackedInt32Array([0,1,2,5,4,3]),Vector2(100,100),100)
	check(is_equal_approx(image.get_pixel(10,10).r,-.2),"Nearest triangle wins regardless of winding/order")
	check(image.get_pixel(90,90).r > 1e9,"No surface outside triangles")
	check(raster.rasterize(vertices,PackedInt32Array([0,1,999]),Vector2(100,100),100) == null,"Reject invalid mesh indices")
	var reference := Head.reference_points()
	var counts := []
	var timings := []
	var occlusion := Occlusion.new()
	for yaw in [-65,0,65]:
		var points := PackedVector2Array()
		var depth := PackedFloat32Array()
		for p in reference:
			var rotated: Vector3 = Basis(Vector3.UP,deg_to_rad(yaw))*p
			points.append(Vector2(320+rotated.x*18,320-rotated.y*18)/640)
			depth.append(-rotated.z*18/640)
		occlusion.update(points,depth,Vector2(640,640))
		check(occlusion.valid,"Depth map produced at yaw %d"%yaw)
		var map: Image = occlusion.depth_image
		var hidden := 0
		for i in 468:
			var at := Vector2i(points[i]*Vector2(map.get_size()))
			if depth[i] > map.get_pixelv(at).r+occlusion.width*occlusion.tolerance: hidden += 1
		counts.append(hidden)
		timings.append(occlusion.update_ms)
	check(counts[0] > counts[1]+20 and counts[2] > counts[1]+20,"Turns hide far-side face points")
	check(counts[1] < 80,"Frontal measured surface remains visible")
	# Check actual shader fragments, including mirrored coordinate mapping.
	if "--render" in OS.get_cmdline_user_args():
		root.size = Vector2i(400,200)
		var canvas := Control.new()
		canvas.size = Vector2(400,200)
		root.add_child(canvas)
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_2D
		mesh.use_custom_data = true
		var quad := QuadMesh.new(); quad.size = Vector2.ONE; mesh.mesh = quad
		mesh.instance_count = 2
		for i in 2:
			mesh.set_instance_transform_2d(i,Transform2D(Vector2(40,0),Vector2(0,40),Vector2(100+i*200,100)))
			mesh.set_instance_custom_data(i,Color(-.2 if i == 0 else .2,0,0,0))
		var dots := MultiMeshInstance2D.new(); dots.multimesh = mesh
		var material := ShaderMaterial.new(); material.shader = load("res://landmarks.gdshader"); dots.material = material
		canvas.add_child(dots)
		var plane := Image.create(384,192,false,Image.FORMAT_RF); plane.fill(Color(0,0,0,1))
		occlusion.texture = ImageTexture.create_from_image(plane); occlusion.valid = true
		occlusion.apply(material,canvas,Vector2(400,200),false)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		check(rendered.get_pixel(100,100).g > .7,"Front point visible through fragment test")
		check(rendered.get_pixel(300,100).g < .3,"Back point hidden by fragment test")
		rendered.save_png(ProjectSettings.globalize_path("res://../artifacts/occlusion-fragments.png"))
		# A strand may be hidden over the head but visible beyond its silhouette.
		for y in plane.get_height():
			for x in plane.get_width(): plane.set_pixel(x,y,Color(0 if x < 192 else 1e10,0,0,1))
		occlusion.texture = ImageTexture.create_from_image(plane)
		mesh.set_instance_custom_data(0,Color(.2,0,0,0))
		var strands := MultiMeshInstance2D.new()
		var strand_mesh := MultiMesh.new()
		strand_mesh.transform_format = MultiMesh.TRANSFORM_2D
		strand_mesh.use_custom_data = true
		strand_mesh.mesh = quad
		strand_mesh.instance_count = 1
		strand_mesh.set_instance_transform_2d(0,Transform2D(Vector2(0,12),Vector2(300,0),Vector2(200,150)))
		strand_mesh.set_instance_custom_data(0,Color(1,1,80,80))
		strands.multimesh = strand_mesh
		var strand_material := ShaderMaterial.new(); strand_material.shader = load("res://beard/strands.gdshader")
		strand_material.set_shader_parameter("frame_width",400.0)
		strands.material = strand_material; canvas.add_child(strands)
		for mirrored in [false,true]:
			occlusion.apply(material,canvas,Vector2(400,200),mirrored)
			occlusion.apply(strand_material,canvas,Vector2(400,200),mirrored)
			await process_frame
			await RenderingServer.frame_post_draw
			rendered = root.get_texture().get_image()
			var visible_x := 100 if mirrored else 300
			var hidden_x := 300 if mirrored else 100
			check(rendered.get_pixel(visible_x,100).g > .7 and rendered.get_pixel(hidden_x,100).g < .3,"Point mask coordinates and mirror %s"%mirrored)
			check(rendered.get_pixel(visible_x,150).g > .7 and rendered.get_pixel(hidden_x,150).g < .3,"Strand clips per fragment, mirror %s"%mirrored)
		# A single segment crosses the surface in depth: each endpoint has its
		# own depth, rather than assigning the root's depth to the whole strand.
		plane.fill(Color(0,0,0,1))
		occlusion.texture = ImageTexture.create_from_image(plane)
		strand_mesh.set_instance_custom_data(0,Color(1,1,-80,80))
		occlusion.apply(strand_material,canvas,Vector2(400,200),false)
		await process_frame
		await RenderingServer.frame_post_draw
		rendered = root.get_texture().get_image()
		rendered.save_png(ProjectSettings.globalize_path("res://../artifacts/collision-depth-gradient.png"))
		check(rendered.get_pixel(100,150).g > .7 and rendered.get_pixel(300,150).g < .3,"Segment endpoint depth interpolates across the actual rendered quad")
	print("OCCLUSION hidden=",counts," update_ms=",timings," failures=",failures)
	quit(0 if failures.is_empty() else 1)
