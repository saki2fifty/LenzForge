extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const PROJECTION = Transform3D(Basis(Vector3.RIGHT,Vector3.DOWN,Vector3.FORWARD),Vector3.ZERO)
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)

func fixture() -> RefCounted:
	var solver: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config := Profile.defaults()
	config.merge({"length":1.0,"gravity":3.0,"wind":0.0,"damping":.025,"collisions":false,"preserve_shape":false},true)
	var data := PackedFloat32Array()
	for i in 4: data.append_array(PackedFloat32Array([.8,3,1,0,1,.3,.1,1,.3,.1,.1,1]))
	check(solver.configure(4,8,config,data),"Configure clip fixture")
	check(solver.set_anchors_3d(PackedVector3Array([Vector3(80,10,-10),Vector3(80,30,20),Vector3(110,15,-5),Vector3(140,20,-8)]),
		100,Vector3.DOWN,Vector3.RIGHT,Vector2.ZERO,Vector2.ONE),"Initialize clip fixture")
	return solver

func perform(solver: RefCounted, a := Vector2(60,50), b := Vector2(160,70), vertices := PackedVector3Array(), indices := PackedInt32Array()) -> Dictionary:
	return solver.clip_line(a,b,vertices,indices,Transform3D.IDENTITY,PROJECTION,1.0)

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var solver := fixture()
	var hidden: PackedVector3Array = solver.get_strand_points_3d(1)
	var result := perform(solver)
	check(result.get("cuts",[]).size()==3,"Blade cuts nearest visible strand at each crossing")
	check(solver.get_strand_points_3d(1)==hidden,"Fully hidden rear strand stays untouched")
	var fractions := []
	for edit in result.get("cuts",[]):
		var points: PackedVector3Array = solver.get_strand_points_3d(edit.index)
		check(points.size()==9,"Shortened strands retain all eight segments")
		check(absf(points[-1].y-(50+(points[-1].x-60)*.2))<.002,"Each tip lands on the sloped blade")
		check(points[0].y=={0:10,2:15,3:20}[int(edit.index)],"Root remains pinned")
		fractions.append(snappedf(float(edit.fraction),.001))
	check(fractions.size()==3 and fractions[0]!=fractions[1] and fractions[1]!=fractions[2],"Lengths vary by each strand's actual intersection")
	check(solver.get_clipping_count()==3,"Every cut creates one detached piece")
	var debris: PackedFloat32Array = solver.get_clippings_buffer(PROJECTION)
	var y_before := debris[7]
	for i in 24: solver.advance(1.0/120)
	var falling: PackedFloat32Array = solver.get_clippings_buffer(PROJECTION)
	check(falling[7]>y_before+3,"Detached roots are free and fall under gravity")
	for i in 300: solver.advance(1.0/120)
	check(solver.get_clipping_count()==0 and solver.get_clippings_buffer(PROJECTION).is_empty(),"Expired pieces release physics and render data")
	var reverse := fixture()
	var reverse_result := perform(reverse,Vector2(160,70),Vector2(60,50))
	check(reverse_result.cuts.size()==3,"Reversing stroke direction keeps the root-connected side")
	for i in [0,2,3]:
		var points: PackedVector3Array = reverse.get_strand_points_3d(i)
		check(absf(points[-1].y-(50+(points[-1].x-60)*.2))<.002,"Reversed stroke has the same cut plane")
	var blocked := fixture()
	var shield := PackedVector3Array([Vector3(60,0,-40),Vector3(100,0,-40),Vector3(100,100,-40),Vector3(60,100,-40)])
	var blocked_result := perform(blocked,Vector2(60,50),Vector2(160,70),shield,PackedInt32Array([0,1,2,0,2,3]))
	check(blocked_result.cuts.size()==2,"Solid head occludes front and back hair behind its surface")
	check(blocked.get_strand_points_3d(0)[-1].y==90,"Hidden head-side strand retains its full length")
	check(perform(blocked,Vector2(NAN,0)).is_empty(),"Reject invalid strokes atomically")
	check(perform(blocked,Vector2.ONE,Vector2.ONE).is_empty(),"Click without a line cannot cut")
	check(perform(blocked,Vector2.ZERO,Vector2(100,0),shield,PackedInt32Array([0,1,99])).is_empty(),"Reject invalid mesh indices")
	var peel := fixture()
	perform(peel)
	var behind := perform(peel,Vector2(60,54),Vector2(160,74))
	check(behind.cuts.size()==1 and int(behind.cuts[0].index)==1,"A later lower stroke reaches the newly exposed rear layer")
	var bulk: RefCounted = ClassDB.instantiate("BeardSimulator")
	var config := Profile.defaults()
	config.merge({"length":1.0,"collisions":false},true)
	var attributes := PackedFloat32Array()
	var roots := PackedVector3Array()
	for i in 2048:
		attributes.append_array(PackedFloat32Array([.8,.1,.1,0,1,1,1,1,1,1,1,1]))
		roots.append(Vector3(i+1,10,0))
	bulk.configure(2048,16,config,attributes)
	bulk.set_anchors_3d(roots,100,Vector3(0,1,0),Vector3.RIGHT,Vector2.ZERO,Vector2.ONE)
	for height in [50,40]:
		var batch := perform(bulk,Vector2(0,height),Vector2(2049,height))
		check(batch.cuts.size()==2048,"Maximum-density cut retains every crossing")
		check(bulk.get_clipping_count()==2048,"Repeated maximum cuts cannot grow the fragment pool")
	bulk.clear_clippings()
	check(bulk.get_clippings_buffer(PROJECTION).is_empty(),"Explicit cleanup releases a full fragment pool")
	var studio = load("res://studio.tscn").instantiate()
	studio.persist_settings = false
	studio.backend_url = "http://127.0.0.1:9"
	root.add_child(studio)
	var layer: Control = studio.beard
	var tool: Control = layer.clippers
	check(studio.quick_toolbar.buttons.clippers.disabled,"Toolbar clippers start greyed out in camera mode")
	layer.set_settings({"strands":512,"segments":8,"mustache_enabled":false,"gravity":3.0,"length":.6,"wind":0.0})
	layer.set_mannequin(true)
	layer.set_enabled(true)
	await process_frame
	await process_frame
	studio.quick_toolbar.buttons.clippers.button_pressed = true
	check(tool.active and not studio.quick_toolbar.buttons.clippers.disabled,"Toolbar activates clippers in 3D")
	layer.simulator.reset()
	var before: Dictionary = layer.get_document()
	var bottom := -INF
	for i in layer.attachment.size(): bottom = maxf(bottom,layer.simulator.get_strand_points_3d(i)[-1].y)
	var a: Vector2 = layer._screen(Vector2(100,bottom-40))
	var b: Vector2 = layer._screen(Vector2(1180,bottom-70))
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = a
	layer._gui_input(press)
	var motion := InputEventMouseMotion.new(); motion.button_mask = MOUSE_BUTTON_MASK_LEFT; motion.position = b
	layer._gui_input(motion)
	check(tool.dragging and tool.start==a and tool.finish==b,"Drag exposes explicit start and finish")
	var paused: PackedVector3Array = layer.simulator.get_strand_points_3d(0)
	layer._process(.1)
	check(layer.simulator.get_strand_points_3d(0)==paused,"Hair holds still while aiming the blade")
	press.pressed = false; press.position = b
	layer._gui_input(press)
	check(not tool.dragging and tool.last_count>0,"Release commits the visible haircut")
	check(Profile.validate(layer.get_document()).is_empty(),"Cut lengths, colors and guides are valid saved edits")
	check(layer.simulator.get_render_buffer().size()==512*8*16,"Cut does not change strand or segment counts")
	var saved: Dictionary = layer.get_document()
	var actual := {}
	for id in layer.overrides:
		var index := int(id)
		var points: PackedVector3Array = layer.simulator.get_strand_points_3d(index)
		var length := 0.0
		for j in range(1,points.size()): length += points[j].distance_to(points[j-1])
		actual[id] = length
	tool.undo()
	check(layer.get_document()==before and layer.simulator.get_clipping_count()==0,"Undo restores the previous saved look and removes fragments")
	layer.apply_document(saved)
	layer.simulator.reset()
	for id in actual:
		var points: PackedVector3Array = layer.simulator.get_strand_points_3d(int(id))
		var length := 0.0
		for j in range(1,points.size()): length += points[j].distance_to(points[j-1])
		check(absf(length-actual[id])<1.0,"Saved cut restores its retained length")
	layer.set_mannequin(false)
	check(studio.quick_toolbar.buttons.clippers.disabled and not tool.active and layer.simulator.get_clipping_count()==0,"Leaving 3D cancels the tool and cleans fragments")
	print("CLIPPERS cuts=",saved.strands.size()," commit_ms=",tool.last_cut_ms," failures=",failures)
	quit(0 if failures.is_empty() else 1)
