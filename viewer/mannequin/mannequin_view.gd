extends Control
## On-demand 3D preview. The head is constructed only when first opened.
const HeadModel = preload("res://mannequin/head_model.gd")
const Groom = preload("res://beard/groom_regions.gd")
signal pose_changed
const FRAME := Vector2(1280,720)
var viewport := SubViewport.new()
var camera: Camera3D
var pivot: Node3D
var picture := TextureRect.new()
var reference := PackedVector3Array()
var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var active := false
var mirror := true
var face_width := 0.0
var dots: Dictionary = {}
var hair: MultiMeshInstance3D
var hair_material := ShaderMaterial.new()
var hair_texture: ImageTexture
var root_texture: ImageTexture
var hair_image: Image
var root_positions := PackedVector3Array()
var _built := false
var _roots_dirty := true
var _surface_bins: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(FRAME)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	hide()

func _ready() -> void:
	resized.connect(_resize)
	_resize()

func set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		_build()
		picture.texture = viewport.get_texture()
		request_frame()
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _built: hair.hide()

func _build() -> void:
	if _built: return
	_built = true
	camera = Camera3D.new()
	pivot = Node3D.new()
	hair = MultiMeshInstance3D.new()
	reference = HeadModel.reference_points()
	_surface_bins = HeadModel.surface_bins(reference)
	face_width = reference[454].distance_to(reference[234])
	viewport.add_child(pivot)
	pivot.add_child(HeadModel.build(reference))
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0,-2,50)
	camera.size = 36
	camera.current = true
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101925")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d6e5")
	environment.ambient_light_energy = .45
	world.environment = environment
	viewport.add_child(world)
	for light in [[Vector3(-35,-32,0),1.1,Color("fff0d9")],[Vector3(15,140,0),.65,Color("9ccee2")]]:
		var lamp := DirectionalLight3D.new()
		lamp.rotation_degrees = light[0]; lamp.light_energy = light[1]; lamp.light_color = light[2]
		viewport.add_child(lamp)
	for key in ["reference","extensions","generated","surface"]:
		var drawing := MultiMeshInstance3D.new()
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mesh.mesh = quad
		drawing.multimesh = mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://mannequin/points.gdshader")
		drawing.material_override = material
		drawing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(drawing)
		dots[key] = drawing
	hair.multimesh = MultiMesh.new()
	hair.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	hair.multimesh.mesh = quad
	hair_material.shader = preload("res://mannequin/strands_3d.gdshader")
	hair_material.set_shader_parameter("units_per_pixel",1/pixels_per_unit())
	hair_material.set_shader_parameter("camera_y",camera.position.y)
	hair.material_override = hair_material
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hair.custom_aabb = AABB(Vector3(-100,-100,-100),Vector3(200,200,200))
	viewport.add_child(hair)

func _resize() -> void:
	# Match display resolution, including tiny library thumbnails; cap at 720p.
	var unit := clampi(floori(minf(size.x/16,size.y/9)),4,80)
	viewport.size = Vector2i(unit*16,unit*9)
	request_frame()

func request_frame() -> void:
	if active:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		if not RenderingServer.frame_post_draw.is_connected(_frame_rendered):
			RenderingServer.frame_post_draw.connect(_frame_rendered,CONNECT_ONE_SHOT)

func _frame_rendered() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_pose(new_yaw: float, new_pitch: float, new_zoom := 1.0) -> void:
	yaw = wrapf(new_yaw,-180,180)
	pitch = clampf(new_pitch,-70,70)
	zoom = clampf(new_zoom,.55,2.0)
	pivot.rotation_degrees = Vector3(pitch,yaw,0)
	camera.size = 36/zoom
	hair_material.set_shader_parameter("units_per_pixel",1/pixels_per_unit())
	pose_changed.emit()
	request_frame()

func reset_view() -> void:
	set_pose(0,0,1)

func orbit(motion: Vector2) -> void:
	set_pose(yaw+motion.x*.35*(-1 if mirror else 1),pitch+motion.y*.35,zoom)

func set_mirror(value: bool) -> void:
	mirror = value
	picture.flip_h = value

func pixels_per_unit() -> float:
	return FRAME.y/camera.size

func world_point(local: Vector3) -> Vector3:
	return pivot.transform*local

func project_world(world: Vector3) -> Vector2:
	return FRAME*.5+Vector2(world.x,-world.y+camera.position.y)*pixels_per_unit()

func project_points(local_points: PackedVector3Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	projected.resize(local_points.size())
	for i in local_points.size(): projected[i] = project_world(world_point(local_points[i]))
	return projected

func face_depth() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(reference.size())
	for i in reference.size(): result[i] = -world_point(reference[i]).z*pixels_per_unit()/FRAME.x
	return result

func extension_points(model: RefCounted) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not model.config.enabled: return result
	result.resize(model.offsets.size())
	for i in result.size():
		var offset: Vector3 = model.offsets[i]
		result[i] = reference[model.source_a[i]].lerp(reference[model.source_b[i]],model.weights[i])+Vector3(offset.x,-offset.y,-offset.z)*face_width
	return result

func set_dots(key: String, points: PackedVector3Array, color: Color, radius: float, shown: bool) -> void:
	if not _built: return
	var drawing: MultiMeshInstance3D = dots[key]
	drawing.visible = shown and not points.is_empty()
	if drawing.visible:
		var mesh := drawing.multimesh
		if mesh.instance_count != points.size(): mesh.instance_count = points.size()
		var fit := maxf(.01,minf(size.x/FRAME.x,size.y/FRAME.y))
		var diameter := radius*2/fit/pixels_per_unit()
		for i in points.size():
			mesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*diameter),world_point(points[i])+Vector3(0,0,.06)))
		drawing.material_override.set_shader_parameter("point_color",color)
	request_frame()

func bound_points(bindings: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for b in bindings:
		var ids: Vector3i = b.indices
		var weights: Vector3 = b.weights
		var offset: Vector3 = b.offset
		result.append(reference[ids.x]*weights.x+reference[ids.y]*weights.y+reference[ids.z]*weights.z+Vector3(offset.x,-offset.y,-offset.z)*face_width)
	return result

func attach_roots(config: Dictionary, bindings: Array, virtual_surface: PackedVector3Array) -> PackedVector2Array:
	# Use the established grooming rules in the neutral face plane, then rotate
	# the resulting 3D roots. This stays well-defined at profile and rear views.
	if _roots_dirty:
		_build_roots(config,bindings,virtual_surface)
		_roots_dirty = false
	var positions := PackedVector2Array()
	positions.resize(root_positions.size())
	var depths := PackedFloat32Array()
	depths.resize(root_positions.size())
	for i in root_positions.size():
		var world := world_point(root_positions[i])
		positions[i] = project_world(world)
		depths[i] = world.z
	var data := Image.create_from_data(1,bindings.size(),false,Image.FORMAT_RF,depths.to_byte_array())
	if root_texture == null or root_texture.get_height() != bindings.size(): root_texture = ImageTexture.create_from_image(data)
	else: root_texture.update(data)
	hair_material.set_shader_parameter("root_depth",root_texture)
	return positions

func _build_roots(config: Dictionary, bindings: Array, virtual_surface: PackedVector3Array) -> void:
	var neutral := PackedVector2Array()
	for p in reference: neutral.append((FRAME*.5+Vector2(p.x,-p.y+camera.position.y)*pixels_per_unit())/FRAME)
	var surface := PackedVector2Array()
	for p in virtual_surface: surface.append(FRAME*.5+Vector2(p.x,-p.y+camera.position.y)*pixels_per_unit())
	var positions := Groom.root_positions(config,bindings,neutral,FRAME,surface)
	root_positions.resize(bindings.size())
	for i in bindings.size():
		var b: Dictionary = bindings[i]
		var z: float = reference[b.indices.x].z*b.weights.x+reference[b.indices.y].z*b.weights.y+reference[b.indices.z].z*b.weights.z
		if b.has("virtual_cell") and not virtual_surface.is_empty():
			var cell: Vector4i = b.virtual_cell; var w: Vector4 = b.virtual_weights
			z = virtual_surface[cell.x].z*w.x+virtual_surface[cell.y].z*w.y+virtual_surface[cell.z].z*w.z+virtual_surface[cell.w].z*w.w
		var xy := (positions[i]-FRAME*.5)/pixels_per_unit()
		var point := Vector3(xy.x,-xy.y+camera.position.y,z)
		if not b.has("virtual_cell"): point = HeadModel.fit_surface(point,_surface_bins,reference)
		root_positions[i] = point+Vector3(0,0,.08)

func update_hair(buffer: PackedFloat32Array, segments: int, shown: bool) -> void:
	if not _built: return
	hair.visible = shown
	if shown and not buffer.is_empty():
		var count := buffer.size()/16
		if hair.multimesh.instance_count != count:
			hair.multimesh.instance_count = count
			for i in count: hair.multimesh.set_instance_transform(i,Transform3D.IDENTITY)
		# Reuse the native packed output directly; no per-segment GDScript conversion.
		var rows := ceili(float(count)/64)
		var packed := buffer
		packed.resize(rows*64*16)
		if hair_image == null: hair_image = Image.new()
		hair_image.set_data(256,rows,false,Image.FORMAT_RGBAF,packed.to_byte_array())
		if hair_texture == null or hair_texture.get_height() != rows:
			hair_texture = ImageTexture.create_from_image(hair_image)
			hair_material.set_shader_parameter("strand_data",hair_texture)
		else: hair_texture.update(hair_image)
		hair_material.set_shader_parameter("segments",segments)
	request_frame()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("101925"))
