extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Layer = preload("res://beard/beard_layer.gd")
const Library = preload("res://beard/beard_library.gd")
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := Profile.defaults()
	for key in Groom.NUMBERS:
		var invalid := config.duplicate(true)
		invalid[key] = INF
		check(not Profile.validate(Profile.document("Invalid",invalid,{})).is_empty(),"Validate " + key)
	config.chin_extension = .15; config.jaw_expansion = .1; config.ear_reach = .1; config.sideburn_height = 1.0; config.coverage_fill = 1.0
	config.brow_enabled = true; config.hair_style = "Afro"
	var bindings := Profile.all_anchors(config)
	check(bindings == Profile.all_anchors(config),"Root generation is deterministic")
	check(bindings.size() == int(config.strands)+int(config.brow_count)+int(config.hair_count),"Every enabled region has its own density")
	var face := Profile.mannequin()
	var dims := Vector2(1280,720)
	var roots := Groom.root_positions(config,bindings,face,dims)
	var width := ((face[454]-face[234])*dims).length()
	var below := false
	var beyond := false
	var raised := false
	for i in bindings.size():
		check(roots[i].is_finite(),"Root must be finite")
		if bindings[i].region != "beard": continue
		below = below or roots[i].y > face[152].y*dims.y+width*.02
		beyond = beyond or roots[i].x < face[234].x*dims.x or roots[i].x > face[454].x*dims.x
		raised = raised or roots[i].y < face[234].y*dims.y
	check(below and beyond and raised,"Offset roots extend below the chin, toward ears, and up the sideburns")
	var wide := config.duplicate(true)
	wide.mustache_width = 1.7; wide.mustache_thickness = 2.0; wide.mustache_lift = .05
	var wide_roots := Groom.root_positions(wide,bindings,face,dims)
	var lip := face[0]*dims
	var mustache_index := -1
	for i in bindings.size():
		if bindings[i].region != "mustache": continue
		mustache_index = i
		check(absf(wide_roots[i].x-lip.x-(roots[i].x-lip.x)*1.7) < .001,"Mustache width expands coverage")
		check(absf(wide_roots[i].y-lip.y-((roots[i].y-lip.y)*2-width*.05)) < .001,"Mustache thickness and lift move roots")
	check(mustache_index >= 0,"Full beard includes mustache roots")
	var pivot := dims*.5
	var moved_face := PackedVector2Array()
	for point in face: moved_face.append(((point*dims-pivot).rotated(.6)*1.2+pivot+Vector2(35,-20))/dims)
	var moved := Groom.root_positions(config,bindings,moved_face,dims)
	for i in roots.size():
		check(moved[i].distance_to((roots[i]-pivot).rotated(.6)*1.2+pivot+Vector2(35,-20)) < .001,"Generated anchors follow scale, roll, and translation")
	var old := Profile.document("Version one",Profile.defaults(),{})
	old.version = 1
	for key in Groom.defaults("Full beard"): old.settings.erase(key)
	old.settings.root_color = "1256abff"; old.settings.tip_color = "abcdef12"
	old.settings.root_width = 5.0; old.settings.length = .8
	old.settings.preserve_shape = true
	check(Profile.validate(old).is_empty(),"Load v1 documents without new settings")
	var layer := Layer.new()
	layer.size = Vector2(640,480)
	root.add_child(layer)
	layer.apply_document(old)
	check(layer.config.hair_style == "None" and not layer.config.brow_enabled,"Migration leaves new optional regions disabled")
	check(layer.config.mustache_color == old.settings.root_color and layer.config.mustache_tip_color == old.settings.tip_color,"Old mustache colors survive migration")
	check(layer.config.mustache_motion == "Styled" and layer.config.mustache_root_width == 5.0,"Old mustache motion and taper survive migration")
	for b in layer.attachment:
		if b.region == "mustache": check(is_equal_approx(Groom.strand_settings(layer.config,b).length,.8*float(b.length)),"Old mustache length survives migration")
	old.settings.length = .02
	layer.apply_document(old)
	check(Profile.validate(layer.get_document()).is_empty(),"Minimum legacy length migrates to a valid editable document")
	layer.apply_document(Profile.document("Combined",config,{"hair:0":{"length":1.4},"brow:0":{"root_width":3}}))
	layer.set_enabled(true); layer.set_mannequin(true)
	check(layer.last_error.is_empty() and layer.mannequin_view.dots.generated.multimesh.instance_count > 100,"Combined groom and generated root overlay initialize")
	# Translation/scale/roll assertions compare the same planar live fixture.
	# The offline mannequin now uses an actual anatomical 3D reference mesh.
	layer.set_mannequin(false)
	layer.set_face(face,dims)
	layer.simulator.advance(1.0/120)
	var brow_index := int(config.strands)
	var static_before: PackedVector2Array = layer.simulator.get_strand_points(brow_index)
	layer.set_settings({"wind":8.0,"gravity":12.0})
	for i in 120: layer.simulator.advance(1.0/120)
	check(layer.simulator.get_strand_points(brow_index) == static_before,"Static eyebrows ignore gravity and wind")
	layer.set_setting("brow_motion","Free")
	for i in 120: layer.simulator.advance(1.0/120)
	check(layer.simulator.get_strand_points(brow_index)[-1].distance_to(static_before[-1]) > 1,"Moving eyebrows respond to forces")
	layer.set_settings({"brow_motion":"Static","mustache_motion":"Static"})
	layer.simulator.advance(1.0/120)
	var rigid_brow: PackedVector2Array = layer.simulator.get_strand_points(brow_index)
	var rigid_mustache: PackedVector2Array = layer.simulator.get_strand_points(mustache_index)
	for i in 60: layer.simulator.advance(1.0/120)
	check(layer.simulator.get_strand_points(mustache_index) == rigid_mustache,"Static mustache ignores forces")
	layer.set_mannequin(false)
	layer.set_face(moved_face,dims)
	layer.simulator.advance(1.0/120)
	var turned_brow: PackedVector2Array = layer.simulator.get_strand_points(brow_index)
	for j in rigid_brow.size():
		check(turned_brow[j].distance_to((rigid_brow[j]-pivot).rotated(.6)*1.2+pivot+Vector2(35,-20)) < .01,"Static shapes follow face translation, scale, and roll")
	layer.set_setting("mustache_motion","Free")
	for i in 60: layer.simulator.advance(1.0/120)
	var moved_mustache: PackedVector2Array = layer.simulator.get_strand_points(mustache_index)
	var expected_tip := (rigid_mustache[-1]-pivot).rotated(.6)*1.2+pivot+Vector2(35,-20)
	check(moved_mustache[-1].distance_to(expected_tip) > 1,"Free mustache responds to forces")
	layer.set_mannequin(true)
	layer.set_setting("brow_enabled",false)
	check(layer.overrides.has("brow:0") and layer.overrides.has("hair:0"),"Toggling a region preserves its edits")
	layer.set_setting("brow_enabled",true)
	var exported := Profile.with_geometry(layer.get_document())
	check(exported.geometry.guides.size() == bindings.size(),"Export includes every enabled region")
	check(exported.geometry.guides[int(config.strands)].index == "brow:0","Interchange uses stable region IDs")
	check(Profile.validate(JSON.parse_string(JSON.stringify(exported))).is_empty(),"v2 export round trip")
	for style in Groom.HAIR_STYLES.slice(1):
		layer.set_settings(Groom.hair_preset(style))
		layer.simulator.reset()
		for i in 30: layer.simulator.advance(1.0/60)
		for value in layer.simulator.get_render_buffer(): check(is_finite(value),"Finite " + style + " geometry")
	layer.set_settings({"strands":1024,"brow_count":256,"hair_count":768,"segments":16})
	check(layer.attachment.size() == 2048 and layer.last_error.is_empty(),"Maximum combined allocation is bounded at 2048")
	layer._process(1.0/60)
	check(layer.mannequin_view.hair.multimesh.instance_count == 2048*16,"One 3D draw batch contains all regions")
	var dense: Dictionary = layer.get_document()
	var guide: Array = []
	for j in 65: guide.append([sin(j*.12)*.06,j/64.0])
	for b in layer.attachment:
		dense.strands[b.id] = {"guide":guide,"root_width":3.2,"tip_width":.2,"root_color":"abcdef12","tip_color":"123456ff","length":1.0}
	var largest := Profile.with_geometry(dense)
	var library := Library.new()
	var path := ProjectSettings.globalize_path("res://../artifacts/groom-maximum.json")
	check(library.write_path(path,largest).is_empty(),"Maximum groom with dense custom guides saves")
	check(library.read_path(path).error.is_empty(),"Maximum exported groom fits the file limit and reloads")
	var native = ClassDB.instantiate("BeardSimulator")
	var attributes := PackedFloat32Array([1,2,.2,0,1,1,1,1,1,1,1,1])
	for bad in [PackedFloat32Array([0]),PackedFloat32Array([3,.5,0]),PackedFloat32Array([1,INF,0]),PackedFloat32Array([1,.5,NAN]),PackedFloat32Array([.5,.5,0])]:
		check(not native.configure(1,8,Profile.defaults(),attributes,PackedVector2Array(),bad),"Native region options reject malformed values")
	layer.free()
	print("GROOM_PROBE failures=",failures)
	quit(0 if failures.is_empty() else 1)
