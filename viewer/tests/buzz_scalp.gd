extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Surface = preload("res://tracking/head_surface.gd")
const PROJECTION = Transform3D(Basis(Vector3.RIGHT,Vector3.DOWN,Vector3.FORWARD),Vector3.ZERO)
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)
func fixture() -> RefCounted:
	var solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config := Profile.defaults()
	config.merge({"length":1.0,"collisions":false},true)
	var data := PackedFloat32Array()
	for i in 4: data.append_array(PackedFloat32Array([.8,3,1,0,1,.3,.1,1,.3,.1,.1,1]))
	solver.configure(4,8,config,data)
	solver.set_anchors_3d(PackedVector3Array([Vector3(80,10,-10),Vector3(80,30,20),Vector3(110,15,-5),Vector3(140,20,-8)]),100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	return solver
func buzz(solver: RefCounted, a: Vector2, b: Vector2, width := 8.0, shield := PackedVector3Array(), triangles := PackedInt32Array()) -> Dictionary:
	return solver.clip_buzz(a,b,width,shield,triangles,Transform3D.IDENTITY,PROJECTION,1.0)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var solver := fixture()
	var rear: PackedVector3Array = solver.get_strand_points_3d(1)
	var touch := buzz(solver,Vector2(80,50),Vector2(80,50))
	check(touch.get("cuts",[]).size()==1,"Stationary teeth cut on contact without requiring a drag line")
	check(solver.get_strand_points_3d(1)==rear,"Buzz preserves fully hidden rear hair")
	check(absf(solver.get_strand_points_3d(0)[-1].y-48)<1,"Blade contact includes the strand's visible width")
	check(buzz(fixture(),Vector2(75.8,50),Vector2(75.8,50)).get("cuts",[]).size()==1,"Blade catches the edge of a thick hair without crossing its center")
	var sweep := fixture()
	check(buzz(sweep,Vector2(60,60),Vector2(160,60)).cuts.size()==3,"Fast sweep crosses every visible intervening strand")
	var shield := PackedVector3Array([Vector3(60,0,-40),Vector3(100,0,-40),Vector3(100,100,-40),Vector3(60,100,-40)])
	check(buzz(fixture(),Vector2(60,60),Vector2(160,60),8,shield,PackedInt32Array([0,1,2,0,2,3])).cuts.size()==2,"Buzz respects solid bust occlusion")
	check(buzz(solver,Vector2(NAN,0),Vector2.ZERO).is_empty(),"Reject nonfinite buzz coordinates")
	check(buzz(solver,Vector2.ZERO,Vector2.ONE,INF).is_empty(),"Reject invalid blade widths")
	var spatial_solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	var spatial_config := Profile.defaults()
	spatial_config.merge({"length":1.0,"collisions":false},true)
	var steps := PackedVector3Array()
	for j in 8: steps.append(Vector3(0,.1,.075))
	check(spatial_solver.configure(1,8,spatial_config,PackedFloat32Array([.8,3,1,0,1,1,1,1,1,1,1,1]),PackedVector2Array(),PackedFloat32Array([2,.8,0,0]),steps),"Configure spatial rest guide")
	spatial_solver.set_anchors_3d(PackedVector3Array([Vector3(80,10,-50)]),100,Vector3(0,1,0),Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	var spatial_cut := buzz(spatial_solver,Vector2(80,50),Vector2(80,50))
	check(spatial_cut.get("cuts",[]).size()==1 and spatial_cut.cuts[0].has("guide3d"),"Spatial cuts retain depth in their saved guide")
	if spatial_cut.get("cuts",[]).size()==1:
		check(Profile._guide_valid(spatial_cut.cuts[0].guide3d,3),"Cut spatial guide validates for autosave and library")
		var cut_tip: Vector3 = spatial_solver.get_strand_points_3d(0)[-1]
		spatial_solver.reset()
		check(spatial_solver.get_strand_points_3d(0)[-1].distance_to(cut_tip)<.001,"Spatial cut keeps its length and depth after reset")
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings=false; studio.backend_url="http://127.0.0.1:9"
	root.add_child(studio)
	var layer: Control = studio.beard
	var tool: Control = layer.clippers
	check(studio.quick_toolbar.clipper_menu.disabled,"Both halves of Clippers are disabled outside the mannequin")
	layer.set_mannequin(true); layer.set_enabled(true)
	await process_frame
	await process_frame
	layer.set_process(false)
	studio.quick_toolbar.clipper_menu.get_popup().id_pressed.emit(1)
	check(tool.mode=="Buzz" and tool.active,"Dropdown selects and activates Buzz")
	layer.simulator.reset()
	var bottom := -INF
	for i in layer.attachment.size(): bottom=maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
	var before: Dictionary = layer.get_document()
	var motion := InputEventMouseMotion.new()
	motion.position=layer._screen(Vector2(300,bottom-60))
	layer._gui_input(motion)
	tool._process(1.0/60)
	check(layer.get_document()==before and not tool.buzzing,"Hovering the clipper image never cuts")
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=motion.position
	layer._gui_input(press)
	for x in [500,700,980]:
		motion.position=layer._screen(Vector2(x,bottom-60)); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		layer._gui_input(motion); tool._process(1.0/60)
	press.pressed=false; press.position=motion.position
	layer._gui_input(press)
	check(not tool.buzzing and not tool.is_processing(),"Release stops the motor and its sampling loop")
	check(tool.stroke_count>0 and tool.history.size()==1,"A held stroke cuts hair and creates exactly one undo entry")
	check(Profile.validate(layer.get_document()).is_empty(),"Buzz produces valid persistent strand edits")
	var after: Dictionary = layer.get_document()
	tool._process(.1)
	check(layer.get_document()==after,"No cutting after release")
	tool.undo()
	check(layer.get_document()==before,"Undo restores the complete Buzz stroke")
	layer.set_settings({"hair_style":"Regular","hair_count":512,"hair_motion":"Static","brow_enabled":false})
	layer.set_process(false)
	layer.simulator.reset()
	var vertices: PackedVector3Array = layer.mannequin_view.surface.build_reference()
	var roots: PackedVector3Array = layer.mannequin_view.surface.math.sample(vertices,layer.root_bindings.indices,layer.root_bindings.weights)
	var center := (vertices[234]+vertices[454])*.5
	var width := vertices[234].distance_to(vertices[454])
	var coverage := {"left":0,"right":0,"back":0,"crown":0}
	var spatial := 0
	for i in layer.attachment.size():
		if layer.attachment[i].region!="hair": continue
		var p := (roots[i]-center)/width
		if p.x<-.35: coverage.left+=1
		if p.x>.35: coverage.right+=1
		if p.z>.4: coverage.back+=1
		if p.y<-.55: coverage.crown+=1
		if p.z<-.3: check(p.y<-.42,"Scalp roots stay above the frontal hairline")
		var points: PackedVector3Array = layer.simulator.get_strand_points_3d(i)
		if absf(points[-1].z-points[0].z)>.5: spatial+=1
		check(points.size()==9,"Scalp uses the selected segment budget")
	for region in coverage: check(coverage[region]>8,"Scalp coverage includes "+region)
	check(spatial>100,"Styled scalp guides bend in depth rather than a frontal plane")
	var exported := Profile.with_geometry(layer.get_document())
	var g: Array = exported.geometry.guides[-1].points
	check(absf(g[0][2]-g[-1][2])>.0001,"Exports retain spatial scalp guides")
	layer.set_mannequin(false)
	check(not tool.buzzing and not tool.active and studio.quick_toolbar.clipper_menu.disabled,"Leaving the mannequin disarms Buzz")
	print("BUZZ_SCALP coverage=",coverage," spatial=",spatial," failures=",failures)
	quit(0 if failures.is_empty() else 1)
