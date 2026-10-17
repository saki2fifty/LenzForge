extends Control
## Transparent, on-demand 3D hair layer composited over the camera image.
var viewport := SubViewport.new()
var picture := TextureRect.new()
var camera := Camera3D.new()
var hair := preload("res://beard/strand_mesh.gd").new()
var frame_size := Vector2(1280,720)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(1280,720)
	add_child(viewport)
	viewport.add_child(camera)
	viewport.add_child(hair)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position.z = 8192
	camera.far = 16384
	camera.current = true
	hair.shader_material.set_shader_parameter("units_per_pixel",1.0)
	hair.shader_material.set_shader_parameter("camera_y",0.0)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var composite := ShaderMaterial.new()
	composite.shader = preload("res://beard/composite.gdshader")
	picture.material = composite
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	picture.texture = viewport.get_texture()
	hide()

func _ready() -> void:
	resized.connect(_resize)
	visibility_changed.connect(func():
		if not visible: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	set_frame(frame_size,false)

func set_frame(dimensions: Vector2, mirror: bool) -> void:
	frame_size = dimensions
	picture.flip_h = mirror
	camera.size = frame_size.y
	hair.shader_material.set_shader_parameter("frame_size",frame_size)
	_resize()

func _resize() -> void:
	var fit := minf(minf(1.0,720.0/frame_size.y),minf(size.x/frame_size.x,size.y/frame_size.y))
	var dimensions := Vector2i((frame_size*maxf(fit,.05)).round())
	if viewport.size != dimensions: viewport.size = dimensions

func set_occlusion(occlusion: RefCounted) -> void:
	var enabled: bool = occlusion != null and occlusion.enabled and occlusion.valid
	hair.shader_material.set_shader_parameter("head_occlusion_enabled",enabled)
	if enabled:
		hair.shader_material.set_shader_parameter("head_depth",occlusion.texture)
		hair.shader_material.set_shader_parameter("head_depth_bias",occlusion.width*occlusion.tolerance)

func update_hair(buffer: PackedFloat32Array, segments: int, face_width: float) -> void:
	hair.upload(buffer,segments,face_width)
	if visible: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
