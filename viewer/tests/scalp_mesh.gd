extends SceneTree
const Surface = preload("res://tracking/head_surface.gd")
const Scalp = preload("res://beard/scalp_mesh.gd")
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var surface := Surface.new()
	var neutral := Surface.canonical_points()
	surface.set_personal_reference(neutral)
	surface.set_reference()
	var scalp := Scalp.new()
	root.add_child(scalp)
	var config := Profile.defaults()
	var reports := []
	for style in Groom.HAIR_STYLES.slice(1):
		config.merge(Groom.hair_preset(style),true)
		scalp.configure(surface,config); scalp.follow(surface)
		check(scalp.mesh is ArrayMesh and scalp.mesh.get_surface_count()==1,"One generated mesh surface for "+style)
		var arrays := scalp.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var sculpted := Scalp.Sculpted.has_style(style)
		var edges := {}
		for p in points: check(p.is_finite(),"Finite "+style+" vertices")
		for n in normals: check(n.is_finite(),"Finite "+style+" normals")
		for i in range(0,indices.size(),3):
			for j in 3:
				var a := indices[i+j]; var b := indices[i+(j+1)%3]
				var edge := Vector2i(mini(a,b),maxi(a,b))
				edges[edge] = edges.get(edge,0)+1
		if sculpted:
			check(arrays[Mesh.ARRAY_TEX_UV].size()==points.size(),"Lock flow UVs preserved for "+style)
			check(points.size()<60000 and indices.size()<300000,"Bounded sculpted geometry for "+style)
		else:
			for count: int in edges.values(): check(count==2,"Closed manifold shell and rim for "+style)
			check(points.size()<20000 and indices.size()<100000,"Bounded mesh geometry for "+style)
		var coverage := {"left":0,"right":0,"back":0,"crown":0}
		var center := (surface.vertices[234]+surface.vertices[454])*.5
		for p in points:
			var q: Vector3 = (Scalp.FLIP*(scalp.transform*p)-center)/surface.width
			if q.x<-.35: coverage.left+=1
			if q.x>.35: coverage.right+=1
			if q.z>.4: coverage.back+=1
			if q.y<-.55: coverage.crown+=1
		for region in coverage:
			if style=="Mohawk" and region in ["left","right"]: continue
			check(coverage[region]>8,style+" covers the "+region)
		reports.append({"style":style,"vertices":points.size(),"triangles":indices.size()/3,"build_ms":scalp.build_ms})
	config.merge(Groom.hair_preset("Long layered"),true)
	scalp.configure(surface,config); scalp.follow(surface)
	var original := PackedVector3Array()
	for p in scalp.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: original.append(Scalp.FLIP*(scalp.transform*p))
	var revision := scalp.revision
	var stable_mesh := scalp.mesh
	var stable_points: PackedVector3Array = stable_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	var timings: Array[float] = []
	for tick in 180:
		var rotation := Basis(Vector3.UP,sin(tick*.08)*2.4)*Basis(Vector3.RIGHT,sin(tick*.13)*.4)
		var expression := neutral.duplicate()
		for i in [10,151,9,338,109,159,145,386,374]: expression[i].y += sin(tick*.3)*1.5
		for i in [152,377,400,13,14]: expression[i].y += sin(tick*.4)*2
		var face := PackedVector2Array(); var depth := PackedFloat32Array()
		var translation := Vector3(640,360,10)
		for p in expression:
			var q: Vector3 = rotation*p*23+translation
			face.append(Vector2(q.x/1280,q.y/720)); depth.append(q.z/1280)
		surface.update(face,depth,Vector2(1280,720))
		var began := Time.get_ticks_usec()
		scalp.configure(surface,config); scalp.follow(surface)
		timings.append((Time.get_ticks_usec()-began)/1000.0)
		for i in range(0,original.size(),23):
			var actual: Vector3 = Scalp.FLIP*(scalp.transform*stable_points[i])
			worst = maxf(worst,actual.distance_to(rotation*original[i]*23+translation))
	check(worst<.005,"Mesh follows immediate pose without blink/jaw deformation: %f"%worst)
	check(scalp.mesh==stable_mesh and scalp.revision==revision,"Turns and expressions reuse the mesh")
	config.hair_color="f042aeff"
	scalp.configure(surface,config)
	check(scalp.mesh==stable_mesh,"Color edits do not rebuild geometry")
	config.hair_count=32; config.segments=2
	scalp.configure(surface,config)
	check(scalp.mesh==stable_mesh,"Legacy strand count and facial segments never change the scalp mesh")
	config.hair_length=.6
	scalp.configure(surface,config)
	check(scalp.revision==revision+1 and scalp.mesh!=stable_mesh,"Shape edits rebuild the mesh once")
	surface.crown=.3
	surface.update(PackedVector2Array(),PackedFloat32Array(),Vector2(1280,720))
	surface.set_reference()
	scalp.configure(surface,config)
	check(scalp.revision==revision+2,"Head calibration changes refit the mesh")
	var layer = load("res://beard/beard_layer.gd").new()
	root.add_child(layer)
	layer.set_mannequin(true); layer.set_enabled(true); layer.set_process(false)
	for i in 60: layer.simulator.advance(1.0/120)
	var before: PackedFloat32Array = layer.simulator.get_render_buffer()
	layer.set_settings(Groom.hair_preset("Center-parted"))
	check(layer.attachment.size()==int(layer.config.strands),"Scalp allocates no simulated strands")
	check(layer.simulator.get_render_buffer()==before,"Changing hairstyles preserves facial hair physics")
	check(layer.mannequin_view.scalp.visible,"Enabled mesh appears in the mannequin")
	var saved: Dictionary = layer.get_document()
	layer.set_setting("hair_style","None")
	check(layer.mannequin_view.scalp.mesh==null and not layer.mannequin_view.scalp.visible,"None removes the object")
	layer.apply_document(JSON.parse_string(JSON.stringify(saved)))
	check(layer.mannequin_view.scalp.visible and layer.config.hair_style=="Center-parted","Saved looks restore sculpted mesh choice")
	layer.set_enabled(false)
	check(not layer.mannequin_view.scalp.visible,"Master hair toggle hides mesh and strands")
	layer.free(); scalp.free()
	timings.sort()
	var report := {"fixture":"Generated 3D scalp objects, headless CPU. Mesh construction on edits; 180 stable-pose updates. Excludes GPU completion and tracking inference.","styles":reports,"pose_update_ms":{"p50":timings[timings.size()/2],"p95":timings[int(timings.size()*.95)]},"pose_error_pixels":worst,"failures":failures}
	FileAccess.open("res://../artifacts/scalp-mesh.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SCALP_MESH ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
