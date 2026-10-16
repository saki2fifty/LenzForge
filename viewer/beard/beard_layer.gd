extends Control
const Profile = preload("res://beard/beard_profile.gd")
const Groom = preload("res://beard/groom_regions.gd")
const Head = preload("res://beard/virtual_head.gd")
signal changed
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
var instances := MultiMesh.new()
var drawing := MultiMeshInstance2D.new()
var root_markers := MultiMeshInstance2D.new()
var virtual_markers := MultiMeshInstance2D.new()
var virtual_anchors: Array = []
var virtual_points := PackedVector2Array()
var face_depth := PackedFloat32Array()
var selection := Control.new()
var attachment: Array = []
var generated_indices := PackedInt32Array()
var roots := PackedVector2Array()
var face := PackedVector2Array()
var face_seen_at := 0
var update_ms := 0.0
var last_error := ""
var _face_live := false
var _demo_offset := Vector2.ZERO

func _init() -> void:
	# Own child nodes even when controls are built outside the tree in tests.
	add_child(drawing)
	add_child(root_markers)
	add_child(virtual_markers)
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.draw.connect(_draw_selection)
	add_child(selection)

func _ready() -> void:
	set_process(false)
	if not ClassDB.class_exists("BeardSimulator"):
		last_error = "Run Setup.ps1 -SkipInstall to build beard physics."
		return
	simulator = ClassDB.instantiate("BeardSimulator")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = quad
	drawing.multimesh = instances
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://beard/strands.gdshader")
	drawing.material = shader
	drawing.hide()
	var marker_mesh := MultiMesh.new()
	marker_mesh.transform_format = MultiMesh.TRANSFORM_2D
	marker_mesh.mesh = quad
	root_markers.multimesh = marker_mesh
	var marker_material := ShaderMaterial.new()
	marker_material.shader = preload("res://landmarks.gdshader")
	root_markers.material = marker_material
	root_markers.hide()
	var virtual_mesh := MultiMesh.new()
	virtual_mesh.transform_format = MultiMesh.TRANSFORM_2D
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
	if not enabled: drawing.hide(); root_markers.hide(); virtual_markers.hide()
	elif mannequin: _set_demo_face()
	elif _face_live: _attach()
	queue_redraw()
	selection.queue_redraw()
	changed.emit()

func set_mannequin(value: bool) -> void:
	mannequin = value
	_demo_offset = Vector2.ZERO
	clear_face()
	if mannequin: _set_demo_face()
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
	face_seen_at = 0
	drawing.hide()
	root_markers.hide()
	virtual_markers.hide()
	virtual_points.clear()
	face_depth.clear()
	set_process(false)
	queue_redraw()
	selection.queue_redraw()

func _set_demo_face() -> void:
	video_size = Vector2(1280, 720)
	face = Profile.mannequin()
	face_depth.clear()
	for i in face.size(): face[i] += _demo_offset
	preview_face_changed.emit()
	_face_live = true
	set_process(enabled and simulator != null)
	if enabled: _attach()
	_update_transform()

func _rebuild() -> void:
	var selected_id := selected_key()
	attachment = Profile.all_anchors(config)
	virtual_anchors = Head.build(config) if config.virtual_enabled else []
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
	options.resize(attachment.size()*3)
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
		options[i*3] = regional.mode
		options[i*3+1] = regional.hold
		options[i*3+2] = 1.0 if regional.collision else 0.0
	var physics := config.duplicate()
	physics.length = 1.0 # Attributes carry absolute lengths in face widths for every region.
	if not simulator.configure(attachment.size(), int(config.segments), physics, attributes, steps, options):
		last_error = "The beard configuration could not be applied."
		return
	last_error = ""
	root_markers.material.set_shader_parameter("point_color",Color.html(config.generated_root_color))
	virtual_markers.material.set_shader_parameter("point_color",Color.html(config.virtual_color))
	var count := attachment.size() * int(config.segments)
	if instances.instance_count != count: instances.instance_count = count
	if _face_live: _attach()
	queue_redraw()

func _attach() -> void:
	if simulator == null or face.size() < 455: return
	var horizontal := (face[454] - face[234]) * video_size
	var width := horizontal.length()
	if width < 10: clear_face(); return
	if config.virtual_enabled:
		var basis := Head.frame(face,video_size,face_depth)
		if basis.is_empty(): clear_face(); return
		virtual_points = Head.project(virtual_anchors,face,video_size,basis)
	roots = Groom.root_positions(config,attachment,face,video_size,virtual_points)
	var down := Vector2(-horizontal.y, horizontal.x).normalized()
	var mouth := (face[0] + face[17]) * .5 * video_size
	var radii := Vector2(((face[291]-face[61])*video_size).length()*.52,
		((face[17]-face[0])*video_size).length()*.55 + width*.015)
	if not simulator.set_anchors(roots, width, down, mouth, radii): clear_face(); return
	drawing.visible = enabled
	_update_root_markers()
	_update_virtual_markers()

func _update_virtual_markers() -> void:
	virtual_markers.visible = enabled and _face_live and bool(config.virtual_enabled) and bool(config.show_virtual_landmarks)
	if not virtual_markers.visible or virtual_markers.multimesh == null: return
	var mesh := virtual_markers.multimesh
	if mesh.instance_count != virtual_points.size(): mesh.instance_count = virtual_points.size()
	var diameter := 4.5/maxf(.01,minf(size.x/video_size.x,size.y/video_size.y))
	var buffer := PackedFloat32Array()
	buffer.resize(virtual_points.size()*8)
	for i in virtual_points.size():
		buffer[i*8] = diameter; buffer[i*8+3] = virtual_points[i].x
		buffer[i*8+5] = diameter; buffer[i*8+7] = virtual_points[i].y
	mesh.buffer = buffer

func _update_root_markers() -> void:
	root_markers.visible = enabled and _face_live and bool(config.show_generated_roots)
	if not root_markers.visible or root_markers.multimesh == null: return
	var mesh := root_markers.multimesh
	if mesh.instance_count != generated_indices.size(): mesh.instance_count = generated_indices.size()
	if generated_indices.is_empty(): return
	var diameter := 4.0/maxf(.01,minf(size.x/video_size.x,size.y/video_size.y))
	var buffer := PackedFloat32Array()
	buffer.resize(generated_indices.size()*8)
	for j in generated_indices.size():
		var root := roots[generated_indices[j]]
		buffer[j*8] = diameter; buffer[j*8+3] = root.x
		buffer[j*8+5] = diameter; buffer[j*8+7] = root.y
	mesh.buffer = buffer

func _process(delta: float) -> void:
	if not mannequin and (not face_seen_at or Time.get_ticks_msec() - face_seen_at > 250):
		clear_face()
	if not _face_live or simulator == null: return
	var started := Time.get_ticks_usec()
	simulator.advance(delta)
	instances.buffer = simulator.get_render_buffer()
	update_ms = (Time.get_ticks_usec() - started) / 1000.0
	if edit_strands and selected_strand >= 0: selection.queue_redraw()

func _update_transform() -> void:
	var fit := minf(size.x / video_size.x, size.y / video_size.y)
	var origin := (size - video_size*fit)*.5
	drawing.transform = Transform2D(Vector2(-fit if mirror else fit, 0), Vector2(0, fit),
		origin + Vector2(video_size.x*fit if mirror else 0.0, 0))
	root_markers.transform = drawing.transform
	virtual_markers.transform = drawing.transform
	_update_root_markers()
	_update_virtual_markers()
	queue_redraw()
	selection.queue_redraw()

func _screen(point: Vector2) -> Vector2:
	return drawing.transform * point

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
		var fit := minf(size.x/video_size.x, size.y/video_size.y)
		_demo_offset += Vector2(-event.relative.x if mirror else event.relative.x, event.relative.y) / (video_size*fit)
		_demo_offset = _demo_offset.clamp(Vector2(-.2,-.2), Vector2(.2,.15))
		_set_demo_face()

func _draw() -> void:
	if mannequin:
		draw_rect(Rect2(Vector2.ZERO, size), Color("101925"))
		var outline := PackedVector2Array()
		for i in 64:
			var angle := float(i)/64*TAU
			outline.append(_screen((Vector2(.5 + sin(angle)*.135, .43 + cos(angle)*.31) + _demo_offset)*video_size))
		draw_colored_polygon(outline, Color("ae8470"))
		for x in [.447, .553]:
			var center := _screen((Vector2(x,.43)+_demo_offset)*video_size)
			draw_circle(center, maxf(2, size.y*.012), Color("322c30"))
		var mouth := _screen((Vector2(.5,.568)+_demo_offset)*video_size)
		draw_line(mouth-Vector2(size.x*.035,0), mouth+Vector2(size.x*.035,0), Color("70463e"), 3, true)

func _draw_selection() -> void:
	if enabled and edit_strands and _face_live:
		for root in roots: selection.draw_circle(_screen(root), 1.4, Color(1,1,1,.4))
		if selected_strand >= 0 and simulator:
			var points: PackedVector2Array = simulator.get_strand_points(selected_strand)
			for i in points.size(): points[i] = _screen(points[i])
			if points.size() > 1: selection.draw_polyline(points, Color("68dfc3"), 2, true)
