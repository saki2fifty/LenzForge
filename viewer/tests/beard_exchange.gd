extends SceneTree
const Profile = preload("res://beard/beard_profile.gd")
const Library = preload("res://beard/beard_library.gd")
const Groom = preload("res://beard/groom_regions.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var library := Library.new()
	if args[0] == "export":
		var config := Profile.defaults()
		config.merge(Groom.virtual_preset(),true)
		config.hair_style = "Afro"; config.brow_enabled = true; config.chin_extension = .1
		config.mustache_motion = "Static"
		var data := Profile.with_geometry(Profile.document("Blender round trip",config,{}))
		var error := library.write_path(args[1],data)
		print("BEARD_EXPORT error=",error)
		quit(0 if error.is_empty() else 1)
	else:
		var loaded := library.read_path(args[1])
		if not loaded.error.is_empty(): print(loaded.error); quit(1); return
		if not loaded.data.strands["0"].has("guide") or not is_equal_approx(float(loaded.data.strands["0"].root_width),3.2):
			print("Blender edits were not preserved"); quit(1); return
		if not loaded.data.strands.has("hair:0") or not loaded.data.strands.has("brow:0") or loaded.data.settings.mustache_motion != "Static":
			print("Regional hair edits or motion settings were lost"); quit(1); return
		if not loaded.data.settings.virtual_enabled or not is_equal_approx(float(loaded.data.settings.crown_height),.42):
			print("Virtual head fitting was lost"); quit(1); return
		if not is_equal_approx(float(loaded.data.strands["hair:0"].root_width),4.5):
			print("Scalp curve edit was not preserved"); quit(1); return
		var layer = load("res://beard/beard_layer.gd").new()
		root.add_child(layer)
		layer.apply_document(loaded.data)
		layer.set_enabled(true)
		layer.set_mannequin(true)
		for i in 120: layer._process(1.0/60)
		var valid: bool = layer.last_error.is_empty()
		for value in layer.simulator.get_render_buffer(): valid = valid and is_finite(value)
		layer.free()
		print("BEARD_BLENDER_ROUNDTRIP valid=",valid)
		quit(0 if valid else 1)
