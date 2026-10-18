extends SceneTree
const Surface = preload("res://tracking/head_surface.gd")
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	root.size=Vector2i(400,400)
	var live := preload("res://beard/live_strands.gd").new()
	live.size=Vector2(400,400)
	root.add_child(live)
	live.set_frame(Vector2(400,400),false)
	live.show()
	var surface := Surface.new()
	surface.set_reference()
	for i in surface.vertices.size(): surface.vertices[i]=surface.vertices[i]*12+Vector3(200,265,0)
	var config := preload("res://beard/beard_profile.gd").defaults()
	config.merge({"hair_style":"Regular","hair_color":"ff0000ff","hair_tip_color":"ff0000ff"},true)
	live.update_scalp(surface,config,true)
	await frame()
	var portrait := live.viewport.get_texture().get_image()
	portrait.save_png(ProjectSettings.globalize_path("res://../artifacts/scalp-mesh-live.png"))
	var at := Vector2i(-1,-1)
	for y in range(50,240):
		if portrait.get_pixel(200,y).a>.99: at=Vector2i(200,y+5); break
	check(at.x>=0,"Live scalp occupies the expected projected crown")
	if at.x<0: print("SCALP_MESH_RENDER failures=",failures); quit(1); return
	var solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	solver.configure(1,2,{"length":1.0,"collisions":false,"gravity":0.0},PackedFloat32Array([.4,10,10,0,0,0,1,1,0,0,1,1]))
	for depth in [-1000,1000]:
		solver.set_anchors_3d(PackedVector3Array([Vector3(at.x,at.y-10,depth)]),100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
		solver.reset()
		live.update_hair(solver.get_render_buffer(),2,100)
		await frame()
		var color := live.viewport.get_texture().get_image().get_pixelv(at)
		check(color.b>.8 if depth<0 else color.r>.2 and color.b<.2,"Mesh and facial strands share per-pixel depth: %s"%color)
	live.hair.hide()
	var mask := preload("res://tracking/head_occlusion.gd").new()
	var plane := Image.create(4,4,false,Image.FORMAT_RF)
	plane.fill(Color(-100,0,0,1))
	mask.texture=ImageTexture.create_from_image(plane); mask.valid=true; mask.width=1
	live.set_occlusion(mask)
	live.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await frame()
	check(live.viewport.get_texture().get_image().is_invisible(),"Head depth mask occludes the entire far-side mesh")
	mask.enabled=false
	live.set_occlusion(mask)
	live.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await frame()
	check(not live.viewport.get_texture().get_image().is_invisible(),"Occlusion toggle restores the mesh")
	var position := live.scalp.position
	live.set_frame(Vector2(800,600),true)
	check(live.scalp.position.is_equal_approx(position+Vector3(-200,100,0)),"Resolution changes immediately recenter the existing object")
	live.free()
	print("SCALP_MESH_RENDER failures=",failures)
	quit(0 if failures.is_empty() else 1)
