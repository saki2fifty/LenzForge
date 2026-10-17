extends MultiMeshInstance3D
## One reusable upload and GPU depth/color passes for every hair region.
var shader_material := ShaderMaterial.new()
var data_image: Image
var data_texture: ImageTexture

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	shader_material.shader = preload("res://mannequin/strands_3d.gdshader")
	material_override = shader_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-16384,-16384,-16384),Vector3(32768,32768,32768))

func upload(buffer: PackedFloat32Array, segments: int, face_width: float) -> void:
	if buffer.is_empty(): return
	var count := buffer.size()/16
	if multimesh.instance_count != count:
		multimesh.instance_count = count
		for i in count: multimesh.set_instance_transform(i,Transform3D.IDENTITY)
	var rows := ceili(float(count)/64)
	var packed := buffer
	packed.resize(rows*64*16)
	if data_image == null: data_image = Image.new()
	data_image.set_data(256,rows,false,Image.FORMAT_RGBAF,packed.to_byte_array())
	if data_texture == null or data_texture.get_height() != rows:
		data_texture = ImageTexture.create_from_image(data_image)
		shader_material.set_shader_parameter("strand_data",data_texture)
	else: data_texture.update(data_image)
	shader_material.set_shader_parameter("segments",segments)
	shader_material.set_shader_parameter("strand_count",count/segments)
	shader_material.set_shader_parameter("layer_bias",face_width*.0005)
