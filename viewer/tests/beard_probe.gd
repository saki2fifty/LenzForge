extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Library = preload("res://beard/beard_library.gd")
const Layer = preload("res://beard/beard_layer.gd")
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := Profile.defaults()
	var data := Profile.document("Test beard", config, {"0": {"length": 1.5, "root_width": 4.0}})
	check(Profile.validate(data).is_empty(), "Default profile must validate")
	for key in Profile.LIMITS:
		var invalid := data.duplicate(true)
		invalid.settings[key] = INF
		check(not Profile.validate(invalid).is_empty(), "Reject non-finite " + key)
	var invalid := data.duplicate(true)
	invalid.settings.strands = 100000
	check(not Profile.validate(invalid).is_empty(), "Bound strand allocation")
	invalid = data.duplicate(true); invalid.strands["-1"] = {}
	check(not Profile.validate(invalid).is_empty(), "Reject negative strand IDs")
	invalid = data.duplicate(true); invalid.settings.root_color = "not a color"
	check(not Profile.validate(invalid).is_empty(), "Validate colors")
	invalid = data.duplicate(true); invalid.settings.preserve_shape = "yes"
	check(not Profile.validate(invalid).is_empty(), "Validate shape preservation switch")
	check(Profile.anchors(config) == Profile.anchors(config), "Seeded roots must be repeatable")
	var custom := data.duplicate(true)
	custom.strands["0"]["guide"] = [[0,0],[.2,.3],[0,.7]]
	check(Profile.validate(custom).is_empty(), "Custom guide validates")
	var guide_steps := Profile.strand_steps(config,custom.strands,0)
	var guide_length := 0.0
	for step in guide_steps: guide_length += step.length()
	check(is_equal_approx(guide_length,1.0), "Custom curve resampling preserves normalized arc length")
	var exported := Profile.with_geometry(custom)
	check(exported.geometry.guides.size() == int(config.strands), "Export neutral Blender curves")
	check(exported.geometry.guides[0].points.size() == int(config.segments)+1, "Export all curve control points")
	for style in Profile.STYLES:
		var preset := Profile.defaults(style)
		for anchor in Profile.anchors(preset):
			var w: Vector3 = anchor.weights
			check(is_equal_approx(w.x+w.y+w.z, 1.0) and w.x >= 0 and w.y >= 0 and w.z >= 0, "Barycentric root bounds")
	var library := Library.new()
	library.directory = ProjectSettings.globalize_path("res://../artifacts/beard-test-%d" % Time.get_ticks_usec())
	var saved := library.save_model(data, "abcdef")
	check(saved.error.is_empty(), "Save beard: " + saved.error)
	check(library.list_models().size() == 1, "List saved model")
	var loaded := library.load_model("abcdef")
	if not loaded.error.is_empty():
		print("BEARD_PROBE load error: ",loaded.error)
		quit(1)
		return
	check(loaded.error.is_empty() and loaded.data.strands["0"].root_width == 4, "Round-trip strand overrides")
	data.name = "Renamed"
	check(library.save_model(data, "abcdef").error.is_empty(), "Atomically overwrite existing model")
	check(library.load_model("abcdef").data.name == "Renamed", "Save updates model name")
	check(not library.save_model(data, "../outside").error.is_empty(), "Reject unsafe save ID")
	check(not library.delete_model("../outside").is_empty(), "Reject unsafe delete ID")
	check(library.delete_model("abcdef").is_empty() and library.list_models().is_empty(), "Delete library model")
	# Largest supported export must remain readable after detailed curve edits.
	var dense := Profile.document("Dense edited beard", Profile.defaults(), {})
	dense.settings.strands = 1024; dense.settings.segments = 16
	var dense_guide: Array = []
	for i in 65: dense_guide.append([sin(float(i)/64*TAU)*.1,float(i)/64])
	for i in 1024: dense.strands[str(i)] = {"guide":dense_guide, "length":3.0}
	var dense_export := Profile.with_geometry(dense)
	check(library.save_model(dense_export,"fedcba").error.is_empty(), "Save maximum-size edited export")
	check(library.load_model("fedcba").error.is_empty(), "Read maximum-size edited export")
	library.delete_model("fedcba")
	var solver = ClassDB.instantiate("BeardSimulator")
	var attributes := PackedFloat32Array([1, 4, 0, 0, 1, .3, .1, 1, .3, .1, .1, 1])
	config.gravity = 0; config.wind = 0; config.turbulence = 0; config.stiffness = 0; config.collisions = false
	check(solver.configure(1, 8, config, attributes), "Configure native solver")
	check(solver.set_anchors(PackedVector2Array([Vector2(100,100)]), 200, Vector2.DOWN, Vector2.ZERO, Vector2.ONE), "Set root")
	var rest: PackedVector2Array = solver.get_strand_points(0)
	for i in 120: solver.advance(1.0/60)
	var settled: PackedVector2Array = solver.get_strand_points(0)
	check(rest[-1].distance_to(settled[-1]) < .001, "Zero-force strand must remain at rest")
	config.wind = 4
	solver.configure(1, 8, config, attributes)
	for i in 120: solver.advance(1.0/60)
	var windy: PackedVector2Array = solver.get_strand_points(0)
	check(windy[-1].x > rest[-1].x + 1, "Wind must move the strand")
	check(windy[0].is_equal_approx(Vector2(100,100)), "Root must stay pinned")
	check(solver.get_max_length_error() < .001, "Constrain segment lengths")
	config.wind = 0; config.gravity = 8; config.preserve_shape = true
	solver.configure(1, 8, config, attributes)
	solver.set_anchors(PackedVector2Array([Vector2(600,300)]), 200, Vector2.RIGHT, Vector2.ZERO, Vector2.ONE)
	config.preserve_shape = false
	solver.configure(1, 8, config, attributes)
	for i in 120: solver.advance(1.0/60)
	check(solver.get_strand_points(0)[-1].y > 305, "Gravity must sag a horizontal strand")
	check(not solver.configure(1025, 8, config, attributes), "Bound native allocation")
	check(not solver.set_anchors(PackedVector2Array([Vector2(NAN,0)]), 200, Vector2.DOWN, Vector2.ZERO, Vector2.ONE), "Reject invalid anchors")
	solver.advance(1000)
	for point in solver.get_strand_points(0): check(point.is_finite(), "Bound catch-up after a stall")
	config.collisions = true
	solver.configure(1, 8, config, attributes)
	solver.set_anchors(PackedVector2Array([Vector2(100,100)]), 200, Vector2.DOWN, Vector2(100,140), Vector2(20,10))
	for i in 30: solver.advance(1.0/60)
	for point in solver.get_strand_points(0):
		check(((point-Vector2(100,140))/Vector2(20,10)).length() >= .999, "Mouth collision excludes points")
	var buffer: PackedFloat32Array = solver.get_render_buffer()
	check(buffer.size() == 8*16, "Packed instance layout")
	for value in buffer: check(is_finite(value), "Finite render buffer")
	attributes[0] = 0
	solver.configure(1, 8, config, attributes)
	solver.advance(1.0/60)
	check(solver.get_render_buffer()[11] == 0, "Hidden strand has zero alpha")
	var layer := Layer.new()
	layer.size = Vector2(640,480)
	root.add_child(layer)
	layer.set_enabled(true)
	layer.set_mannequin(true)
	layer._process(1.0/60)
	check(layer.roots.size() == 256 and layer.drawing.visible, "Offline preview attaches all strands")
	# Include the actual lip collider: a still face must not keep hair jittering.
	for i in 1200: layer.simulator.advance(1.0/120)
	var calm_tips := PackedVector2Array()
	for i in 256: calm_tips.append(layer.simulator.get_strand_points(i)[-1])
	var largest_drift := 0.0
	for tick in 120:
		layer.simulator.advance(1.0/120)
		for i in 256:
			largest_drift = maxf(largest_drift,calm_tips[i].distance_to(layer.simulator.get_strand_points(i)[-1]))
	check(largest_drift < .5, "Stationary full beard must settle with mouth collision: %f px" % largest_drift)
	layer.selected_strand = 3
	layer.set_strand_setting("length", 2.0)
	check(layer.overrides["3"].length == 2.0 and layer.config.length == .45, "Individual edit preserves global settings")
	layer.apply_document(custom)
	check(layer.last_error.is_empty(), "Custom curves reach the native solver")
	var legacy := custom.duplicate(true)
	legacy.settings.erase("preserve_shape")
	layer.apply_document(legacy)
	check(not layer.config.preserve_shape, "Existing documents default to free-hanging physics")
	layer.apply_document(dense)
	check(layer.last_error.is_empty(), "Maximum strand length includes regional length factors")
	layer.apply_document(custom)
	layer.set_mirror(false)
	var plain: Vector2 = layer._screen(layer.roots[0])
	layer.set_mirror(true)
	var reflected: Vector2 = layer._screen(layer.roots[0])
	check(is_equal_approx(plain.x+reflected.x,layer.size.x) and is_equal_approx(plain.y,reflected.y), "Mirror uses the same letterboxed frame as video")
	layer.size = Vector2(1280,960)
	layer._update_transform()
	check(layer._screen(layer.roots[0]).is_equal_approx(reflected*2), "Resize preserves face attachment")
	layer.set_mannequin(false)
	layer.set_face(Profile.mannequin(), Vector2(1280,720))
	check(layer._face_live, "Live face attachment")
	layer.clear_face()
	check(not layer.is_processing() and not layer.drawing.visible, "Face loss pauses physics and hides beard")
	layer.set_face(Profile.mannequin(), Vector2(1280,720))
	layer.set_enabled(false)
	check(not layer.is_processing(), "Hidden beard has no simulation work")
	layer.free()
	print("BEARD_PROBE failures=", failures)
	quit(0 if failures.is_empty() else 1)
