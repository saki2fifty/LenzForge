extends Control
## One instanced draw replaces hundreds of separately tessellated circles.
var points: PackedVector2Array = []
var mirror := true
var point_size := 2.0
var tint := Color("68dfc3")
var show_points := true
var video_size := Vector2(1280, 720)
var instances := MultiMesh.new()
var preview_surface: Control
var depth := PackedFloat32Array()
var occlusion: RefCounted

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	instances.mesh = quad
	var dots := ShaderMaterial.new()
	dots.shader = preload("res://landmarks.gdshader")
	material = dots
	resized.connect(queue_redraw)

func _draw() -> void:
	if is_instance_valid(preview_surface) and preview_surface.active:
		preview_surface.set_dots("reference",preview_surface.reference,tint,point_size,show_points)
		return
	if not show_points or points.is_empty():
		return
	if instances.instance_count < points.size():
		instances.instance_count = points.size()
	instances.visible_instance_count = points.size()
	var scale_factor := minf(size.x / video_size.x, size.y / video_size.y)
	var fitted := video_size * scale_factor
	var origin := (size - fitted) * 0.5
	var diameter := point_size * 2.0
	for index in points.size():
		var point := points[index]
		var uv := Vector2(1.0 - point.x if mirror else point.x, point.y)
		instances.set_instance_transform_2d(index, Transform2D(
			Vector2(diameter, 0), Vector2(0, diameter), origin + uv * fitted))
		instances.set_instance_custom_data(index, Color(depth[index] if index < depth.size() else 0.0,0,0,0))
	material.set_shader_parameter("point_color", tint)
	if occlusion: occlusion.apply(material,self,video_size,mirror)
	draw_multimesh(instances, null)
