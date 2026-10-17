extends RefCounted
## One low-resolution depth map per tracking result, shared by all live overlays.
var enabled := true
var head_depth := .65
var crown := .20
var tolerance := .012
var width := 0.0
var texture: ImageTexture
var depth_image: Image
var rasterizer: RefCounted
var triangles := PackedInt32Array()
var update_ms := 0.0
var valid := false

var surface := preload("res://tracking/head_surface.gd").new()

func update(points: PackedVector2Array, depth: PackedFloat32Array, dimensions: Vector2) -> void:
	valid = false
	var started := Time.get_ticks_usec()
	surface.head_depth = head_depth
	surface.crown = crown
	surface.update(points,depth,dimensions)
	if not enabled or rasterizer == null or surface.vertices.is_empty() or depth.size() < 468: return
	width = surface.width/dimensions.x
	var image: Image = rasterizer.rasterize(surface.vertices,surface.topology(),dimensions,384,1.0/dimensions.x)
	if image == null: return
	depth_image = image
	if texture == null or texture.get_size() != Vector2(image.get_size()): texture = ImageTexture.create_from_image(image)
	else: texture.update(image)
	valid = true
	update_ms = (Time.get_ticks_usec()-started)/1000.0

func _init() -> void:
	if ClassDB.class_exists("FaceOccluder"): rasterizer = ClassDB.instantiate("FaceOccluder")
	triangles = surface.topology()

func apply(material: ShaderMaterial, canvas: Control, dimensions: Vector2, mirror: bool, preview := false) -> void:
	material.set_shader_parameter("occlusion_enabled",enabled and valid and not preview)
	if not enabled or not valid or preview: return
	var fit := minf(canvas.size.x/dimensions.x,canvas.size.y/dimensions.y)
	material.set_shader_parameter("head_depth",texture)
	material.set_shader_parameter("video_origin",canvas.global_position+(canvas.size-dimensions*fit)*.5)
	material.set_shader_parameter("video_extent",dimensions*fit)
	material.set_shader_parameter("occlusion_mirror",mirror)
	material.set_shader_parameter("depth_bias",width*tolerance)
