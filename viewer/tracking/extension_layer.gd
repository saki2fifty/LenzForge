extends Control
## Updates once per tracking result, one instanced draw, no strand simulation.
const Extensions = preload("res://tracking/face_extensions.gd")
signal settings_changed
signal tracking_changed
var model := Extensions.new()
var drawing := MultiMeshInstance2D.new()
var instances := MultiMesh.new()
var mirror := true
var video_size := Vector2(1280,720)
var face := PackedVector2Array()
var face_depth := PackedFloat32Array()
var face_seen_at := 0
var update_ms := 0.0
var preview := false
var preview_surface: Control
var buffer := PackedFloat32Array()
var occlusion: RefCounted
var guides_visible := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drawing)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	instances.mesh = quad
	drawing.multimesh = instances
	var dots := ShaderMaterial.new()
	dots.shader = preload("res://landmarks.gdshader")
	drawing.material = dots
	drawing.hide()

func _ready() -> void:
	set_process(false)
	resized.connect(_upload)

func set_settings(values: Dictionary) -> bool:
	if not model.configure(values): return false
	_refresh()
	settings_changed.emit()
	return true

func set_mirror(value: bool) -> void:
	mirror = value
	_upload()

func set_face(points: PackedVector2Array, dimensions: Vector2, depth: PackedFloat32Array = PackedFloat32Array(), is_preview := false) -> void:
	face = points
	face_depth = depth
	video_size = dimensions
	preview = is_preview
	face_seen_at = Time.get_ticks_msec()
	_refresh()

func clear_face() -> void:
	face.clear()
	face_depth.clear()
	model.points.clear()
	face_seen_at = 0
	drawing.hide()
	set_process(false)
	tracking_changed.emit()

func _refresh() -> void:
	var started := Time.get_ticks_usec()
	var previous_count := model.points.size()
	if is_instance_valid(preview_surface) and preview_surface.active:
		model.points = preview_surface.project_points(preview_surface.extension_points(model))
	else: model.update(face,video_size,face_depth)
	_upload()
	set_process(not preview and not face.is_empty())
	update_ms = (Time.get_ticks_usec()-started)/1000.0
	if previous_count != model.points.size(): tracking_changed.emit()

func _upload() -> void:
	if is_instance_valid(preview_surface) and preview_surface.active:
		preview_surface.set_dots("extensions",preview_surface.extension_points(model),Color.html(model.config.color),
			float(model.config.point_size),guides_visible and bool(model.config.show_points))
		drawing.hide()
		return
	drawing.visible = guides_visible and model.config.show_points and not model.points.is_empty()
	if not drawing.visible: return
	var fit := minf(size.x/video_size.x,size.y/video_size.y)
	if fit <= 0: drawing.hide(); return
	var origin := (size-video_size*fit)*.5
	drawing.transform = Transform2D(Vector2(-fit if mirror else fit,0),Vector2(0,fit),
		origin+Vector2(video_size.x*fit if mirror else 0.0,0))
	drawing.material.set_shader_parameter("point_color",Color.html(model.config.color))
	var count := model.points.size()
	if instances.instance_count != count: instances.instance_count = count
	buffer.resize(count*12)
	var diameter := float(model.config.point_size)*2/fit
	for i in count:
		buffer[i*12] = diameter; buffer[i*12+3] = model.points[i].x
		buffer[i*12+5] = diameter; buffer[i*12+7] = model.points[i].y
		buffer[i*12+8] = model.point_depth[i] if i < model.point_depth.size() else 0.0
	instances.buffer = buffer
	if occlusion: occlusion.apply(drawing.material,self,video_size,mirror,preview)

func _process(_delta: float) -> void:
	if Time.get_ticks_msec()-face_seen_at > 250: clear_face()
