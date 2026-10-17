extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Surface = preload("res://tracking/head_surface.gd")
const Groom = preload("res://beard/surface_groom.gd")
var failures: Array[String] = []
func check(value: bool, detail: String) -> void:
	if not value and not detail in failures: failures.append(detail)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var layer = load("res://beard/beard_layer.gd").new()
	root.add_child(layer)
	layer.set_enabled(true); layer.set_mannequin(true)
	for shape in [Vector2(.65,.2),Vector2(1.0,.4),Vector2(.3,.1)]:
		layer.mannequin_view.set_surface_shape(shape.x,shape.y)
		for preset in [{},{"lower_root_depth":.7,"sideburn_width":.2},{"beard_virtual_roots":false,"virtual_enabled":true,"side_back":.8,"chin_back":.5,"ear_reach":.6}]:
			var config := Profile.defaults()
			config.merge(preset,true)
			layer.apply_document(Profile.document("Boundary",config,{}))
			var surface: RefCounted = layer.mannequin_view.surface
			var positions: PackedVector3Array = surface.sample(layer.root_bindings)
			var edge := maxf(surface.vertices[234].z,surface.vertices[454].z)
			var virtual_count := 0
			for i in layer.attachment.size():
				if layer.attachment[i].region != "beard": continue
				check(positions[i].z <= edge+.0001,"Automatic beard roots stop at the measured ear-side landmarks for every head fit and coverage mode")
				if layer.root_bindings.indices[i*3] >= 478: virtual_count += 1
			if layer.config.beard_virtual_roots: check(virtual_count > 40,"Lower virtual roots remain available in front of the rear boundary")
	# A head-fit change alone must refresh the cap, without a density/style edit.
	layer.apply_document(Profile.document("Fit",Profile.defaults(),{}))
	layer.mannequin_view.set_surface_shape(1.1,.3)
	var roots: PackedVector3Array = layer.mannequin_view.surface.sample(layer.root_bindings)
	for i in layer.attachment.size():
		if layer.attachment[i].region == "beard": check(roots[i].z <= 2.436,"Changing head depth alone preserves the measured rear boundary")
	layer.selected_strand = 0
	layer.set_strand_setting("anchor","virtual:2200:250000:250000")
	check(layer.mannequin_view.root_positions[0].distance_to(layer.mannequin_view.surface.resolve("virtual:2200:250000:250000").position*Vector3(1,-1,-1)) < .0001,"Explicit landmark placement remains available")
	layer.free()
	print("BEARD_BOUNDARY failures=",failures)
	quit(0 if failures.is_empty() else 1)
