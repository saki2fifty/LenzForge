extends RefCounted
## One low-resolution depth map per tracking result, shared by all live overlays.
const Frame = preload("res://tracking/face_frame.gd")
const Extensions = preload("res://tracking/face_extensions.gd")
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

func _init() -> void:
	if ClassDB.class_exists("FaceOccluder"): rasterizer = ClassDB.instantiate("FaceOccluder")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mannequin/assets/canonical_face.json"))
	for triangle in data.triangles: triangles.append_array(PackedInt32Array(triangle))
	var previous := PackedInt32Array(Extensions.OUTLINE)
	for ring in range(1,13):
		var next := PackedInt32Array()
		for i in previous.size(): next.append(468+(ring-1)*previous.size()+i)
		for i in previous.size():
			var j := (i+1)%previous.size()
			triangles.append_array(PackedInt32Array([previous[i],next[i],previous[j],previous[j],next[i],next[j]]))
		previous = next

func update(points: PackedVector2Array, depth: PackedFloat32Array, dimensions: Vector2) -> void:
	valid = false
	if not enabled or rasterizer == null or points.size() < 468 or depth.size() < 468: return
	var started := Time.get_ticks_usec()
	var basis := Frame.frame(points,dimensions,depth)
	if basis.is_empty(): return
	width = basis.width/dimensions.x
	var vertices := PackedVector3Array()
	for i in 468: vertices.append(Vector3(points[i].x*dimensions.x,points[i].y*dimensions.y,depth[i]*dimensions.x))
	var right: Vector3 = basis.right3
	var down: Vector3 = basis.down3
	var back: Vector3 = basis.back3
	var center := (vertices[234]+vertices[454])*.5
	# Close the measured face with a fitted cranium. This estimates unmeasured
	# scalp/back geometry; it does not claim camera depth or segmentation.
	for ring in range(1,13):
		var t := float(ring)/12
		var radial := cos(t*PI*.5)
		var reach := sin(t*PI*.5)
		for id in Extensions.OUTLINE:
			var local := vertices[id]-center
			var upper := maxf(-local.dot(down)/basis.width,0.0)
			var point := center+(right*local.dot(right)+down*local.dot(down))*radial
			point += back*lerpf(local.dot(back),head_depth*basis.width,reach)
			point -= down*upper*upper*crown*4*basis.width*sin(t*PI)
			vertices.append(point)
	for i in vertices.size(): vertices[i].z /= dimensions.x
	var image: Image = rasterizer.rasterize(vertices,triangles,dimensions,384)
	if image == null: return
	depth_image = image
	if texture == null or texture.get_size() != Vector2(image.get_size()): texture = ImageTexture.create_from_image(image)
	else: texture.update(image)
	valid = true
	update_ms = (Time.get_ticks_usec()-started)/1000.0

func apply(material: ShaderMaterial, canvas: Control, dimensions: Vector2, mirror: bool, preview := false) -> void:
	material.set_shader_parameter("occlusion_enabled",enabled and valid and not preview)
	if not enabled or not valid or preview: return
	var fit := minf(canvas.size.x/dimensions.x,canvas.size.y/dimensions.y)
	material.set_shader_parameter("head_depth",texture)
	material.set_shader_parameter("video_origin",canvas.global_position+(canvas.size-dimensions*fit)*.5)
	material.set_shader_parameter("video_extent",dimensions*fit)
	material.set_shader_parameter("occlusion_mirror",mirror)
	material.set_shader_parameter("depth_bias",width*tolerance)
