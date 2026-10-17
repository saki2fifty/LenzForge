extends Control
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const MannequinView = preload("res://mannequin/mannequin_view.gd")
const SurfaceGroom = preload("res://beard/surface_groom.gd")
var surface := preload("res://tracking/head_surface.gd").new()
var external_surface := false
var extension_model: RefCounted
var root_bindings: Dictionary = {}
var render_order := PackedInt32Array()
var _binding_config: Dictionary = {}
var _binding_overrides: Dictionary = {}
var _binding_shape := Vector4(-1,-1,-1,-1)
signal changed
var guides_visible := true
signal preview_face_changed
signal strand_selected(index: int)
var config := Profile.defaults()
var overrides: Dictionary = {}
var model_name := "My beard"
var enabled := false
var mannequin := false
var edit_strands := false
var selected_strand := -1
var mirror := true
var video_size := Vector2(1280, 720)
var simulator: RefCounted
var live_view := preload("res://beard/live_strands.gd").new()
var _video_transform := Transform2D.IDENTITY
var root_markers := MultiMeshInstance2D.new()
var virtual_markers := MultiMeshInstance2D.new()
var virtual_anchors: Array = []
var virtual_points := PackedVector2Array()
var face_depth := PackedFloat32Array()
var root_depth := PackedFloat32Array()
var virtual_depth := PackedFloat32Array()
var occlusion: RefCounted
var selection := Control.new()
var attachment: Array = []
var generated_indices := PackedInt32Array()
var roots := PackedVector2Array()
var face := PackedVector2Array()
var face_seen_at := 0
var update_ms := 0.0
var last_error := ""
var _face_live := false
var mannequin_view := MannequinView.new()
var mannequin_toolbar := HBoxContainer.new()

func _init() -> void:
	# Own child nodes even when controls are built outside the tree in tests.
	mannequin_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mannequin_view)
	mannequin_view.pose_changed.connect(_set_demo_face)
	live_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(live_view)
	add_child(root_markers)
	add_child(virtual_markers)
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.draw.connect(_draw_selection)
	add_child(selection)
	mannequin_toolbar.position = Vector2(12,12)
	mannequin_toolbar.add_theme_constant_override("separation",8)
	add_child(mannequin_toolbar)
	for entry in [["Front",0],["Side",90],["Back",180]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func(): mannequin_view.set_pose(entry[1],0,mannequin_view.zoom))
		mannequin_toolbar.add_child(button)
	var reset := Button.new()
	reset.text = "Reset view"
	reset.pressed.connect(mannequin_view.reset_view)
	mannequin_toolbar.add_child(reset)
	var hint := Label.new()
	hint.text = "Drag to rotate · Wheel to zoom"
	hint.add_theme_font_size_override("font_size",12)
	mannequin_toolbar.add_child(hint)
	mannequin_toolbar.hide()

func _ready() -> void:
	process_priority = 10 # Readers and matched landmark attachments run first.
	set_process(false)
	if not ClassDB.class_exists("BeardSimulator"):
		last_error = "Run Setup.ps1 -SkipInstall to build beard physics."
		return
	simulator = ClassDB.instantiate("BeardSimulator")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var marker_mesh := MultiMesh.new()
	marker_mesh.transform_format = MultiMesh.TRANSFORM_2D
	marker_mesh.use_custom_data = true
	marker_mesh.mesh = quad
	root_markers.multimesh = marker_mesh
	var marker_material := ShaderMaterial.new()
	marker_material.shader = preload("res://landmarks.gdshader")
	root_markers.material = marker_material
	root_markers.hide()
	var virtual_mesh := MultiMesh.new()
	virtual_mesh.transform_format = MultiMesh.TRANSFORM_2D
	virtual_mesh.use_custom_data = true
	virtual_mesh.mesh = quad
	virtual_markers.multimesh = virtual_mesh
	virtual_markers.material = marker_material.duplicate()
	virtual_markers.hide()
	resized.connect(_update_transform)
	_rebuild()
	_update_transform()
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func apply_document(data: Dictionary) -> String:
	var error := Profile.validate(data)
	if not error.is_empty(): return error
	config = Groom.normalized(data.settings)
	config["preserve_shape"] = bool(config.get("preserve_shape", false))
	for key in ["strands", "segments", "seed"]: config[key] = int(config[key])
	overrides = data.get("strands", {}).duplicate(true)
	model_name = data.name
	selected_strand = -1
	_rebuild()
	changed.emit()
	return ""

func get_document() -> Dictionary:
	return Profile.document(model_name, config, overrides)

func set_setting(key: String, value: Variant) -> void:
	set_settings({key:value})

func set_settings(values: Dictionary) -> void:
	var candidate := get_document()
	candidate.settings.merge(values,true)
	# Validate counts before using them to prune edits; bad settings stay atomic.
	if not Profile.validate(Profile.document(model_name,candidate.settings,{})).is_empty(): return
	for id in candidate.strands.keys():
		if not Groom.valid_id(id,candidate.settings): candidate.strands.erase(id)
	if not Profile.validate(candidate).is_empty(): return
	config = candidate.settings
	overrides = candidate.strands
	var forces_only := simulator != null and not root_bindings.is_empty()
	for key in values:
		if key not in ["gravity","wind","turbulence","damping","mustache_gravity","mustache_wind","mustache_turbulence","mustache_damping"]: forces_only = false
	if forces_only:
		simulator.set_forces(config.gravity,config.wind,config.turbulence,config.damping)
		simulator.set_mustache_forces(config.mustache_gravity,config.mustache_wind,config.mustache_turbulence,config.mustache_damping,config.mustache_collisions)
		changed.emit()
		return
	_rebuild()
	changed.emit()

func set_strand_setting(key: String, value: Variant) -> void:
	if selected_strand < 0: return
	var candidate := get_document()
	var id := selected_key()
	if not candidate.strands.has(id): candidate.strands[id] = {}
	candidate.strands[id][key] = value
	if key == "curl": candidate.strands[id].erase("guide")
	if not Profile.validate(candidate).is_empty(): return
	overrides = candidate.strands
	_rebuild()
	changed.emit()

func reset_selected() -> void:
	overrides.erase(selected_key())
	_rebuild()
	changed.emit()

func selected_key() -> String:
	return attachment[selected_strand].id if selected_strand >= 0 and selected_strand < attachment.size() else ""

func selected_defaults() -> Dictionary:
	return Groom.strand_settings(config,attachment[selected_strand]) if selected_strand >= 0 and selected_strand < attachment.size() else config

func set_enabled(value: bool) -> void:
	enabled = value
	set_process(enabled and simulator != null)
	if not enabled: live_view.hide(); root_markers.hide(); virtual_markers.hide()
	elif mannequin: _set_demo_face()
	elif _face_live: _attach()
	if mannequin:
		mannequin_view.update_hair(PackedFloat32Array(),int(config.segments),enabled)
		_update_root_markers()
		_update_virtual_markers()
	queue_redraw()
	selection.queue_redraw()
	changed.emit()

func set_mannequin(value: bool) -> void:
	mannequin = value
	clear_face()
	mannequin_view.set_active(value)
	mannequin_toolbar.visible = value and size.x >= 320
	if mannequin: mannequin_view.set_pose(mannequin_view.yaw,mannequin_view.pitch,mannequin_view.zoom)
	_update_mouse()
	queue_redraw()
	changed.emit()

func set_edit_strands(value: bool) -> void:
	edit_strands = value
	_update_mouse()
	queue_redraw()
	selection.queue_redraw()

func _update_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if edit_strands or mannequin else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_CROSS if edit_strands else Control.CURSOR_MOVE

func set_mirror(value: bool) -> void:
	mirror = value
	mannequin_view.set_mirror(value)
	_update_transform()

func set_face(points: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array = PackedFloat32Array()) -> void:
	if mannequin: return
	if points.size() < 455: clear_face(); return
	var dimensions_changed := dimensions != video_size
	face = points
	face_depth = depth
	video_size = dimensions
	face_seen_at = Time.get_ticks_msec()
	_face_live = true
	set_process(enabled and simulator != null)
	if enabled: _attach()
	if dimensions_changed: _update_transform()

func clear_face() -> void:
	_face_live = false
	if not external_surface: surface.clear()
	face_seen_at = 0
	live_view.hide()
	root_markers.hide()
	virtual_markers.hide()
	virtual_points.clear()
	face_depth.clear()
	set_process(false)
	queue_redraw()
	selection.queue_redraw()

func _set_demo_face() -> void:
	if not mannequin: return
	video_size = MannequinView.FRAME
	face = mannequin_view.project_points(mannequin_view.reference)
	for i in face.size(): face[i] /= video_size
	face_depth = mannequin_view.face_depth()
	_face_live = true
	set_process(enabled and simulator != null)
	if enabled: _attach()
	_update_transform()
	preview_face_changed.emit()

func _rebuild() -> void:
	mannequin_view._roots_dirty = true
	var selected_id := selected_key()
	attachment = Profile.all_anchors(config)
	# Physics and color changes reuse the cached surface fit too.
	var placement := {}
	for key in ["style","strands","seed","mustache_enabled","mustache_density","mustache_width","mustache_thickness","mustache_lift",
		"brow_enabled","brow_count","brow_width","brow_thickness","brow_lift","brow_arch","brow_style",
		"hair_style","hair_count","hawk_width","hair_width","hairline","crown_width","crown_height","crown_back",
		"chin_extension","jaw_expansion","ear_reach","sideburn_height","root_layers","coverage_fill","chin_back","side_back",
		"virtual_enabled","virtual_columns","virtual_rows","beard_virtual_roots","lower_root_depth",
		"beard_sideburns","sideburn_rise","sideburn_width"]: placement[key] = config[key]
	var anchors_only := {}
	for id in overrides:
		if overrides[id].has("anchor"): anchors_only[id] = {"anchor":overrides[id].anchor}
	var source: RefCounted = mannequin_view.surface if mannequin else surface
	if placement != _binding_config or anchors_only != _binding_overrides or root_bindings.is_empty() or _binding_shape != source.shape_signature():
		_binding_config = placement
		_binding_overrides = anchors_only
		_fit_bindings(source)
	mannequin_view.shared_root_bindings = root_bindings
	virtual_anchors.clear()
	virtual_points.clear()
	generated_indices.clear()
	for i in attachment.size():
		if attachment[i].synthetic: generated_indices.append(i)
	selected_strand = -1
	for i in attachment.size():
		if attachment[i].id == selected_id: selected_strand = i
	roots.resize(attachment.size())
	if simulator == null: return
	var attributes := PackedFloat32Array()
	var steps := PackedVector2Array()
	var options := PackedFloat32Array()
	attributes.resize(attachment.size() * 12)
	options.resize(attachment.size()*4)
	for i in attachment.size():
		var edit: Dictionary = overrides.get(attachment[i].id, {})
		var regional := Groom.strand_settings(config,attachment[i])
		var root_color := Color.html(edit.get("root_color", regional.root_color))
		var tip_color := Color.html(edit.get("tip_color", regional.tip_color))
		var values := [float(regional.length) * float(edit.get("length", 1.0)),
			edit.get("root_width", regional.root_width), edit.get("tip_width", regional.tip_width), edit.get("curl", regional.curl),
			root_color.r, root_color.g, root_color.b, root_color.a, tip_color.r, tip_color.g, tip_color.b, tip_color.a]
		for j in 12: attributes[i*12+j] = values[j]
		steps.append_array(Profile.strand_steps(config,overrides,i,attachment[i]))
		options[i*4] = regional.mode
		options[i*4+1] = regional.hold
		options[i*4+2] = 1.0 if regional.collision else 0.0
		options[i*4+3] = 1.0 if attachment[i].region == "mustache" else 0.0
	var physics := config.duplicate()
	physics.length = 1.0 # Attributes carry absolute lengths in face widths for every region.
	if not simulator.configure(attachment.size(), int(config.segments), physics, attributes, steps, options):
		last_error = "The beard configuration could not be applied."
		return
	if not simulator.set_render_order(render_order):
		last_error = "The strand layering could not be applied."
		return
	last_error = ""
	root_markers.material.set_shader_parameter("point_color",Color.html(config.generated_root_color))
	virtual_markers.material.set_shader_parameter("point_color",Color.html(config.virtual_color))
	if _face_live: _attach()
	queue_redraw()

func _attach() -> void:
	if simulator == null or face.size() < 455: return
	if mannequin:
		_attach_mannequin()
		return
	if not external_surface: surface.update(face,face_depth,video_size)
	_update_binding_shape(surface)
	var width: float = surface.width
	if width < 10: clear_face(); return
	var positions: PackedVector3Array = surface.sample(root_bindings)
	if positions.size() != attachment.size(): clear_face(); return
	roots.resize(positions.size())
	root_depth.resize(positions.size())
	for i in positions.size():
		roots[i] = Vector2(positions[i].x,positions[i].y)
		root_depth[i] = positions[i].z/video_size.x
	_apply_occlusion()
	var right: Vector3 = (surface.vertices[454]-surface.vertices[234]).normalized()
	var down: Vector3 = surface.vertices[152]-surface.vertices[10]
	down = (down-right*down.dot(right)).normalized()
	var mouth := (face[0] + face[17]) * .5 * video_size
	var radii := Vector2(((face[291]-face[61])*video_size).length()*.52,
		((face[17]-face[0])*video_size).length()*.55 + width*.015)
	if config.collisions or (config.mustache_enabled and config.mustache_collisions): simulator.set_head_surface(surface.vertices,surface.topology())
	else: simulator.set_head_surface(PackedVector3Array(),PackedInt32Array())
	if not simulator.set_anchors_3d(positions, width, down, right, mouth, radii): clear_face(); return
	live_view.visible = enabled
	_update_root_markers()
	_update_virtual_markers()

func _attach_mannequin() -> void:
	_update_binding_shape(mannequin_view.surface)
	roots = mannequin_view.attach_roots()
	var width := mannequin_view.face_width*mannequin_view.pixels_per_unit()
	var down3: Vector3 = mannequin_view.pivot.basis*Vector3.DOWN
	var right3: Vector3 = mannequin_view.pivot.basis*Vector3.RIGHT
	var down := down3*Vector3(1,-1,-1)
	var right := right3*Vector3(1,-1,-1)
	var mouth := (face[0]+face[17])*.5*video_size
	var radii := Vector2(((face[291]-face[61])*video_size).length()*.52,
		((face[17]-face[0])*video_size).length()*.55+width*.015)
	if config.collisions or (config.mustache_enabled and config.mustache_collisions):
		var head: PackedVector3Array = mannequin_view.surface.vertices.duplicate()
		for i in head.size():
			var world: Vector3 = mannequin_view.world_point(head[i]*Vector3(1,-1,-1))
			var pixel: Vector2 = mannequin_view.project_world(world)
			head[i] = Vector3(pixel.x,pixel.y,-world.z*mannequin_view.pixels_per_unit())
		simulator.set_head_surface(head,surface.topology())
	else: simulator.set_head_surface(PackedVector3Array(),PackedInt32Array())
	if not simulator.set_anchors_3d(mannequin_view.root_camera_positions,width,down,right,mouth,radii): clear_face(); return
	live_view.hide()
	_update_root_markers()
	_update_virtual_markers()

func _fit_bindings(source: RefCounted) -> void:
	root_bindings = SurfaceGroom.build(source,config,attachment,_binding_overrides)
	render_order = SurfaceGroom.draw_order(source,root_bindings,attachment)
	_binding_shape = source.shape_signature()
	mannequin_view.shared_root_bindings = root_bindings
	mannequin_view._roots_dirty = true

func _update_binding_shape(source: RefCounted) -> void:
	if _binding_shape == source.shape_signature(): return
	_fit_bindings(source)
	if simulator: simulator.set_render_order(render_order)

func _update_virtual_markers() -> void:
	# General landmarks own the shared surface guides, independently of hair.
	virtual_markers.hide()
	if mannequin: mannequin_view.set_dots("surface",PackedVector3Array(),Color.WHITE,2,false)
	return

func _update_root_markers() -> void:
	if mannequin:
		var generated := PackedVector3Array()
		for index in generated_indices:
			if index < mannequin_view.root_positions.size(): generated.append(mannequin_view.root_positions[index])
		mannequin_view.set_dots("generated",generated,Color.html(config.generated_root_color),2,guides_visible and enabled and bool(config.show_generated_roots))
		root_markers.hide()
		return
	root_markers.visible = guides_visible and enabled and _face_live and bool(config.show_generated_roots)
	if not root_markers.visible or root_markers.multimesh == null: return
	var mesh := root_markers.multimesh
	if mesh.instance_count != generated_indices.size(): mesh.instance_count = generated_indices.size()
	if generated_indices.is_empty(): return
	var diameter := 4.0/maxf(.01,minf(size.x/video_size.x,size.y/video_size.y))
	var buffer := PackedFloat32Array()
	buffer.resize(generated_indices.size()*12)
	for j in generated_indices.size():
		var root := roots[generated_indices[j]]
		buffer[j*12] = diameter; buffer[j*12+3] = root.x
		buffer[j*12+5] = diameter; buffer[j*12+7] = root.y
		buffer[j*12+8] = root_depth[generated_indices[j]] if generated_indices[j] < root_depth.size() else 0.0
	mesh.buffer = buffer

func _process(delta: float) -> void:
	if not mannequin and (not face_seen_at or Time.get_ticks_msec() - face_seen_at > 250):
		clear_face()
	if not _face_live or simulator == null: return
	var started := Time.get_ticks_usec()
	simulator.advance(delta)
	var buffer: PackedFloat32Array = simulator.get_render_buffer()
	if mannequin: mannequin_view.update_hair(buffer,int(config.segments),enabled)
	else: live_view.update_hair(buffer,int(config.segments),surface.width)
	update_ms = (Time.get_ticks_usec() - started) / 1000.0
	if edit_strands and selected_strand >= 0: selection.queue_redraw()

func _update_transform() -> void:
	mannequin_toolbar.visible = mannequin and size.x >= 320
	mannequin_toolbar.get_child(4).visible = size.x >= 540
	var fit := minf(size.x / video_size.x, size.y / video_size.y)
	var origin := (size - video_size*fit)*.5
	_video_transform = Transform2D(Vector2(-fit if mirror else fit, 0), Vector2(0, fit),
		origin + Vector2(video_size.x*fit if mirror else 0.0, 0))
	live_view.set_frame(video_size,mirror)
	root_markers.transform = _video_transform
	virtual_markers.transform = _video_transform
	_apply_occlusion()
	_update_root_markers()
	_update_virtual_markers()
	queue_redraw()
	selection.queue_redraw()

func _apply_occlusion() -> void:
	live_view.set_occlusion(occlusion)
	if occlusion == null: return
	for item in [root_markers,virtual_markers]:
		if item.material: occlusion.apply(item.material,self,video_size,mirror,mannequin)

func _screen(point: Vector2) -> Vector2:
	return _video_transform * point

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and edit_strands and _face_live:
		var nearest := -1
		var distance := 22.0
		for i in roots.size():
			var d := _screen(roots[i]).distance_to(event.position)
			if d < distance: distance = d; nearest = i
		selected_strand = nearest
		strand_selected.emit(nearest)
		queue_redraw()
		selection.queue_redraw()
	elif event is InputEventMouseMotion and mannequin and not edit_strands and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		mannequin_view.orbit(event.relative)
	elif event is InputEventMouseButton and mannequin and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			mannequin_view.set_pose(mannequin_view.yaw,mannequin_view.pitch,
				mannequin_view.zoom*(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.1))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click and not edit_strands:
			mannequin_view.reset_view()

func _draw_selection() -> void:
	if enabled and edit_strands and _face_live:
		for root in roots: selection.draw_circle(_screen(root), 1.4, Color(1,1,1,.4))
		if selected_strand >= 0 and simulator:
			var points: PackedVector2Array = simulator.get_strand_points(selected_strand)
			for i in points.size(): points[i] = _screen(points[i])
			if points.size() > 1: selection.draw_polyline(points, Color("68dfc3"), 2, true)
